#!/usr/bin/env bash
set -e

PREFIX="${PREFIX:-$HOME/.local}"

if [ "$1" = "--system" ] || [ "$EUID" -eq 0 ]; then
    PREFIX="/usr/local"
fi

echo "Installing Loaf v0.1.0 to $PREFIX..."

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

cp -r "$DIR/share/icons/hicolor/"* "$PREFIX/share/icons/hicolor/"

# Update desktop and icon databases if available
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$PREFIX/share/icons/hicolor" 2>/dev/null || true
fi

echo "Successfully installed Loaf! Run it with: loaf"
