/*
 * Tool for applying overlays from configuration.nix to users under the system
 * (by adding <nixpkgs-overlays> in NIX_PATH).
 *
 * Sample usage in a NixOS Module (e.g. configuration.nix):
 *
 *     { pkgs, options, ... }:
 *
 *     {
 *       nix.nixPath = with pkgs;
 *         (options.nix.nixPath.default or [ ]) ++
 *         [ "nixpkgs-overlays=${overlays-compat}/" ]
 *       ;
 *     }
 *
 * See: http://bit.ly/using-overlays-from-config-as-nixpkgs-overlays-in-NIX_PATH
 */

{ system, bash, coreutils }:

derivation {
  name = "overlays-compat";
  inherit system;
  builder = "${bash}/bin/bash";
  args = [
    "-c"
    ''
      ${coreutils}/bin/mkdir -p $out && \
      echo "$src" > "$out/overlays.nix"
    ''
  ];
  src = ''
    self: super:
    with super.lib; let
      # Using the nixos plumbing that's used to evaluate the config...
      eval = import <nixpkgs/nixos/lib/eval-config.nix>;
      # Evaluate the config,
      paths = (eval {modules = [(import <nixos-config>)];})
        # then get the `nixpkgs.overlays` option.
        .config.nixpkgs.overlays
      ;
    in
    foldl' (flip extends) (_: super) paths self
  '';
}
