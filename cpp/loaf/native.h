// Native helpers exposed to QML as the `native` context property and to
// Rust through cxx (see src/native.rs).
#pragma once

#include <QDBusAbstractAdaptor>
#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <QWindow>

#include "rust/cxx.h"

class QQmlApplicationEngine;

namespace loaf {
class PortalService;

class LoafNative : public QObject
{
    Q_OBJECT
    // "tab" (normal) or "mini" (compact window, from --mini).
    Q_PROPERTY(QString startupMode READ startupMode CONSTANT)
    // True when started through D-Bus activation (--portal): only picker
    // windows are shown until a normal open request arrives.
    Q_PROPERTY(bool portalOnly READ portalOnly CONSTANT)
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

    // ---- portal file chooser ----------------------------------------------
    // Creates the portal service and exports the FileChooser backend.
    // Returns false when another backend owns the portal name. In portal
    // mode (D-Bus activation) the service exits when idle.
    bool initPortal(bool portalOnly);
    // QML answers a picker request: code 0 = picked, 1 = cancelled. The
    // results JSON carries uris (paths), choices and current_filter.
    Q_INVOKABLE void respondPicker(const QString &handle, uint code, const QString &resultsJson);
    Q_INVOKABLE void cancelPicker(const QString &handle);
    // Overwrite checks for the save dialog.
    Q_INVOKABLE bool fileExists(const QString &path) const;
    Q_INVOKABLE bool isDirectory(const QString &path) const;
    // Makes a picker window transient for the caller's window on X11
    // ("x11:0x..." handles); Wayland needs xdg-foreign, which Qt Quick does
    // not expose, so there we degrade gracefully.
    Q_INVOKABLE void setPickerTransient(QWindow *window, const QString &parentWindow, bool modal) const;

    void queueOpen(const QStringList &paths, const QString &mode);
    void setPortalMode(bool portal) { m_portalOnly = portal; }
    QString startupMode() const { return m_mode; }
    bool portalOnly() const { return m_portalOnly; }
    bool isAdmin() const;

Q_SIGNALS:
    void clipboardChanged();
    // mode: "tab" (open folders), "select" (show items), "properties",
    // "window" (raise / new window request).
    void openRequested(const QStringList &paths, const QString &mode);
    // A portal file chooser request arrived; spec is the normalized JSON.
    void pickerRequested(const QString &handle, const QString &spec);
    // The request was closed from the D-Bus side (Request.Close()).
    void pickerDismissed(const QString &handle);

private:
    QVariantMap readClipboard() const;

    QStringList m_pending;
    QString m_mode = QStringLiteral("tab");
    bool m_portalOnly = false;
    QVariantMap m_clipboard;
    class PortalService *m_portal = nullptr;
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

// MIME helpers for Rust.
rust::String mime_type_for(rust::Str path, bool sniff);
rust::String mime_comment_for(rust::Str mime);
// Whether a file name matches a MIME filter (shared-mime-info inheritance
// and aliases included). Directories only match directory types.
bool mime_filter_matches(rust::Str fileName, rust::Str filterMime, bool isDir);

// Sets the application name / desktop file id (Wayland app id).
void set_application_identity(rust::Str version);

} // namespace loaf
