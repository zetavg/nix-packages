{ ... }:

pkgs: overlays: let
  inherit (builtins) trace foldl';
  allMods = foldl' (accumulatedMods: overlay:
    let
      super = pkgs // accumulatedMods;
      self = overwrittenPkgs;
      modification = overlay self super;
    in accumulatedMods // modification
  ) { } overlays;
  overwrittenPkgs = pkgs // allMods // {
    callPackage = pkgs.lib.callPackageWith (pkgs // allMods);
  };
in (
  builtins.trace "Warning: Your Nixpkgs version is lower than 19.03, which does not support \"appendOverlays\". \"manuallyAppendOverlaysToPkgs\" will be used as an alternative, but its actual behavior isn't the same as \"appendOverlays\", some changes made by overlays will not affect the base, or also the \"self\" argument provided to other overlays. Consider using this package as an overlay of Nixpkgs instead of importing it directly to avoid this problem."
  overwrittenPkgs
)
