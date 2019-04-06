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
  inherit (builtins) hasAttr trace foldl';
  overlays = import ./manifest.nix;
in if hasAttr "appendOverlays" pkgs then
  pkgs.appendOverlays overlays
else
  (import ./lib/manuallyAppendOverlaysToPkgs.nix { }) pkgs overlays
