# RPM spec for Loaf (Fedora / RHEL / openSUSE-compatible).
#
# Build from a source tarball (needs network access for crates.io unless the
# crates are vendored):
#   git archive --prefix=loaf-0.2.0/ -o ~/rpmbuild/SOURCES/loaf-0.2.0.tar.gz HEAD
#   rpmbuild -ba packaging/rpm/loaf.spec
#
# Or package an already built binary (target/release/loaf) without
# compiling again:
#   rpmbuild -bb --define "_prebuilt 1" --define "_sourcedir $PWD" packaging/rpm/loaf.spec

%global debug_package %{nil}
%define _prefix /usr

Name:           loaf
Version:        0.3.0
Release:        1%{?dist}
Summary:        Material 3 Expressive file manager built with Rust and Qt 6
License:        MIT
URL:            https://github.com/m-uvex/loaf-fm
Source0:        %{name}-%{version}.tar.gz

%if 0%{!?_prebuilt:1}
BuildRequires:  cargo
BuildRequires:  rust
BuildRequires:  gcc-c++
BuildRequires:  cmake
BuildRequires:  pkgconfig
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtbase-private-devel
BuildRequires:  qt6-qtdeclarative-devel
%endif
BuildRequires:  desktop-file-utils

Requires:       qt6-qtbase-gui
Requires:       qt6-qtdeclarative
Requires:       qt6-qtsvg
Requires:       hicolor-icon-theme
Recommends:     qt6-qtwayland
# Archives: 7-Zip handles zip/7z/rar/iso and encrypted archives.
Recommends:     (7zip or p7zip)
Recommends:     tar
Recommends:     zstd
# Drives: mount, eject, unlock encrypted (LUKS) volumes, rename labels.
Recommends:     udisks2
# Video / PDF thumbnails through the freedesktop thumbnailer system.
Recommends:     ffmpegthumbnailer
Suggests:       evince-thumbnailer
# Open files with their default application, remember passwords.
Recommends:     xdg-utils
Recommends:     libsecret
Suggests:       polkit

%description
Loaf is a fast file manager for Linux with a Material 3 Expressive design:
tabs and split view, background file operations with progress and undo,
the freedesktop trash (including trash folders on other drives), archive
browsing and extraction, thumbnails shared with other file managers,
GTK bookmarks, Recent and Starred files, and a low-power mode for older
computers.

%prep
%if 0%{?_prebuilt:1}
# Prebuilt: take the binary and assets straight from the checkout.
%setup -q -c -T -n %{name}-%{version}
cp -a "%{_sourcedir}/packaging" "%{_sourcedir}/README.md" "%{_sourcedir}/LICENSE" "%{_sourcedir}/THIRD-PARTY-LICENSES.md" .
install -Dm755 "%{_sourcedir}/target/release/loaf" target/release/loaf
%else
%autosetup -n %{name}-%{version}
%endif

%build
%if 0%{!?_prebuilt:1}
export QMAKE=%{_libdir}/qt6/bin/qmake
cargo build --release --locked
%endif

%install
install -Dm755 target/release/loaf %{buildroot}%{_bindir}/loaf
install -Dm644 packaging/assets/loaf.desktop %{buildroot}%{_datadir}/applications/loaf.desktop
install -Dm644 packaging/assets/loaf.portal %{buildroot}%{_datadir}/xdg-desktop-portal/portals/loaf.portal
install -Dm644 packaging/assets/org.freedesktop.impl.portal.desktop.loaf.service %{buildroot}%{_datadir}/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service
for sz in 16 32 48 64 128 256 512; do
    install -Dm644 packaging/assets/icons/hicolor/${sz}x${sz}/apps/loaf.png \
        %{buildroot}%{_datadir}/icons/hicolor/${sz}x${sz}/apps/loaf.png
done
install -Dm644 packaging/assets/icons/hicolor/scalable/apps/loaf.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/loaf.svg
install -Dm644 LICENSE %{buildroot}%{_datadir}/licenses/%{name}/LICENSE
install -Dm644 THIRD-PARTY-LICENSES.md %{buildroot}%{_datadir}/licenses/%{name}/THIRD-PARTY-LICENSES.md

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/loaf.desktop

%files
%license LICENSE
%doc README.md THIRD-PARTY-LICENSES.md
%{_bindir}/loaf
%{_datadir}/applications/loaf.desktop
%{_datadir}/xdg-desktop-portal/portals/loaf.portal
%{_datadir}/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service
%{_datadir}/icons/hicolor/*/apps/loaf.*
%{_datadir}/licenses/%{name}/

%changelog
* Mon Oct 26 2026 Loaf contributors - 0.2.0-1
- Release v0.2.0: SMB network shares, P2P Cloudflare sharing, tab/split view, batch rename, and asynchronous thumbnail pipeline.

* Tue Oct 20 2026 Loaf contributors - 0.1.0-1
- First RPM package.
