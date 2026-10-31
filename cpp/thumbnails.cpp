#include "loaf/thumbnails.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QImage>
#include <QImageReader>
#include <QMimeDatabase>
#include <QMutex>
#include <QProcess>
#include <QQuickImageResponse>
#include <QRunnable>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QUrl>

#include <QThread>
#include <QWaitCondition>

#include <cstring>

#include <atomic>

namespace loaf {
namespace {

QString cacheRoot()
{
    QString base = qEnvironmentVariable("XDG_CACHE_HOME");
    if (base.isEmpty())
        base = QDir::homePath() + QStringLiteral("/.cache");
    return base + QStringLiteral("/thumbnails");
}

struct Flavor {
    const char *dir;
    int size;
};

Flavor flavorFor(int wanted)
{
    if (wanted <= 128)
        return {"normal", 128};
    if (wanted <= 256)
        return {"large", 256};
    if (wanted <= 512)
        return {"x-large", 512};
    return {"xx-large", 1024};
}

// One parsed $XDG_DATA_DIRS/thumbnailers/*.thumbnailer entry.
struct Thumbnailer {
    QString exec;
    QStringList mimes;
};

QList<Thumbnailer> loadThumbnailers()
{
    QList<Thumbnailer> out;
    QStringList dirs = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, QStringLiteral("thumbnailers"),
                                                 QStandardPaths::LocateDirectory);
    QSet<QString> seen;
    for (const QString &dir : dirs) {
        const QFileInfoList files = QDir(dir).entryInfoList({QStringLiteral("*.thumbnailer")}, QDir::Files);
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
                if (line.startsWith(QLatin1Char('['))) {
                    inGroup = line == QLatin1String("[Thumbnailer Entry]");
                    continue;
                }
                if (!inGroup)
                    continue;
                const int eq = line.indexOf(QLatin1Char('='));
                if (eq < 0)
                    continue;
                const QString key = line.left(eq).trimmed();
                const QString value = line.mid(eq + 1).trimmed();
                if (key == QLatin1String("Exec"))
                    t.exec = value;
                else if (key == QLatin1String("TryExec"))
                    tryExec = value;
                else if (key == QLatin1String("MimeType"))
                    t.mimes = value.split(QLatin1Char(';'), Qt::SkipEmptyParts);
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
    for (const Thumbnailer &t : thumbnailers()) {
        for (const QString &m : t.mimes) {
            if (mime.inherits(m))
                return &t;
        }
    }
    return nullptr;
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
        if (c == QLatin1Char('"')) {
            inQuote = !inQuote;
            has = true;
        } else if (c.isSpace() && !inQuote) {
            if (has || !cur.isEmpty())
                args << cur;
            cur.clear();
            has = false;
        } else if (c == QLatin1Char('%') && i + 1 < exec.size()) {
            const QChar code = exec.at(++i);
            switch (code.toLatin1()) {
            case 'i': cur += input; break;
            case 'u': cur += uri; break;
            case 'o': cur += output; break;
            case 's': cur += QString::number(size); break;
            case '%': cur += QLatin1Char('%'); break;
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
    static const char *safe = "-_.!~*'()/&=:@+$,";
    QByteArray out("file://");
    for (unsigned char c : rawPath) {
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || (c && std::strchr(safe, c))) {
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
        m_error = image.isNull() && error.isEmpty() ? QStringLiteral("no thumbnail") : error;
        emit finished();
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
    ThumbWork(const QByteArray &rawPath, const QSize &requested, bool cover, const std::atomic<bool> &cancelled)
        : m_raw(rawPath), m_path(QFile::decodeName(rawPath)), m_requested(requested), m_cover(cover),
          m_cancelled(cancelled) {}

    bool stopped() const { return m_cancelled.load() || g_shutdown.load(); }

    QImage m_image;
    QString m_error;

    void produce()
    {
        const QFileInfo fi(m_path);
        if (!fi.isFile() || !fi.isReadable()) {
            m_error = QStringLiteral("not a readable file");
            return;
        }
        const QString root = cacheRoot();
        // Never thumbnail the thumbnail cache itself (spec).
        if (fi.absoluteFilePath().startsWith(root + QLatin1Char('/')))
            return loadPlain(fi);

        const int wanted = qMax(m_requested.width(), m_requested.height()) > 0
            ? qMax(m_requested.width(), m_requested.height()) : 128;
        // A cropped thumbnail needs its short side to fill the box: one flavor
        // up still covers it for images up to 2:1.
        const Flavor flavor = flavorFor(m_cover ? wanted * 2 : wanted);
        const QByteArray uri = glibFileUri(m_raw);
        const QString md5 = QString::fromLatin1(QCryptographicHash::hash(uri, QCryptographicHash::Md5).toHex());
        const QString mtime = QString::number(fi.lastModified().toSecsSinceEpoch());
        const QString cached = root + QLatin1Char('/') + QLatin1String(flavor.dir) + QLatin1Char('/') + md5 + QStringLiteral(".png");
        const QString failMarker = root + QStringLiteral("/fail/loaf-1.0/") + md5 + QStringLiteral(".png");

        // 1. Valid cached thumbnail?
        {
            QImageReader r(cached);
            if (r.canRead() && r.text(QStringLiteral("Thumb::MTime")) == mtime) {
                QImage img = r.read();
                if (!img.isNull())
                    return finish(img);
            }
        }
        // 2. Known failure for this version of the file?
        {
            QImageReader r(failMarker);
            if (r.canRead() && r.text(QStringLiteral("Thumb::MTime")) == mtime) {
                m_error = QStringLiteral("thumbnailing failed before");
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
                if (r.canRead() && r.text(QStringLiteral("Thumb::MTime")) == mtime)
                    return finish(r.read());
                m_error = QStringLiteral("no thumbnail");
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
            m_error = QStringLiteral("no thumbnailer could handle this file");
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
        const QString out = tmp.filePath(QStringLiteral("thumb.png"));
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
        img.setText(QStringLiteral("Thumb::URI"), QString::fromLatin1(uri));
        img.setText(QStringLiteral("Thumb::MTime"), mtime);
        img.setText(QStringLiteral("Software"), QStringLiteral("Loaf"));
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
            const QSize crop = out.size().boundedTo(m_requested);
            m_image = out.copy((out.width() - crop.width()) / 2, (out.height() - crop.height()) / 2,
                               crop.width(), crop.height());
            return;
        }
        if (m_requested.isValid() && !m_requested.isEmpty()
            && (img.width() > m_requested.width() || img.height() > m_requested.height()))
            m_image = img.scaled(m_requested, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        else
            m_image = img;
    }

    QByteArray m_raw;
    QString m_path;
    QSize m_requested;
    bool m_cover;
    const std::atomic<bool> &m_cancelled;
};

} // namespace

ThumbnailProvider::ThumbnailProvider()
{
    // Thumbnailing is I/O and CPU heavy: two workers keep scrolling smooth
    // on low-end machines without starving the UI.
    m_pool.setMaxThreadCount(qBound(1, QThread::idealThreadCount() / 2, 2));
    m_pool.setExpiryTimeout(30000);
}

ThumbnailProvider::~ThumbnailProvider()
{
    // Don't make quitting wait for queued thumbnails.
    g_shutdown.store(true);
    m_pool.clear();
    m_pool.waitForDone();
}

ThumbRunnable::ThumbRunnable(const QByteArray &path, const QSize &requested, bool cover,
                             std::shared_ptr<std::atomic<bool>> cancelled)
    : m_path(path), m_requested(requested), m_cover(cover), m_cancelled(std::move(cancelled))
{
    setAutoDelete(true);
}

void ThumbRunnable::run()
{
    ThumbWork work(m_path, m_requested, m_cover, *m_cancelled);
    if (!m_cancelled->load() && !g_shutdown.load())
        work.produce();
    Q_EMIT done(work.m_image, work.m_error);
}

// id = hex(UTF-8/raw path bytes) "-" mtime ["/cover"]; hex keeps any byte
// sequence (spaces, '%', '#', non-UTF-8) unambiguous inside an image URL.
// "/cover" asks for an image that fills the requested size (cropped tiles)
// instead of fitting inside it.
static QByteArray pathFromId(const QString &id)
{
    const int dash = id.indexOf(QLatin1Char('-'));
    const QByteArray hex = (dash >= 0 ? id.left(dash) : id).toLatin1();
    return QByteArray::fromHex(hex);
}

QQuickImageResponse *ThumbnailProvider::requestImageResponse(const QString &id, const QSize &requestedSize)
{
    auto cancelled = std::make_shared<std::atomic<bool>>(false);
    auto *response = new ThumbResponse(cancelled);
    const bool cover = id.endsWith(QLatin1String("/cover"));
    auto *runnable = new ThumbRunnable(pathFromId(id), requestedSize, cover, cancelled);
    QObject::connect(runnable, &ThumbRunnable::done, response, &ThumbResponse::handleDone, Qt::QueuedConnection);
    m_pool.start(runnable);
    return response;
}

} // namespace loaf
