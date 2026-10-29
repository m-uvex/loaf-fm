<div align="center">

# 🍞 Loaf

**A beautiful and fast Rust-based Material 3 Expressive file manager for Linux.**

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/ad2768e4-8a4c-4bf0-ae3c-7565732e2be2" />

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
> Another Note: I'm kinda in need for an app icon for Loaf, if you're willing to help please DM me on discord; @m_uvex . Thank you!

---

## Features

- **Material 3 Expressive Design**: Fluid spring motion, smooth path transitions, and calibrated state layers.
- **Dynamic Theming**: 8 curated color palettes plus automatic dynamic palette generation from your desktop wallpaper.
- **Fast Directory Navigation**: Snappy directory switching with zero disk bottlenecks and smooth directional animations.
- **Archive Support**: One-click non-modal archive compression for `.zip`, password-protected encrypted `.zip`, `.tar.gz`, `.7z`, and advanced formats (`.tar.xz`, `.tar.zst`, `.tar.bz2`, `.cpio`).
- **Comprehensive Undo / Redo**: Multi-step operation history (`Ctrl+Z` / `Ctrl+Y`) for renames, creations, moves, and deletions.
- **Storage & Drive Dashboard**: "This PC" overview with internal drive pool stats, drive space indicators, mount/unmount/rename actions, and optional customizable layout.
- **Native Trash Integration**: Standard freedesktop directory listing of trashed items with one-click restore and toolbar empty action.
- **Multiple View Modes**: Responsive Grid View and Detailed List View with dynamic column adaptation for narrow windows.
- **Rich Drag & Drop**: Drag files into breadcrumb chips, folders, or path bar with right-click menu options (Copy, Move, Link Here).
- **Navigation Controls**: Mouse side buttons (Back / Forward), full keyboard navigation, and click-outside search defocusing.
- **Tabs & Split View**: Tabs (`Ctrl+T`), a side-by-side split view (`F3`), and your tabs and window restored on the next start.
- **Background Operations**: Copy, move, trash, compress and extract run in the background with a progress pill, cancel, undo, and a filesystem flush before removable drives report "done".
- **Safe by Default**: freedesktop trash (also on USB drives), restores and overwrites that never lose data, archive passwords never on the command line.
- **Live Folders**: Changes made by other programs appear instantly (inotify), only the changed rows update.
- **Thumbnails**: Images, videos, PDFs and fonts through the shared freedesktop thumbnail cache and system thumbnailers, loaded in the background.
- **Search**: Filter the folder as you type, or search subfolders / your whole home folder in the background, optionally inside text files.
- **Desktop Integration**: GTK bookmarks (including `sftp://`/`ftp://` network shortcuts shared with Nemo/Nautilus, opened with the system handler), localized user folders, Recent and Starred, Open With / default apps, templates ("New Document"), Nautilus scripts, system clipboard, "Show in folder" from other apps, Open as Administrator.
- **Network Storage (SMB / Windows Share)**: Connect to SMB / CIFS shares (`smb://server/share`), manage named server profiles, authenticate with user/domain credentials, securely store credentials via system keyring, and browse remote network directories seamlessly.
- **P2P File Sharing via Link**: Share files or compressed archives peer-to-peer using on-demand Cloudflare tunnels, optional password protection, expiration timers, and bandwidth rate-limiting.
- **Low-Power Mode**: Turns off animations and effects automatically on machines without GPU acceleration or with little memory; reduce-motion and text-size settings for accessibility.

---

## Installation

The easiest way to install Loaf is through our interactive management script:

```bash
curl -sSL https://raw.githubusercontent.com/m-uvex/loaf-fm/main/install.sh | bash
```

---

## Alternative Manual Installation Methods

Pre-built packages are available for manual installation (See release page for packages):

### 1. Standalone AppImage (Universal)

Download the self-contained `.AppImage` and run it directly:

```bash
chmod +x Loaf-v0.2.0-x86_64.AppImage
./Loaf-v0.2.0-x86_64.AppImage
```

### 2. Debian and Debian-based (Ubuntu, Mint, etc.) (`.deb`)

Download the `.deb` package and install it using `apt` or `dpkg`:

```bash
# Using apt (Recommended):
sudo apt install ./loaf_0.2.0_amd64.deb

# Or using dpkg:
sudo dpkg -i ./loaf_0.2.0_amd64.deb
sudo apt-get install -f
```

### 3. Arch and Arch-based (Manjaro, CachyOS, etc.)

Install from the AUR (`loaf-fm`) with your AUR helper:

```bash
yay -S loaf-fm
# or
paru -S loaf-fm
```

Or download the `.pkg.tar.zst` package from the release page and install it using `pacman`:

```bash
sudo pacman -U ./loaf-0.2.0-1-x86_64.pkg.tar.zst
```

Or build from the included `PKGBUILD`:

```bash
cd packaging/arch
makepkg -si
```

### 4. Fedora / RHEL / openSUSE (`.rpm`)

Download the `.rpm` package and install it using `dnf`:

```bash
sudo dnf install ./loaf-0.2.0-1.fc44.x86_64.rpm
```

### 5. Using Nix / NixOS

Run directly with flakes enabled:

```bash
nix run github:m-uvex/loaf-fm
```

For a declarative installation, add to your `flake.nix`:

```nix
loaf.url = "github:m-uvex/loaf-fm";
```
And add to your `configuration.nix`:
```nix
{ inputs, pkgs, ...}:

{
    nixpkgs.overlays = [ loaf.overlays.default ];

    environment.systemPackages = [ pkgs.loaf ];
}
```
> [!NOTE]
> We DO ~~not~~ support `home-manager`!
---

## Building from Source

### Using Nix (Recommended)

Loaf provides a complete Nix flake containing all Qt6 libraries and build dependencies:

```bash
# Enter dev shell and run:
nix develop --command cargo run

# Compile an optimized release binary:
nix develop --command cargo build --release
```

### Manual Build

Requirements:
- Rust toolchain (1.75+) and a C++17 compiler
- Qt 6.x development files (`qtbase` incl. private headers and QtDBus, `qtdeclarative`, `qtsvg`, `qtwayland`)
  - Fedora: `sudo dnf install qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtsvg-devel qt6-qtwayland-devel`
- CMake, Ninja, and `pkg-config`

Optional at runtime (features degrade gracefully without them):
- `7zip`/`p7zip` (zip, 7z, rar, iso, encrypted archives), `tar`, `zstd`, `cpio`
- `udisks2` (mount, eject, unlock encrypted drives, rename labels)
- KDE MTP support (`kio-extras` with `kmtpd`) for USB phone browsing and read/write transfers; KIOFuse is not required.
- `ffmpegthumbnailer` / `evince-thumbnailer` (video and PDF thumbnails)
- `xdg-utils`, `libsecret` (`secret-tool`, to remember drive passphrases), `polkit` (Open as Administrator)

MTP phones must be unlocked with USB file transfer enabled. Loaf supports file and folder copies and moves in both directions, new folders and files, rename, preview and permanent deletion. Name collisions create a separate copy. Phone roots are protected; MTP has no trash, undo or symbolic links. Cancellation stops further files after the current phone transfer finishes. A failed transfer can leave a partial destination; a failed move retains its source.

Opening or previewing a phone file downloads a private local copy. Editor changes are not uploaded automatically: copy the edited file back to the phone. Loaf's MTP clipboard format supports transfers between Loaf windows.

```bash
cargo build --release
./target/release/loaf
cargo test   # backend unit tests
```

## Command Line

```text
loaf [OPTIONS] [PATH...]

  PATH               Folder to open, or a file to show selected in its folder
  -p, --path <DIR>   Start in DIR
  -m, --mini         Start in the compact layout
      --new-window   Open a separate window instead of a tab in the running one
  -v, --verbose      Print diagnostic messages
      --version      Print the version
  -h, --help         Print help
```

Running `loaf <path>` while Loaf is open hands the path to the running window
(as a new tab). Loaf also answers `org.freedesktop.FileManager1`, so "Show in
folder" from browsers and other apps opens it.

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

## How AI is used in this project

I've been learning rust for a while and took on this project as my first real project to build with rust so **most of the code is hand written** by me to 1 test my limits and 2 learn even more.
AI comes in where it's actually useful, It is used to write docs and comments, it created the install script and takes care of releases, some bugs were fixed with the help of AI and animations were also created by it.
Every single line my AI writes is reviewed by me (and sometimes edited) and everything is tested properly.
Btw the claude contributor is because of a PR, I don't even use claude.....

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for the full license text and [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md) for third-party notices and LGPL compliance details.
