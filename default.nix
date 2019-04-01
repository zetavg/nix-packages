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
  pkgs = rec {
  };
in nixpkgs // pkgs
