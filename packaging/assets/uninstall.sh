#!/usr/bin/env bash
set -e

PREFIX="${PREFIX:-$HOME/.local}"

if [ "$1" = "--system" ] || [ "$EUID" -eq 0 ]; then
    PREFIX="/usr/local"
fi

echo "Uninstalling Loaf from $PREFIX..."

rm -f "$PREFIX/bin/loaf"
rm -f "$PREFIX/share/applications/loaf.desktop"
find "$PREFIX/share/icons/hicolor" -name "loaf.png" -delete 2>/dev/null || true
find "$PREFIX/share/icons/hicolor" -name "loaf.svg" -delete 2>/dev/null || true

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true
fi

echo "Loaf uninstalled."
