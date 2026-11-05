{
  description = "loaf - Material 3 Expressive file manager in Rust and QML";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      packageBuilder =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          qtEnv = pkgs.qt6.env "qt6-env" [
            pkgs.qt6.qtbase
            pkgs.qt6.qtdeclarative
            pkgs.qt6.qtsvg
            pkgs.qt6.qtwayland
          ];
        in
        pkgs.rustPlatform.buildRustPackage {
          pname = "loaf";
          version = "0.2.0";
          src = ./.;
          cargoLock = {
            lockFile = ./Cargo.lock;
          };
          nativeBuildInputs = with pkgs; [
            pkg-config
            cmake
            ninja
            qt6.qttools
            qt6.wrapQtAppsHook
          ];
          dontUseCmakeConfigure = true;
          dontUseNinjaBuild = true;
          dontUseNinjaInstall = true;
          buildInputs = [
            qtEnv
            pkgs.libGL
            pkgs.p7zip
            pkgs.zip
            pkgs.shared-mime-info
          ];
          QMAKE = "${qtEnv}/bin/qmake";
          postPatch = ''
            export QMAKE="${qtEnv}/bin/qmake"
          '';
          QT_PLUGIN_PATH = "${qtEnv}/lib/qt-6/plugins";
          QML2_IMPORT_PATH = "${qtEnv}/lib/qt-6/qml";
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [
            qtEnv
            pkgs.libGL
          ]}";
          XDG_DATA_DIRS = "${pkgs.shared-mime-info}/share";
          postInstall = ''
            install -Dm644 packaging/assets/loaf.desktop $out/share/applications/loaf.desktop
            install -Dm644 packaging/assets/loaf.portal $out/share/xdg-desktop-portal/portals/loaf.portal
            install -Dm644 packaging/assets/org.freedesktop.impl.portal.desktop.loaf.service $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service
            substituteInPlace $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.loaf.service \
              --replace-fail "Exec=/usr/bin/loaf" "Exec=$out/bin/loaf"
            mkdir -p $out/share/icons
            cp -r packaging/assets/icons/hicolor $out/share/icons/
          '';
        };
    in
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        qtEnv = pkgs.qt6.env "qt6-env" [
          pkgs.qt6.qtbase
          pkgs.qt6.qtdeclarative
          pkgs.qt6.qtsvg
          pkgs.qt6.qtwayland
        ];
      in
      {
        packages.default = packageBuilder system;

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/loaf";
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            pkg-config
            cmake
            ninja
            rustc
            cargo
            rustfmt
            clippy
            patchelf
            qt6.qttools
          ];

          buildInputs = [
            qtEnv
            pkgs.libGL
            pkgs.p7zip
            pkgs.zip
            pkgs.shared-mime-info
          ];

          QMAKE = "${qtEnv}/bin/qmake";
          shellHook = ''
            # qtbase's setup-hook exports QMAKE=<qtbase>/bin/qmake, which lacks
            # modules like Qml (no libQt6Qml.prl). qt-build-utils runs qmake with
            # env cleared, dropping QMAKEPATH, so point QMAKE at the qt6-env
            # wrapper whose compiled-in prefix contains all modules.
            export QMAKE="${qtEnv}/bin/qmake"
          '';
          QT_PLUGIN_PATH = "${qtEnv}/lib/qt-6/plugins";
          QML2_IMPORT_PATH = "${qtEnv}/lib/qt-6/qml";
          LD_LIBRARY_PATH = "${
            pkgs.lib.makeLibraryPath [
              qtEnv
              pkgs.libGL
            ]
          }:$LD_LIBRARY_PATH";
          LIBRARY_PATH = "${
            pkgs.lib.makeLibraryPath [
              qtEnv
              pkgs.libGL
            ]
          }:$LIBRARY_PATH";
          XDG_DATA_DIRS = "${pkgs.shared-mime-info}/share:$XDG_DATA_DIRS";
        };
      }
    ))
    // {
      overlays.default = final: prev: {
        loaf = packageBuilder final.system;
      };
    };
}
