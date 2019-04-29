{
  lib,
  fetchNpmPackage,
  buildNpmPackage,
  mkNpmPackageBundle,
  mkInstalledNpmPackage,
  mkNodePackage
}:

# Nodejs that might be needed
nodejs:
{
  # A valid name for the nix store, e.g. "babel-core"
  name,
  # The origional package name, e.g. "@babel/core"
  packageName,
  # Version name of the npm package
  version ? "",
  # Executables that this package provided
  bin ? {},

  # Different ways to specify the source
  tarball ? null, # Tarballs that are packaged by npm
  src ? null,
  srcs ? [ ],

  # Conditions that might change how we build the package
  hasInstallationHooks ? false,
  hasPrepareHooks ? false,
  privateDependencies ? { },
  dependencies ? { },
  devDependencies ? { },

  # Build inputs for "installed" package
  buildInputs ? [ ],

  ...
} @ attrs:

let
  inherit (builtins) isFunction isBool hasAttr toJSON;
  inherit (lib) mapAttrs filterAttrs;
  # Get the package
  package =
    if tarball != null then fetchNpmPackage attrs
    else if src != null || srcs != [ ] then buildNpmPackage { inherit nodejs; format = "directory"; } attrs
    # TODO: Add support for git sources
    else throw "mkNodePackage: don't know how to build node package ${attrs.name or "undefined-name"}, attrs are ${toJSON attrs}";
  package' = if !hasInstallationHooks then package else mkInstalledNpmPackage {
    inherit nodejs package buildInputs;
  };
  # Bundle the package if it have privateDependencies
  package'' = if privateDependencies == { } then package' else mkNpmPackageBundle {
    package = package';
    bundlePackages = mapAttrs (n: v: mkNodePackage nodejs v) privateDependencies;
  };
in package''
