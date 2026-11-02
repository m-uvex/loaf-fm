#include "loaf/native.h"
#include "loaf/portal.h"
#include "loaf/thumbnails.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusReply>
#include <QFileInfo>
#include <QGuiApplication>
#include <QLocale>
#include <QMimeData>
#include <QMimeDatabase>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>
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

void LoafNative::respondPicker(const QString &handle, uint code, const QString &resultsJson)
{
    if (m_portal)
        m_portal->respond(handle, code, resultsJson);
}

void LoafNative::cancelPicker(const QString &handle)
{
    respondPicker(handle, 1, QStringLiteral("{}"));
}

bool LoafNative::fileExists(const QString &path) const
{
    return QFileInfo::exists(path);
}
bool LoafNative::isDirectory(const QString &path) const
{
    return QFileInfo(path).isDir();
}


void LoafNative::setPickerTransient(QWindow *window, const QString &parentWindow, bool modal) const
{
    if (!window)
        return;
    // Wayland needs xdg-foreign to make one window transient for another,
    // which Qt Quick does not expose; X11 window ids work.
    if (QGuiApplication::platformName() != QLatin1String("xcb") || !parentWindow.startsWith(QLatin1String("x11:")))
        return;
    bool ok = false;
    const qulonglong id = parentWindow.mid(4).toULongLong(&ok, 0);
    if (!ok || id == 0)
        return;
    QWindow *parent = QWindow::fromWinId(static_cast<WId>(id));
    if (!parent)
        return;
    window->setTransientParent(parent);
    if (modal)
        window->setModality(Qt::WindowModal);
    // fromWinId only wraps the foreign window; drop the wrapper with the picker.
    connect(window, &QObject::destroyed, parent, &QObject::deleteLater);
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
    // mode: "tab" or "mini", optionally with ",new-window" or ",portal".
    const QString modeStr = toQString(mode);
    const bool newWindow = modeStr.contains(QLatin1String("new-window"));
    const bool portalMode = modeStr.contains(QLatin1String("portal"));
    native->setPortalMode(portalMode);
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

        // The portal backend serves file chooser requests on demand; in
        // portal mode (D-Bus activation) it is the reason we are running,
        // so losing the race to another backend means there is nothing to
        // do and the process can exit quietly.
        if (!native->initPortal(portalMode)) {
            if (portalMode)
                QTimer::singleShot(0, QCoreApplication::instance(), &QCoreApplication::quit);
            else
                qWarning("loaf: another backend already owns org.freedesktop.impl.portal.desktop.loaf");
        }
    }
    if (portalMode)
        // Only picker windows are shown; the process exits when the last
        // one closes and no file manager window was opened meanwhile.
        QGuiApplication::setQuitOnLastWindowClosed(false);

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

MimeFilterMatcher::MimeFilterMatcher(const rust::Vec<rust::String> &filterMimes)
{
    filterTypes.reserve(static_cast<qsizetype>(filterMimes.size()));
    for (const rust::String &filterMime : filterMimes)
        filterTypes.append(database.mimeTypeForName(toQString(filterMime)));
}

bool MimeFilterMatcher::matches(const rust::Str fileName) const
{
    const QMimeType actual = database.mimeTypeForFile(toQString(fileName), QMimeDatabase::MatchExtension);
    if (!actual.isValid())
        return false;
    for (const QMimeType &filter : filterTypes) {
        if (filter.isValid() && actual.inherits(filter.name()))
            return true;
    }
    return false;
}

std::unique_ptr<MimeFilterMatcher> new_mime_filter_matcher(const rust::Vec<rust::String> &filterMimes)
{
    return std::make_unique<MimeFilterMatcher>(filterMimes);
}

rust::String mime_comment_for(rust::Str mime)
{
    static QMimeDatabase db;
    return toRust(db.mimeTypeForName(toQString(mime)).comment());
}

void set_application_identity(rust::Str version)
{
    // Keep an alpha channel even when the window starts with a solid background;
    // users can enable translucency later without recreating the window.
    QQuickWindow::setDefaultAlphaBuffer(true);
    QCoreApplication::setApplicationVersion(toQString(version));
    QCoreApplication::setApplicationName(QStringLiteral("loaf"));
    QCoreApplication::setOrganizationName(QStringLiteral("loaf"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("Loaf"));
    QGuiApplication::setDesktopFileName(QStringLiteral("loaf"));
}

} // namespace loaf
