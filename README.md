# Nix Packages

[![Build Status](https://travis-ci.com/zetavg/nix-packages.svg?branch=master)](https://travis-ci.com/zetavg/nix-packages)
[![Cachix Cache](https://img.shields.io/badge/cachix-zetavg-blue.svg)](https://zetavg.cachix.org)

Nix packages. Ruby, Rails, Node.js/NPM, Nginx + Passenger.
<!--
## Installation

To make this package collection accessible for your login user, add the following to `~/.config/nixpkgs/config.nix`:

```nix
{
  packageOverrides = pkgs: {
    zpkgs = import (builtins.fetchTarball "https://git.io/zpkgs-archive-master") {
      inherit pkgs;
    };
  };
}
```

<details>
<summary>Diff</summary>

```patch
 {
   packageOverrides = pkgs: {
+    zpkgs = import (builtins.fetchTarball "https://git.io/zpkgs-archive-master") {
+      inherit pkgs;
+    };
   };
 }
```

</details>

Then follow the [instructions on Cachix](https://zetavg.cachix.org/) to setup binary cache.

For NixOS, add the following to your `/etc/nixos/configuration.nix`:

```nix
{ pkgs, ... }:

{
  nixpkgs.config.packageOverrides = pkgs: {
    zpkgs = import (builtins.fetchTarball "https://git.io/zpkgs-archive-master") {
      inherit pkgs;
    };
  };
  nix.binaryCaches = [
    https://zetavg.cachix.org/
  ];
  nix.binaryCachePublicKeys = [
    "zetavg.cachix.org-1:Sj61CXglgN8FnXEipp0T3WXTrgrnkwv2fIW/krLIT7Q="
  ];
}
```

<details>
<summary>Diff</summary>

```patch
 { pkgs, ... }:

 {
   nixpkgs.config.packageOverrides = pkgs: {
+    zpkgs = import (builtins.fetchTarball "https://git.io/zpkgs-archive-master") {
+      inherit pkgs;
+    };
   };
   nix.binaryCaches = [
+    https://zetavg.cachix.org/
   ];
   nix.binaryCachePublicKeys = [
+    "zetavg.cachix.org-1:Sj61CXglgN8FnXEipp0T3WXTrgrnkwv2fIW/krLIT7Q="
   ];
 }
```

</details>
-->
