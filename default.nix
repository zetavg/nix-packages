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
  inherit (builtins) foldl';
in pkgs.appendOverlays [
  (import ./extend-lib.nix)
  (import ./all-packages.nix)
  (import ./all-overlays.nix)
]
