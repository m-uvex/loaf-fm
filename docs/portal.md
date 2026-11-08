# File Chooser Portal (`xdg-desktop-portal`)

Loaf can serve as the system backend for `org.freedesktop.impl.portal.FileChooser`. When enabled, applications that request files via portals (Firefox, Chrome, Flatpaks, `zenity`, etc.) use a Loaf picker window instead of standard GTK or Qt dialogs.

---

## How It Works

* **D-Bus Activation**: When an app triggers a file chooser, D-Bus invokes `loaf --portal`. It runs headlessly until a request arrives and automatically terminates after the last dialog closes.
* **Full File Manager Experience**: Each request opens a dedicated picker window with your customized sidebar, view modes, search filters, and file previews.
* **Sandboxing**: Runs outside sandbox restrictions on the host session to securely pass selected file URIs back to calling apps.

---

## Configuration

Pre-built packages (`.deb`, `.rpm`, Arch AUR, and `install.sh`) install the required `.portal` and D-Bus `.service` files automatically to `/usr/share/`.

To set Loaf as your preferred picker, configure your desktop portal preference:

### Hyprland / Sway / Wayland Compositors

Add or edit `~/.config/xdg-desktop-portal/portals.conf` (or compositor-specific configs like `hyprland-portals.conf`):

```ini
[preferred]
org.freedesktop.impl.portal.FileChooser=loaf

```

> **Note:** By default, `loaf.portal` sets `UseIn=Hyprland;` so it does not override file choosers on other desktops unexpectedly. Setting it explicitly in `portals.conf` enables it across any compositor (Sway, River, Niri, etc.).

### NixOS (24.05+)

Add the package to `extraPortals` and define the preferred interface in your `configuration.nix`:

```nix
xdg.portal = {
  enable = true;
  extraPortals = [ pkgs.loaf ];
  config.common."org.freedesktop.impl.portal.FileChooser" = "loaf";
};

```

### Apply Changes

Restart the portal services or log out and back in:

```bash
systemctl --user restart xdg-desktop-portal

```

---

## Testing & Verification

1. **Verify D-Bus Registration:**
```bash
busctl --user introspect org.freedesktop.impl.portal.desktop.loaf /org/freedesktop/portal/desktop

```

2. **Trigger a Test Picker Dialog:**
```bash
gdbus call --session \
    --dest org.freedesktop.impl.portal.desktop.loaf \
    --object-path /org/freedesktop/portal/desktop \
    --method org.freedesktop.impl.portal.FileChooser.OpenFile \
    /org/freedesktop/portal/desktop/request/test/h1 com.example.app "" "Open" "{}"

```

3. **End-to-End Test:**
Open any file prompt (`Ctrl+O` in Firefox or run `zenity --file-selection`). The Loaf picker interface should appear.

---

## Known Behaviors

* **Wayland Modality**: On Wayland, pickers appear as independent top-level windows rather than attached modal dialogs due to `xdg-foreign` limitations in Qt Quick. On X11, windows are strictly modal and parented.
* **Sandboxed Packaging**: Flatpak builds cannot act as host portal providers; Loaf must be installed on the host system.
* **Special Locations**: Virtual directories (Recent, Starred, Trash) are hidden in the picker to ensure valid, accessible filesystem paths are returned.
