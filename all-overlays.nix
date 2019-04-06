/*
 * An overlay that overlay all overlays.
 *
 * Requirement: extend-lib.
 */

self: super:

let
  inherit (builtins) map foldl';
  inherit (super.lib) getImportablePathsUnderDir;
  overlays = map (file: import file) (getImportablePathsUnderDir ./overlays);
  combineOverlays =
    overlays: self: super:
    foldl' (
      lastOutput: overlay:
      let
        lastSuper = super // lastOutput;
        output = overlay self lastSuper;
        newOutput = lastOutput // output;
      in newOutput
    ) { } overlays;
  overlay = combineOverlays overlays;
  overlayOutput = overlay self super;
in overlayOutput // {
  # Automatically log differentials made by all overlays to the nixpkgs-diff
  # attr. Do aware that changes made by subsequent overlays will not be
  # reflected here, unless they'll also add their changes to nixpkgs-diff.
  nixpkgs-diff = (super.nixpkgs-diff or { }) // overlayOutput;
}
