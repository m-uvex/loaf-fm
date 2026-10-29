#include "loaf/native.h"
#include "loaf/thumbnails.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusArgument>
#include <QDBusUnixFileDescriptor>
#include <QEventLoop>
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QMutex>
#include <QMutexLocker>
#include <QTimer>
#include <fcntl.h>
#include <unistd.h>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
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

// Accepts local paths and Loaf MTP locations. MTP validation happens in Rust.
static QStringList toLocalPaths(const QStringList &items)
{
    QStringList out;
    for (const QString &item : items) {
        if (item.isEmpty())
            continue;
        if (item.startsWith(QLatin1String("mtp://"))) {
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
    QDBusConnection::sessionBus().connect(QStringLiteral("org.kde.kmtpd5"),
        QStringLiteral("/modules/kmtpd"), QStringLiteral("org.kde.kmtp.Daemon"),
        QStringLiteral("devicesChanged"), this, SLOT(notifyMtpDevicesChanged()));
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
    bool hasMtp = false;
    for (const QString &p : paths) {
        const bool mtp = p.startsWith(QLatin1String("mtp://"));
        hasMtp |= mtp;
        const QUrl u = mtp ? QUrl(p) : QUrl::fromLocalFile(p);
        urls << u;
        gnome += '\n' + u.toEncoded();
        plain << p;
    }
    auto *data = new QMimeData;
    // Loaf MTP addresses are private provider identities, not KIO URLs.
    // Keep them in our MIME format so copying between Loaf windows works.
    if (!hasMtp) {
        data->setUrls(urls);
        data->setData(QStringLiteral("x-special/gnome-copied-files"), gnome);
        data->setData(QStringLiteral("application/x-kde-cutselection"), cut ? "1" : "0");
    }
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
    const bool ours = data->hasFormat(QStringLiteral("application/x-loaf-files"));
    if (ours || data->hasFormat(QStringLiteral("x-special/gnome-copied-files"))) {
        const QList<QByteArray> lines = data->data(ours ? QStringLiteral("application/x-loaf-files") : QStringLiteral("x-special/gnome-copied-files")).split('\n');
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
            else if (ours && u.scheme() == QLatin1String("mtp") && !u.host().isEmpty())
                paths << u.toString(QUrl::FullyEncoded);
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

// Explicit messages avoid QDBusInterface's synchronous introspection before its
// timeout is set. These helpers run on Rust workers, never the GUI thread.
static QDBusMessage mtpCall(const QString &path, const QString &interface,
                           const QString &method, const QVariantList &arguments = {})
{
    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.kmtpd5"), path, interface, method);
    message.setArguments(arguments);
    return QDBusConnection::sessionBus().call(message, QDBus::Block, 1500);
}

static QVariantMap mtpProperties(const QString &path, const QString &interface)
{
    QDBusReply<QVariantMap> reply = mtpCall(path, QStringLiteral("org.freedesktop.DBus.Properties"),
                                         QStringLiteral("GetAll"), {interface});
    return reply.isValid() ? reply.value() : QVariantMap{};
}

rust::String list_kmtp_devices_json()
{
    // Plain Rust unit tests do not create a Qt application / D-Bus dispatcher.
    if (!QCoreApplication::instance())
        return toRust(QStringLiteral("[]"));
    QJsonArray array;
    QDBusReply<QList<QDBusObjectPath>> reply = mtpCall(QStringLiteral("/modules/kmtpd"),
        QStringLiteral("org.kde.kmtp.Daemon"), QStringLiteral("listDevices"));
    if (!reply.isValid())
        return toRust(QStringLiteral("[]")); // KDE MTP support is optional.
    for (const auto &device : reply.value()) {
        const auto properties = mtpProperties(device.path(), QStringLiteral("org.kde.kmtp.Device"));
        const QString udi = properties.value(QStringLiteral("udi")).toString();
        if (udi.isEmpty())
            continue; // Never silently open a different device via mtp:/.
        const QString name = properties.value(QStringLiteral("friendlyName")).toString();
        const QString udiHex = QString::fromLatin1(udi.toUtf8().toHex());
        const QString url = QStringLiteral("mtp://loaf/") + udiHex + QLatin1Char('/');
        quint64 total = 0, free = 0;
        QDBusReply<QList<QDBusObjectPath>> storages = mtpCall(device.path(),
            QStringLiteral("org.kde.kmtp.Device"), QStringLiteral("listStorages"));
        if (storages.isValid()) {
            for (const auto &storage : storages.value()) {
                const auto props = mtpProperties(storage.path(), QStringLiteral("org.kde.kmtp.Storage"));
                total += props.value(QStringLiteral("maxCapacity")).toULongLong();
                free += props.value(QStringLiteral("freeSpaceInBytes")).toULongLong();
            }
        }
        array.append(QJsonObject{{QStringLiteral("name"), name}, {QStringLiteral("udi"), udi},
            {QStringLiteral("url"), url},
            {QStringLiteral("model"), name}, {QStringLiteral("total_bytes"), static_cast<double>(total)},
            {QStringLiteral("free_bytes"), static_cast<double>(free)}});
    }
    return toRust(QString::fromUtf8(QJsonDocument(array).toJson(QJsonDocument::Compact)));
}

static rust::String mtpError(const QString &message)
{
    const QJsonObject result{{QStringLiteral("entries"), QJsonArray{}}, {QStringLiteral("error"), message}};
    return toRust(QString::fromUtf8(QJsonDocument(result).toJson(QJsonDocument::Compact)));
}

rust::String list_mtp_directory(rust::Str url)
{
    if (!QCoreApplication::instance()) {
        return mtpError(QStringLiteral("D-Bus application instance not available"));
    }

    const QString urlStr = toQString(url);
    if (!urlStr.startsWith(QStringLiteral("mtp://"))) {
        return mtpError(QStringLiteral("Invalid MTP URL scheme"));
    }

    QString pathWithoutScheme = urlStr.mid(6);
    if (pathWithoutScheme.startsWith(QLatin1String("loaf/"))) pathWithoutScheme.remove(0, 5);
    if (pathWithoutScheme.endsWith(QLatin1Char('/')))
        pathWithoutScheme.chop(1);
    if (pathWithoutScheme.contains(QLatin1Char('?')) || pathWithoutScheme.contains(QLatin1Char('#'))) {
        return mtpError(QStringLiteral("URL query and fragment are not supported"));
    }

    const QStringList parts = pathWithoutScheme.split(QLatin1Char('/'));
    if (parts.isEmpty() || parts[0].isEmpty()) {
        return mtpError(QStringLiteral("Empty MTP device identifier"));
    }

    const QString udiHex = parts[0];
    const QByteArray udiBytes = QByteArray::fromHex(udiHex.toLatin1());
    if (udiBytes.isEmpty() || udiHex != QString::fromLatin1(udiBytes.toHex())) {
        return mtpError(QStringLiteral("Invalid UDI hex encoding"));
    }
    const QString targetUdi = QString::fromUtf8(udiBytes);

    // 1. Locate device
    QDBusReply<QList<QDBusObjectPath>> reply = mtpCall(QStringLiteral("/modules/kmtpd"),
        QStringLiteral("org.kde.kmtp.Daemon"), QStringLiteral("listDevices"));
    if (!reply.isValid()) {
        return mtpError(QStringLiteral("KDE MTP daemon: %1").arg(reply.error().message()));
    }

    QDBusObjectPath devicePath;
    for (const auto &device : reply.value()) {
        const auto props = mtpProperties(device.path(), QStringLiteral("org.kde.kmtp.Device"));
        if (props.value(QStringLiteral("udi")).toString() == targetUdi) {
            devicePath = device;
            break;
        }
    }

    if (devicePath.path().isEmpty()) {
        return mtpError(QStringLiteral("Device is disconnected"));
    }

    // 2. Query storages
    QDBusReply<QList<QDBusObjectPath>> storagesReply = mtpCall(devicePath.path(),
        QStringLiteral("org.kde.kmtp.Device"), QStringLiteral("listStorages"));
    if (!storagesReply.isValid() || storagesReply.value().isEmpty()) {
        return mtpError(QStringLiteral("No storages found. Unlock the device and enable file transfer."));
    }

    // Root listing: return storage descriptions as directories
    if (parts.size() == 1) {
        QJsonArray entries;
        for (const auto &storage : storagesReply.value()) {
            const auto props = mtpProperties(storage.path(), QStringLiteral("org.kde.kmtp.Storage"));
            const QString desc = props.value(QStringLiteral("description")).toString();
            if (desc.isEmpty())
                continue;
            entries.append(QJsonObject{
                {QStringLiteral("name"), desc},
                {QStringLiteral("is_dir"), true},
                {QStringLiteral("size"), 0.0},
                {QStringLiteral("modified"), 0.0}
            });
        }
        if (entries.isEmpty())
            return mtpError(QStringLiteral("No accessible storage. Unlock the phone and enable file transfer."));
        QJsonObject res;
        res.insert(QStringLiteral("entries"), entries);
        return toRust(QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact)));
    }

    // Decode storage description from percent-encoded URL component
    const QString storageDesc = QUrl::fromPercentEncoding(parts[1].toUtf8());
    QList<QDBusObjectPath> matchingStorages;
    for (const auto &storage : storagesReply.value()) {
        const auto props = mtpProperties(storage.path(), QStringLiteral("org.kde.kmtp.Storage"));
        if (props.value(QStringLiteral("description")).toString() == storageDesc) {
            matchingStorages.append(storage);
        }
    }

    if (matchingStorages.size() > 1) {
        return mtpError(QStringLiteral("Ambiguous storage: multiple storages share the exact same description"));
    }
    if (matchingStorages.isEmpty()) {
        return mtpError(QStringLiteral("Storage not found on device"));
    }

    const QDBusObjectPath targetStoragePath = matchingStorages.first();

    // Build internal storage path: '/' + remaining decoded components joined by '/'
    QString subPath = QStringLiteral("/");
    for (int i = 2; i < parts.size(); ++i) {
        const QString decodedSeg = QUrl::fromPercentEncoding(parts[i].toUtf8());
        if (decodedSeg.isEmpty() || decodedSeg == QStringLiteral(".") || decodedSeg == QStringLiteral("..")
            || decodedSeg.contains(QLatin1Char('/')) || decodedSeg.contains(QLatin1Char('\0'))) {
            return mtpError(QStringLiteral("Invalid path component in URL"));
        }
        if (subPath.length() > 1) {
            subPath += QLatin1Char('/');
        }
        subPath += decodedSeg;
    }

    // Call getFilesAndFolders on storage with 30000ms timeout
    auto callMsg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.kmtpd5"),
        targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"), QStringLiteral("getFilesAndFolders"));
    callMsg.setArguments({subPath});
    QDBusMessage callReply = QDBusConnection::sessionBus().call(callMsg, QDBus::Block, 30000);

    if (callReply.type() != QDBusMessage::ReplyMessage) {
        return mtpError(QStringLiteral("Failed to list MTP storage: %1").arg(callReply.errorMessage()));
    }

    const QVariantList args = callReply.arguments();
    if (args.size() != 2 || callReply.signature() != QLatin1String("a(uuustxs)i")) {
        return mtpError(QStringLiteral("Unexpected response from MTP service"));
    }

    const int resultStatus = args[1].toInt();
    if (resultStatus == 1) {
        return mtpError(QStringLiteral("Path not found on MTP device"));
    } else if (resultStatus == 2) {
        return mtpError(QStringLiteral("Path is a file, not a directory"));
    } else if (resultStatus != 0) {
        return mtpError(QStringLiteral("Error listing path on MTP device"));
    }

    const QDBusArgument dbusArg = args[0].value<QDBusArgument>();
    QJsonArray entries;
    dbusArg.beginArray();
    while (!dbusArg.atEnd()) {
        quint32 itemId = 0;
        quint32 parentId = 0;
        quint32 storageId = 0;
        QString filename;
        quint64 filesize = 0;
        qint64 modificationdate = 0;
        QString filetype;

        dbusArg.beginStructure();
        dbusArg >> itemId >> parentId >> storageId >> filename >> filesize >> modificationdate >> filetype;
        dbusArg.endStructure();

        const bool isDir = (filetype == QStringLiteral("inode/directory"));
        entries.append(QJsonObject{
            {QStringLiteral("name"), filename},
            {QStringLiteral("is_dir"), isDir},
            {QStringLiteral("size"), static_cast<double>(filesize)},
            {QStringLiteral("modified"), static_cast<double>(modificationdate)}
        });
    }
    dbusArg.endArray();

    QJsonObject res;
    res.insert(QStringLiteral("entries"), entries);
    return toRust(QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact)));
}

static QMutex s_mtpTransferMutex;

rust::String mtp_operation_json(rust::Str action, rust::Str url, rust::Str argument)
{
    if (!QCoreApplication::instance()) {
        const QJsonObject err{{QStringLiteral("error"), QStringLiteral("D-Bus application instance not available")}};
        return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
    }

    const QString actionStr = toQString(action);
    const QString urlStr = toQString(url);
    const QString argStr = toQString(argument);
    QMutexLocker<QMutex> mutationLock(actionStr == QStringLiteral("stat") ? nullptr : &s_mtpTransferMutex);

    if (!urlStr.startsWith(QStringLiteral("mtp://"))) {
        const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Invalid MTP URL scheme")}};
        return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
    }

    QString pathWithoutScheme = urlStr.mid(6);
    if (pathWithoutScheme.startsWith(QLatin1String("loaf/"))) pathWithoutScheme.remove(0, 5);
    if (pathWithoutScheme.endsWith(QLatin1Char('/')))
        pathWithoutScheme.chop(1);
    if (pathWithoutScheme.contains(QLatin1Char('?')) || pathWithoutScheme.contains(QLatin1Char('#'))) {
        const QJsonObject err{{QStringLiteral("error"), QStringLiteral("URL query and fragment are not supported")}};
        return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
    }

    const QStringList parts = pathWithoutScheme.split(QLatin1Char('/'));
    if (parts.isEmpty() || parts[0].isEmpty()) {
        const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Empty MTP device identifier")}};
        return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
    }

    const QString udiHex = parts[0];
    const QByteArray udiBytes = QByteArray::fromHex(udiHex.toLatin1());
    if (udiBytes.isEmpty() || udiHex != QString::fromLatin1(udiBytes.toHex())) {
        const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Invalid UDI hex encoding")}};
        return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
    }
    const QString targetUdi = QString::fromUtf8(udiBytes);

    // Locate device
    QDBusReply<QList<QDBusObjectPath>> reply = mtpCall(QStringLiteral("/modules/kmtpd"),
        QStringLiteral("org.kde.kmtp.Daemon"), QStringLiteral("listDevices"));
    if (!reply.isValid()) {
        const QJsonObject err{{QStringLiteral("error"), QStringLiteral("KDE MTP daemon is not available")}};
        return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
    }

    QDBusObjectPath devicePath;
    for (const auto &device : reply.value()) {
        const auto props = mtpProperties(device.path(), QStringLiteral("org.kde.kmtp.Device"));
        if (props.value(QStringLiteral("udi")).toString() == targetUdi) {
            devicePath = device;
            break;
        }
    }

    if (devicePath.path().isEmpty()) {
        const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Device is disconnected")}};
        return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
    }

    // Locate storages
    QDBusReply<QList<QDBusObjectPath>> storagesReply = mtpCall(devicePath.path(),
        QStringLiteral("org.kde.kmtp.Device"), QStringLiteral("listStorages"));
    if (!storagesReply.isValid() || storagesReply.value().isEmpty()) {
        const QJsonObject err{{QStringLiteral("error"), QStringLiteral("No storages found. Unlock the device and enable file transfer.")}};
        return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
    }

    // Reject mutations on device root
    if (parts.size() <= 1 && actionStr != QStringLiteral("stat")) {
        const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Mutations on device root are not supported")}};
        return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
    }

    if (parts.size() == 1 && actionStr == QStringLiteral("stat")) {
        // Synthesize metadata for device root
        const auto devProps = mtpProperties(devicePath.path(), QStringLiteral("org.kde.kmtp.Device"));
        const QString friendlyName = devProps.value(QStringLiteral("friendlyName")).toString();
        const QJsonObject res{
            {QStringLiteral("exists"), true},
            {QStringLiteral("name"), friendlyName.isEmpty() ? QStringLiteral("Phone") : friendlyName},
            {QStringLiteral("is_dir"), true},
            {QStringLiteral("size"), 0.0},
            {QStringLiteral("modified"), 0.0}
        };
        return toRust(QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact)));
    }

    // Match storage description
    const QString storageDesc = QUrl::fromPercentEncoding(parts[1].toUtf8());
    QList<QDBusObjectPath> matchingStorages;
    for (const auto &storage : storagesReply.value()) {
        const auto props = mtpProperties(storage.path(), QStringLiteral("org.kde.kmtp.Storage"));
        if (props.value(QStringLiteral("description")).toString() == storageDesc) {
            matchingStorages.append(storage);
        }
    }

    if (matchingStorages.size() > 1) {
        const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Ambiguous storage: multiple storages share the exact same description")}};
        return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
    }
    if (matchingStorages.isEmpty()) {
        if (actionStr == QStringLiteral("stat")) {
            const QJsonObject res{{QStringLiteral("exists"), false}};
            return toRust(QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact)));
        }
        const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Storage not found on device")}};
        return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
    }

    const QDBusObjectPath targetStoragePath = matchingStorages.first();

    // Storage root checks
    if (parts.size() == 2) {
        if (actionStr == QStringLiteral("stat")) {
            const QJsonObject res{
                {QStringLiteral("exists"), true},
                {QStringLiteral("name"), storageDesc},
                {QStringLiteral("is_dir"), true},
                {QStringLiteral("size"), 0.0},
                {QStringLiteral("modified"), 0.0}
            };
            return toRust(QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact)));
        } else if (actionStr != QStringLiteral("mkdir") && actionStr != QStringLiteral("upload")) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Cannot rename or delete storage root")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
    }

    // Build internal storage path
    QString subPath = QStringLiteral("/");
    for (int i = 2; i < parts.size(); ++i) {
        const QString decodedSeg = QUrl::fromPercentEncoding(parts[i].toUtf8());
        if (decodedSeg.isEmpty() || decodedSeg == QStringLiteral(".") || decodedSeg == QStringLiteral("..")
            || decodedSeg.contains(QLatin1Char('/')) || decodedSeg.contains(QLatin1Char('\0'))) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Invalid path component in URL")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
        if (subPath.length() > 1) {
            subPath += QLatin1Char('/');
        }
        subPath += decodedSeg;
    }

    if (actionStr == QStringLiteral("stat")) {
        auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.kmtpd5"),
            targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"), QStringLiteral("getFileMetadata"));
        msg.setArguments({subPath});
        QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 30000);
        if (reply.type() != QDBusMessage::ReplyMessage) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("D-Bus call getFileMetadata failed: %1").arg(reply.errorMessage())}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
        const QVariantList args = reply.arguments();
        if (args.isEmpty() || reply.signature() != QLatin1String("(uuustxs)")) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Unexpected getFileMetadata response signature")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
        const QDBusArgument arg = args[0].value<QDBusArgument>();
        quint32 itemId = 0, parentId = 0, storageId = 0;
        QString filename;
        quint64 filesize = 0;
        qint64 modificationdate = 0;
        QString filetype;
        arg.beginStructure();
        arg >> itemId >> parentId >> storageId >> filename >> filesize >> modificationdate >> filetype;
        arg.endStructure();

        if (itemId == 0) {
            const QJsonObject res{{QStringLiteral("exists"), false}};
            return toRust(QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact)));
        }
        const bool isDir = (filetype == QStringLiteral("inode/directory"));
        const QJsonObject res{
            {QStringLiteral("exists"), true},
            {QStringLiteral("name"), filename},
            {QStringLiteral("is_dir"), isDir},
            {QStringLiteral("size"), static_cast<double>(filesize)},
            {QStringLiteral("modified"), static_cast<double>(modificationdate)}
        };
        return toRust(QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact)));
    } else if (actionStr == QStringLiteral("mkdir")) {
        if (argStr.isEmpty() || argStr == QStringLiteral(".") || argStr == QStringLiteral("..")
            || argStr.contains(QLatin1Char('/')) || argStr.contains(QLatin1Char('\0'))) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Invalid directory name")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
        QString targetPath = subPath;
        if (targetPath.length() > 1) {
            targetPath += QLatin1Char('/');
        }
        targetPath += argStr;

        auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.kmtpd5"),
            targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"), QStringLiteral("createFolder"));
        msg.setArguments({targetPath});
        QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 30000);
        if (reply.type() != QDBusMessage::ReplyMessage) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("D-Bus call createFolder failed: %1").arg(reply.errorMessage())}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
        const qint64 ret = reply.arguments().value(0).toLongLong();
        if (ret > 0) {
            const QJsonObject res{{QStringLiteral("ok"), true}};
            return toRust(QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact)));
        } else if (ret == -1) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Directory already exists")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        } else if (ret == -2) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("File blocks directory creation")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        } else {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Failed to create folder on MTP device")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
    } else if (actionStr == QStringLiteral("rename")) {
        if (subPath == QStringLiteral("/")) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Cannot rename storage root")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
        if (argStr.isEmpty() || argStr == QStringLiteral(".") || argStr == QStringLiteral("..")
            || argStr.contains(QLatin1Char('/')) || argStr.contains(QLatin1Char('\0'))) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Invalid new name for rename")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
        const QString renamedUrl = urlStr.left(urlStr.lastIndexOf(QLatin1Char('/')) + 1)
            + QString::fromLatin1(QUrl::toPercentEncoding(argStr));
        const rust::String targetUrl = toRust(renamedUrl);
        const rust::String targetReply = mtp_operation_json(rust::Str("stat"), targetUrl, rust::Str(""));
        const QJsonObject targetState = QJsonDocument::fromJson(QByteArray(targetReply.data(), static_cast<qsizetype>(targetReply.size()))).object();
        if (targetState.contains(QStringLiteral("error")) || targetState.value(QStringLiteral("exists")).toBool())
            return mtpError(QStringLiteral("Rename target already exists or could not be checked"));
        auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.kmtpd5"),
            targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"), QStringLiteral("setFileName"));
        msg.setArguments({subPath, argStr});
        QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 30000);
        if (reply.type() != QDBusMessage::ReplyMessage) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("D-Bus call setFileName failed: %1").arg(reply.errorMessage())}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
        const int ret = reply.arguments().value(0).toInt();
        if (ret == 0) {
            const QJsonObject res{{QStringLiteral("ok"), true}};
            return toRust(QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact)));
        } else {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Failed to rename object on MTP device (code %1)").arg(ret)}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
    } else if (actionStr == QStringLiteral("delete")) {
        if (subPath == QStringLiteral("/")) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Cannot delete storage root")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
        auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.kmtpd5"),
            targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"), QStringLiteral("deleteObject"));
        msg.setArguments({subPath});
        QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 30000);
        if (reply.type() != QDBusMessage::ReplyMessage) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("D-Bus call deleteObject failed: %1").arg(reply.errorMessage())}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
        const int ret = reply.arguments().value(0).toInt();
        if (ret == 0) {
            const QJsonObject res{{QStringLiteral("ok"), true}};
            return toRust(QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact)));
        } else {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Failed to delete object on MTP device (code %1)").arg(ret)}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
    } else if (actionStr == QStringLiteral("download")) {
        if (subPath == QStringLiteral("/")) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Cannot download storage root")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
        if (argStr.isEmpty() || !QDir::isAbsolutePath(argStr)) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Local destination must be an absolute path")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }


        const QByteArray localPathBytes = argStr.toUtf8();
        const int rawFd = ::open(localPathBytes.constData(), O_CREAT | O_EXCL | O_WRONLY, 0644);
        if (rawFd < 0) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Failed to create destination file (already exists or permission denied)")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }

        MtpTransferReceiver receiver;
        bool conn1 = QDBusConnection::sessionBus().connect(QStringLiteral("org.kde.kmtpd5"),
            targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
            QStringLiteral("copyFinished"), &receiver, SLOT(onCopyFinished(int)));
        bool conn2 = QDBusConnection::sessionBus().connect(QStringLiteral("org.kde.kmtpd5"),
            targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
            QStringLiteral("copyProgress"), &receiver, SLOT(onCopyProgress(quint64,quint64)));

        if (!conn1) {
            ::close(rawFd);
            ::unlink(localPathBytes.constData());
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Failed to connect to storage copyFinished signal")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }

        QDBusUnixFileDescriptor dbusFd(rawFd);
        auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.kmtpd5"),
            targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"), QStringLiteral("getFileToFileDescriptor"));
        msg.setArguments({QVariant::fromValue(dbusFd), subPath});

        QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 30000);
        if (reply.type() != QDBusMessage::ReplyMessage) {
            QDBusConnection::sessionBus().disconnect(QStringLiteral("org.kde.kmtpd5"),
                targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
                QStringLiteral("copyFinished"), &receiver, SLOT(onCopyFinished(int)));
            if (conn2) {
                QDBusConnection::sessionBus().disconnect(QStringLiteral("org.kde.kmtpd5"),
                    targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
                    QStringLiteral("copyProgress"), &receiver, SLOT(onCopyProgress(quint64,quint64)));
            }
            ::close(rawFd);
            ::unlink(localPathBytes.constData());
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("D-Bus call getFileToFileDescriptor failed: %1").arg(reply.errorMessage())}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }

        const int ret = reply.arguments().value(0).toInt();
        if (ret != 0) {
            QDBusConnection::sessionBus().disconnect(QStringLiteral("org.kde.kmtpd5"),
                targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
                QStringLiteral("copyFinished"), &receiver, SLOT(onCopyFinished(int)));
            if (conn2) {
                QDBusConnection::sessionBus().disconnect(QStringLiteral("org.kde.kmtpd5"),
                    targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
                    QStringLiteral("copyProgress"), &receiver, SLOT(onCopyProgress(quint64,quint64)));
            }
            ::close(rawFd);
            ::unlink(localPathBytes.constData());
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Failed to start MTP download (code %1)").arg(ret)}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }

        // Event loop with idle timeout
        QEventLoop loop;
        QObject::connect(&receiver, &MtpTransferReceiver::finished, &loop, &QEventLoop::quit);

        QTimer idleTimer;
        idleTimer.setSingleShot(true);
        QObject::connect(&idleTimer, &QTimer::timeout, &loop, &QEventLoop::quit);
        QObject::connect(&receiver, &MtpTransferReceiver::progressReceived, [&idleTimer]() {
            idleTimer.start(30000);
        });

        idleTimer.start(30000);
        if (!receiver.m_finished) {
            loop.exec();
        }

        QDBusConnection::sessionBus().disconnect(QStringLiteral("org.kde.kmtpd5"),
            targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
            QStringLiteral("copyFinished"), &receiver, SLOT(onCopyFinished(int)));
        if (conn2) {
            QDBusConnection::sessionBus().disconnect(QStringLiteral("org.kde.kmtpd5"),
                targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
                QStringLiteral("copyProgress"), &receiver, SLOT(onCopyProgress(quint64,quint64)));
        }

        const bool flushed = !receiver.m_finished || receiver.m_result != 0 || ::fsync(rawFd) == 0;
        ::close(rawFd);
        if (!flushed) { ::unlink(localPathBytes.constData()); return mtpError(QStringLiteral("Could not flush downloaded file")); }

        if (!receiver.m_finished) {
            ::unlink(localPathBytes.constData());
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Download timed out (no progress for 30s)")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }

        if (receiver.m_result != 0) {
            ::unlink(localPathBytes.constData());
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Download failed with result %1").arg(receiver.m_result)}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }

        const QJsonObject res{{QStringLiteral("ok"), true}};
        return toRust(QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact)));
    } else if (actionStr == QStringLiteral("upload")) {
        const rust::String current = mtp_operation_json(rust::Str("stat"), url, rust::Str(""));
        const QJsonObject targetState = QJsonDocument::fromJson(QByteArray(current.data(), static_cast<qsizetype>(current.size()))).object();
        if (targetState.contains(QStringLiteral("error")) || targetState.value(QStringLiteral("exists")).toBool()) {
            return mtpError(QStringLiteral("Upload target already exists or could not be checked"));
        }

        if (argStr.isEmpty() || !QDir::isAbsolutePath(argStr)) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Local source must be an absolute path")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }
        if (subPath == QStringLiteral("/")) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Destination path must include a filename")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }


        const QByteArray localPathBytes = argStr.toUtf8();
        const int rawFd = ::open(localPathBytes.constData(), O_RDONLY);
        if (rawFd < 0) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Failed to open local source file")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }

        MtpTransferReceiver receiver;
        bool conn1 = QDBusConnection::sessionBus().connect(QStringLiteral("org.kde.kmtpd5"),
            targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
            QStringLiteral("copyFinished"), &receiver, SLOT(onCopyFinished(int)));
        bool conn2 = QDBusConnection::sessionBus().connect(QStringLiteral("org.kde.kmtpd5"),
            targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
            QStringLiteral("copyProgress"), &receiver, SLOT(onCopyProgress(quint64,quint64)));

        if (!conn1) {
            ::close(rawFd);
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Failed to connect to storage copyFinished signal")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }

        QDBusUnixFileDescriptor dbusFd(rawFd);
        auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.kmtpd5"),
            targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"), QStringLiteral("sendFileFromFileDescriptor"));
        msg.setArguments({QVariant::fromValue(dbusFd), subPath});

        QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 30000);
        if (reply.type() != QDBusMessage::ReplyMessage) {
            QDBusConnection::sessionBus().disconnect(QStringLiteral("org.kde.kmtpd5"),
                targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
                QStringLiteral("copyFinished"), &receiver, SLOT(onCopyFinished(int)));
            if (conn2) {
                QDBusConnection::sessionBus().disconnect(QStringLiteral("org.kde.kmtpd5"),
                    targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
                    QStringLiteral("copyProgress"), &receiver, SLOT(onCopyProgress(quint64,quint64)));
            }
            ::close(rawFd);
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("D-Bus call sendFileFromFileDescriptor failed: %1").arg(reply.errorMessage())}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }

        const int ret = reply.arguments().value(0).toInt();
        if (ret != 0) {
            QDBusConnection::sessionBus().disconnect(QStringLiteral("org.kde.kmtpd5"),
                targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
                QStringLiteral("copyFinished"), &receiver, SLOT(onCopyFinished(int)));
            if (conn2) {
                QDBusConnection::sessionBus().disconnect(QStringLiteral("org.kde.kmtpd5"),
                    targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
                    QStringLiteral("copyProgress"), &receiver, SLOT(onCopyProgress(quint64,quint64)));
            }
            ::close(rawFd);
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Failed to start MTP upload (code %1)").arg(ret)}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }

        // Event loop with idle timeout
        QEventLoop loop;
        QObject::connect(&receiver, &MtpTransferReceiver::finished, &loop, &QEventLoop::quit);

        QTimer idleTimer;
        idleTimer.setSingleShot(true);
        QObject::connect(&idleTimer, &QTimer::timeout, &loop, &QEventLoop::quit);
        QObject::connect(&receiver, &MtpTransferReceiver::progressReceived, [&idleTimer]() {
            idleTimer.start(30000);
        });

        idleTimer.start(30000);
        if (!receiver.m_finished) {
            loop.exec();
        }

        QDBusConnection::sessionBus().disconnect(QStringLiteral("org.kde.kmtpd5"),
            targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
            QStringLiteral("copyFinished"), &receiver, SLOT(onCopyFinished(int)));
        if (conn2) {
            QDBusConnection::sessionBus().disconnect(QStringLiteral("org.kde.kmtpd5"),
                targetStoragePath.path(), QStringLiteral("org.kde.kmtp.Storage"),
                QStringLiteral("copyProgress"), &receiver, SLOT(onCopyProgress(quint64,quint64)));
        }

        ::close(rawFd);

        if (!receiver.m_finished) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Upload timed out (no progress for 30s)")}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }

        if (receiver.m_result != 0) {
            const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Upload failed with result %1").arg(receiver.m_result)}};
            return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
        }

        const QJsonObject res{{QStringLiteral("ok"), true}};
        return toRust(QString::fromUtf8(QJsonDocument(res).toJson(QJsonDocument::Compact)));
    } else {
        const QJsonObject err{{QStringLiteral("error"), QStringLiteral("Unknown action: %1").arg(actionStr)}};
        return toRust(QString::fromUtf8(QJsonDocument(err).toJson(QJsonDocument::Compact)));
    }
}

} // namespace loaf
