{ lib, stdenvNoCC, fetchurl, coreutils }:

let
  inherit (builtins) isAttrs;
  mirrors = import ./mirrors.nix;
  fetchurl' = { url ? "", ... }@attrs: if url == "" then fetchurl attrs else
    # Add default mirrors
    let
      listOfListOfMirrorUrls = with builtins; lib.mapAttrsToList (
        site: mirrors:
        let m = match "${site}(.*)" url; in
        if (typeOf m) == "list" then
          map (mirror: "${mirror}${head m}") mirrors
        else []
      ) mirrors;
      urls = [ url ] ++ (lib.flatten listOfListOfMirrorUrls);
    in fetchurl (attrs // { url = ""; inherit urls; });
in

{ # A valid name for the nix store, e.g. "babel-core"
  name ? ""
  # The origional package name, e.g. "@babel/core"
, packageName ? ""
  # Version name of the npm package
, version ? ""
  # The tarball attrset that contains a url and a hash
, tarball ? null
, ...
}:

let
  source =
    if tarball != null then fetchurl' tarball
    else throw "fetchNpmPackage requires `tarball` attribute to be set as the parameter for `fetchurl`";
  derivationName =
    if name != "" && version != "" then "npm-${name}-${version}"
    else throw "fetchNpmPackage requires `name` and `version` to be set";
  passthru = {
    inherit name packageName version;
  };
in

stdenvNoCC.mkDerivation {
  name = derivationName;
  src = source;
  builder = ./builder.sh;
  env = "${coreutils}/bin/env";
  inherit passthru;
}
