# Loaf Roadmap & Suggestions

Feature suggestions collected from Reddit and discussions (This file is written and updated automatically by AI)

Legend: `[x]` done, `[~]` partial / missing a piece, `[ ]` not started

---

## Navigation & Views
- [ ] **Miller Columns (Cascading View)**: Hierarchical column-by-column browsing mode (like macOS Finder / Yazi) for rapid drill-down directory traversal.
- [ ] **Per-Folder View Preferences**: (togglable in settings) Remember layout preferences per directory with auto-detection (e.g. automatic large thumbnail grid for `Pictures` and `Videos`, compact list/table view for code and documents).
- [ ] **Pictures Gallery View**: Dedicated gallery view for `Pictures/` and any subdirectories, displaying all images in a large gallery layout with a bottom pane/window for any non-picture files.
- [~] **Quick Look / File Preview**: Instant preview panel or overlay (Spacebar trigger) for media, text, markdown, and syntax-highlighted code without launching external apps.
  - [x] Spacebar + context-menu preview overlay with images (full size), rendered markdown (headings, lists, quotes, bold/italic/code) and language-aware code highlighting (15+ languages, theme-colored).
  - [x] Graceful states for folders, media, PDFs and binary files.
  - [ ] Video/audio playback inside the preview (needs Qt Multimedia) and PDF page rendering (needs poppler).
- [ ] **Alternative View Experiments**:
  - [ ] 2D infinite canvas / plane view (spatial driftwm-style file navigation).
  - [ ] Horizontal scrolling flow (Niri-inspired horizontal scroll grid instead of vertical grid).
- [ ] **Vim Navigation Keybindings**: Full keyboard-driven navigation (`h`, `j`, `k`, `l`, visual select, quick filter jump) for power users who want a GUI with terminal-speed navigation.
- [x] **Direct Path Entry**: Clickable path bar toggle to edit raw Unix paths directly with tab completion.
- [~] **State & Session Persistence**: Retain last visited directory, open tabs, and window geometry across application restarts.
  - PC section layout is saved. View mode (list/grid) and last dir are NOT persisted yet (`johnsmitheroo` report: "doesn't remember my choice for List View or Grid View").

---

## Drives & System Storage Overview
- [x] **"This PC" / Drives Hub**: Centralized system storage dashboard (inspired by `nautilus-my-computer`):
  - Categorized display for internal partitions, external USB drives, and active network mounts.
  - Visual disk usage gauge bars showing used and available capacity at a glance.
  - Quick action buttons to mount, unmount, rename, and safely eject removable storage.

---

## File Operations & Reliability
- [ ] **Guaranteed Sync / Safe Buffer Flush**: Enforce filesystem buffer flush (`sync`) before marking file copy/move operations as completed on removable drives, preventing data loss on early disconnect.
- [ ] **High-Performance Safe Copy/Move Pipeline**: Explore integration with tools like [`cppp`](https://github.com/kernelginar/cppp) or native Rust `copy_file_range` / `io_uring` with guaranteed buffer sync.
- [~] **Inline File Renaming**: Direct in-place text label editing on `F2` without spawning intrusive modal dialog windows. (Currently `F2` opens a modal input, not inline.)
- [x] **Smart Conflict Resolution Dialog**: Intelligent conflict prompt when pasting or moving existing files (side-by-side date and size comparisons, overwrite, auto-rename, skip, replace all).
- [ ] **Bulk Renamer**: Pattern-based and sequential multi-file renaming utility.
- [x] **Symlink Creation**: Context menu action and drag-and-drop modifier to create relative or absolute symbolic links. (Symlink badge shown on cards.)
- [x] **Archive Management**: Native archive creation and extraction (zip, tar.gz, 7z + advanced tar.xz/zst/bz2/cpio under experimental) with password encryption and progress feedback.

---

## Theming & Personalization
- [~] **Popular Theme Presets**: Built-in support for popular community palettes:
  - [x] Catppuccin
  - [x] Rosé Pine
  - [x] Tokyo Night
  - [x] Gruvbox
  - [x] Nord
  - [ ] Everforest (requested, missing)
  - [ ] Breeze (requested, missing)
- [x] **Dynamic Wallpaper Theming (Matugen / Pywal)**: Automatic color extraction and dynamic M3 palette generation based on the current desktop wallpaper (reads quickshell / wal / matugen `colors.json`).
- [~] **Custom Color Palette / User Config**: Preset accent palettes exist in settings, but no user-defined custom color tokens / config file yet.
- [ ] **Customizable Toolbar & Layout**: Configurable toolbar actions, reorderable sidebar places, and adjustable layout density (similar to Dolphin).
- [~] **Material 3 Custom Icon Set**: Phosphor vs system icon source toggle exists, but no dedicated MD3 icon variants.
- [x] **Header Hierarchy & Layout Polish**: Refine branding badge vs breadcrumb path styling to avoid ambiguity between the app name and the current directory name. (Brand badge show/hide setting added.)
- [ ] **Advanced Theme Creator**: Deeper theme editor beyond presets (Musa noted "plans to make a more advanced theme creator").

---

## Distribution & Install
- [ ] **AUR Package**: Publish `loaf` to the AUR for one-command Arch install (`popular-factor3553` request).
- [ ] **curl Install Script**: One-liner curl | sh install for quick setup (`popular-factor3553` request).

---

## Network & Remote Storage
- [ ] **Named SMB Profile Manager**: First-class SMB connection manager supporting human-readable aliases (e.g. "Home NAS", "Media Server") instead of raw auto-generated IP address strings.
- [ ] **Remote Protocol Support**: SFTP, FTP, and WebDAV support with saved profiles and sidebar bookmarks.

---

## Open With & Application Handling
- [x] **Open With…**: Right-click a file *or folder* to pick the app that opens it. MIME-aware suggestions (current default marked), a full "Other Applications" list, and a "Set Default Application" submenu that writes `mimeapps.list` via `xdg-mime`.
  - [x] Long app lists scroll (wheel + keyboard) instead of overflowing the screen.
  - [x] "Run Custom Command…" — type any shell command for the selected item (`%f` placeholder, shell syntax like pipes and redirection supported).
  - [x] **Recent** group (last 8 apps, persisted across restarts) at the top of *both* Open With and Set Default Application, with a history icon and the current default check-marked. Re-using an app moves it to the front; uninstalled apps drop out.
  - [ ] Per-file-type recent history (so a PDF viewer stays on top for PDFs only).
  - [ ] Surface recently used custom commands in the Open With list.
  - [ ] Add a "Open With…" toolbar/keyboard action (not only the context menu).
  - [ ] Show application icons from the `.desktop` `Icon=` key next to the entry names.

---

## Scrolling & Long Menus
- [x] **Scrollable context menus**: Menu rows live in a `Flickable` capped at 70% of the window height, so long menus (app lists, big directories) never overflow the screen.
  - [x] Mouse wheel scrolls the menu over a row without bubbling to the window behind it.
  - [x] Keyboard navigation scrolls the highlighted row into view.
  - [x] Scroll resets on open and is preserved when a submenu is re-shown with unchanged content.
  - [ ] Virtualized rows so menus with thousands of entries stay cheap (currently every row is instantiated).

---

## Integrations & Context Actions
- [ ] **Device Sharing (LocalSend & KDE Connect)**: Right-click context actions to send selected files directly to local devices via LocalSend or KDE Connect.
- [ ] **HTML Live Server**: Context menu action on `.html` files or web project folders to spin up an instant local HTTP live server and open it in the default browser.
- [ ] **Custom User Actions / Scripts**: Support for custom shell scripts and user-defined commands executed on selected files.
- [ ] **Open as Administrator**: "Open as root" / pkexec action for privileged operations (`naughtorious666`, `Azure-Tides` request).
- [ ] **Side Terminal Panel**: Embedded terminal (kitty/foot/ghostty) that can replace or sit beside the file preview (`naughtorious666` request).
- [ ] **Browse Inside Archives**: Open archives like folders without extracting (`aceusgrdj` request).
- [ ] **MTP / Android Device Support**: Native MTP and phone-over-USB file access (`Either-Tax-6948`, `Azure-Tides` request).
- [ ] **Keyring Integration**: Store SMB / encrypted directory passwords in the system keyring (`Azure-Tides` request).
