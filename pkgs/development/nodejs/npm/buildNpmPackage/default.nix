{ lib, stdenvNoCC, coreutils, mkNodeEnvForPackage }:

{
  nodejs,
  format ? "tarball"
}:

{ # A valid name for the nix store, e.g. "babel-core"
  name ? ""
  # The origional package name, e.g. "@babel/core"
, packageName ? ""
  # Version name of the npm package
, version ? ""
  # The source of the package
, src ? ""
, srcs ? [ ]
  # Executables that this package provided
, bin ? {}
, ...
} @ attrs:

let
  inherit (builtins) isString isPath isList;
  derivationName =
    if name != "" && version != "" then "${nodejs.name}-${name}-${version}"
    else throw "fetchNpmPackage requires `name` and `version` to be set";
  nodeEnv = mkNodeEnvForPackage nodejs { production = false; } attrs;
  passthru = attrs // {
    nameWithoutVersion = name;
  };
in

stdenvNoCC.mkDerivation {
  name = derivationName;
  inherit src srcs;
  inherit format;
  buildInputs = [ nodejs ];
  builder = ./builder.sh;
  setupNodeEnvScript = nodeEnv.setupScript;
  env = "${coreutils}/bin/env";
  inherit passthru;
}
