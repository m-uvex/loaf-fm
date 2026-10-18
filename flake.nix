{
  description = "loaf - Material 3 Expressive file manager in Rust and QML";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        qtEnv = pkgs.qt6.env "qt6-env" [
          pkgs.qt6.qtbase
          pkgs.qt6.qtdeclarative
          pkgs.qt6.qtsvg
          pkgs.qt6.qtwayland
        ];
      in {
        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "loaf";
          version = "0.1.0";
          src = ./.;
          cargoLock = {
            lockFile = ./Cargo.lock;
          };
          nativeBuildInputs = with pkgs; [
            pkg-config
            cmake
            ninja
          ];
          dontUseCmakeConfigure = true;
          dontUseNinjaBuild = true;
          dontUseNinjaInstall = true;
          buildInputs = [
            qtEnv
            pkgs.libGL
            pkgs.p7zip
            pkgs.zip
          ];
          QMAKE = "${qtEnv}/bin/qmake";
          QT_PLUGIN_PATH = "${qtEnv}/lib/qt-6/plugins";
          QML2_IMPORT_PATH = "${qtEnv}/lib/qt-6/qml";
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [ qtEnv pkgs.libGL ]}";
          postInstall = ''
            install -Dm644 packaging/assets/loaf.desktop $out/share/applications/loaf.desktop
            mkdir -p $out/share/icons
            cp -r packaging/assets/icons/hicolor $out/share/icons/
          '';
        };
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
          ];

          buildInputs = [
            qtEnv
            pkgs.libGL
            pkgs.p7zip
            pkgs.zip
          ];

          QMAKE = "${qtEnv}/bin/qmake";
          QT_PLUGIN_PATH = "${qtEnv}/lib/qt-6/plugins";
          QML2_IMPORT_PATH = "${qtEnv}/lib/qt-6/qml";
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [ qtEnv pkgs.libGL ]}:$LD_LIBRARY_PATH";
          LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [ qtEnv pkgs.libGL ]}:$LIBRARY_PATH";
        };
      });
}
