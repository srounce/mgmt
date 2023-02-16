{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    devshell.url = "github:numtide/devshell";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      perSystem = { config, self', inputs', pkgs, system, ... }: 
      let
        lib = pkgs.lib;

        devshell = pkgs.callPackage inputs.devshell {
          inputs = inputs;
        };

        version = pkgs.runCommand "" {} ''
          mkdir $out

          date -Idate > "$out/version"
        '';

        mgmt = pkgs.buildGoModule {
          pname = "mgmt";
          inherit version;

          src = ./.;

          buildInputs = with pkgs; [
            pkg-config
            augeas
            libxml2

            ragel
            gotools
            nex
            go-bindata

          ] ++ lib.optionals stdenv.isDarwin [

          ];

          nativeBuildInputs = with pkgs; [
            pkg-config
            #graphviz
            libvirt
          ];

          vendorSha256 = "sha256-Dtqy4TILN+7JXiHKHDdjzRTsT8jZYG5sPudxhd8znXY";

          configurePhase = ''
            cd $src/lang
            go build
          '';
        };
      in
      {
        #packages.default = pkgs.hello;
        packages.default = mgmt;

        devShells.default = pkgs.mkShell {
          inputsFrom = [
            mgmt
          ];

          packages = [
            pkgs.go
            pkgs.vagrant
          ];
        };

      };

      flake = 
      let
        pkgs = import inputs.nixpkgs { system = "aarch64-darwin"; };

        src = pkgs.copyPathToStore ./.;
        version = builtins.readFile (pkgs.runCommand "version" { nativeBuildInputs = [ pkgs.git ]; } ''
          ls -alspH ${src}
          GIT_DIR=${src}/.git git describe --match '[0-9]*\.[0-9]*\.[0-9]*' --tags --dirty --always > $out
        '');

      in
      {
        version = "v${version}";
      };
    };
}
