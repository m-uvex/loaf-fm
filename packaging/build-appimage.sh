#!/usr/bin/env bash
set -eo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$DIR/packaging/dist"
APPDIR="$DIR/packaging/AppDir"

VERSION="$(grep -m1 '^version = ' "$DIR/Cargo.toml" | cut -d '"' -f2)"
VERSION="${VERSION:-0.2.0}"

BIN="$DIR/target/release/loaf"
if [ ! -f "$BIN" ]; then
    if [ -f "$DIR/target/debug/loaf" ]; then
        BIN="$DIR/target/debug/loaf"
    else
        echo "Binary not found at $BIN. Building release binary..."
        (cd "$DIR" && cargo build --release)
    fi
fi

mkdir -p "$DIST"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor"
mkdir -p "$APPDIR/usr/share/doc/loaf"
mkdir -p "$APPDIR/usr/share/licenses/loaf"

echo "Staging AppDir for Loaf v$VERSION..."
cp "$BIN" "$APPDIR/usr/bin/loaf"
cp "$DIR/packaging/assets/loaf.desktop" "$APPDIR/usr/share/applications/loaf.desktop"
cp "$DIR/packaging/assets/loaf.desktop" "$APPDIR/loaf.desktop"
cp -r "$DIR/packaging/assets/icons/hicolor/." "$APPDIR/usr/share/icons/hicolor/"
cp "$DIR/packaging/assets/icons/hicolor/scalable/apps/loaf.svg" "$APPDIR/loaf.svg"
if [ -f "$DIR/packaging/assets/icons/hicolor/256x256/apps/loaf.png" ]; then
    cp "$DIR/packaging/assets/icons/hicolor/256x256/apps/loaf.png" "$APPDIR/loaf.png"
fi

if [ -f "$DIR/LICENSE" ]; then
    cp "$DIR/LICENSE" "$APPDIR/usr/share/licenses/loaf/LICENSE"
fi
if [ -f "$DIR/THIRD-PARTY-LICENSES.md" ]; then
    cp "$DIR/THIRD-PARTY-LICENSES.md" "$APPDIR/usr/share/licenses/loaf/THIRD-PARTY-LICENSES.md"
fi
if [ -f "$DIR/README.md" ]; then
    cp "$DIR/README.md" "$APPDIR/usr/share/doc/loaf/README.md"
fi

TOOLS_DIR="$DIR/packaging/.tools"
mkdir -p "$TOOLS_DIR"

LINUXDEPLOY="$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_QT="$TOOLS_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
APPIMAGE_RUNTIME="$TOOLS_DIR/runtime-x86_64"

download_tool() {
    local target="$1"
    local repo="$2"
    local filename="$3"

    echo "Fetching $filename..."
    # 1. Try direct GitHub release download
    if curl -fsSL --retry 3 --max-time 60 -o "$target" \
        "https://github.com/$repo/releases/download/continuous/$filename" 2>/dev/null; then
        chmod +x "$target"
        return 0
    fi

    # 2. Fallback: resolve asset via GitHub API (bypasses fastly/cloudflare 504 on direct release downloads)
    echo "Direct download failed, resolving asset ID via GitHub API for $filename..."
    local asset_id
    asset_id=$(curl -sL "https://api.github.com/repos/$repo/releases/tags/continuous" | \
        grep -B2 "\"$filename\"" | grep '"id":' | head -1 | tr -dc '0-9')
    if [ -n "$asset_id" ]; then
        if curl -fsSL --retry 3 --max-time 90 -H "Accept: application/octet-stream" \
            "https://api.github.com/repos/$repo/releases/assets/$asset_id" -o "$target"; then
            chmod +x "$target"
            return 0
        fi
    fi

    echo "Failed to fetch $filename" >&2
    return 1
}

if [ ! -f "$LINUXDEPLOY" ]; then
    download_tool "$LINUXDEPLOY" "linuxdeploy/linuxdeploy" "linuxdeploy-x86_64.AppImage"
fi

if [ ! -f "$LINUXDEPLOY_QT" ]; then
    download_tool "$LINUXDEPLOY_QT" "linuxdeploy/linuxdeploy-plugin-qt" "linuxdeploy-plugin-qt-x86_64.AppImage"
fi

if [ ! -f "$APPIMAGE_RUNTIME" ]; then
    download_tool "$APPIMAGE_RUNTIME" "AppImage/type2-runtime" "runtime-x86_64"
fi

export LDAI_RUNTIME_FILE="$APPIMAGE_RUNTIME"
export QML_SOURCES_PATHS="$DIR/qml"
export LDA_NO_COPY_COPYRIGHT_FILES=1

OUTPUT_NAME="Loaf-v${VERSION}-x86_64.AppImage"

echo "Running linuxdeploy to bundle Qt6 libraries and generate AppImage..."
"$LINUXDEPLOY" --appimage-extract-and-run \
    --appdir "$APPDIR" \
    -e "$BIN" \
    -d "$APPDIR/loaf.desktop" \
    -i "$APPDIR/loaf.svg" \
    --plugin qt \
    --output appimage

if [ -f "Loaf-${VERSION}-x86_64.AppImage" ]; then
    mv "Loaf-${VERSION}-x86_64.AppImage" "$DIST/$OUTPUT_NAME"
elif [ -f "Loaf-x86_64.AppImage" ]; then
    mv "Loaf-x86_64.AppImage" "$DIST/$OUTPUT_NAME"
fi

echo "AppImage created at $DIST/$OUTPUT_NAME"
(cd "$DIST" && sha256sum "$OUTPUT_NAME" >> SHA256SUMS 2>/dev/null || true)
