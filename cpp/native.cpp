#include "loaf/native.h"
#include "loaf/thumbnails.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QGuiApplication>
#include <QLocale>
#include <QMimeData>
#include <QMimeDatabase>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTranslator>
#include <QUrl>

namespace loaf {

static const char *kService = "io.github.m_uvex.Loaf";
static const char *kPath = "/io/github/m_uvex/Loaf";

static QString toQString(rust::Str s)
{
    return QString::fromUtf8(s.data(), static_cast<qsizetype>(s.size()));
}

static rust::String toRust(const QString &s)
{
    const QByteArray utf8 = s.toUtf8();
    return rust::String(utf8.constData(), static_cast<size_t>(utf8.size()));
}

// Accepts plain paths and file:// URIs; returns absolute local paths.
static QStringList toLocalPaths(const QStringList &items)
{
    QStringList out;
    for (const QString &item : items) {
        if (item.isEmpty())
            continue;
        // Loaf's own views (trash:///, recent:///, starred:///) pass through.
        if (item.startsWith(QLatin1String("trash:")) || item.startsWith(QLatin1String("recent:"))
            || item.startsWith(QLatin1String("starred:"))) {
            out << item;
            continue;
        }
        const QUrl url = item.startsWith(QLatin1Char('/')) ? QUrl::fromLocalFile(item) : QUrl::fromUserInput(item);
        if (url.isLocalFile())
            out << QFileInfo(url.toLocalFile()).absoluteFilePath();
    }
    return out;
}

LoafNative::LoafNative(QObject *parent)
    : QObject(parent)
{
    if (QClipboard *cb = QGuiApplication::clipboard()) {
        // Parse once per change: reading another app's clipboard can block,
        // so menus must never do it synchronously.
        connect(cb, &QClipboard::dataChanged, this, [this] {
            m_clipboard = readClipboard();
            Q_EMIT clipboardChanged();
        });
        m_clipboard = readClipboard();
    }
}

void LoafNative::setClipboardFiles(const QStringList &paths, bool cut)
{
    QList<QUrl> urls;
    QByteArray gnome = cut ? "cut" : "copy";
    QStringList plain;
    for (const QString &p : paths) {
        const QUrl u = QUrl::fromLocalFile(p);
        urls << u;
        gnome += '\n' + u.toEncoded();
        plain << p;
    }
    auto *data = new QMimeData;
    data->setUrls(urls);
    data->setData(QStringLiteral("x-special/gnome-copied-files"), gnome);
    data->setData(QStringLiteral("application/x-kde-cutselection"), cut ? "1" : "0");
    data->setData(QStringLiteral("application/x-loaf-files"), gnome);
    data->setText(plain.join(QLatin1Char('\n')));
    QGuiApplication::clipboard()->setMimeData(data);
}

QVariantMap LoafNative::clipboardFiles() const
{
    return m_clipboard;
}

QVariantMap LoafNative::readClipboard() const
{
    QVariantMap result{{QStringLiteral("cut"), false}, {QStringLiteral("paths"), QStringList()}};
    const QMimeData *data = QGuiApplication::clipboard()->mimeData();
    if (!data)
        return result;
    bool cut = false;
    QStringList paths;
    if (data->hasFormat(QStringLiteral("x-special/gnome-copied-files"))) {
        const QList<QByteArray> lines = data->data(QStringLiteral("x-special/gnome-copied-files")).split('\n');
        for (int i = 0; i < lines.size(); ++i) {
            const QByteArray line = lines[i].trimmed();
            if (i == 0 && (line == "cut" || line == "copy")) {
                cut = line == "cut";
                continue;
            }
            if (line.isEmpty())
                continue;
            const QUrl u = QUrl::fromEncoded(line);
            if (u.isLocalFile())
                paths << u.toLocalFile();
        }
    }
    if (paths.isEmpty() && data->hasUrls()) {
        for (const QUrl &u : data->urls()) {
            if (u.isLocalFile())
                paths << u.toLocalFile();
        }
        cut = data->data(QStringLiteral("application/x-kde-cutselection")) == "1";
    }
    result[QStringLiteral("cut")] = cut;
    result[QStringLiteral("paths")] = paths;
    return result;
}

bool LoafNative::clipboardHasFiles() const
{
    return !clipboardFiles().value(QStringLiteral("paths")).toStringList().isEmpty();
}

void LoafNative::setClipboardText(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
}

void LoafNative::clearClipboardIfOurs()
{
    const QMimeData *data = QGuiApplication::clipboard()->mimeData();
    if (data && data->hasFormat(QStringLiteral("application/x-loaf-files")))
        QGuiApplication::clipboard()->clear();
}

QString LoafNative::mimeType(const QString &path, bool sniffContents) const
{
    static QMimeDatabase db;
    return db.mimeTypeForFile(path, sniffContents ? QMimeDatabase::MatchDefault : QMimeDatabase::MatchExtension).name();
}

QString LoafNative::mimeComment(const QString &path) const
{
    static QMimeDatabase db;
    return db.mimeTypeForFile(path).comment();
}

QStringList LoafNative::takePendingOpen()
{
    QStringList out;
    out.swap(m_pending);
    return out;
}

void LoafNative::queueOpen(const QStringList &paths, const QString &mode)
{
    m_pending = paths;
    if (!mode.isEmpty())
        m_mode = mode;
    Q_EMIT openRequested(paths, mode);
}

bool LoafNative::isAdmin() const
{
    return !qEnvironmentVariable("LOAF_ADMIN").isEmpty();
}

FileManager1Adaptor::FileManager1Adaptor(QObject *host, LoafNative *native)
    : QDBusAbstractAdaptor(host), m_native(native) {}

void FileManager1Adaptor::ShowFolders(const QStringList &uris, const QString &)
{
    Q_EMIT m_native->openRequested(toLocalPaths(uris), QStringLiteral("tab"));
}

void FileManager1Adaptor::ShowItems(const QStringList &uris, const QString &)
{
    Q_EMIT m_native->openRequested(toLocalPaths(uris), QStringLiteral("select"));
}

void FileManager1Adaptor::ShowItemProperties(const QStringList &uris, const QString &)
{
    Q_EMIT m_native->openRequested(toLocalPaths(uris), QStringLiteral("properties"));
}

LoafAppAdaptor::LoafAppAdaptor(QObject *host, LoafNative *native)
    : QDBusAbstractAdaptor(host), m_native(native) {}

void LoafAppAdaptor::Open(const QStringList &paths, const QString &mode)
{
    Q_EMIT m_native->openRequested(toLocalPaths(paths), mode.isEmpty() ? QStringLiteral("tab") : mode);
}

bool forward_to_running_instance(const rust::Vec<rust::String> &paths, rust::Str mode)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected() || !bus.interface())
        return false;
    if (!bus.interface()->isServiceRegistered(QString::fromLatin1(kService)))
        return false;
    QStringList raw;
    for (const rust::String &p : paths)
        raw << QString::fromUtf8(p.data(), static_cast<qsizetype>(p.size()));
    QDBusMessage msg = QDBusMessage::createMethodCall(QString::fromLatin1(kService), QString::fromLatin1(kPath),
                                                      QStringLiteral("io.github.m_uvex.Loaf"), QStringLiteral("Open"));
    msg << toLocalPaths(raw) << toQString(mode);
    // A hung instance must not stall this launch for long.
    QDBusMessage reply = bus.call(msg, QDBus::Block, 3000);
    return reply.type() == QDBusMessage::ReplyMessage;
}

void setup_engine(QQmlApplicationEngine &engine, const rust::Vec<rust::String> &paths, rust::Str mode)
{
    auto *native = new LoafNative(&engine);
    QStringList raw;
    for (const rust::String &p : paths)
        raw << QString::fromUtf8(p.data(), static_cast<qsizetype>(p.size()));
    // mode: "tab" or "mini", optionally with ",new-window".
    const QString modeStr = toQString(mode);
    const bool newWindow = modeStr.contains(QLatin1String("new-window"));
    native->queueOpen(toLocalPaths(raw), modeStr.section(QLatin1Char(','), 0, 0));

    QDBusConnection bus = QDBusConnection::sessionBus();
    // A separate window or an admin (root) instance must not take over the
    // user's services.
    if (bus.isConnected() && !native->isAdmin() && !newWindow) {
        // One object per path, each exporting just its own interface.
        auto *appObj = new QObject(native);
        new LoafAppAdaptor(appObj, native);
        auto *fmObj = new QObject(native);
        new FileManager1Adaptor(fmObj, native);
        if (bus.registerService(QString::fromLatin1(kService)))
            bus.registerObject(QString::fromLatin1(kPath), appObj, QDBusConnection::ExportAdaptors);
        else
            qWarning("loaf: another instance already owns %s", kService);
        // FileManager1 stays with whichever file manager claimed it first.
        if (bus.registerService(QStringLiteral("org.freedesktop.FileManager1")))
            bus.registerObject(QStringLiteral("/org/freedesktop/FileManager1"), fmObj, QDBusConnection::ExportAdaptors);
    }

    auto *translator = new QTranslator(&engine);
    if (translator->load(QLocale(), QStringLiteral("loaf"), QStringLiteral("_"), QStringLiteral(":/i18n")))
        QCoreApplication::installTranslator(translator);

    engine.rootContext()->setContextProperty(QStringLiteral("nativeBridge"), native);
    engine.addImageProvider(QStringLiteral("thumb"), new ThumbnailProvider);
}

rust::String mime_type_for(rust::Str path, bool sniff)
{
    static QMimeDatabase db;
    return toRust(db.mimeTypeForFile(toQString(path), sniff ? QMimeDatabase::MatchDefault : QMimeDatabase::MatchExtension).name());
}

rust::String mime_comment_for(rust::Str mime)
{
    static QMimeDatabase db;
    return toRust(db.mimeTypeForName(toQString(mime)).comment());
}

// True when the saved window opacity is below 1. Only then does the window
// get an alpha channel: an opaque window lets the compositor skip blending
// it every frame, which matters on integrated GPUs.
static bool wantsAlphaBuffer()
{
    QString dir = qEnvironmentVariable("XDG_CONFIG_HOME");
    if (dir.isEmpty())
        dir = QDir::homePath() + QStringLiteral("/.config");
    QFile f(dir + QStringLiteral("/loaf/config.json"));
    if (!f.open(QIODevice::ReadOnly))
        return false;
    const QJsonValue v = QJsonDocument::fromJson(f.readAll()).object().value(QStringLiteral("backgroundOpacity"));
    bool ok = v.isDouble();
    const double opacity = v.isString() ? v.toString().toDouble(&ok) : v.toDouble(1.0);
    return ok && opacity < 0.999; // 0 (fully transparent) needs alpha too
}

static bool g_alphaBuffer = false;

bool LoafNative::alphaBuffer() const
{
    return g_alphaBuffer;
}

void set_application_identity(rust::Str version)
{
    g_alphaBuffer = wantsAlphaBuffer();
    QQuickWindow::setDefaultAlphaBuffer(g_alphaBuffer);
    QCoreApplication::setApplicationVersion(toQString(version));
    QCoreApplication::setApplicationName(QStringLiteral("loaf"));
    QCoreApplication::setOrganizationName(QStringLiteral("loaf"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("Loaf"));
    QGuiApplication::setDesktopFileName(QStringLiteral("loaf"));
}

} // namespace loaf
