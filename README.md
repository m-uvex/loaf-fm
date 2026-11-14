<div align="center">

# 🍞 Loaf

**A beautiful and fast Rust-based Material 3 Expressive file manager for Linux.**

<img width="1918" height="1078" alt="image" src="https://github.com/user-attachments/assets/3966949b-121a-4d59-90d5-9abcec449c21" />

<br/>

[![Language](https://img.shields.io/badge/Language-Rust_%26_QML-DEA584?style=flat-square&labelColor=1a1a1e)](https://www.rust-lang.org/)
[![Design](https://img.shields.io/badge/Design-Material_3_Expressive-6750A4?style=flat-square&labelColor=1a1a1e)](https://m3.material.io/)
[![Icons](https://img.shields.io/badge/Icons-Phosphor-f5bd6d?style=flat-square&labelColor=1a1a1e)](https://phosphoricons.com/)
[![Platform](https://img.shields.io/badge/Platform-Linux-5e81ac?style=flat-square&labelColor=1a1a1e)](#installation)
[![License](https://img.shields.io/badge/License-MIT-888888?style=flat-square&labelColor=1a1a1e)](LICENSE)

<br/>

</div>

---

## Overview

Loaf is designed to replace crowded, outdated file managers with an interface that looks modern, runs fast, and doesn't compromise on functionality. Built using **Rust** for native system performance and **Qt6 Quick / QML** for fluid Material 3 Expressive animations.
> Note: Loaf is still at a very alpha stage, expect bugs or missing features. Contributions of any kind are very welcome!

---

## Features

### Performance & Design

* **Fast by Design**: Built with a high-performance Rust backend and hardware acceleration for snappy folder navigation and low memory usage.
* **Material 3 Expressive UI**: Modern interface with fluid spring animations, modular rounded geometry, and curated icons.
* **Dynamic Theming & Opacity**: 8 built-in palettes, automatic accent extraction from your desktop wallpaper, and granular slider control over window transparency, foreground, and background opacity.
* **Low-Power Mode**: Automatically disables animations, transparencies, and blur effects when on battery or low-spec hardware to conserve resources.

### Navigation & Layout

* **Tabs & Split View**: Multi-task efficiently with browser-style tabs (`Ctrl+T`) and side-by-side dual pane view (`F3`).
* **Flexible View Modes**: Responsive Grid and Detailed List views featuring connected, fluid item selection.
* **Drive & Storage Dashboard**: A dedicated "This PC" hub with partition usage bars, mount/eject controls, and customizable layouts.

### Deep Customization & Extensibility

* **Total Interface Customization**: Tailor the UI to your workflow—show, hide, or reorder sidebar entries, toolbar buttons, headers, and context menu actions.
* **Full Nautilus Scripts Support**: Run your existing Nautilus scripts directly from the context menu for automated file actions.
* **Power Actions**: Built-in context options for **Open In Terminal**, **Open With...**, and elevated administrative operations.

### File Operations & Previews

* **Quick Look**: Press `Space` to instantly preview images, videos, audio, and documents without launching an external app.
* **Rich Thumbnails**: High-resolution thumbnail generation for photos, video clips, PDFs, and font files.
* **Built-in Archive Engine**: Browse, extract, and compress `.zip`, `.tar.*`, `.7z`, and other standard formats directly within the directory tree.

### Connectivity & System Integration

* **Network Storage**: Connect and browse network shares effortlessly over SMB, WebDAV, and other standard protocols.
* **P2P Link Sharing**: Generate a local link to instantly beam files and folders to any phone, PC, or browser on your network.
* **Native XDG File Picker**: Built-in desktop file portal integration that replaces generic system dialogs with Loaf's full interface across all your apps.

---

## Installation

### Quick Install

Install or update Loaf using the interactive script:

```bash
curl -sSL https://raw.githubusercontent.com/m-uvex/loaf-fm/main/install.sh | bash

```

---

### Pre-built Packages

Download pre-compiled binaries from the **[Releases](https://github.com/m-uvex/loaf-fm/releases)** page.

#### AppImage (Universal)

```bash
chmod +x Loaf-*.AppImage
./Loaf-*.AppImage

```

#### Debian / Ubuntu / Mint (`.deb`)

```bash
sudo apt install ./loaf_*_amd64.deb

```

#### Arch / Manjaro / CachyOS

Install from the AUR *(Community maintained)*:

```bash
yay -S loaf-fm-bin
# or
paru -S loaf-fm-bin

```

*Or install the downloaded package manually:*

```bash
sudo pacman -U ./loaf-*.pkg.tar.zst

```

#### Fedora / RHEL / openSUSE (`.rpm`)

```bash
sudo dnf install ./loaf-*.rpm

```

#### Nix / NixOS (Recommended, Tested)

Run directly:

```bash
nix run github:m-uvex/loaf-fm

```

Declarative setup via Flakes:

```nix
# flake.nix
inputs.loaf.url = "github:m-uvex/loaf-fm";

# configuration.nix
{ inputs, pkgs, ... }: {
  nixpkgs.overlays = [ inputs.loaf.overlays.default ];
  environment.systemPackages = [ pkgs.loaf ];
}

```

---

## Building from Source

### Option A: Using Nix (Recommended)

The dev shell provides all Qt6 dependencies and toolchains automatically:

```bash
nix develop --command cargo build --release

```

### Option B: Manual Build

#### 1. Dependencies

* **Build tools:** Rust (1.75+), C++17 compiler, CMake, Ninja, `pkg-config`
* **Qt6 libraries:** `qtbase` (including private headers and QtDBus), `qtdeclarative`, `qtsvg`, `qtwayland`
* *Fedora:* `sudo dnf install qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtsvg-devel qt6-qtwayland-devel`
* *Debian/Ubuntu:* `sudo apt install qt6-base-dev qt6-base-private-dev qt6-declarative-dev libqt6svg6-dev qt6-wayland-dev`
* *Arch:* `sudo pacman -S qt6-base qt6-declarative qt6-svg qt6-wayland`

Qt Linguist tools (`lupdate`/`lrelease`) compile the `translations/*.ts` catalogues into the
binary. The UI language follows the system locale, can be changed in Settings → Interface →
Language, or overridden for one launch with `LOAF_LANG` (e.g. `LOAF_LANG=id_ID ./target/release/loaf`).

Contributors: to regenerate the master catalogue, run
`lupdate cpp qml translations/loaf_<locale>.ts`. Edit translations with Qt Linguist (`linguist`), compile them with
`lrelease translations/loaf_<locale>.ts -qm loaf_<locale>.qm`, and list each locale in
`qml/settings/languages.json` so the Language picker shows it.

Optional at runtime (features degrade gracefully without them):
- `7zip`/`p7zip` (zip, 7z, rar, iso, encrypted archives), `tar`, `zstd`, `cpio`
- `udisks2` (mount, eject, unlock encrypted drives, rename labels)
- Optional MTP USB phone support: `kio-extras` package on Arch (`pacman -S kio-extras`), Debian/Ubuntu (`apt install kio-extras`), or `pkgs.kdePackages.kio-extras` on NixOS. This package provides the canonical session D-Bus service `org.kde.kmtpd5` (executed via `kio-extras-service`/`kiod6`) for USB phone browsing and read/write transfers. On NixOS, install it at the system level (`environment.systemPackages = [ pkgs.kdePackages.kio-extras ];` and `services.dbus.packages = [ pkgs.kdePackages.kio-extras ];`) so its D-Bus service is registered in the session activation registry, rather than merely in a transient `nix-shell`. A full KDE Plasma desktop environment or manually running daemon is not required (the host D-Bus session bus activates the service on demand across Hyprland, Sway, GNOME, etc., provided the service file is registered). When absent or unregistered, MTP devices degrade cleanly without affecting local disk browsing or causing UI hangs; KIOFuse is not required.
- `ffmpegthumbnailer` / `evince-thumbnailer` (video and PDF thumbnails)
- `xdg-utils`, `libsecret` (`secret-tool`, to remember drive passphrases), `polkit` (Open as Administrator)


#### 2. Optional Runtime Dependencies

Features degrade gracefully if these are not installed:

* `kio-extras` – MTP USB phone support (requires session D-Bus registration)
* `7zip` / `p7zip`, `tar`, `zstd` – Archive browsing and extraction
* `udisks2` – Drive management, mounting, and passphrase unlocking
* `ffmpegthumbnailer`, `evince-thumbnailer` – Video and PDF thumbnails
* `polkit` – Admin file operations

#### 3. Compile and Run

```bash
cargo build --release
./target/release/loaf

```

---

## Command Line Usage

 ```text
loaf [OPTIONS] [PATH...]

  PATH               Folder to open, or a file to show selected in its folder
  -p, --path <DIR>   Start in DIR
  -m, --mini         Start in the compact layout
      --new-window   Open a separate window instead of a tab in the running one
      --class <NAME> Use NAME as the window class (Wayland app id / WM_CLASS)
      --portal       Serve the xdg-desktop-portal file chooser (D-Bus activation)
  -v, --verbose      Print diagnostic messages
      --version      Print the version
  -h, --help         Print help
``` 

### Integration Notes

* **Single-Instance IPC**: Running `loaf <path>` when an instance is already active attaches the path as a new tab by default.
* **Desktop "Show in Folder"**: Registers as the default `org.freedesktop.FileManager1` D-Bus provider so browsers and external apps reveal files directly in Loaf.
* **Window Rules**: Passing `--class <NAME>` spawns an isolated instance with a distinct identity, making it easy to configure floating, sizing, or workspace rules in Hyprland, Sway, or i3.
* **System File Dialogs**: Running with `--portal` allows Loaf to replace generic system open/save file pickers. See [docs/portal.md](docs/portal.md) for details.

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Ctrl` + `Z` | Undo last operation |
| `Ctrl` + `Y` / `Ctrl` + `Shift` + `Z` | Redo last operation |
| `Ctrl` + `H` | Toggle hidden files |
| `Ctrl` + `L` | Edit path bar directly |
| `Alt` + `Left` / `Mouse Back` | Navigate back in history |
| `Alt` + `Right` / `Mouse Forward` | Navigate forward in history |
| `Alt` + `Up` / `Backspace` | Navigate to parent directory |
| `F2` | Rename selected item |
| `Delete` | Move selected items to Trash |
| `Ctrl` + `A` | Select all items |
| `Ctrl` + `C` / `Ctrl` + `X` / `Ctrl` + `V` | Copy / Cut / Paste |
| `Arrow Keys` | Move selection across files and folders |
| `Enter` / `Return` | Open selected item |
| `Escape` | Dismiss modal / Close context menu / Defocus search |
| `Shift` + `Delete` | Delete permanently (asks first) |
| `Space` | Quick Look preview |
| `F2` (several selected) | Rename several items at once |
| `Ctrl` + `T` / `Ctrl` + `W` | New tab / Close tab |
| `Ctrl` + `Tab` / `Ctrl` + `Shift` + `Tab` | Next / previous tab |
| `F3` | Toggle split view |
| `F5` / `Ctrl` + `R` | Reload the folder |
| `F9` | Expand / collapse the sidebar |
| `Ctrl` + `F` | Search |
| `Ctrl` + `N` | New window |
| `Ctrl` + `Shift` + `N` | New folder |
| `Ctrl` + `D` | Add the folder to the sidebar |
| `Ctrl` + `S` / `Ctrl` + `Shift` + `I` | Select by pattern / Invert selection |
| `Ctrl` + `Shift` + `C` | Copy path |
| `Alt` + `Enter` | Properties |
| `Ctrl` + `+` / `Ctrl` + `-` / `Ctrl` + `0` / `Ctrl` + Scroll | Icon size |
| `Ctrl` + `1` / `Ctrl` + `2` | Grid / List view |
| `Alt` + `Home` | Home folder |

---

## Architecture

```text
loaf/
├── src/
│   ├── main.rs              Entry point: command line, single instance, QML engine
│   ├── pane.rs              LoafEngine: one file view as a threaded QAbstractListModel
│   ├── core.rs              LoafCore: file operations, undo/redo, drives, places, settings
│   ├── native.rs            Rust side of the C++ helpers (cpp/)
│   ├── fsops.rs             Copy/move/delete with progress, cancel and filesystem flush
│   ├── trash.rs             freedesktop.org trash (home and per-drive)
│   ├── archive.rs           Archive create/extract/list through 7-Zip, tar, cpio
│   ├── listing.rs           Directory scanning, natural sort, incremental diffs
│   ├── watcher.rs           inotify folder and device watchers
│   ├── search.rs            Background recursive search
│   ├── apps.rs / xdg.rs     Desktop entries, MIME defaults, user dirs, bookmarks, recent
│   ├── icons.rs / drives.rs Icon themes; block devices through UDisks
│   └── info.rs / theme.rs   Quick Look and Properties data; dark mode and wallpaper palette
├── cpp/                     Async thumbnail provider, clipboard, MIME, D-Bus services
├── qml/
│   ├── main.qml             Main window: top bar, tabs, split view, menus and dialogs
│   ├── FilePane.qml         One file view (grid / list, selection, inline rename)
│   ├── Sidebar.qml          Places, bookmarks, Recent, Starred and Trash
│   ├── QuickLook.qml        Space-bar preview
│   ├── PropertiesDialog.qml / BatchRenameDialog.qml / ConflictDialog.qml
│   ├── OperationsPanel.qml / Toast.qml   Progress pill and messages
│   ├── PCView.qml           This PC tab: storage devices and frequent folders
│   ├── SettingsView.qml     Theme preferences, icons, behavior, and experimental toggles
│   ├── Theme.qml            Material 3 design token engine & palette derivation
│   ├── LoafIcon.qml         Vector icon resolver for Phosphor typography
│   └── components/          Reusable Material 3 component library
│       ├── LoafPopup.qml        Elevated popup container with smooth transitions
│       ├── LoafMenu.qml         Cascading menus and keyboard navigation
│       ├── LoafMenuItem.qml     Individual menu rows with sequential stagger animation
│       ├── LoafButton.qml       Tonal, filled, outlined, and text button variants
│       ├── LoafSwitch.qml       Spring-animated Material 3 pill toggle switch
│       ├── LoafSegmented.qml    Sliding segmented controls for view/sorting modes
│       ├── LoafDialog.qml       Centered modal dialog surfaces
│       ├── LoafTextPrompt.qml   Input modals (New Folder, New File, Rename, Password)
│       ├── LoafCard.qml         Interactive and surface card containers
│       ├── SectionHeader.qml    Unified dashboard and section headers
│       ├── UsageBar.qml         Smooth progress/storage capacity bar
│       └── DriveCard.qml        Mountable, partitioned, and external drive cards
├── packaging/               Packaging recipes, .desktop entries, icons, and dist artifacts
├── assets/
│   ├── fonts/               Phosphor font weights (Regular, Bold, Fill, Duotone, Light, Thin)
│   └── resources.qrc        Qt resource manifest
├── Cargo.toml               Rust package manifest
└── flake.nix                Nix flake declaring devShell and default package
```

---

## Contributing

We welcome contributions of all kinds! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on branch targets (`main`), setting up your development environment with or without Nix, architecture overview, and testing instructions.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for the full license text and [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md) for third-party notices and LGPL compliance details.
