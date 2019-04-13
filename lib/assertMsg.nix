{ lib, ... }:

let
  assertMsg = pred: msg:
    if pred
    then true
    else builtins.trace msg false;
in lib.assertMsg or assertMsg
