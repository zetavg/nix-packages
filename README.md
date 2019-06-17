# Nix Packages

[![Build Status](https://travis-ci.com/zetavg/nix-packages.svg?branch=master)](https://travis-ci.com/zetavg/nix-packages)
[![Cachix Cache](https://img.shields.io/badge/cachix-zetavg-blue.svg)](https://zetavg.cachix.org)

Nix packages. Ruby, Rails, Node.js/NPM, Nginx + Passenger.

## Installation

For short, there're three types of installation, each with options to choose from:

- [NixOS Systemwide](#nixos-systemwide)
  - [Option 1: Overlay (Recommended)](#option-1-overlay-recommended)
  - [Option 2: Addon](#option-2-addon)
- [Single User](#single-user)
  - [Option 1: Overlay (Recommended)](#option-1-overlay-recommended-1)
  - [Option 2: Addon](#option-2-addon-1)
- [Project Basis](#project-basis)

### NixOS Systemwide

You can use this package collection to compose your NixOS system, and/or provide the package collection to all users under your system.

#### Option 1: Overlay (Recommended)

Apply the following configuration in your NixOS Module (e.g. `configuration.nix`), to install this package collection as an ["overlay"](https://nixos.wiki/wiki/Overlays) for nixpkgs (i.e. new packages will be available directly under `let pkgs = import <nixpkgs> { }; in pkgs`, and some provided will be overwritten), for the system and every user under the system. See the comments for details as you may want to change something:

```nix
{ pkgs, options, ... }:

let
  # To "pin" to a certain commit, use this instead of `fetchTarball`:
  # zpkgs-source = builtins.fetchGit {
  #   url = "https://github.com/zetavg/nix-packages.git";
  #   ref = "master";
  #   # Get the latest commit rev on
  #   # https://github.com/zetavg/nix-packages/commits/master
  #   rev = "...";
  # };
  zpkgs-source = builtins.fetchTarball "https://git.io/zpkgs-archive-master";
in {
  # Use the package collection as an overlay of nixpkgs
  nixpkgs.overlays =
    (options.nixpkgs.overlays.default or [ ]) ++
    (import "${zpkgs-source}/manifest.nix");

  # Also apply the zpkgs overlay to users under the system
  # See:
  #  - http://bit.ly/using-overlays-from-config-as-nixpkgs-overlays-in-NIX_PATH
  #  - http://bit.ly/overlays-compat-in-zpkgs
  nix.nixPath = with pkgs;
    (options.nix.nixPath.default or [ ]) ++
    [ "nixpkgs-overlays=${overlays-compat}/" ]
  ;

  # Add binary cache servers for zpkgs
  nix.binaryCaches = (options.nix.binaryCaches.default or [ ]) ++ [
    https://zetavg.cachix.org/
  ];
  nix.binaryCachePublicKeys = (options.nix.binaryCachePublicKeys.default or [ ]) ++ [
    "zetavg.cachix.org-1:Sj61CXglgN8FnXEipp0T3WXTrgrnkwv2fIW/krLIT7Q="
  ];
}
```

With the above configurations applied, you can use the new provided packages, such as `pkgs.nginx-with-passenger` in other system configuration modules. Users under the system can also install the new provided or modified packages using the `nix-env` command like `nix-env -iA nixpkgs.passenger`, or refer them such as `nix-instantiate --eval -E 'let pkgs = import <nixpkgs> { }; in pkgs.passenger'`, as well as you run `sudo nixos-rebuild switch` to switch to the new config.

#### Option 2: Addon

If you want to leave `<nixpkgs>` unchanged, the following config will make this package collection accessible under the `.zpkgs` attribute of `<nixpkgs>`, but only for the system (i.e. new provided or modified packages will be available under `pkgs.zpkgs`, e.g. `pkgs.zpkgs.nginx-with-passenger`, in other system configuration modules). See the comments for details as you may want to change something:

<details>
<summary>Show Config</summary>

```nix
{ pkgs, options, ... }:

let
  # To "pin" to a certain commit, use this instead of `fetchTarball`:
  # zpkgs-source = builtins.fetchGit {
  #   url = "https://github.com/zetavg/nix-packages.git";
  #   ref = "master";
  #   # Get the latest commit rev on
  #   # https://github.com/zetavg/nix-packages/commits/master
  #   rev = "...";
  # };
  zpkgs-source = builtins.fetchTarball "https://git.io/zpkgs-archive-master";
in {
  # Make the package collection accessialbe under the zpkgs attribute
  nixpkgs.packageOverrides = pkgs: {
    zpkgs = import zpkgs-source {
      inherit pkgs;
    };
  };

  # Add binary cache servers for zpkgs
  nix.binaryCaches = (options.nix.binaryCaches.default or [ ]) ++ [
    https://zetavg.cachix.org/
  ];
  nix.binaryCachePublicKeys = (options.nix.binaryCachePublicKeys.default or [ ]) ++ [
    "zetavg.cachix.org-1:Sj61CXglgN8FnXEipp0T3WXTrgrnkwv2fIW/krLIT7Q="
  ];
}
```

</details>

Aware that this installation option will not affect users under the system. To make the packages available for users, you'll need to go for the [single user installation type](#single-user) for every user needed.

### Single User

If you're not using NixOS or only want to use this package collection as your own, then this is the type of installation you'll use.

#### Option 1: Overlay (Recommended)

Edit `~/.config/nixpkgs/overlays.nix` and add the following configuration. See the comments for details as you may want to change something:

```nix
let
  # To "pin" to a certain commit, use this instead of `fetchTarball`:
  # zpkgs-source = builtins.fetchGit {
  #   url = "https://github.com/zetavg/nix-packages.git";
  #   ref = "master";
  #   # Get the latest commit rev on
  #   # https://github.com/zetavg/nix-packages/commits/master
  #   rev = "...";
  # };
  zpkgs-source = builtins.fetchTarball "https://git.io/zpkgs-archive-master";
in (import "${zpkgs-source}/manifest.nix") ++ [
  # Add other overlays here
]
```

After appling the config, you can install the new provided or modified packages using the `nix-env` command like `nix-env -iA nixpkgs.passenger`, or refer them such as `nix-instantiate --eval -E 'let pkgs = import <nixpkgs> { }; in pkgs.passenger'`.

Follow the [instructions on Cachix](https://zetavg.cachix.org/) to add the new binary cache server for this package collection.

#### Option 2: Addon

If you want to leave `<nixpkgs>` unchanged, the following config will make this package collection accessible under the `.zpkgs` attribute of `<nixpkgs>`, apply it to `~/.config/nixpkgs/config.nix`. See the comments for details as you may want to change something:

<details>
<summary>Show Config</summary>

```nix
let
  # To "pin" to a certain commit, use this instead of `fetchTarball`:
  # zpkgs-source = builtins.fetchGit {
  #   url = "https://github.com/zetavg/nix-packages.git";
  #   ref = "master";
  #   # Get the latest commit rev on
  #   # https://github.com/zetavg/nix-packages/commits/master
  #   rev = "...";
  # };
  zpkgs-source = builtins.fetchTarball "https://git.io/zpkgs-archive-master";
in {
  packageOverrides = pkgs: {
    zpkgs = zpkgs-source {
      inherit pkgs;
    };
  };
}
```

</details>

After appling the config, you can install the new provided or modified packages using the `nix-env` command like `nix-env -iA nixpkgs.zpkgs.passenger`, or refer them such as `nix-instantiate --eval -E 'let pkgs = import <nixpkgs> { }; in pkgs.zpkgs.passenger'`.

Follow the [instructions on Cachix](https://zetavg.cachix.org/) to add the new binary cache server for this package collection.

### Project Basis

To craft software that are buildable via nix with the help of this package collection, take `mkNodePackageWithRuntime` for example, you can write something like this as your `default.nix`:

```nix
{
  # To "pin" to a certain commit, use this instead of `fetchTarball`:
  # pkgs ? import (
  #   builtins.fetchGit {
  #     url = "https://github.com/zetavg/nix-packages.git";
  #     ref = "master";
  #     # Get the latest commit rev on
  #     # https://github.com/zetavg/nix-packages/commits/master
  #     rev = "...";
  #   }
  # ) { },
  pkgs ? import (
    builtins.fetchTarball "https://git.io/zpkgs-archive-master"
  ) { /* pkgs = import <nixpkgs> { } # If you want to use system <nixpkgs> rather then the nixpkgs version pinned in zpkgs */ },
  nodejs ? pkgs.nodejs,
  mkNodePackageWithRuntime ? pkgs.mkNodePackageWithRuntime,
  ...
}:
let
  npmPackage = import ./npm-package.nix {
    srcs = [
      ./package.json
      # ...
    ];
  };
in mkNodePackageWithRuntime nodejs { } npmPackage
```
