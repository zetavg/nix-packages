{
  pkgs ? import ((import <nixpkgs> { }).fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "19.03";
    # Get the sha256 by command:
    # nix-prefetch-git --rev <rev> --no-deepClone https://github.com/NixOS/nixpkgs.git
    sha256 = "0q2m2qhyga9yq29yz90ywgjbn9hdahs7i8wwlq7b55rdbyiwa5dy";
  }) { },
  overlays ? [],
  ...
}:
let
  inherit (builtins) hasAttr;
  package-overlays = import ./manifest.nix;
  all-overlays = package-overlays ++ overlays;
in if hasAttr "appendOverlays" pkgs then
  pkgs.appendOverlays all-overlays
else
  (import ./lib/manuallyAppendOverlaysToPkgs.nix { }) pkgs all-overlays
