/*
 * The package collection as an overlay of nixpkgs
 */

self: super: import ../default.nix { pkgs = super; }
