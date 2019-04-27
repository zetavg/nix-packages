{ lib, callPackage, mkNodeEnv, mkNodePackage }:

nodejs:
{
  production ? true,
  environmentVariables ? {},
  buildInputs ? [],
}:
{
  name,
  dependencyBuildInputs ? {},
  dependencyPatchPhases ? {},
  dependencyIgnoreRules ? {},
  dependencies ? {},
  devDependencies ? {},
  ...
}:

let
  inherit (builtins) isFunction isBool isAttrs hasAttr;
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
            else if isFunction expr then callPackage expr { }
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
    name: attrs:
    let
      hasDependencyBuildInputs = hasAttr name dependencyBuildInputs;
      buildInputs =
        let
          buildInputsValue = dependencyBuildInputs.${name};
          buildInputsValue' =
            if isAttrs buildInputsValue then buildInputsValue
            else if isFunction buildInputsValue then callPackage buildInputsValue { }
            else null;
        in buildInputsValue';
      hasDependencyPatchPhase = hasAttr name dependencyPatchPhases;
      patchPhase =
        let
          patchPhaseValue = dependencyPatchPhases.${name};
          patchPhaseValue' =
            if isAttrs patchPhaseValue then patchPhaseValue
            else if isFunction patchPhaseValue then callPackage patchPhaseValue { }
            else null;
        in patchPhaseValue';
      attrs' =
        if hasDependencyBuildInputs then attrs // { inherit buildInputs; }
        else attrs;
      attrs'' =
        if hasDependencyPatchPhase then attrs' // { inherit patchPhase; }
        else attrs';
    in mkNodePackage nodejs attrs''
  ) dependenciesToInstall;
in mkNodeEnv {
  name = envName;
  inherit
    nodejs
    nodeModules
    environmentVariables
    buildInputs;
}
