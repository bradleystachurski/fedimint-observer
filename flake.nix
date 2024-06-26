{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flakebox = {
      url = "github:rustshop/flakebox";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, flakebox }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        flakeboxLib = flakebox.lib.${system} { };
        lib = pkgs.lib;
        stdenv = pkgs.stdenv;

        toolchainArgs = {
          extraRustFlags = "--cfg tokio_unstable";
        };
        stdToolchains = flakeboxLib.mkStdToolchains toolchainArgs;

        rustSrc = flakeboxLib.filterSubPaths {
          root = builtins.path {
            name = "flakebox-tutorial";
            path = ./.;
          };
          paths = [
            "Cargo.toml"
            "Cargo.lock"
            ".cargo"
            "src"
            "schema"
          ];
        };

        packages =
          (flakeboxLib.craneMultiBuild { toolchains = stdToolchains; }) (craneLib':
            let
              craneLib = (craneLib'.overrideArgs {
                pname = "fedimint-observer";
                src = rustSrc;
              });
            in
            rec {
              workspaceDeps = craneLib.buildWorkspaceDepsOnly { };
              workspaceBuild = craneLib.buildWorkspace {
                cargoArtifacts = workspaceDeps;
              };
              fedimint-observer = craneLib.buildPackage { };
            });
      in
      {
        devShells = flakeboxLib.mkShells {
          nativeBuildInputs = [ ] ++ lib.optionals stdenv.isDarwin [
            pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
          ];
        };

        legacyPackages = packages;
        packages.default = packages.fedimint-observer;
      }
    );
}
