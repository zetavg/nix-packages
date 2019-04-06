{ lib, ... }:

let
  inherit (builtins) attrValues filter mapAttrs match pathExists readDir;
in rec {
  listDir = dir: attrValues (mapAttrs (name: type: { inherit name type; }) (readDir dir));
  isDirContainingDefaultNixPath = path: pathExists (path + "/default.nix");
  isNixFilePath = path: match ".+\.nix" (baseNameOf path) != null;
  getPathAndTypeUnderDir = dir: map ({ name, type }: { path = dir + "/${name}"; inherit type; }) (listDir dir);
  getImportablePathsUnderDir = dir: map ({ path, ... }: path) (filter ({ path, type }: if type == "directory" then isDirContainingDefaultNixPath path else isNixFilePath path) (getPathAndTypeUnderDir dir));
  getImportPathsUnderDir = dir: filter (path: (baseNameOf path) != "default.nix") (getImportablePathsUnderDir dir);
}
