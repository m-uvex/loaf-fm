#!/usr/bin/env bash
set -e

PREFIX="${PREFIX:-$HOME/.local}"

if [ "$1" = "--system" ] || [ "$EUID" -eq 0 ]; then
    PREFIX="/usr/local"
fi

echo "Installing Loaf v0.2.0 to $PREFIX..."

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$PREFIX/bin"
mkdir -p "$PREFIX/share/applications"
mkdir -p "$PREFIX/share/icons/hicolor"

install -m 755 "$DIR/bin/loaf" "$PREFIX/bin/loaf"
install -m 644 "$DIR/share/applications/loaf.desktop" "$PREFIX/share/applications/loaf.desktop"

# Fix Exec path if installed in custom prefix
if [ "$PREFIX" != "/usr" ]; then
    sed -i "s|^Exec=loaf|Exec=$PREFIX/bin/loaf|" "$PREFIX/share/applications/loaf.desktop"
fi

# xdg-desktop-portal backend (file chooser) + D-Bus activation.
mkdir -p "$PREFIX/share/xdg-desktop-portal/portals" "$PREFIX/share/dbus-1/services"
install -m 644 "$DIR/share/xdg-desktop-portal/portals/loaf.portal" "$PREFIX/share/xdg-desktop-portal/portals/loaf.portal"
install -m 644 "$DIR/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service" "$PREFIX/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service"
if [ "$PREFIX" != "/usr" ]; then
    sed -i "s|^Exec=/usr/bin/loaf|Exec=$PREFIX/bin/loaf|" "$PREFIX/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service"
fi

cp -r "$DIR/share/icons/hicolor/"* "$PREFIX/share/icons/hicolor/"

if [ -f "$DIR/LICENSE" ] || [ -f "$DIR/share/licenses/loaf/LICENSE" ]; then
    mkdir -p "$PREFIX/share/licenses/loaf"
    [ -f "$DIR/LICENSE" ] && install -m 644 "$DIR/LICENSE" "$PREFIX/share/licenses/loaf/LICENSE"
    [ -f "$DIR/THIRD-PARTY-LICENSES.md" ] && install -m 644 "$DIR/THIRD-PARTY-LICENSES.md" "$PREFIX/share/licenses/loaf/THIRD-PARTY-LICENSES.md"
    [ -f "$DIR/share/licenses/loaf/LICENSE" ] && install -m 644 "$DIR/share/licenses/loaf/LICENSE" "$PREFIX/share/licenses/loaf/LICENSE"
    [ -f "$DIR/share/licenses/loaf/THIRD-PARTY-LICENSES.md" ] && install -m 644 "$DIR/share/licenses/loaf/THIRD-PARTY-LICENSES.md" "$PREFIX/share/licenses/loaf/THIRD-PARTY-LICENSES.md"
fi

# Update desktop and icon databases if available
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$PREFIX/share/icons/hicolor" 2>/dev/null || true
fi

echo "Successfully installed Loaf! Run it with: loaf"
