{
  pkgs ? import ((import <nixpkgs> { }).fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "19.03-beta";
    sha256 = "1wr6dzy99rfx8s399zjjjcffppsbarxl2960wgb0xjzr7v65pikz";
  }) { },
  ...
}:
let
  nixpkgs = pkgs;
  # Combine all the packages, while the original nixpkgs is still accessable
  # and the added packages set can isolatedly obtainaded via zpkgs.
  allPackages = nixpkgs // zpkgs // {
    inherit nixpkgs zpkgs;
  };

  lib = nixpkgs.lib.extend (self: super: let
    callLibs = file: import file { lib = super // self; };
  in {
    join = callLibs ./lib/join.nix;
    removeExtensionFromFilename = callLibs ./lib/removeExtensionFromFilename.nix;
    toYaml = callLibs ./lib/toYaml.nix;
    getOverlayUtils = callLibs ./lib/getOverlayUtils.nix;
  });

  zpkgs = let
    callPackage = nixpkgs.lib.callPackageWith allPackages;
    overlayUtils = lib.getOverlayUtils {
      overlayGroupName = "zOverlays";
      self = allPackages; super = nixpkgs;
    };
    inherit (overlayUtils) callOverlay mergeOverlays;
  in rec {
    inherit lib callPackage;

    npm = callPackage ./pkgs/development/nodejs/npm { };
    mkNodeEnvDerivation = npm.mkNodeEnv;
    mkNpmPackageDerivation = npm.mkNpmPackageWithRuntime;
    npm-package-to-nix = callPackage ./pkgs/development/nodejs/npm-package-to-nix/package.nix { };

    buildRubyGem = callPackage ./pkgs/development/ruby/gem { };
    bundlerEnv = nixpkgs.bundlerEnv.override { # Override bundlerEnv to use the new buildRubyGem
      inherit callPackage;
    };
    buildRailsApp = callPackage ./pkgs/development/ruby/rails-app { };

    passenger = callPackage ./pkgs/servers/passenger { };
    nginx-mod-passenger = callPackage ./pkgs/servers/nginx-mod-passenger.nix { };
    nginx-with-passenger = callPackage ./pkgs/servers/nginx-with-passenger.nix { };
  } // (
    mergeOverlays [
      (callOverlay ./overlays/gdrive.nix)
    ]
  );
in allPackages
