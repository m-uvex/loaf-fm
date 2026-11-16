#include "loaf/thumbnails.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QMimeDatabase>
#include <QMutex>
#include <QPainter>
#include <QProcess>
#include <QQuickImageResponse>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QThread>
#include <QWaitCondition>

#include <algorithm>
#include <atomic>
#include <string_view>

using namespace Qt::StringLiterals;
namespace loaf {
namespace {

QString cacheRoot()
{
    QString base = qEnvironmentVariable("XDG_CACHE_HOME");
    if (base.isEmpty())
        base = QDir::homePath() + u"/.cache"_s;
    return base + u"/thumbnails"_s;
}

struct Flavor {
    QLatin1StringView dir;
    int size;
};

Flavor flavorFor(int wanted)
{
    if (wanted <= 128)
        return {"normal"_L1, 128};
    if (wanted <= 256)
        return {"large"_L1, 256};
    if (wanted <= 512)
        return {"x-large"_L1, 512};
    return {"xx-large"_L1, 1024};
}

// One parsed $XDG_DATA_DIRS/thumbnailers/*.thumbnailer entry.
struct Thumbnailer {
    QString exec;
    QStringList mimes;
};

QList<Thumbnailer> loadThumbnailers()
{
    QList<Thumbnailer> out;
    QStringList dirs = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, u"thumbnailers"_s,
                                                 QStandardPaths::LocateDirectory);
    QSet<QString> seen;
    for (const QString &dir : dirs) {
        const QFileInfoList files = QDir(dir).entryInfoList({u"*.thumbnailer"_s}, QDir::Files);
        for (const QFileInfo &fi : files) {
            if (seen.contains(fi.fileName()))
                continue;
            seen.insert(fi.fileName());
            QFile f(fi.absoluteFilePath());
            if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
                continue;
            Thumbnailer t;
            QString tryExec;
            bool inGroup = false;
            while (!f.atEnd()) {
                const QString line = QString::fromUtf8(f.readLine()).trimmed();
                if (line.startsWith('['_L1)) {
                    inGroup = line == "[Thumbnailer Entry]"_L1;
                    continue;
                }
                if (!inGroup)
                    continue;
                const int eq = line.indexOf('='_L1);
                if (eq < 0)
                    continue;
                const QStringView view(line);
                const QStringView key = view.first(eq).trimmed();
                const QString value = view.sliced(eq + 1).trimmed().toString();
                if (key == "Exec"_L1)
                    t.exec = value;
                else if (key == "TryExec"_L1)
                    tryExec = value;
                else if (key == "MimeType"_L1)
                    t.mimes = value.split(';'_L1, Qt::SkipEmptyParts);
            }
            if (!tryExec.isEmpty() && QStandardPaths::findExecutable(tryExec).isEmpty() && !QFileInfo(tryExec).isExecutable())
                continue;
            if (!t.exec.isEmpty() && !t.mimes.isEmpty())
                out.append(t);
        }
    }
    return out;
}

const QList<Thumbnailer> &thumbnailers()
{
    static const QList<Thumbnailer> list = loadThumbnailers();
    return list;
}

const Thumbnailer *thumbnailerFor(const QMimeType &mime)
{
    const auto &list = thumbnailers();
    const auto it = std::ranges::find_if(list, [&mime](const Thumbnailer &t) {
        return std::ranges::any_of(t.mimes, [&mime](const QString &m) { return mime.inherits(m); });
    });
    return it != list.end() ? &*it : nullptr;
}

// Splits an Exec line, honouring quotes, and substitutes %i %u %o %s.
QStringList expandExec(const QString &exec, const QString &input, const QString &uri, const QString &output, int size)
{
    QStringList args;
    QString cur;
    bool inQuote = false;
    bool has = false;
    for (int i = 0; i < exec.size(); ++i) {
        const QChar c = exec.at(i);
        if (c == '"'_L1) {
            inQuote = !inQuote;
            has = true;
        } else if (c.isSpace() && !inQuote) {
            if (has || !cur.isEmpty())
                args << cur;
            cur.clear();
            has = false;
        } else if (c == '%'_L1 && i + 1 < exec.size()) {
            const QChar code = exec.at(++i);
            switch (code.toLatin1()) {
            case 'i': cur += input; break;
            case 'u': cur += uri; break;
            case 'o': cur += output; break;
            case 's': cur += QString::number(size); break;
            case '%': cur += '%'_L1; break;
            default: break;
            }
            has = true;
        } else {
            cur += c;
        }
    }
    if (has || !cur.isEmpty())
        args << cur;
    return args;
}

// Avoid launching several heavy thumbnailers for the same file at once;
// a second request waits for the first and then reads the cache.
QMutex g_inflightMutex;
QWaitCondition g_inflightDone;
QSet<QString> g_inflight;
// Set when the provider is destroyed: queued jobs return immediately.
std::atomic<bool> g_shutdown{false};

// file:// URI exactly as GLib's g_filename_to_uri() builds it, so the md5
// cache key and Thumb::URI match Nautilus, Dolphin and friends. Works on the
// raw file name bytes (non-UTF-8 names included).
QByteArray glibFileUri(const QByteArray &rawPath)
{
    constexpr std::string_view safe = "-_.!~*'()/&=:@+$,";
    QByteArray out("file://");
    for (unsigned char c : rawPath) {
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || (c && safe.contains(static_cast<char>(c)))) {
            out.append(char(c));
        } else {
            out.append('%');
            out.append(QByteArray::number(c, 16).toUpper().rightJustified(2, '0'));
        }
    }
    return out;
}

// Creates `dir` and missing parents with mode 0700 (thumbnail spec).
void makePrivateDir(const QString &dir)
{
    if (QFileInfo(dir).isDir())
        return;
    makePrivateDir(QFileInfo(dir).absolutePath());
    QDir().mkdir(dir, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
}

enum class GenResult { Ok, Failed, Transient };

class ThumbResponse : public QQuickImageResponse
{
public:
    explicit ThumbResponse(std::shared_ptr<std::atomic<bool>> cancelled)
        : m_cancelled(std::move(cancelled)) {}

    QQuickTextureFactory *textureFactory() const override
    {
        return QQuickTextureFactory::textureFactoryForImage(m_image);
    }
    QString errorString() const override { return m_error; }
    void cancel() override { m_cancelled->store(true); }

    void handleDone(const QImage &image, const QString &error)
    {
        m_image = image;
        m_error = image.isNull() && error.isEmpty() ? u"no thumbnail"_s : error;
        Q_EMIT finished();
    }

private:
    std::shared_ptr<std::atomic<bool>> m_cancelled;
    QImage m_image;
    QString m_error;
};

// The actual work, kept out of the QObject so it is easy to follow.
class ThumbWork
{
public:
    ThumbWork(const QByteArray &rawPath, const QSize &requested, bool cover, bool round,
              const std::atomic<bool> &cancelled)
        : m_raw(rawPath), m_path(QFile::decodeName(rawPath)), m_requested(requested), m_cover(cover),
          m_round(round), m_cancelled(cancelled) {}

    bool stopped() const { return m_cancelled.load() || g_shutdown.load(); }

    QImage m_image;
    QString m_error;

    void produce()
    {
        const QFileInfo fi(m_path);
        if (!fi.isFile() || !fi.isReadable()) {
            m_error = u"not a readable file"_s;
            return;
        }
        const QString root = cacheRoot();
        // Never thumbnail the thumbnail cache itself (spec).
        if (fi.absoluteFilePath().startsWith(root + '/'_L1))
            return loadPlain(fi);

        const int maxDim = std::max(m_requested.width(), m_requested.height());
        const int wanted = maxDim > 0 ? maxDim : 128;
        // A cropped thumbnail needs its short side to fill the box: one flavor
        // up still covers it for images up to 2:1.
        const Flavor flavor = flavorFor(m_cover ? wanted * 2 : wanted);
        const QByteArray uri = glibFileUri(m_raw);
        const QString md5 = QString::fromLatin1(QCryptographicHash::hash(uri, QCryptographicHash::Md5).toHex());
        const QString mtime = QString::number(fi.lastModified().toSecsSinceEpoch());
        const QString cached = root + '/'_L1 + flavor.dir + '/'_L1 + md5 + u".png"_s;
        const QString failMarker = root + u"/fail/loaf-1.0/"_s + md5 + u".png"_s;

        // 1. Valid cached thumbnail?
        {
            QImageReader r(cached);
            if (r.canRead() && r.text(u"Thumb::MTime"_s) == mtime) {
                QImage img = r.read();
                if (!img.isNull())
                    return finish(img);
            }
        }
        // 2. Known failure for this version of the file?
        {
            QImageReader r(failMarker);
            if (r.canRead() && r.text(u"Thumb::MTime"_s) == mtime) {
                m_error = u"thumbnailing failed before"_s;
                return;
            }
        }
        if (stopped())
            return;

        // Only one job generates a given file at a time; others wait for it.
        {
            QMutexLocker lock(&g_inflightMutex);
            bool waited = false;
            while (g_inflight.contains(cached) && !stopped()) {
                g_inflightDone.wait(&g_inflightMutex, 200);
                waited = true;
            }
            if (waited) {
                lock.unlock();
                QImageReader r(cached);
                if (r.canRead() && r.text(u"Thumb::MTime"_s) == mtime)
                    return finish(r.read());
                m_error = u"no thumbnail"_s;
                return;
            }
            g_inflight.insert(cached);
        }
        QImage img;
        const GenResult result = generate(fi, flavor.size, uri, img);
        {
            QMutexLocker lock(&g_inflightMutex);
            g_inflight.remove(cached);
            g_inflightDone.wakeAll();
        }
        if (stopped())
            return; // not a real failure: don't write a fail marker

        if (result != GenResult::Ok) {
            // Only remember real failures; timeouts and missing tools may work later.
            if (result == GenResult::Failed) {
                QImage marker(1, 1, QImage::Format_ARGB32);
                marker.fill(Qt::transparent);
                store(marker, failMarker, uri, mtime);
            }
            m_error = u"no thumbnailer could handle this file"_s;
            return;
        }
        if (img.width() > flavor.size || img.height() > flavor.size)
            img = img.scaled(flavor.size, flavor.size, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        store(img, cached, uri, mtime);
        finish(img);
    }

    GenResult generate(const QFileInfo &fi, int size, const QByteArray &uri, QImage &img)
    {
        static QMimeDatabase db;
        const QMimeType mime = db.mimeTypeForFile(fi);

        // Qt can decode it: scale while reading (JPEG decodes at 1/2..1/8).
        QImageReader reader(fi.absoluteFilePath());
        reader.setAutoTransform(true);
        const bool qtFormat = reader.canRead();
        if (qtFormat) {
            QSize full = reader.size();
            if (full.isValid() && (full.width() > size || full.height() > size))
                reader.setScaledSize(full.scaled(size, size, Qt::KeepAspectRatio));
            img = reader.read();
            if (!img.isNull())
                return GenResult::Ok;
        }
        if (stopped())
            return GenResult::Transient;

        // A system thumbnailer (ffmpegthumbnailer, evince, gdk-pixbuf, ...).
        const Thumbnailer *t = thumbnailerFor(mime);
        if (!t)
            return GenResult::Failed;
        QTemporaryDir tmp;
        if (!tmp.isValid())
            return GenResult::Transient;
        const QString out = tmp.filePath(u"thumb.png"_s);
        QStringList args = expandExec(t->exec, fi.absoluteFilePath(), QString::fromLatin1(uri), out, size);
        if (args.isEmpty())
            return GenResult::Failed;
        QProcess proc;
        proc.setProgram(args.takeFirst());
        proc.setArguments(args);
        proc.setStandardOutputFile(QProcess::nullDevice());
        proc.setStandardErrorFile(QProcess::nullDevice());
        proc.start();
        if (!proc.waitForStarted(3000))
            return GenResult::Transient;
        // Poll so a cancelled request (scrolled away, quitting) stops the tool.
        for (int waited = 0; waited < 15000; waited += 100) {
            if (proc.waitForFinished(100))
                break;
            if (stopped()) {
                proc.kill();
                proc.waitForFinished(1000);
                return GenResult::Transient;
            }
        }
        if (proc.state() != QProcess::NotRunning) {
            proc.kill();
            proc.waitForFinished(1000);
            return GenResult::Transient; // too slow (e.g. a network disk): retry later
        }
        if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0)
            return GenResult::Failed;
        img = QImage(out);
        return img.isNull() ? GenResult::Failed : GenResult::Ok;
    }

    static void store(const QImage &src, const QString &file, const QByteArray &uri, const QString &mtime)
    {
        QImage img = src;
        img.setText(u"Thumb::URI"_s, QString::fromLatin1(uri));
        img.setText(u"Thumb::MTime"_s, mtime);
        img.setText(u"Software"_s, u"Loaf"_s);
        makePrivateDir(QFileInfo(file).absolutePath());
        QSaveFile out(file);
        if (!out.open(QIODevice::WriteOnly))
            return;
        out.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
        if (img.save(&out, "PNG"))
            out.commit();
        else
            out.cancelWriting();
    }

    void loadPlain(const QFileInfo &fi)
    {
        QImageReader r(fi.absoluteFilePath());
        finish(r.read());
    }

    void finish(const QImage &img)
    {
        if (img.isNull())
            return;
        if (m_cover && m_requested.isValid() && !m_requested.isEmpty()) {
            // Scale to cover the box and keep its centre, so the QML crop
            // never has to upscale.
            QImage out = img;
            if (img.width() > m_requested.width() && img.height() > m_requested.height())
                out = img.scaled(m_requested, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
            // Keep the box's shape even for a small image, so rounded corners
            // aren't cut off by the QML crop.
            const QSize crop = m_requested.scaled(out.size(), Qt::KeepAspectRatio).boundedTo(m_requested);
            m_image = rounded(out.copy((out.width() - crop.width()) / 2, (out.height() - crop.height()) / 2,
                                       crop.width(), crop.height()));
            return;
        }
        if (m_requested.isValid() && !m_requested.isEmpty()
            && (img.width() > m_requested.width() || img.height() > m_requested.height()))
            m_image = rounded(img.scaled(m_requested, Qt::KeepAspectRatio, Qt::SmoothTransformation));
        else
            m_image = rounded(img);
    }

    // Corner radius ~1/6 of the short side, matching the frame drawn in QML.
    // Drawn with an image brush: unlike a clip path, it is antialiased.
    QImage rounded(const QImage &img) const
    {
        if (!m_round || img.isNull())
            return img;
        QImage out(img.size(), QImage::Format_ARGB32_Premultiplied);
        out.fill(Qt::transparent);
        QPainter p(&out);
        p.setRenderHint(QPainter::Antialiasing);
        p.setPen(Qt::NoPen);
        p.setBrush(QBrush(img));
        const qreal r = static_cast<qreal>(std::min(img.width(), img.height())) / 6.0;
        p.drawRoundedRect(QRectF(0, 0, img.width(), img.height()), r, r);
        return out;
    }

    QByteArray m_raw;
    QString m_path;
    QSize m_requested;
    bool m_cover;
    bool m_round;
    const std::atomic<bool> &m_cancelled;
};

// id = hex(UTF-8/raw path bytes) "-" mtime ["/cover"]["/round"]; hex keeps any
// byte sequence (spaces, '%', '#', non-UTF-8) unambiguous inside an image URL.
// "/cover" asks for an image that fills the requested size (cropped tiles)
// instead of fitting inside it. "/round" rounds the corners here, once, so
// QML needs no offscreen mask layer per thumbnail.
QByteArray pathFromId(const QString &id)
{
    const int dash = id.indexOf('-'_L1);
    const QByteArray hex = (dash >= 0 ? QStringView(id).first(dash) : QStringView(id)).toLatin1();
    return QByteArray::fromHex(hex);
}

} // namespace

ThumbnailProvider::ThumbnailProvider()
{
    // Thumbnailing is I/O and CPU heavy: two workers keep scrolling smooth
    // on low-end machines without starving the UI.
    m_pool.setMaxThreadCount(std::clamp(QThread::idealThreadCount() / 2, 1, 2));
    m_pool.setExpiryTimeout(30000);
}

ThumbnailProvider::~ThumbnailProvider()
{
    // Don't make quitting wait for queued thumbnails.
    g_shutdown.store(true);
    m_pool.clear();
    m_pool.waitForDone();
}

ThumbRunnable::ThumbRunnable(const QByteArray &path, const QSize &requested, bool cover, bool round,
                             std::shared_ptr<std::atomic<bool>> cancelled)
    : m_path(path), m_requested(requested), m_cover(cover), m_round(round), m_cancelled(std::move(cancelled))
{
    setAutoDelete(true);
}

void ThumbRunnable::run()
{
    ThumbWork work(m_path, m_requested, m_cover, m_round, *m_cancelled);
    if (!m_cancelled->load() && !g_shutdown.load())
        work.produce();
    Q_EMIT done(work.m_image, work.m_error);
}


QQuickImageResponse *ThumbnailProvider::requestImageResponse(const QString &id, const QSize &requestedSize)
{
    auto cancelled = std::make_shared<std::atomic<bool>>(false);
    auto *response = new ThumbResponse(cancelled);
    const bool cover = id.contains("/cover"_L1);
    const bool round = id.endsWith("/round"_L1);
    auto *runnable = new ThumbRunnable(pathFromId(id), requestedSize, cover, round, cancelled);
    QObject::connect(runnable, &ThumbRunnable::done, response, &ThumbResponse::handleDone, Qt::QueuedConnection);
    m_pool.start(runnable);
    return response;
}

} // namespace loaf
