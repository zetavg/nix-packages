{ lib, ... }:

let
  inherit (builtins) typeOf;
  inherit (lib) splitString join mapAttrsToList;
  splitLines = splitString "\n";
  joinToLines = join "\n";
  # TODO: Fix
  #   lib.toYaml [ [ ] ]
  #   => error: cannot coerce null to a string
  #   lib.toYaml { n = { }; }
  #   => error: cannot coerce null to a string
  toYaml = x: let
    type = typeOf x;
  in
    if type == "set"
      then joinToLines (
        mapAttrsToList (name: value: (
          let
            typeOfValue = typeOf value;
            yamlValue = toYaml value;
            indentedYamlValue = joinToLines(
              map (line: "  ${line}") (splitLines yamlValue)
            );
          in if typeOfValue == "list" || typeOfValue == "set" then
            "${name}:\n${indentedYamlValue}"
          else
            "${name}: ${yamlValue}"
        )) x
      )
    else if type == "list"
      then joinToLines (
        map (i: "- ${toYaml i}") x
      )
    else if type == "string" || type == "path"
      then "\"${x}\""
    else if type == "bool"
      then if x then "true" else "false"
    else toString x;
in toYaml
