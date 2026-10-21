# Loaf Roadmap & Suggestions

Feature suggestions collected from Reddit, discussions, and idea dumps (including community contributions)

Legend: `[x]` done, `[~]` partial / missing a piece, `[ ]` not started

---

## Navigation & Views
- [ ] **Miller Columns (Cascading View)**: Hierarchical column-by-column browsing mode (like macOS Finder / Yazi) for rapid drill-down directory traversal.
- [ ] **Per-Folder View Preferences**: (togglable in settings) Remember layout preferences per directory with auto-detection (e.g. automatic large thumbnail grid for `Pictures` and `Videos`, compact list/table view for code and documents).
- [ ] **Pictures Gallery View**: Dedicated gallery view for `Pictures/` and any subdirectories, displaying all images in a large gallery layout with a bottom pane/window for any non-picture files.
- [ ] **Bookshelf View (`~/Games` default)**: Horizontally scrollable bookshelf layout for games/roms where directories render as physical disc covers with titles and metadata printed sideways on their spines.
- [ ] **Minecraft Folder Specific View**: Special launcher-like categorized workspace layout inside any Minecraft directory to neatly organize screenshots, worlds, and mods.
- [ ] **Physics-Enabled Toy View (Trash / Fun)**: Physics-enabled sandbox view where files fall, can be dragged, thrown, and bounced around (especially fun inside the Trash directory).
- [ ] **"This PC" 3D Room Desk View**: Immersive room layout view where folders and system locations sit on physical desk items (e.g., Trashcan on the floor, Pictures on the wall, Projects in a drawer, Music on a vinyl player).
- [ ] **Split View**: Side-by-side split view mode to view and manage multiple directories simultaneously.
- [ ] **Quick Look / File Preview & Right Sidebar**: Instant preview panel / overlay (Spacebar trigger) and dedicated collapsible right sidebar with file info and preview.
- [ ] **Tabs & Experimental Vertical Tabs**: Tabbed browsing interface with support for an experimental vertical tabs layout mode.
- [ ] **Alternative View Experiments**:
  - [ ] 2D infinite canvas / plane view (spatial Apple-Watch-style bubble view sorted outwards from the center by date/criteria).
  - [ ] Horizontal scrolling flow (Niri-inspired horizontal scroll grid instead of vertical grid).
- [ ] **Vim Navigation Keybindings**: Full keyboard-driven navigation (`h`, `j`, `k`, `l`, visual select, quick filter jump) for power users who want a GUI with terminal-speed navigation.
- [x] **Direct Path Entry**: Clickable path bar toggle to edit raw Unix paths directly with tab completion.
- [~] **State & Session Persistence**: Retain last visited directory, open tabs, and window geometry across application restarts (including resuming last active session upon restart).
- [ ] **IDE-Like File Tree View**: Integrated inline file tree directory view directly inside the main workspace.
- [ ] **Grouping in Directory View**: Group items by criteria such as modification date, size, or type.
- [ ] **Starred / Pinned Files**: Star any file to pin it to a dedicated Starred section at the top of the directory view.
- [x] **View Size Control**: Adjustable view size/zoom via view menu, `Ctrl + Scroll` wheel, and `Ctrl + +/-`.

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
- [~] **Inline File Renaming**: Direct in-place text label editing on `F2` without spawning intrusive modal dialog windows.
- [x] **Smart Conflict Resolution Dialog**: Intelligent conflict prompt when pasting or moving existing files (side-by-side date and size comparisons, overwrite, auto-rename, skip, replace all).
- [ ] **Bulk Renamer**: Pattern-based and sequential multi-file renaming utility.
- [x] **Symlink Creation**: Context menu action and drag-and-drop modifier to create relative or absolute symbolic links.
- [x] **Archive Management**: Native archive creation and extraction (zip, tar.gz, 7z + advanced formats) with password encryption and progress feedback.
- [ ] **Universal Virtual Disk Archive Reader**: Support browsing and extracting raw disk images and virtual machine container formats (`.iso`, `.img`, `.vmdk`, `.vdi`) including GPT/MBR partitions.
- [ ] **Downloads Smart Organizer**: Context menu "Organize" action for the Downloads folder using an intelligent rule-based / AI assistant structure to categorize files, purge useless installers, and remove duplicates.
- [ ] **File Picker Mode**: Standalone file picker integration mode allowing Loaf to serve as the system file open/save dialog.
- [ ] **File Converter**: On-the-fly file conversion utility supporting bulk image conversions (e.g. PNG to JPG) directly in the right-click context menu.
- [ ] **Video Compressor**: Video compression utility in media context menus with target size selection and presets (e.g. Discord, WhatsApp).
- [ ] **PDF Tools Submenu**: Right-click context menu actions for PDF files to extract images, merge multiple PDFs, and more.
- [ ] **Animated Trashcan**: Polished animations for trashing items, restoring files from trash, and emptying/cleaning the trash can.
- [ ] **M3E Operation Progress Indicator**: Bottom-right floating Material 3 Expressive loading pill with active operation count, expandable history drawer, and cancellation controls.

---

## Theming & Personalization
- [~] **Popular Theme Presets**: Catppuccin, Rosé Pine, Tokyo Night, Gruvbox, Nord (Everforest & Breeze requested).
- [x] **Dynamic Wallpaper Theming (Matugen / Pywal)**: Automatic color extraction and dynamic M3 palette generation based on current desktop wallpaper.
- [~] **Custom Color Palette / User Config**: Preset accent palettes exist, but user-defined custom color tokens / config file planned.
- [ ] **Customizable Toolbar & Layout**: Configurable toolbar actions and adjustable layout density.
- [x] **Header Hierarchy & Layout Polish**: Branding badge vs breadcrumb path toggle and polish.
- [ ] **Mini / Compact Mode**: Ultra-compact layout mode showing only essential information for minimalist workflows.
- [ ] **Background Opacity Control**: Adjustable window background opacity setting for transparent rice aesthetics.
- [ ] **Customizable Directory Icons**: Override theme and app defaults for any directory's icon and color. Dedicated settings manager tab for viewing and bulk-customizing all custom folder icons.

---

## Sidebar & Context Menu Customization
- [ ] **Sidebar Customization**: Reorder, add, or remove items (including "Any file" and default places) and manage storage/remote devices.
- [ ] **Context Menu Editor**: Customizer to enable, disable, or reorder any button in context menus for complete decluttering.

---

## Network, Cloud & Remote Storage
- [ ] **Named SMB Profile Manager**: Friendly aliases for SMB connections.
- [ ] **Remote Protocols & Cloud Services**: SFTP, FTP, WebDAV, Google Drive, and Microsoft OneDrive mounting support.
- [ ] **Keyring Integration**: Secure password storage in system keyring for SMB and encrypted volumes.

---

## CLI & Runtime Options
- [ ] **Robust CLI Argument Parser**: Command-line interface flags for startup behavior and diagnostics:
  - `-v` / `--verbose`: Detailed stdout/stderr logging (file scanning, IPC, thumbnail generation).
  - `-p` / `--path <dir>`: Launch directly into a specific directory.
  - `-m` / `--mini`: Start in ultra-compact Mini mode.
  - `--version`: Display version information and exit.
  - `-h` / `--help`: Print CLI usage instructions and flags.

---

## Integrations & Context Actions
- [ ] **Device Sharing (LocalSend, KDE Connect & Bluetooth)**: Send selected files directly to local devices via LocalSend, KDE Connect, or Bluetooth file transfer.
- [ ] **Send by Link**: Upload file to a free hosting service (e.g. Catbox / GoFile), generate and shorten a shareable download link, and copy it to clipboard.
- [ ] **HTML Live Server**: Context menu action on `.html` files or web folders to spin up an instant localhost server and open in browser.
- [ ] **Git Integration**: In git repositories, display repository info/commits, and provide a Git submenu in folder context menus (Sync, Pull, Push, Open on GitHub/GitLab).
- [ ] **Nautilus Scripts Support**: Full compatibility with standard Nautilus scripts system.
- [ ] **Open as Administrator**: Root / pkexec operations support.
- [ ] **Side Terminal Panel**: Embedded terminal panel next to previews.
- [ ] **Browse Inside Archives**: Direct archive tree navigation without extraction.
- [ ] **MTP / Android Device Support**: Native phone-over-USB storage access.
- [ ] **Video Thumbnails**: Extract and display video frame thumbnails in grid and list views.
- [ ] **Advanced Selection Behaviors**:
  - [ ] Grid-accurate shift selection (selecting a file then `Shift + Down` selects only the item directly underneath, bypassing left-to-right row wrapping).
  - [ ] Seamless connected selection supporting vertical and list view layouts.

---

## Web & Landing Page
- [ ] **Landing Page (`loaf.muvex.dev`)**: Build and publish a clean landing page website for `loaf` at `loaf.muvex.dev`.
