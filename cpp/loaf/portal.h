// The xdg-desktop-portal backend for org.freedesktop.impl.portal.FileChooser.
//
// Options arrive as a{sv} on QtDBus; they are demarshaled into the JSON
// request spec described in src/portal/filters.rs, validated by Rust and
// shown by QML through LoafNative::pickerRequested. Replies are delayed
// until the user picks (LoafNative::respondPicker), cancels, or the
// frontend closes the request object (response code 2).
#pragma once

#include <QDBusAbstractAdaptor>
#include <QDBusArgument>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QJsonObject>
#include <optional>
#include <QMap>
#include <QObject>
#include <QVariantMap>

namespace loaf {

class LoafNative;

// D-Bus types from org.freedesktop.impl.portal.FileChooser. The operator
// overloads below make QList<T> marshal as the corresponding D-Bus array.
struct PortalPattern
{
    uint kind = 0; // 0 = glob, 1 = MIME type
    QString pattern;
};

struct PortalFilter
{
    QString name;
    QList<PortalPattern> patterns;
};

// A (value id, value label) pair inside a choice.
struct PortalChoicePair
{
    QString id;
    QString label;
};

// a(ssa(ss)s): label, id, options, currently selected value id.
struct PortalChoice
{
    QString label;
    QString id;
    QList<PortalChoicePair> values;
    QString selected;
};

QDBusArgument &operator<<(QDBusArgument &argument, const PortalPattern &pattern);
const QDBusArgument &operator>>(const QDBusArgument &argument, PortalPattern &pattern);
QDBusArgument &operator<<(QDBusArgument &argument, const PortalFilter &filter);
const QDBusArgument &operator>>(const QDBusArgument &argument, PortalFilter &filter);
QDBusArgument &operator<<(QDBusArgument &argument, const PortalChoicePair &pair);
const QDBusArgument &operator>>(const QDBusArgument &argument, PortalChoicePair &pair);
QDBusArgument &operator<<(QDBusArgument &argument, const PortalChoice &choice);
const QDBusArgument &operator>>(const QDBusArgument &argument, PortalChoice &choice);

// Owns the pending requests. Adaptor slots execute on the GUI thread
// because the adaptors and PortalService live on that thread.
class PortalService : public QObject
{
    Q_OBJECT
public:
    explicit PortalService(LoafNative *native);

    // Portal-only instances (--portal activation) exit when the last
    // picker is answered and no file manager window is visible.
    void setPortalOnly(bool portalOnly) { m_portalOnly = portalOnly; }

    void start(const QString &kind, const QDBusObjectPath &handle, const QString &appId,
               const QString &parentWindow, const QString &title, const QVariantMap &options,
               const QDBusMessage &message);
    // Request.Close(): end the interaction with response code 2.
    void closeRequest(const QString &handle);
    // QML answering for the user: code 0/1 plus results JSON.
    void respond(const QString &handle, uint code, const QString &resultsJson);

private:
    struct PendingRequest
    {
        QDBusMessage reply;
        QObject *requestObject = nullptr;
    };

    void beginRequest(const QString &handle, const QString &spec);
    void finishRequest(const QString &handle, QObject *requestObject, bool dismissed);
    void quitIfIdle();
    // Takes the pending entry out; returns nullopt when already gone.
    std::optional<PendingRequest> takePending(const QString &handle);

    LoafNative *m_native;
    bool m_portalOnly = false;
    QMap<QString, PendingRequest> m_pending;
};

// org.freedesktop.impl.portal.FileChooser on /org/freedesktop/portal/desktop.
class PortalFileChooserAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.impl.portal.FileChooser")
    Q_PROPERTY(uint version READ version CONSTANT)
public:
    PortalFileChooserAdaptor(QObject *host, PortalService *service);
    uint version() const { return 4; }

public Q_SLOTS:
    void OpenFile(const QDBusObjectPath &handle, const QString &appId, const QString &parentWindow,
                  const QString &title, const QVariantMap &options, const QDBusMessage &message);
    void SaveFile(const QDBusObjectPath &handle, const QString &appId, const QString &parentWindow,
                  const QString &title, const QVariantMap &options, const QDBusMessage &message);
    void SaveFiles(const QDBusObjectPath &handle, const QString &appId, const QString &parentWindow,
                   const QString &title, const QVariantMap &options, const QDBusMessage &message);

private:
    PortalService *m_service;
};

// org.freedesktop.impl.portal.Request, one per pending request, exported at
// the handle path the frontend picked.
class PortalRequestAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.impl.portal.Request")
public:
    PortalRequestAdaptor(QObject *host, PortalService *service, const QString &handle);

public Q_SLOTS:
    void Close(const QDBusMessage &message);

private:
    PortalService *m_service;
    QString m_handle;
};

} // namespace loaf
