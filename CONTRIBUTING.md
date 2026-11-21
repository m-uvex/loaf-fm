# Contributing to Loaf

Thank you for your interest in contributing to **Loaf**! Loaf is an experimental, modern Material 3 Expressive file manager for Linux, built with Rust, C++, and Qt6 Quick.

Whether you are fixing a bug, adding new features, improving packaging, or helping with documentation, all contributions are welcome.

---

## 🧭 Branching Strategy

- **`main`** is our primary active development and release branch. **All pull requests must target `main`**.

### Opening a Pull Request
1. Fork the repository and clone your fork.
2. Branch off of the latest `main` branch:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/my-cool-feature
   ```
3. Keep your commits clean and descriptive (we follow [Conventional Commits](https://www.conventionalcommits.org/), e.g. `feat:`, `fix:`, `perf:`, `chore:`).
4. If `main` has moved forward while you were working, **rebase** your branch onto `origin/main` before opening your PR:
   ```bash
   git fetch origin
   git rebase origin/main
   ```

---

## 🛠️ Development Environment

### Using Nix (Recommended)

The repository provides a complete Nix flake containing all Qt6 libraries, Rust toolchains, and build tooling:

```bash
# Run Loaf in development mode:
nix develop --command cargo run

# Run unit tests:
nix develop --command cargo test

# Build an optimized release binary:
nix develop --command cargo build --release
```

### Manual Setup (Without Nix)

If you prefer building directly on your host distribution:

1. **Rust Toolchain**: Rust 1.75+ (`rustc`, `cargo`).
2. **C++ Compiler**: A modern C++17 compiler (`g++` or `clang++`).
3. **Qt6 Libraries**:
   - `qtbase` (including private headers and `QtDBus`)
   - `qtdeclarative` (QML and Quick engine)
   - `qtsvg`
   - `qtwayland`
   - `qttools` (provides `lupdate`/`lrelease` for the translation catalogues)
4. **Build Tools**: `cmake`, `ninja`, `pkg-config`.

**Fedora / RHEL / CentOS:**
```bash
sudo dnf install qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtsvg-devel qt6-qtwayland-devel qt6-qttools-devel cmake ninja-build pkg-config
```

**Ubuntu / Debian / Pop!_OS:**
```bash
sudo apt install build-essential cmake ninja-build pkg-config \
    qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-svg-dev qt6-tools-dev libqt6waylandclient6-dev
```

**Arch Linux / Manjaro / EndeavourOS:**
```bash
sudo pacman -S --needed base-devel cmake ninja pkgconf qt6-base qt6-declarative qt6-svg qt6-tools qt6-wayland
```

Then build and run:
```bash
cargo run
cargo test
```

### Fast Development Iteration (`scripts/dev-loaf`)

To iterate without invoking Cargo on every run or risking broken builds:

```bash
# 1. Compile and atomically publish a launchable dev binary:
./scripts/dev-loaf build

# 2. Run the published build instantly (no Cargo call, caller CWD preserved):
./scripts/dev-loaf run

# 3. Snapshot previous good binary before building a new experiment:
./scripts/dev-loaf build --keep my-experiment

# 4. Run a saved snapshot:
./scripts/dev-loaf run --keep my-experiment

# 5. (Optional) Install an isolated user desktop entry (Loaf (Development)):
./scripts/dev-loaf install-desktop
```

#### Prerequisites, Workflow & Known Constraints

- **Python standard library only**: Requires Python 3.8+ (`python3`). Zero third-party Python dependencies.
- **Explicit build required**: A normal `cargo build` in your terminal builds into Cargo's target directory but does not publish to the dev launcher. You must run `./scripts/dev-loaf build` to compile and publish the active development binary.
- **Cargo cache preserved**: Does not purge Cargo build caches or object directories. Respects custom `CARGO_TARGET_DIR` and `.cargo/config.toml` target directories via Cargo compiler artifact discovery.
- **Dynamic Qt & Runtime dependencies**: Loaf dynamically links against Qt6 and host C/C++ libraries. The published development binary relies on host runtime libraries and does not bundle a self-contained environment. When using Nix, run the helper within `nix develop` or ensure equivalent runtime dependencies are available.
- **Platform support**: Linux only (X11 / Wayland).
- **Checkout relocation**: The desktop entry (`loaf-dev.desktop`) records the absolute checkout path. If you move or rename the repository directory, re-run `./scripts/dev-loaf install-desktop`.

---

## 🧱 Codebase Architecture

Loaf is organized into three clean layers:

```text
loaf/
├── src/                  # Pure-Rust & CXX-Qt engine
│   ├── core.rs           # LoafCore QObject: drives, bookmarks, settings, background jobs, Open With
│   ├── pane.rs           # LoafEngine: QAbstractListModel on worker threads with live inotify updates
│   ├── fsops.rs          # Threaded copy, move, delete with cancel and progress callbacks
│   ├── trash.rs          # FreeDesktop trash spec with removable drive ($topdir/.Trash-$uid) support
│   ├── watcher.rs        # inotify directory and device monitoring
│   ├── apps.rs           # Cached desktop entries and MIME associations
│   ├── archive.rs        # Safe extraction and compression (zip, 7z, tar, cpio)
│   ├── drives.rs         # Storage drive discovery and UDisks2 integration
│   ├── icons.rs          # Icon theme resolution and XDG data lookup
│   ├── listing.rs        # Directory listing, natural sorting, and hidden file logic
│   └── xdg.rs            # Localized XDG user dirs, GTK bookmarks, recently-used.xbel, scripts
├── cpp/                  # Native C++ bridges and async providers
│   ├── thumbnails.cpp    # QQuickAsyncImageProvider (image://thumb/...) running on QThreadPool
│   └── native.cpp        # D-Bus single instance, system clipboard interop, MIME detection
└── qml/                  # Material 3 Expressive QML Interface
    ├── main.qml          # App shell, global shortcuts, dialog routing, top navigation bar
    ├── FilePane.qml      # Primary file view pane: tabs, split view (F3), grid/list views
    ├── Sidebar.qml       # Collapsible navigation rail: places, drives, bookmarks, trash
    ├── QuickLook.qml     # Spacebar file preview modal with syntax highlighting & media inspection
    ├── SettingsView.qml  # Preferences panel (Interface, Behavior, Accessibility, Experimental, About)
    ├── PCView.qml        # "This PC" storage drive cards and frequent directory dashboard
    ├── ConflictDialog.qml# File transfer conflict resolution dialog (side-by-side comparison)
    ├── Theme.qml         # Material 3 tokens, dynamic palettes, Pywal/Matugen integration
    └── components/       # Reusable Material 3 design components (LoafButton, LoafMenu, etc.)
```

---

## 🎨 Design & Coding Guidelines

### 1. Material 3 Expressive Design
- Loaf strictly adheres to Material 3 Expressive aesthetics: generous paddings, pill-shaped tags, rounded surface containers (`theme.radiusXl`), and smooth spring/cubic transitions.
- Every animation must respect `theme.animate` (which honors the user's Reduce Motion and Low-Power settings).
- Use reusable components in `qml/components/` (`LoafButton`, `LoafMenu`, `LoafSwitch`, `LoafSegmented`, `LoafDialog`, `LoafCard`) rather than hand-rolling one-off UI primitives.

### 2. Performance & Responsiveness
- **Never block the main UI thread**: Filesystem I/O, thumbnail generation, large directory scans, and compression must run on worker threads or async providers.
- **Image Thumbnails**: All thumbnails use `image://thumb/...` through the native `QQuickAsyncImageProvider`. Always specify an explicit `sourceSize` on `Image` items to avoid decoding full-resolution raw photos into RAM.
- **QML Layouts**: Avoid circular height/width references in QML items (e.g. making an item's `height` depend on a parent view's `contentHeight`), as this causes binding loops and crash hazards.

### 3. Broad Linux Distribution Portability
- **Never hardcode Nix store paths** or distro-specific paths in code or packaging. Use `util::which("binary")` for runtime discovery.
- Keep dependencies lean and optional where possible (e.g. 7-Zip, ffmpegthumbnailer, and secret-tool are optional runtime enhancements; Loaf degrades gracefully when they are absent).

---

## 🧪 Testing Your Changes

Before submitting your PR, verify:

1. **Backend Tests**: Run `cargo test` to ensure all pure-Rust unit tests pass:
   ```bash
   cargo test
   ```
2. **Formatting**: Ensure your code follows formatting standards:
   ```bash
   cargo fmt --check
   cargo clippy
   ```
3. **Runtime Check**: Launch Loaf and ensure there are no QML warnings or console errors in `stdout` / `stderr`:
   ```bash
   ./target/debug/loaf
   ```

---

## 💡 Feature Ideas & Roadmap

Check [`TODO.md`](./TODO.md) before submitting large feature suggestions to see existing roadmap items, community requests, and planned view experiments.

If you have questions or want to discuss an architectural change before writing code, feel free to open a Discussion on GitHub or to message me on Discord (m_uvex)!
