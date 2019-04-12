/*
 * Force some attrs to be required from callPackage.
 */
{
  pkgs,
  ...
} @ attrs:

import ./default.nix attrs
