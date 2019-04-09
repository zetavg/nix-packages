/*
 * An overlay to add all packages.
 *
 * Requirement: extend-lib.
 */

self: super:

let
  inherit (builtins) fetchTarball;
  inherit (self) callPackage;
  pkgs = with self; {
    npm = callPackage ./pkgs/development/nodejs/npm { };
    mkNodeEnvDerivation = npm.mkNodeEnv;
    mkNpmPackageDerivation = npm.mkNpmPackageWithRuntime;
    npm-package-to-nix = callPackage ./pkgs/development/nodejs/npm-package-to-nix/package.nix { };

    neofetch-web = callPackage (
      builtins.fetchGit {
        url = "https://github.com/zetavg/neofetch-web.git";
        ref = "master";
        rev = "c6f3eee3fd8d7a688081e6b13c5c087a5ec66499";
      } + /package.nix
    ) { pkgs = self.pkgs; };

    buildRubyGem = callPackage ./pkgs/development/ruby/gem {
      buildRubyGem = super.buildRubyGem;
    };
    buildRailsApp = callPackage ./pkgs/development/ruby/rails-app { };

    passenger = callPackage ./pkgs/servers/passenger { };
    nginx-mod-passenger = callPackage ./pkgs/servers/nginx-mod-passenger.nix { };
    nginx-with-passenger = callPackage ./pkgs/servers/nginx-with-passenger.nix { };

    sample-rails-app = callPackage (
      fetchTarball "https://github.com/zetavg/rails-nix-sample/archive/master.tar.gz"
    ) { pkgs = self.pkgs; };

    overlays-compat = callPackage ./pkgs/os-specific/nixos/overlays-compat.nix { };

    # Log the differentials we made to the nixpkgs-diff attr. Do aware that
    # changes made by subsequent overlays will not be reflected here, unless
    # they'll also add their changes to nixpkgs-diff.
    nixpkgs-diff = (super.nixpkgs-diff or { }) // pkgs;
  };
in pkgs
