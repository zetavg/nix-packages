# Force some fields to be required to get them from callPackage

{
  pkgs,
  mkNpmPackageDerivation,
  ...
} @ attrs:

import ./default.nix attrs
