{ ... }:

let
  inherit (builtins) head match;
  removeExtensionFromFilename = filename: head (match "([^.]+).*" filename);
in removeExtensionFromFilename
