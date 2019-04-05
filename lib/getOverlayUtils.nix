{ lib, ... }:

let
  inherit (builtins) baseNameOf;
  inherit (lib) removeExtensionFromFilename;
in {
  overlayGroupName ? "ovly",
  self,
  super,
  ...
}:
{
  # Call a overlay while saving itself into the overlayGroupName attr
  callOverlay = overlayFile: let
    overlayName = removeExtensionFromFilename (baseNameOf overlayFile);
    overlay = import overlayFile;
  in (overlay self super) // {
    "${overlayGroupName}" = { "${overlayName}" = overlay; };
  };
  # Merge overlay outputs with the overlayGroupName attr handled
  mergeOverlays = builtins.foldl' (x: y: x // y // {
    "${overlayGroupName}" = (x."${overlayGroupName}" or {}) // (y."${overlayGroupName}" or {});
  }) {};
}
