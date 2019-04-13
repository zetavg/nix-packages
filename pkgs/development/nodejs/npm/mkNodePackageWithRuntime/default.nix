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
  inherit (lib) filterAttrs mapAttrsToList concatStringsSep assertMsg;

  name = "${nodejs.name}-${package.nameWithoutVersion}-${package.version}+runtime";
  package = mkNodePackage nodejs attrs;
  packageName = package.packageName;
  env = mkNodeEnvForPackage nodejs envAttrs package;
  devEnv = mkNodeEnvForPackage nodejs (envAttrs // { production = false; }) package;
  binNameAndPaths = mapAttrsToList (
    name: path: "${name}|${packageName}/${path}"
  ) (package.bin or {});

  passthru = package.passthru // env.passthru // (
    let
      pn = package.packageName;
      sf = package.startupFile or "";
      pr = package.publicRoot or "";
    in rec {
      startupFile = if (sf != "") then "${drv.outPath}/${pn}/${sf}" else null;
      publicRoot = if (pr != "") then "${drv.outPath}/${pn}/${pr}" else null;
      devShell = stdenvNoCC.mkDerivation {
        name = "${name}-dev-shell";
        phases = [ "nobuildPhase" ];
        setupScript = devEnv.setupScript;
        shellHook = ''
          source $setupScript
        '';
        nobuildPhase = "echo 'This derivation is not meant to be built. Producing an empty result.'; touch $out";
      };
      getNginxPassengerConfig = { passenger }:
        assert (
          assertMsg (startupFile != null) "startupFile must be set"
          && assertMsg (publicRoot != null) "publicRoot must be set"
        ); ''
          passenger_enabled on;
          passenger_app_type node;
          passenger_startup_file ${startupFile};
          passenger_nodejs ${nodejs}/bin/node;
          passenger_env_var PATH ${env.path};
          passenger_env_var NODE_PATH ${passenger.nodejs_supportlib}:${env.nodePath};
        '' + concatStringsSep "\n" (
          mapAttrsToList (
            n: v:
            "passenger_env_var ${n} ${v};"
          ) (
            filterAttrs (n: v: v != null && v != "") env.environmentVariables
          )
        );
    }
  );

  drv = stdenvNoCC.mkDerivation {
    inherit name;
    inherit bash coreutils;
    inherit package packageName binNameAndPaths;
    envSetupScript = env.setupScript;
    builder = ./builder.sh;
    inherit passthru;
  };

in drv
