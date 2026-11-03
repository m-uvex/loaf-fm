# Loaf as an xdg-desktop-portal file chooser

Loaf can act as the **backend** for `org.freedesktop.impl.portal.FileChooser`:
apps that open files through xdg-desktop-portal (Firefox, Chromium, Flatpak
apps, GTK/Qt dialogs, `zenity --file-selection`, …) then use a Loaf picker
window instead of a GTK or Qt dialog.

## How it works

- Loaf exports `org.freedesktop.impl.portal.FileChooser` (interface version 4)
  on `/org/freedesktop/portal/desktop` under the bus name
  `org.freedesktop.impl.portal.desktop.loaf`.
- Every request opens a dedicated picker window (the normal sidebar + file
  views, a filter dropdown, choice widgets and an accept button labelled with
  the app's `accept_label`), with its own state keyed by the request handle.
- Each request also exports an `org.freedesktop.impl.portal.Request` object at
  the handle path; `Close()` dismisses the dialog and answers the request with
  response code 2. Cancelling in the UI answers 1, picking answers 0.
- `loaf --portal` starts a picker-only instance for D-Bus activation: no main
  window until a normal `loaf <path>` request arrives, and the process exits
  once the last picker is answered. The regular file manager flow is
  unaffected.

## Installation

The files below ship with every package and land in the standard paths:

| File | Installed to |
| --- | --- |
| `loaf.portal` | `/usr/share/xdg-desktop-portal/portals/loaf.portal` |
| `org.freedesktop.impl.portal.desktop.loaf.service` | `/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service` |

- **Arch (AUR `loaf-fm` / release PKGBUILD)**, **.deb**, **.rpm**, **AppImage-adjacent
  tarballs via `install.sh`**: nothing to do, both files are installed for you.
  Tarball installs into a custom `PREFIX` get the `Exec=` path of the service
  file rewritten automatically.
- **Nix (flake)**: `loaf.portal` and the service file are part of the package
  output; use it through `xdg.portal.extraPortals` (see below).
- **Flatpak**: not supported — a sandboxed build cannot serve the host
  session's portal backend; install Loaf on the host instead.

## Configuration

`loaf.portal` lists `UseIn=Hyprland;` only, so on Hyprland Loaf becomes an
eligible FileChooser backend out of the box. Which backend actually wins is
decided by xdg-desktop-portal's configuration:

**Hyprland / any distro** — `~/.config/xdg-desktop-portal/hyprland-portals.conf`:

```ini
[preferred]
org.freedesktop.impl.portal.FileChooser=loaf
org.freedesktop.impl.portal.ScreenCast=hyprland
# ... keep your other per-interface choices
```

or a generic `~/.config/xdg-desktop-portal/portals.conf` with a
`[preferred]` section per desktop. A bare

```ini
[preferred]
org.freedesktop.impl.portal.FileChooser=loaf
```

routes just the file chooser to Loaf and leaves everything else at the
defaults. Opting in on other desktops (sway, river, niri, …) works the same
way — the `UseIn` list is deliberately limited to Hyprland so Loaf never
takes over a desktop by surprise.

**NixOS** (24.05+):

```nix
xdg.portal = {
  enable = true;
  extraPortals = [ pkgs.loaf-fm ];   # or your own package/overlay input
  config.hyprland."org.freedesktop.impl.portal.FileChooser" = "loaf";
};
```

Restart `xdg-desktop-portal` (or log back in) after changing the config:
`systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gtk`.

## Verifying it works

```sh
# The backend interface must show up:
busctl --user introspect org.freedesktop.impl.portal.desktop.loaf \
    /org/freedesktop/portal/desktop

# A quick OpenFile round trip against the backend directly (opens a picker;
# cancel it in the UI):
gdbus call --session \
    --dest org.freedesktop.impl.portal.desktop.loaf \
    --object-path /org/freedesktop/portal/desktop \
    --method org.freedesktop.impl.portal.FileChooser.OpenFile \
    /org/freedesktop/portal/desktop/request/test/h1 com.example.app "" "Open" "{}"
```

End to end: configure `portals.conf` as above, then use Firefox
("Open file" / "Save as"), a Flatpak app, or `zenity --file-selection` —
the picker window should appear. Things worth trying: cancel, directory
selection (`--directory`), filter switching, multiple selection, save with
overwrite confirmation, and several dialogs at once (each gets its own
window).

## Known limitations

- **Transient parent / modality on Wayland**: making one window transient
  for another needs xdg-foreign, which Qt Quick does not expose. On X11
  (`x11:<window-id>` handles) the picker is made transient and modal for the
  caller; on Wayland it appears as its own toplevel and `modal` is best
  effort. Functionally everything works — the dialog just is not attached to
  the caller's window.
- **Interface version 4**: the `writable` result of newer FileChooser drafts
  is not implemented; `directory` (v3) is.
- **Byte-string paths**: `current_folder`/`current_file`/`files` are accepted
  as raw bytes with the trailing NUL stripped; non-UTF-8 paths are handled
  lossily for display, and the returned URIs are strictly percent-encoded
  `file://` URIs.
- **Special locations**: Recent, Starred and Trash are no longer offered in the
  picker; only real filesystem folders can be browsed and returned.
- The C++ D-Bus marshaling layer is exercised by the manual `gdbus` /
  end-to-end tests above rather than unit tests; the filter matching, request
  validation and URI encoding have Rust unit tests (`cargo test`).
