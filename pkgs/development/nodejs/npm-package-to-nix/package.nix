/*
 * Force some attrs to be required from callPackage.
 */
{
  pkgs,
  mkNpmPackageDerivation,
  ...
} @ attrs:

import ./default.nix attrs
