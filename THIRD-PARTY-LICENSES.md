# Third-Party Licenses and Legal Notices

Loaf is open source software licensed under the MIT License. Loaf links with and incorporates several third-party libraries and components, which are governed by their respective licenses.

---

## 1. Qt 6 (LGPL v3 / GPL v3)

Loaf dynamically links against the Qt 6 libraries (`Qt6Core`, `Qt6Gui`, `Qt6Qml`, `Qt6Quick`, `Qt6DBus`, `Qt6Svg`, `Qt6WaylandClient`), which are copyright (C) The Qt Company Ltd. and other contributors.

Qt is licensed under the GNU Lesser General Public License version 3 (LGPLv3) and the GNU General Public License version 3 (GPLv3).

### Source Code
The source code of the Qt libraries used with Loaf can be obtained from:
- Official Qt Project archives: https://download.qt.io/archive/qt/
- Qt git repositories: https://code.qt.io/cgit/qt/

### Library Replacement and Relinking
Under LGPLv3, you have the right to modify or replace the Qt libraries linked by Loaf:

1. **Distribution Packages (deb, rpm, arch, tarball):**
   Loaf dynamically links against the shared system Qt libraries (`.so` files). You can update, rebuild, or replace any system Qt library using your distribution package manager or custom builds without modifying Loaf.

2. **Standalone Tarball:**
   Loaf uses standard dynamic library resolution (`ld.so`). You can override Qt libraries by specifying `LD_LIBRARY_PATH=/path/to/custom/qt/lib loaf`.

3. **AppImage Distribution:**
   If using the pre-packaged AppImage, the bundled Qt libraries can be replaced as follows:
   - Extract the AppImage: `./Loaf-v0.2.0-x86_64.AppImage --appimage-extract`
   - Replace any Qt shared library inside `squashfs-root/usr/lib/` or `squashfs-root/usr/qml/` with your custom version.
   - Run directly: `./squashfs-root/AppRun` or rebuild the image with `appimagetool squashfs-root`.
   - Alternatively, preload a compatible Qt library using `LD_PRELOAD` or `LD_LIBRARY_PATH`.

A copy of the GNU Lesser General Public License version 3 (LGPLv3) and GNU General Public License version 3 (GPLv3) can be found at https://www.gnu.org/licenses/lgpl-3.0.html and https://www.gnu.org/licenses/gpl-3.0.html.

---

## 2. Phosphor Icons

The vector icon fonts bundled in `assets/fonts/` (`Phosphor.ttf`, `Phosphor-Fill.ttf`, `Phosphor-Bold.ttf`, `Phosphor-Light.ttf`, `Phosphor-Thin.ttf`, `Phosphor-Duotone.ttf`) are from the Phosphor Icons project.

- Copyright (c) 2020-2024 Phosphor Icons (Helena Zhang & Tobias Fried)
- License: MIT License (https://github.com/phosphor-icons/core/blob/main/LICENSE)

---

## 3. M3Shapes / AndroidX Graphics Shapes

The Material 3 Expressive shape and morphing C++ engine in `cpp/m3shapes/` is adapted from `soramanew/m3shapes` and the Android Open Source Project (`androidx.graphics.shapes` / `androidx.compose.material3.MaterialShapes`).

- Copyright (c) soramanew (https://github.com/soramanew/m3shapes)
- Copyright (c) The Android Open Source Project
- License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)

---

## 4. Rust Dependencies (Compiled into Binary)

The Loaf binary compiles Rust crates statically from crates.io. All direct and transitive dependencies are licensed under permissive open-source licenses (MIT, Apache-2.0, Zlib, or Unlicense):

### CXX and CXX-Qt
- `cxx`, `cxx-build`, `cxxbridge-cmd`, `cxx-gen`
  - Copyright (c) 2020 David Tolnay
  - License: MIT OR Apache-2.0
- `cxx-qt`, `cxx-qt-build`, `cxx-qt-gen`, `cxx-qt-lib`
  - Copyright (c) 2021-2024 Klarälvdalens Datakonsult AB (KDAB)
  - License: MIT OR Apache-2.0

### Serde
- `serde`, `serde_derive`, `serde_json`
  - Copyright (c) 2014 Erick Tryzelaar and David Tolnay
  - License: MIT OR Apache-2.0

### Libc
- `libc`
  - Copyright (c) 2014-2024 The Rust Project Developers
  - License: MIT OR Apache-2.0

### Transitive Crates
- `anyhow`, `cfg-if`, `clang-format`, `codespan-reporting`, `convert_case`, `find-msvc-tools`, `foldhash`, `hashbrown`, `indexmap`, `indoc`, `itoa`, `jobserver`, `link-cplusplus`, `memchr`, `proc-macro2`, `quote`, `r-efi`, `rustversion`, `semver`, `shlex`, `static_assertions`, `syn`, `termcolor`, `thiserror`, `unicode-ident`, `unicode-segmentation`, `unicode-width`, `which`, `winapi-util`, `zmij`
  - Licenses: MIT, Apache-2.0, Zlib, and/or Unlicense.

---

## 4. External Runtime Utilities

Loaf integrates with several standard Linux command-line utilities if installed on the host system:
- `7zip` / `p7zip`: archive browsing and extraction (LGPL / GPL with unRAR restriction)
- `ffmpegthumbnailer`: video thumbnail generation (GPL-2.0-or-later)
- `evince-thumbnailer`: PDF thumbnail generation (GPL-2.0-or-later)
- `udisks2`: disk drive management via D-Bus (GPL-2.0-or-later / LGPL-2.0-or-later)
- `xdg-utils`: default application opening (MIT)
- `libsecret`: encrypted volume passphrase storage (LGPL-2.1-or-later)

**Note on distribution:** Loaf does not bundle, vendor, or redistribute binaries or source code of these external utilities in its distribution packages. They are invoked as independent external system processes using standard freedesktop command-line and D-Bus interfaces. Host systems provide their own packages for these tools under their respective licenses.
