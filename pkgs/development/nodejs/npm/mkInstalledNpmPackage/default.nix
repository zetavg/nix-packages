{ stdenvNoCC, mkNodeEnvForPackage }:

# Make an "installed" npm package from a npm package, this is usually for
# building native dependencies.

{
  nodejs
, package
, buildInputs ? []
, ...
}:

let
  name =
    # Prevent "Esy prefix path is too deep in the filesystem" error
    if package.nameWithoutVersion == "reason-cli" then "reason-cli-${package.version}"
    else "npm-${nodejs.name}-${package.nameWithoutVersion}-${package.version}";
  nodeEnv = mkNodeEnvForPackage nodejs { production = true; } package; # Same as mkNodeEnvForPackage nodejs package.passthru
  passthru = package.passthru // {
    inherit nodejs;
  };
in

stdenvNoCC.mkDerivation {
  inherit name package;
  builder = ./builder.sh;
  buildInputs = [ nodejs ] ++ buildInputs;
  setupNodeEnvScript = nodeEnv.setupScript;
  inherit passthru;
}
