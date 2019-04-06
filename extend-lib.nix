/*
 * An overlay to extend lib.
 */

self: super:

let
  extendLib = super.lib.extend;
in {
  lib = extendLib (self: super: let
    callLibs = file: import file { lib = self; };
  in with self; {
    join = callLibs ./lib/join.nix;
    removeExtensionFromFilename = callLibs ./lib/removeExtensionFromFilename.nix;
    toYaml = callLibs ./lib/toYaml.nix;
    path = callLibs ./lib/path.nix;
    inherit (path) listDir isDirContainingDefaultNixPath isNixFilePath
                   getPathAndTypeUnderDir getImportablePathsUnderDir
                   getImportPathsUnderDir;
  });
}
