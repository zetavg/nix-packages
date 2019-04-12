{ lib, stdenv, system, mkNodeEnv, mkNodePackage }:

{
  nodejs,
  name,
  dependencyIgnoreRules ? {},
  dependencies ? {},
  devDependencies ? {},
  production ? true,
  environmentVariables ? {},
  buildInputs ? [],
  ...
}:

let
  inherit (builtins) isFunction isBool hasAttr;
  inherit (lib) mapAttrs filterAttrs;
  envName =
    if production then "${nodejs.name}-${name}-env"
    else "${nodejs.name}-${name}-dev-env";
  filterDependencies = (
    deps:
    let
      filteredDeps = filterAttrs (
        n: v:
        let
          packageName = v.packageName or "";
          expr = dependencyIgnoreRules."${packageName}" or false;
          shouldIgnore =
            if isBool expr then expr
            else if isFunction expr then expr { inherit lib stdenv system; }
            else null;
        in
          if isBool shouldIgnore then !shouldIgnore
          else throw "dependencyIgnoreRules attr ${packageName} is invalid, it should be a boolean or a function returing a boolean"
      ) deps;
      filteredDepsWithDepsFiltered = mapAttrs (
        n: v:
        if hasAttr "dependencies" v then v // { dependencies = filterDependencies v.dependencies; }
        else v
      ) filteredDeps;
    in filteredDepsWithDepsFiltered
  );
  dependenciesToInstall = filterDependencies (
    if production then dependencies
    else dependencies // devDependencies
  );
  nodeModules = mapAttrs (
    n: v:
    mkNodePackage (v // { inherit nodejs; })
  ) dependenciesToInstall;
in mkNodeEnv {
  name = envName;
  inherit
    nodejs
    nodeModules
    environmentVariables
    buildInputs;
}
