{
  nixpkgs ? import ((import <nixpkgs> { }).fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "19.03-beta";
    sha256 = "1wr6dzy99rfx8s399zjjjcffppsbarxl2960wgb0xjzr7v65pikz";
  }) { }
}:

let
  callPackage = nixpkgs.lib.callPackageWith (nixpkgs // pkgs // { inherit nixpkgs; });
  lib = nixpkgs.lib.extend (self: super: let
    callLibs = file: import file { lib = super // self; };
  in {
    join = callLibs ./lib/join.nix;
    toYaml = callLibs ./lib/toYaml.nix;
  });
  pkgs = rec {
    inherit lib;

    npm = callPackage ./pkgs/development/nodejs/npm { };
    mkNodeEnvDerivation = npm.mkNodeEnv;
    mkNpmPackageDerivation = npm.mkNpmPackageWithEnv;

    buildRubyGem = callPackage ./pkgs/development/ruby/gem { };
    bundlerEnv = nixpkgs.bundlerEnv.override { inherit callPackage; };
    buildRailsApp = callPackage ./pkgs/development/ruby/rails-app { };

    passenger = callPackage ./pkgs/servers/passenger { };
    nginx-mod-passenger = callPackage ./pkgs/servers/nginx-mod-passenger.nix { };
    nginx-with-passenger = callPackage ./pkgs/servers/nginx-with-passenger.nix { };
  };
in nixpkgs // pkgs
