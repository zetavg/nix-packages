{
  pkgs ? import (
    builtins.fetchTarball "https://git.io/zpkgs-archive-master"
  ) { },
  nodejs ? pkgs.nodejs,
  mkNodePackageWithRuntime ? pkgs.mkNodePackageWithRuntime,
  ...
}:
let
  npmPackage = import ./npm-package.nix {
    srcs = [
      ./package.json
      ./babel.config.js
      ./src
    ];
  };
in mkNodePackageWithRuntime nodejs { } npmPackage
