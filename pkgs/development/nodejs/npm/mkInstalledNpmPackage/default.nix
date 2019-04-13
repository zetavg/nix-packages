{ stdenvNoCC, mkNodeEnvForPackage }:

# Make an "installed" npm package from a npm package, this is usually for
# building native dependencies.

{
  nodejs
, package
, ...
}:

let
  name = "npm-${nodejs.name}-${package.nameWithoutVersion}-${package.version}";
  nodeEnv = mkNodeEnvForPackage nodejs { production = true; } package; # Same as mkNodeEnvForPackage nodejs package.passthru
  passthru = package.passthru // {
    inherit nodejs;
  };
in

stdenvNoCC.mkDerivation {
  inherit name package;
  builder = ./builder.sh;
  buildInputs = [ nodejs ];
  setupNodeEnvScript = nodeEnv.setupScript;
  inherit passthru;
}
