// Native helpers exposed to QML as the `native` context property and to
// Rust through cxx (see src/native.rs).
#pragma once

#include <QDBusAbstractAdaptor>
#include <QObject>
#include <QStringList>
#include <QVariantMap>

#include "rust/cxx.h"

class QQmlApplicationEngine;

namespace loaf {

class LoafNative : public QObject
{
    Q_OBJECT
    // "tab" (normal) or "mini" (compact window, from --mini).
    Q_PROPERTY(QString startupMode READ startupMode CONSTANT)
    // True when started through "Open as Administrator".
    Q_PROPERTY(bool isAdmin READ isAdmin CONSTANT)
public:
    explicit LoafNative(QObject *parent = nullptr);

    // ---- clipboard (interoperable with Nautilus, Dolphin, ...) ----------
    // Puts files on the system clipboard (x-special/gnome-copied-files,
    // text/uri-list, application/x-kde-cutselection, text/plain).
    Q_INVOKABLE void setClipboardFiles(const QStringList &paths, bool cut);
    // { "cut": bool, "paths": [absolute paths] } read from the clipboard.
    Q_INVOKABLE QVariantMap clipboardFiles() const;
    Q_INVOKABLE bool clipboardHasFiles() const;
    Q_INVOKABLE void setClipboardText(const QString &text);
    // Forget a cut once it was pasted (the files moved away).
    Q_INVOKABLE void clearClipboardIfOurs();

    // ---- MIME ------------------------------------------------------------
    Q_INVOKABLE QString mimeType(const QString &path, bool sniffContents = true) const;
    Q_INVOKABLE QString mimeComment(const QString &path) const;

    // Files passed on the command line / requested over D-Bus but not yet
    // opened by the UI (drained by QML on start-up).
    Q_INVOKABLE QStringList takePendingOpen();

    void queueOpen(const QStringList &paths, const QString &mode);
    QString startupMode() const { return m_mode; }
    bool isAdmin() const;

Q_SIGNALS:
    void clipboardChanged();
    void mtpDevicesChanged();
    // mode: "tab" (open folders), "select" (show items), "properties",
    // "window" (raise / new window request).
    void openRequested(const QStringList &paths, const QString &mode);

private Q_SLOTS:
    void notifyMtpDevicesChanged() { Q_EMIT mtpDevicesChanged(); }

private:
    QVariantMap readClipboard() const;

    QStringList m_pending;
    QString m_mode = QStringLiteral("tab");
    QVariantMap m_clipboard;
};

// org.freedesktop.FileManager1 (used by browsers' "Show in folder").
class FileManager1Adaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.FileManager1")
public:
    FileManager1Adaptor(QObject *host, LoafNative *native);

public Q_SLOTS:
    void ShowFolders(const QStringList &uris, const QString &startupId);
    void ShowItems(const QStringList &uris, const QString &startupId);
    void ShowItemProperties(const QStringList &uris, const QString &startupId);

private:
    LoafNative *m_native;
};

// io.github.m_uvex.Loaf: lets a second `loaf <path>` hand its request to
// the running instance instead of starting another window.
class LoafAppAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "io.github.m_uvex.Loaf")
public:
    LoafAppAdaptor(QObject *host, LoafNative *native);

public Q_SLOTS:
    void Open(const QStringList &paths, const QString &mode);

private:
    LoafNative *m_native;
};

// ---- functions called from Rust ------------------------------------------

// Asks an already running Loaf to handle `paths`. Returns true when it did
// (the new process should then exit).
bool forward_to_running_instance(const rust::Vec<rust::String> &paths, rust::Str mode);

// Registers D-Bus services, the `native` context property, the thumbnail
// image provider and translations, and queues `paths` for opening.
void setup_engine(QQmlApplicationEngine &engine, const rust::Vec<rust::String> &paths, rust::Str mode);

// Enumerates MTP devices via KDE kiod6 / kmtpd over D-Bus without blocking the UI thread.
// Returns a JSON-encoded array of MTP device objects:
// [{"name": "...", "udi": "...", "url": "...", "model": "...", "icon": "device-mobile",
//   "total_bytes": N, "free_bytes": N}, ...]
rust::String list_kmtp_devices_json();

// Lists directory contents of an MTP URL via KDE kiod6 / kmtpd D-Bus directly.
// Returns JSON object: { "entries": [...], "error": "..." }
rust::String list_mtp_directory(rust::Str url);

// Performs an MTP operation (stat, mkdir, rename, delete, download, upload).
// Returns JSON object: { "ok": true, ... } or { "error": "..." }
rust::String mtp_operation_json(rust::Str action, rust::Str url, rust::Str argument);

class MtpTransferReceiver : public QObject
{
    Q_OBJECT
public:
    explicit MtpTransferReceiver(QObject *parent = nullptr) : QObject(parent) {}

public Q_SLOTS:
    void onCopyFinished(int result) {
        m_finished = true;
        m_result = result;
        Q_EMIT finished();
    }
    void onCopyProgress(quint64 sent, quint64 total) {
        m_progressSent = sent;
        m_progressTotal = total;
        Q_EMIT progressReceived();
    }

Q_SIGNALS:
    void finished();
    void progressReceived();

public:
    bool m_finished = false;
    int m_result = -1;
    quint64 m_progressSent = 0;
    quint64 m_progressTotal = 0;
};

// MIME helpers for Rust.
rust::String mime_type_for(rust::Str path, bool sniff);
rust::String mime_comment_for(rust::Str mime);

// Sets the application name / desktop file id (Wayland app id).
void set_application_identity(rust::Str version);

} // namespace loaf
