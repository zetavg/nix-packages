{ lib, stdenvNoCC, bash, coreutils }:

{
  nodejs,
  name,
  nodeModules ? {},
  environmentVariables ? {},
  buildInputs ? [],
  ...
}:

let
  inherit (builtins) map filter toPath concatStringsSep;
  inherit (lib) flatten mapAttrsToList;
  nodeModulesList = mapAttrsToList (k: v: v) nodeModules;
  nodeModuleNameAndSrcs = map (pkg: "${pkg.packageName}|${pkg}") nodeModulesList;
  binNameAndPaths = flatten (
    map (
      pkg: mapAttrsToList (
        name: path: "${name}|${toPath "${pkg}/${path}"}"
      ) pkg.bin
    ) nodeModulesList
  );
  systemPaths = concatStringsSep ":" (
    [ "${bash}/bin" "${coreutils}/bin" "${nodejs}/bin" ] ++
    (map (d: "${d}/bin") buildInputs)
  );
  environmentVariablesStringList = map ({ n, v }: "${n}=${toString v}") (
    filter ({ v, ... }: v != null) (
      mapAttrsToList (n: v: { inherit n v; }) environmentVariables
    )
  );
  environmentVariablesString = concatStringsSep "\n" environmentVariablesStringList;
  exportEnvironmentVariablesString = concatStringsSep "\n" (
    map (v: "export ${v}") environmentVariablesStringList
  );
  passthru = {
    inherit nodejs nodeModules environmentVariables;
    path = "${systemPaths}:${drv.outPath}/node_modules/.bin";
    nodePath = "${drv.outPath}/node_modules";
    setupScript = "${drv.outPath}/setup.sh";
  };

  drv = stdenvNoCC.mkDerivation {
    inherit name;
    inherit nodeModuleNameAndSrcs binNameAndPaths systemPaths;
    environmentVariables = environmentVariablesString;
    exportEnvironmentVariables = exportEnvironmentVariablesString;
    builder = ./builder.sh;
    inherit passthru;
  };
in drv
