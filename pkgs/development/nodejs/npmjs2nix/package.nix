/*
 * Force some attrs to be required from callPackage.
 */
{
  pkgs,
  mkNodePackageWithRuntime,
  ...
} @ attrs:

import ./default.nix attrs
