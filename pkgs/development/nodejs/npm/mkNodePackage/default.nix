{ lib, stdenv, system, mkNodeEnv, fetchNpmPackage, mkNpmPackageBundle }:

let
  mkNodePackage = {
    # Nodejs that might be needed
    nodejs,

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
    srcs ? null,

    # Conditions that might change how we build the package
    hasInstallationHooks ? false,
    hasPrepareHooks ? false,
    privateDependencies ? { },
    dependencies ? { },
    devDependencies ? { },

    ...
  } @ attrs:

  let
    inherit (builtins) isFunction isBool hasAttr toJSON;
    inherit (lib) mapAttrs filterAttrs;
    # Get the package
    package =
      if tarball != null then fetchNpmPackage attrs
      # TODO: Add more cases
      else throw "Don't know how to build node package ${attrs.name}, attrs are ${toJSON attrs}";
    # TODO: "Install" the package
    package' = package;
    # Bundle the package if it have privateDependencies
    package'' = if privateDependencies == { } then package' else mkNpmPackageBundle {
      package = package';
      bundlePackages = mapAttrs (n: v: mkNodePackage v // { inherit nodejs; }) dependencies;
    };
  in package'';
in mkNodePackage
