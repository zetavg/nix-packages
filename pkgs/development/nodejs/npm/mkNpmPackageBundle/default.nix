{ lib, stdenvNoCC }:

{ # A package
  package
  # Some packages that are going to be bundled
, bundlePackages ? {}
, ...
}:

let
  inherit (builtins) map filter length head stringLength concatStringsSep;
  inherit (lib) unique optionalString mapAttrsToList;
  bundlePackagesList = mapAttrsToList (k: v: v) bundlePackages;
  listOfNodejs = unique (
    filter (n: n != null) (map (pkg: pkg.nodejs or null) ([package] ++ bundlePackagesList))
  );
  nodejs =
    if length listOfNodejs == 0 then null
    else if length listOfNodejs == 1 then head listOfNodejs
    else throw "Multiple nodejs versions detected in the bundle: ${concatStringsSep ", " (map (n: n.version) listOfNodejs)}, the bundle only allows packages that are independent with nodejs version, or built with a same nodejs version.";
  baseName = "npm${optionalString (nodejs != null) "-${nodejs.name}"}-bundle-${package.nameWithoutVersion}-${package.name}";
  longName = concatStringsSep "+" ([ baseName ] ++ map (pkg: "${pkg.nameWithoutVersion}-${pkg.name}") bundlePackagesList);
  shortName = "${baseName}-with-some-dependencies";
  name =
    if stringLength longName <= 128 then longName
    else shortName;
  bundlePackageNameAndSrcs = map (pkg: "${pkg.packageName}|${pkg}") bundlePackagesList;
  passthru = package.passthru // {
    inherit package nodejs;
    bundledPackages = bundlePackages;
  };
in

stdenvNoCC.mkDerivation {
  inherit name;
  inherit package bundlePackageNameAndSrcs;
  builder = ./builder.sh;
  inherit passthru;
}
