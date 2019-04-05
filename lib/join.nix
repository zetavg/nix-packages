{ lib, ... }:

let
  inherit (lib) foldr;
  join = separator: foldr (a: b: if b != null then "${a}${separator}${b}" else a) null;
in join
