#!/usr/bin/env bash
# ==============================================================================
# Loaf Installation, Update, Uninstall & Run Script
#
# Official install:
#   curl -sSL https://raw.githubusercontent.com/m-uvex/loaf-fm/main/install.sh | bash
#
# Options:
#   curl -sSL ... | bash -s -- --tarball     # Force standalone tarball install
#   curl -sSL ... | bash -s -- --update      # Update to latest stable release
#   curl -sSL ... | bash -s -- --uninstall   # Uninstall Loaf
#   curl -sSL ... | bash -s -- --try         # Ephemeral test run without installing
#
# Environment variables:
#   LOAF_OS_SPOOF  Override /etc/os-release ID for testing (e.g. LOAF_OS_SPOOF=ubuntu)
#   PREFIX         Install prefix for tarball installs (default: $HOME/.local)
# ==============================================================================

if [ -z "${BASH_VERSION:-}" ]; then
    echo "This installer requires bash. Run: curl -sSL ... | bash" >&2
    exit 1
fi

set -eo pipefail

REPO="m-uvex/loaf-fm"
GITHUB="https://github.com"
API="https://api.github.com"

RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[38;5:38m'
AMBER='\033[38;5:214m'
GREEN='\033[38;5:78m'
RED='\033[38;5:203m'
MUTED='\033[38;5:246m'

print_banner() {
    echo -e "${AMBER}${BOLD}"
    echo "___       ________  ________  ________ "
    echo "|\  \     |\   __  \|\   __  \|\  _____\:"
    echo "\ \  \    \ \  \|\  \ \  \|\  \ \  \__/ "
    echo " \ \  \    \ \  \\\  \ \   __  \ \   __\ "
    echo "  \ \  \____\ \  \\\  \ \  \ \  \ \  \_| "
    echo "   \ \_______\ \_______\ \__\ \__\ \__\ "
    echo "    \|_______|\|_______|\|__|\|__|\|__| "
    echo -e "${RESET}${DIM} Loaf File Manager Installer${RESET}"
    echo -e "${MUTED} ----------------------------------------${RESET}"
}

detect_os() {
    OS_LIKE=""
    if [ -n "${LOAF_OS_SPOOF:-}" ]; then
        echo -e "${AMBER}[!] OS Spoofer active: spoofing ID as '$LOAF_OS_SPOOF'${RESET}"
        OS_ID="$LOAF_OS_SPOOF"
        OS_NAME="Spoofed $LOAF_OS_SPOOF"
        return
    fi

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_NAME="${PRETTY_NAME:-$ID}"
        OS_LIKE="${ID_LIKE:-}"
    elif [ "$(uname)" = "Darwin" ]; then
        OS_ID="macos"
        OS_NAME="macOS"
    else
        OS_ID="unknown"
        OS_NAME="Unknown OS"
    fi
}

check_nixos() {
    if [ "$OS_ID" = "nixos" ]; then
        echo -e "\n${CYAN}================================================================${RESET}"
        echo -e "${CYAN}${BOLD}  NixOS Detected (${OS_NAME})${RESET}"
        echo -e "${CYAN}================================================================${RESET}"
        echo -e "NixOS uses declarative packages. To run or install Loaf on NixOS:\n"
        echo -e "  Run ephemerally:   ${GREEN}nix run github:${REPO}${RESET}"
        echo -e "  Add to flake.nix:  ${GREEN}inputs.loaf.url = \"github:${REPO}\";${RESET}"
        echo -e "                     ${GREEN}environment.systemPackages = [ inputs.loaf.packages.\${pkgs.system}.default ];${RESET}\n"
        echo -e "See the README for complete NixOS instructions."
        echo -e "${CYAN}================================================================${RESET}"
        exit 0
    fi
}

detect_arch() {
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64)  BINARY_ARCH="x86_64"; DEB_ARCH="amd64" ;;
        aarch64|arm64) BINARY_ARCH="aarch64"; DEB_ARCH="arm64" ;;
        *)
            echo -e "${RED}Error: Unsupported architecture: $ARCH${RESET}"
            exit 1
            ;;
    esac
}

detect_pkg_family() {
    PKG_FAMILY="none"
    RPM_FRONTEND="dnf"

    local probe
    for probe in "$OS_ID" $OS_LIKE; do
        case "$probe" in
            debian|ubuntu|linuxmint|pop|elementary|kali|raspbian|neon|zorin)
                PKG_FAMILY="deb"; break ;;
            arch|archlinux|manjaro|endeavouros|cachyos|artix|garuda)
                PKG_FAMILY="pacman"; break ;;
            fedora|rhel|centos|rocky|almalinux|nobara)
                PKG_FAMILY="rpm"; RPM_FRONTEND="dnf"; break ;;
            opensuse*|sles|suse)
                PKG_FAMILY="rpm"; RPM_FRONTEND="zypper"; break ;;
        esac
    done
}

determine_prefix() {
    if [ "${1:-}" = "--system" ] || [ "${EUID:-$(id -u)}" -eq 0 ]; then
        PREFIX="${PREFIX:-/usr/local}"
    else
        PREFIX="${PREFIX:-$HOME/.local}"
    fi
}

as_root() {
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        echo -e "${RED}Error: '$1' requires root privileges, but sudo is unavailable.${RESET}"
        exit 1
    fi
}

check_installed() {
    case "${PKG_FAMILY:-none}" in
        deb)    command -v dpkg >/dev/null 2>&1 && dpkg -s loaf >/dev/null 2>&1 && return 0 ;;
        rpm)    command -v rpm >/dev/null 2>&1 && rpm -q loaf >/dev/null 2>&1 && return 0 ;;
        pacman) command -v pacman >/dev/null 2>&1 && pacman -Q loaf >/dev/null 2>&1 && return 0 ;;
    esac
    [ -f "$PREFIX/bin/loaf" ]
}

RELEASE_JSON=""
get_release_info() {
    if [ -n "$RELEASE_JSON" ]; then
        return 0
    fi

    local url
    if [ -n "${VERSION_TAG:-}" ] && [ "$VERSION_TAG" != "latest" ]; then
        url="$API/repos/$REPO/releases/tags/$VERSION_TAG"
    else
        url="$API/repos/$REPO/releases/latest"
    fi

    echo -e "${CYAN}[*] Fetching release metadata from GitHub...${RESET}"
    RELEASE_JSON="$(curl -fsSL --max-time 15 "$url" 2>/dev/null || true)"
    if [ -z "$RELEASE_JSON" ]; then
        echo -e "${AMBER}[!] GitHub API request failed (rate limited?). Fetching releases page...${RESET}"
        # Fallback to direct releases page if API is rate-limited
        RELEASE_JSON="$(curl -fsSL --max-time 15 "$GITHUB/$REPO/releases/latest" 2>/dev/null || true)"
    fi
}

extract_asset_url() {
    local pattern="$1"
    printf '%s' "$RELEASE_JSON" \
        | grep -o '"browser_download_url": *"[^"]*'"$pattern"'"' \
        | head -n 1 \
        | sed 's/.*"\(https[^"]*\)".*/\1/'
}

download_asset() {
    local dest="$1" kind="$2"
    ASSET_FILE=""
    SRC_ROOT=""

    get_release_info

    local pattern
    local ver="${VERSION_TAG#v}"
    local vpat="${ver:-[^\"/]*}"

    case "$PKG_FAMILY-$kind" in
        deb-native)    pattern="loaf_.*_${DEB_ARCH}\\.deb" ;;
        pacman-native) pattern="loaf-.*-${BINARY_ARCH}\\.pkg\\.tar\\.zst" ;;
        rpm-native)    pattern="loaf-.*\\.${BINARY_ARCH}\\.rpm" ;;
        *-appimage)    pattern="Loaf-.*-${BINARY_ARCH}\\.AppImage" ;;
        *)             pattern="loaf-.*-linux-${BINARY_ARCH}\\.tar\\.gz" ;;
    esac

    local url
    url="$(extract_asset_url "$pattern")"
    if [ -z "$url" ]; then
        return 1
    fi

    local filename
    filename="$(basename "$url")"
    echo -e "${CYAN}[*] Downloading $filename...${RESET}"
    if ! curl -fSL --progress-bar "$url" -o "$dest/$filename"; then
        echo -e "${RED}Error: Failed to download $url${RESET}"
        return 1
    fi

    ASSET_FILE="$dest/$filename"

    if [ "$kind" = "tarball" ]; then
        echo -e "${CYAN}[*] Extracting $filename...${RESET}"
        tar -xzf "$ASSET_FILE" -C "$dest"
        SRC_ROOT="$(find "$dest" -maxdepth 3 -type f -path '*/bin/loaf' 2>/dev/null | head -n 1 | xargs -r dirname | xargs -r dirname)"
        [ -n "$SRC_ROOT" ] && [ -f "$SRC_ROOT/bin/loaf" ] || return 1
    fi

    return 0
}

install_native_package() {
    local pkgfile="$1"
    echo -e "${CYAN}[*] Installing $(basename "$pkgfile") via system package manager...${RESET}"
    case "$PKG_FAMILY" in
        deb)
            if command -v apt-get >/dev/null 2>&1; then
                as_root apt-get update -qq || true
                as_root apt-get install -y "$pkgfile" || {
                    as_root dpkg -i "$pkgfile" || true
                    as_root apt-get install -f -y
                }
            else
                as_root dpkg -i "$pkgfile"
            fi
            ;;
        pacman)
            as_root pacman -U --noconfirm "$pkgfile"
            ;;
        rpm)
            if [ "$RPM_FRONTEND" = "zypper" ]; then
                as_root zypper --non-interactive install "$pkgfile"
            else
                as_root dnf install -y "$pkgfile"
            fi
            ;;
        *)
            echo -e "${RED}Error: No native package manager configured for this distribution.${RESET}"
            return 1
            ;;
    esac
}

install_from_tree() {
    local tree="$1"
    echo -e "${CYAN}[*] Installing files into $PREFIX...${RESET}"
    mkdir -p "$PREFIX/bin" "$PREFIX/share/applications" "$PREFIX/share/icons/hicolor"

    install -m 755 "$tree/bin/loaf" "$PREFIX/bin/loaf"

    if [ -f "$tree/share/applications/loaf.desktop" ]; then
        install -m 644 "$tree/share/applications/loaf.desktop" "$PREFIX/share/applications/loaf.desktop"
        if [ "$PREFIX" != "/usr" ]; then
            if ! sed -i "s|^Exec=loaf|Exec=$PREFIX/bin/loaf|" "$PREFIX/share/applications/loaf.desktop" 2>/dev/null; then
                echo -e "${AMBER}[!] Warning: failed to update Exec path in $PREFIX/share/applications/loaf.desktop${RESET}" >&2
            fi
        fi
    fi

    # xdg-desktop-portal backend (file chooser) + D-Bus activation.
    if [ -f "$tree/share/xdg-desktop-portal/portals/loaf.portal" ]; then
        mkdir -p "$PREFIX/share/xdg-desktop-portal/portals"
        install -m 644 "$tree/share/xdg-desktop-portal/portals/loaf.portal" "$PREFIX/share/xdg-desktop-portal/portals/loaf.portal"
    fi
    if [ -f "$tree/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service" ]; then
        mkdir -p "$PREFIX/share/dbus-1/services"
        install -m 644 "$tree/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service" \
            "$PREFIX/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service"
        if [ "$PREFIX" != "/usr" ]; then
            if ! sed -i "s|^Exec=/usr/bin/loaf|Exec=$PREFIX/bin/loaf|" \
                "$PREFIX/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service" 2>/dev/null; then
                echo -e "${AMBER}[!] Warning: failed to update Exec path in $PREFIX/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service${RESET}" >&2
            fi
        fi

    if [ -d "$tree/share/icons/hicolor" ]; then
        cp -r "$tree/share/icons/hicolor/." "$PREFIX/share/icons/hicolor/" 2>/dev/null || true
    fi

    if [ -d "$tree/share/licenses/loaf" ]; then
        mkdir -p "$PREFIX/share/licenses/loaf"
        cp -r "$tree/share/licenses/loaf/." "$PREFIX/share/licenses/loaf/" 2>/dev/null || true
    fi

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "$PREFIX/share/icons/hicolor" 2>/dev/null || true
    fi
}

remove_native_package() {
    echo -e "${CYAN}[*] Removing Loaf via system package manager...${RESET}"
    case "$PKG_FAMILY" in
        deb)     as_root apt-get remove -y loaf ;;
        pacman)  as_root pacman -R --noconfirm loaf ;;
        rpm)
            if [ "$RPM_FRONTEND" = "zypper" ]; then
                as_root zypper --non-interactive remove loaf
            else
                as_root dnf remove -y loaf
            fi
            ;;
    esac
}

remove_tarball_files() {
    echo -e "${CYAN}[*] Removing Loaf files from $PREFIX...${RESET}"
    rm -f "$PREFIX/bin/loaf"
    rm -f "$PREFIX/share/applications/loaf.desktop"
    rm -f "$PREFIX/share/xdg-desktop-portal/portals/loaf.portal"
    rm -f "$PREFIX/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service"
    rm -rf "$PREFIX/share/licenses/loaf"
    find "$PREFIX/share/icons/hicolor" -name "loaf.png" -delete 2>/dev/null || true
    find "$PREFIX/share/icons/hicolor" -name "loaf.svg" -delete 2>/dev/null || true

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true
    fi
}

do_install() {
    print_banner
    detect_os
    check_nixos
    detect_arch
    detect_pkg_family
    determine_prefix "$@"

    echo -e "Platform: ${CYAN}${OS_NAME}${RESET} (${BINARY_ARCH})"
    if [ "$PKG_FAMILY" != "none" ] && [ "${FORCE_TARBALL:-0}" -ne 1 ]; then
        echo -e "Target:   ${GREEN}Native package (${PKG_FAMILY})${RESET}"
    else
        echo -e "Target:   ${CYAN}Universal tarball ($PREFIX)${RESET}"
    fi
    echo ""

    WORKDIR="$(mktemp -d)"
    trap 'rm -rf "$WORKDIR"' EXIT

    local installed=0

    # Try AppImage first if explicitly requested
    if [ "${FORCE_APPIMAGE:-0}" -eq 1 ]; then
        if download_asset "$WORKDIR" appimage; then
            mkdir -p "$PREFIX/bin"
            install -m 755 "$ASSET_FILE" "$PREFIX/bin/loaf"
            installed=1
        else
            echo -e "${AMBER}[!] AppImage download failed; attempting fallback...${RESET}"
        fi
    fi

    # Try native package first unless forced to tarball/appimage
    if [ "$installed" -eq 0 ] && [ "${FORCE_TARBALL:-0}" -ne 1 ] && [ "${FORCE_APPIMAGE:-0}" -ne 1 ] && [ "$PKG_FAMILY" != "none" ]; then
        if download_asset "$WORKDIR" native; then
            if install_native_package "$ASSET_FILE"; then
                installed=1
            else
                echo -e "${AMBER}[!] Native package installation encountered an issue. Falling back to universal tarball...${RESET}"
            fi
        else
            echo -e "${AMBER}[!] No native package asset found for $OS_NAME; using universal tarball...${RESET}"
        fi
    fi

    # Fall back to standalone tarball
    if [ "$installed" -eq 0 ]; then
        if download_asset "$WORKDIR" tarball; then
            install_from_tree "$SRC_ROOT"
            installed=1
        fi
    fi

    # Local checkout fallback
    if [ "$installed" -eq 0 ]; then
        if [ -f "./target/release/loaf" ]; then
            echo -e "${GREEN}[+] Installing from existing local build (./target/release/loaf)...${RESET}"
            install_from_tree "."
            installed=1
        elif [ -f "./Cargo.toml" ] && command -v cargo >/dev/null 2>&1; then
            echo -e "${AMBER}[!] Building from local source with cargo...${RESET}"
            cargo build --release
            install_from_tree "."
            installed=1
        fi
    fi

    if [ "$installed" -eq 0 ]; then
        echo -e "\n${RED}Error: Could not install Loaf.${RESET}"
        echo -e "Please check your network connection or build manually from source:"
        echo -e "  git clone $GITHUB/$REPO.git && cd loaf && cargo build --release"
        exit 1
    fi

    echo -e "\n${GREEN}${BOLD}[✔] Loaf installed successfully!${RESET}"
    echo -e "Run it with: ${CYAN}loaf${RESET}"

    if [ "$PKG_FAMILY" = "none" ] || [ "${FORCE_TARBALL:-0}" -eq 1 ]; then
        if ! echo ":$PATH:" | grep -q ":$PREFIX/bin:"; then
            echo -e "${AMBER}Notice:${RESET} Add ${CYAN}$PREFIX/bin${RESET} to your PATH if it is not already included:"
            echo -e "  export PATH=\"$PREFIX/bin:\$PATH\""
        fi
    fi
}

do_update() {
    print_banner
    detect_os
    check_nixos
    detect_arch
    detect_pkg_family
    determine_prefix "$@"

    echo -e "${CYAN}[*] Checking for Loaf updates...${RESET}"
    do_install "$@"
}

do_uninstall() {
    print_banner
    detect_os
    check_nixos
    detect_arch
    detect_pkg_family
    determine_prefix "$@"

    if check_installed; then
        case "$PKG_FAMILY" in
            deb|rpm|pacman) remove_native_package 2>/dev/null || true ;;
        esac
        remove_tarball_files
        echo -e "\n${GREEN}[✔] Loaf uninstalled successfully.${RESET}"
    else
        echo -e "${AMBER}Loaf does not appear to be installed on this system.${RESET}"
    fi
}

do_try() {
    print_banner
    detect_os
    check_nixos
    detect_arch
    detect_pkg_family

    echo -e "\n${CYAN}[*] Launching ephemeral test instance of Loaf...${RESET}"
    WORKDIR="$(mktemp -d)"
    trap 'rm -rf "$WORKDIR"' EXIT

    local run_bin=""
    if [ -f "./target/release/loaf" ]; then
        run_bin="./target/release/loaf"
    elif download_asset "$WORKDIR" tarball; then
        run_bin="$SRC_ROOT/bin/loaf"
    else
        echo -e "${RED}Error: Could not retrieve a binary to test.${RESET}"
        exit 1
    fi

    echo -e "${GREEN}[✔] Starting Loaf (Ctrl+C to quit)...${RESET}\n"
    "$run_bin"
}

show_help() {
    print_banner
    echo "Usage: curl -sSL https://raw.githubusercontent.com/$REPO/main/install.sh | bash [options]"
    echo ""
    echo "Options:"
    echo "  (none)        Install Loaf automatically using native packages or tarball"
    echo "  --appimage    Install standalone AppImage directly into \$PREFIX/bin"
    echo "  --tarball     Install universal standalone tarball directly into \$PREFIX"
    echo "  --update      Update Loaf to the latest stable version"
    echo "  --uninstall   Remove Loaf from your system"
    echo "  --try         Run Loaf temporarily without installing"
    echo "  --system      Install system-wide to /usr/local instead of ~/.local"
    echo "  --help, -h    Show this help dialog"
    echo ""
    echo "Environment Variables:"
    echo "  PREFIX        Install prefix for tarballs (default: \$HOME/.local)"
    echo "  LOAF_OS_SPOOF Override detected OS ID (for testing)"
    echo ""
}

main() {
    case "${1:-}" in
        --try|try)
            shift; do_try "$@"
            ;;
        --update|update)
            shift; do_update "$@"
            ;;
        --uninstall|uninstall)
            shift; do_uninstall "$@"
            ;;
        --appimage|appimage)
            FORCE_APPIMAGE=1; shift; do_install "$@"
            ;;
        --tarball|tarball)
            FORCE_TARBALL=1; shift; do_install "$@"
            ;;
        --help|-h|help)
            show_help
            ;;
        --install|install|"")
            [ "${1:-}" = "--install" ] || [ "${1:-}" = "install" ] && shift
            do_install "$@"
            ;;
        *)
            echo -e "${RED}Unknown option: $1${RESET}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
