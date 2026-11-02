#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$DIR/packaging/dist"

VERSION="$(grep -m1 '^version = ' "$DIR/Cargo.toml" | cut -d '"' -f2)"
if [ -z "$VERSION" ]; then
    VERSION="0.2.0"
fi

if [ -f "$DIR/target/release/loaf" ]; then
    BIN="$DIR/target/release/loaf"
elif [ -f "$DIR/target/debug/loaf" ]; then
    BIN="$DIR/target/debug/loaf"
else
    echo "Binary not found at target/release/loaf or target/debug/loaf"
    exit 1
fi

mkdir -p "$DIST"

echo "1. Staging standalone tarball (v$VERSION)..."
TAR_STAGE="$DIR/packaging/tarball/loaf-v${VERSION}-linux-x86_64"
mkdir -p "$TAR_STAGE/bin" "$TAR_STAGE/share/applications" "$TAR_STAGE/share/icons" "$TAR_STAGE/share/doc/loaf" "$TAR_STAGE/share/licenses/loaf" "$TAR_STAGE/share/xdg-desktop-portal/portals" "$TAR_STAGE/share/dbus-1/services"

cp "$BIN" "$TAR_STAGE/bin/loaf"
cp "$DIR/packaging/assets/loaf-run" "$TAR_STAGE/loaf"
cp "$DIR/packaging/assets/install.sh" "$TAR_STAGE/install.sh"
cp "$DIR/packaging/assets/uninstall.sh" "$TAR_STAGE/uninstall.sh"
cp "$DIR/packaging/assets/loaf.desktop" "$TAR_STAGE/share/applications/loaf.desktop"
cp "$DIR/packaging/assets/loaf.portal" "$TAR_STAGE/share/xdg-desktop-portal/portals/loaf.portal"
cp "$DIR/packaging/assets/org.freedesktop.impl.portal.desktop.loaf.service" "$TAR_STAGE/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service"
cp -r "$DIR/packaging/assets/icons/hicolor" "$TAR_STAGE/share/icons/"
cp "$DIR/LICENSE" "$TAR_STAGE/LICENSE"
cp "$DIR/THIRD-PARTY-LICENSES.md" "$TAR_STAGE/THIRD-PARTY-LICENSES.md"
cp "$DIR/LICENSE" "$TAR_STAGE/share/licenses/loaf/LICENSE"
cp "$DIR/THIRD-PARTY-LICENSES.md" "$TAR_STAGE/share/licenses/loaf/THIRD-PARTY-LICENSES.md"
cp "$DIR/README.md" "$TAR_STAGE/share/doc/loaf/README.md"

strip "$TAR_STAGE/bin/loaf" || true
if command -v patchelf >/dev/null 2>&1; then
    patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 --remove-rpath "$TAR_STAGE/bin/loaf" 2>/dev/null || true
fi
tar -czf "$DIST/loaf-v${VERSION}-linux-x86_64.tar.gz" -C "$DIR/packaging/tarball" "loaf-v${VERSION}-linux-x86_64"
cp "$TAR_STAGE/bin/loaf" "$DIST/loaf-v${VERSION}-linux-x86_64"

echo "2. Building Debian package..."
DEB_STAGE="$DIR/packaging/deb/build/loaf_${VERSION}_amd64"
mkdir -p "$DEB_STAGE/DEBIAN" "$DEB_STAGE/usr/bin" "$DEB_STAGE/usr/share/applications" "$DEB_STAGE/usr/share/icons" "$DEB_STAGE/usr/share/doc/loaf" "$DEB_STAGE/usr/share/xdg-desktop-portal/portals" "$DEB_STAGE/usr/share/dbus-1/services"
cp "$DIR/packaging/deb/control" "$DEB_STAGE/DEBIAN/control"
sed -i "s|^Version: .*|Version: $VERSION|" "$DEB_STAGE/DEBIAN/control"
cp "$TAR_STAGE/bin/loaf" "$DEB_STAGE/usr/bin/loaf"
cp "$DIR/packaging/assets/loaf.desktop" "$DEB_STAGE/usr/share/applications/loaf.desktop"
cp "$DIR/packaging/assets/loaf.portal" "$DEB_STAGE/usr/share/xdg-desktop-portal/portals/loaf.portal"
cp "$DIR/packaging/assets/org.freedesktop.impl.portal.desktop.loaf.service" "$DEB_STAGE/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service"
cp -r "$DIR/packaging/assets/icons/hicolor" "$DEB_STAGE/usr/share/icons/"
cp "$DIR/LICENSE" "$DEB_STAGE/usr/share/doc/loaf/copyright"
cp "$DIR/THIRD-PARTY-LICENSES.md" "$DEB_STAGE/usr/share/doc/loaf/THIRD-PARTY-LICENSES.md"
cp "$DIR/README.md" "$DEB_STAGE/usr/share/doc/loaf/README.md"
dpkg-deb --root-owner-group --build "$DEB_STAGE" "$DIST/loaf_${VERSION}_amd64.deb"

echo "3. Building Arch package..."
ARCH_STAGE="$DIR/packaging/arch/build/pkg"
mkdir -p "$ARCH_STAGE/usr/bin" "$ARCH_STAGE/usr/share/applications" "$ARCH_STAGE/usr/share/icons" "$ARCH_STAGE/usr/share/licenses/loaf" "$ARCH_STAGE/usr/share/doc/loaf"
if [ -f "$DIR/packaging/arch/.PKGINFO" ]; then
    cp "$DIR/packaging/arch/.PKGINFO" "$ARCH_STAGE/.PKGINFO"
    sed -i "s|^pkgver = .*|pkgver = $VERSION-1|" "$ARCH_STAGE/.PKGINFO"
fi
cp "$TAR_STAGE/bin/loaf" "$ARCH_STAGE/usr/bin/loaf"
cp "$DIR/packaging/assets/loaf.desktop" "$ARCH_STAGE/usr/share/applications/loaf.desktop"
cp -r "$DIR/packaging/assets/icons/hicolor" "$ARCH_STAGE/usr/share/icons/"
cp "$DIR/LICENSE" "$ARCH_STAGE/usr/share/licenses/loaf/LICENSE"
cp "$DIR/THIRD-PARTY-LICENSES.md" "$ARCH_STAGE/usr/share/licenses/loaf/THIRD-PARTY-LICENSES.md"
cp "$DIR/README.md" "$ARCH_STAGE/usr/share/doc/loaf/README.md"
(cd "$ARCH_STAGE" && tar --zstd --owner=0 --group=0 --numeric-owner -cf "$DIST/loaf-${VERSION}-1-x86_64.pkg.tar.zst" .PKGINFO usr)

echo "4. Building RPM package..."
RPM_TOP="$DIR/packaging/rpm/build"
mkdir -p "$RPM_TOP/BUILD" "$RPM_TOP/RPMS" "$RPM_TOP/SOURCES" "$RPM_TOP/SPECS" "$RPM_TOP/SRPMS" "$RPM_TOP/DB"
mkdir -p "$RPM_TOP/SOURCES/packaging"
cp -r "$DIR/packaging/assets" "$RPM_TOP/SOURCES/packaging/"
cp "$DIR/README.md" "$RPM_TOP/SOURCES/"
cp "$DIR/LICENSE" "$RPM_TOP/SOURCES/"
cp "$DIR/THIRD-PARTY-LICENSES.md" "$RPM_TOP/SOURCES/"
mkdir -p "$RPM_TOP/SOURCES/target/release"
cp "$TAR_STAGE/bin/loaf" "$RPM_TOP/SOURCES/target/release/loaf"
rpmbuild -bb --nodeps --define "_topdir $RPM_TOP" --define "_dbpath $RPM_TOP/DB" --define "_prefix /usr" --define "_prebuilt 1" --define "_sourcedir $RPM_TOP/SOURCES" --define "version $VERSION" "$DIR/packaging/rpm/loaf.spec"
find "$RPM_TOP/RPMS" -name "*.rpm" -exec cp {} "$DIST/" \;

echo "5. Updating SHA256 checksums..."
(cd "$DIST" && sha256sum loaf* Loaf* > SHA256SUMS 2>/dev/null || true)

echo "All distribution packages created successfully in $DIST!"
