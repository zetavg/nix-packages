{
  lib,
  stdenvNoCC,
  bash,
  coreutils,
  mkNodePackage,
  mkNodeEnvForPackage
}:

nodejs:
envAttrs:
attrs:

let
  inherit (builtins) toPath;
  inherit (lib) mapAttrsToList;

  name = "${nodejs.name}-${package.nameWithoutVersion}-${package.version}+runtime";
  package = mkNodePackage nodejs attrs;
  packageName = package.packageName;
  env = mkNodeEnvForPackage nodejs envAttrs package;
  devEnv = mkNodeEnvForPackage nodejs (envAttrs // { production = false; }) package;
  binNameAndPaths = mapAttrsToList (
    name: path: "${name}|${packageName}/${path}"
  ) (package.bin or {});

  passthru = package.passthru // env.passthru // {
    devShell = stdenvNoCC.mkDerivation {
      name = "${name}-dev-shell";
      phases = [ ];
      setupScript = devEnv.setupScript;
      shellHook = ''
        source $setupScript
      '';
    };
  };
in

stdenvNoCC.mkDerivation {
  inherit name;
  inherit bash coreutils;
  inherit package packageName binNameAndPaths;
  envSetupScript = env.setupScript;
  builder = ./builder.sh;
  inherit passthru;
}
