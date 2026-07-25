{
  description = "Reproducible development shell for the 7x7 Kofun game matrix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.nixpkgs-legacy-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
  inputs.nixgl.url = "github:nix-community/nixGL";

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-legacy-darwin,
      nixgl,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor =
        system:
        import (if system == "x86_64-darwin" then nixpkgs-legacy-darwin else nixpkgs) {
          inherit system;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          defold-bob = pkgs.stdenvNoCC.mkDerivation {
            pname = "defold-bob";
            version = "1.12.4";
            src = pkgs.fetchurl {
              url = "https://github.com/defold/defold/releases/download/1.12.4/bob.jar";
              hash = "sha256-VKxX2XEvzR6d5j9AWAPRWdiKL76UC47wWLpQOqQY+hg=";
            };
            dontUnpack = true;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            installPhase = ''
              mkdir -p "$out/share/defold" "$out/bin"
              cp "$src" "$out/share/defold/bob.jar"
              makeWrapper ${pkgs.jdk25}/bin/java "$out/bin/bob" \
                --add-flags "-jar $out/share/defold/bob.jar" \
                --prefix LD_LIBRARY_PATH : ${
                  pkgs.lib.makeLibraryPath (
                    pkgs.lib.optionals pkgs.stdenv.isLinux [
                      pkgs.libGL
                      pkgs.libx11
                      pkgs.libxcursor
                      pkgs.libxext
                      pkgs.libxi
                      pkgs.libxinerama
                      pkgs.libxrandr
                    ]
                  )
                }
            '';
          };
        in
        {
          inherit defold-bob;
          default = defold-bob;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          defold-bob = self.packages.${system}.defold-bob;
          linuxLibraries = pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.alsa-lib
            pkgs.libGL
            pkgs.libxkbcommon
            pkgs.mesa
            pkgs.mesa-demos
            pkgs.xvfb-run
            pkgs.libx11
            pkgs.libxcursor
            pkgs.libxext
            pkgs.libxi
            pkgs.libxinerama
            pkgs.libxrandr
            pkgs.libXxf86vm
          ];
          nixGLPackages = pkgs.lib.optionals (system == "x86_64-linux") [
            nixgl.packages.${system}.nixGLIntel
          ];
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.cargo
              pkgs.clang-tools
              pkgs.clippy
              pkgs.cmake
              defold-bob
              pkgs.gcc
              pkgs.go
              pkgs.godot_4
              pkgs.jdk25
              pkgs.just
              pkgs.love
              pkgs.lua54Packages.lua
              pkgs.ninja
              pkgs.nodejs_24
              pkgs.pkg-config
              pkgs.python3
              pkgs.raylib
              pkgs.rustc
              pkgs.rustfmt
            ]
            ++ linuxLibraries
            ++ nixGLPackages;

            shellHook = ''
              echo "Kofun Game Matrix: 7 games × 7 engines"
              echo "Run 'just --list' for development commands."
            '';
          };
        }
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.nixfmt
      );
    };
}
