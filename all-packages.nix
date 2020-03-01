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
    fetchNpmPackage = callPackage ./pkgs/development/nodejs/npm/fetchNpmPackage { };
    buildNpmPackage = callPackage ./pkgs/development/nodejs/npm/buildNpmPackage { };
    mkInstalledNpmPackage = callPackage ./pkgs/development/nodejs/npm/mkInstalledNpmPackage { };
    mkNpmPackageBundle = callPackage ./pkgs/development/nodejs/npm/mkNpmPackageBundle { };
    mkNodePackage = callPackage ./pkgs/development/nodejs/npm/mkNodePackage { };
    mkNodeEnv = callPackage ./pkgs/development/nodejs/npm/mkNodeEnv { };
    mkNodeEnvForPackage = callPackage ./pkgs/development/nodejs/npm/mkNodeEnvForPackage { };
    mkNodePackageWithRuntime = callPackage ./pkgs/development/nodejs/npm/mkNodePackageWithRuntime { };
    npmjs2nix = callPackage ./pkgs/development/nodejs/npmjs2nix/package.nix { };

    neofetch-web = callPackage (
      builtins.fetchGit {
        url = "https://github.com/zetavg/neofetch-web.git";
        ref = "master";
        rev = "6484e1f683e939cac255b165cb275ea540d26014";
      }
    ) { inherit pkgs mkNodePackageWithRuntime; };

    # The modify of buildRubyGem is disabled because it will break things in these
    # cases:
    #
    #   - Error: builder for '/nix/store/zkdhy0gg8v0sr745hq41lhlvr947ay0w-bundler-1.17.2-gem.drv' failed with exit code 1; last 3 log lines:
    #            installing
    #            buildFlags:
    #            failure: $gempkg path unspecified
    #
    #   - Error: patching script interpreter paths in /nix/store/nfjqfbw0vrywp82ygpp0qrgw0hpbs2gp-ruby2.5.5-mathematical-1.6.11
    #            checking for references to /tmp/nix-build-ruby2.5.5-mathematical-1.6.11.drv-0/ in /nix/store/nfjqfbw0vrywp82ygpp0qrgw0hpbs2gp-ruby2.5.5-mathematical-1.6.11...
    #            open: Permission denied
    #     Reason: The patch to mathematical.so cannot be applied because mathematical.so
    #     is in the shared gem source code directory, which belongs to a seperaterated
    #     packages, that is already built and is read-only
    #     (See nixpkgs/pkgs/tools/typesetting/asciidoctor/default.nix, postFixup phase).
    #
    # buildRubyGem = callPackage ./pkgs/development/ruby/gem {
    #   buildRubyGem = super.buildRubyGem;
    # };
    buildRailsApp = callPackage ./pkgs/development/ruby/rails-app { };

    passenger = callPackage ./pkgs/servers/passenger { };
    nginx-mod-passenger = callPackage ./pkgs/servers/nginx-mod-passenger.nix { };
    nginx-with-passenger = callPackage ./pkgs/servers/nginx-with-passenger.nix { };

    elastic-apm-server = callPackage ./pkgs/servers/monitoring/elastic-apm-server { };
    elastic-apm-server-oss = callPackage ./pkgs/servers/monitoring/elastic-apm-server {
      enableUnfree = false;
    };

    sample-rails-app = callPackage (
      builtins.fetchGit {
        url = "https://github.com/zetavg/rails-nix-sample.git";
        ref = "master";
        rev = "d92e60eee96aeb68ece6ef0fe96020f4235a08ba";
      }
    ) { inherit pkgs buildRailsApp; };

    composeXcodeWrapper = callPackage ./pkgs/development/mobile/compose-xcodewrapper.nix { };
    xcode_10_2 = callPackage ./pkgs/development/mobile/xcode_10_2.nix { };

    overlays-compat = callPackage ./pkgs/os-specific/nixos/overlays-compat.nix { };

    # Log the differentials we made to the nixpkgs-diff attr. Do aware that
    # changes made by subsequent overlays will not be reflected here, unless
    # they'll also add their changes to nixpkgs-diff.
    nixpkgs-diff = (super.nixpkgs-diff or { }) // pkgs;
  };
in pkgs
