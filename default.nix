{
  pkgs ? import ((import <nixpkgs> { }).fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "19.03-beta";
    sha256 = "1wr6dzy99rfx8s399zjjjcffppsbarxl2960wgb0xjzr7v65pikz";
  }) { },
  overlays ? [],
  ...
}:
let
  inherit (builtins) hasAttr trace foldl';
  package-overlays = import ./manifest.nix;
  all-overlays = package-overlays ++ overlays;
in if hasAttr "appendOverlays" pkgs then
  pkgs.appendOverlays all-overlays
else
  (import ./lib/manuallyAppendOverlaysToPkgs.nix { }) pkgs all-overlays
