{ system, lib, stdenv, bash, coreutils, rsync, ... }:

let
  inherit (builtins) replaceStrings;
  inherit (lib) optionalString join;
in rec {
  stripPackageName = replaceStrings [ "/" ] [ ":" ];
  getPackageNameWithVersion = { packageName, version, ... }: "${stripPackageName packageName}-${version}";
  getPackageFullName = { nodejs, packageName, version, ... }@attrs: "${nodejs.name}-${getPackageNameWithVersion attrs}";

  # TODO: If we can get whether a package needs to be build or not (have
  # nixbuild preinstall install postinstall) through nix, then a bunch of src
  # derivations can be directly use as the built ones, since they have no
  # differences.

  # Make derivation to build the source of a npm package
  # (i.e. just download the package without building it)
  mkNpmPackageSource = {
    nodejs,
    packageName,
    version,
    src,
    ...
  }: let
    name = "npm-${stripPackageName packageName}-${version}-src";
  in stdenv.mkDerivation {
    inherit name packageName src;
    buildInputs = [ nodejs coreutils rsync ];
    phases = [ "unpackPhase" "patchPhase" "installPhase" ];
    patchPhase = ''
      patchShebangs .
    '';
    installPhase = ''
      mkdir -p "$out/$packageName"
      rsync -a . "$out/$packageName/" \
        --exclude=/.*.swp \
        --exclude=/._* \
        --exclude=/.DS_Store \
        --exclude=/.git \
        --exclude=/.hg \
        --exclude=/.npmrc \
        --exclude=/.lock-wscript \
        --exclude=/.svn \
        --exclude=/.wafpickle-* \
        --exclude=/config.gypi \
        --exclude=/CVS \
        --exclude=/npm-debug.log \
        --filter='dir-merge,- .npmignore'

      echo "$packageName" > "$out/package-name"
      echo "true" > "$out/not-built"

      binsToLink=($(node "$getBinsScript" "$out/$packageName"))
      for b in $binsToLink; do
        IFS='|' read -r -a arr <<< "$b"
        binName=''${arr[0]}
        binPath=''${arr[1]}
        echo "  $packageName link-bin: $binName -> $binPath"
        mkdir -p "$out/bin"
        cd "$out/bin"
        ln -sf "../$packageName/$binPath" "$binName"
        chmod +x "$binName"
        cd -
      done
    '';
    getBinsScript = ./get-bins.js;
  } // { inherit nodejs packageName; };

  # Make derivation to build the source of a npm package, with dependencies
  # included (i.e. just download the package without building it)
  mkNpmPackageSourceWithDeps = {
    nodejs,
    packageName,
    version,
    src,
    dependencies ? [],
    ...
  } @ attrs: let
    source = mkNpmPackageSource attrs;
    dependencyNames = map (d: getPackageNameWithVersion d) dependencies;
    # TODO: If dependencyNames length > 4, just use "with-deps"
    postfix = "with-${join "-" dependencyNames}";
    name = "npm-${stripPackageName packageName}-${version}-src-${postfix}";
    nodeEnv = mkNodeEnv {
      dontbuild = true;
      name = "${name}-tmp-node-env";
      inherit nodejs dependencies;
    };
  in if (dependencies == []) then source else derivation {
    inherit system name nodeEnv;
    package = source;
    builder = "${bash}/bin/bash";
    buildInputs = [ coreutils ];
    args = [ ./build-with-deps.sh ];
  } // { inherit nodejs packageName dependencyNames; };

  # Make derivation to build a npm package
  mkNpmPackage = {
    nodejs,
    packageName,
    version,
    src,
    buildEnv ? null,
    ...
  } @ attrs: let
    name = getPackageFullName attrs;
    source = mkNpmPackageSource attrs;
    buildScript = ''
      set -e

      unset PATH
      for p in $buildInputs; do
        export PATH=$p/bin''${PATH:+:}$PATH
      done

      # Unpack
      cp -r "$source" "$TMPDIR/build"
      chmod -R +w "$TMPDIR/build"

      # Configure
      export pathToPackage="$(cat "$TMPDIR/build/package-name")"
    '' + optionalString (buildEnv != null) ''
      source "$buildEnv/env.sh"
      # TODO: Delete the following lines
      # export PATH="$PATH:$(cat "$buildEnv/PATH")"
      # export NODE_PATH="$(cat "$buildEnv/NODE_PATH")"
    '' + ''

      # Build
      cd "$TMPDIR/build/$pathToPackage"
      npm run nixbuild --if-present --no-update-notifier
      npm run preinstall --if-present --no-update-notifier
      npm run install --if-present --no-update-notifier
      npm run postinstall --if-present --no-update-notifier
      cd -
      rm -rf "$TMPDIR/build/not-built"

      # Install
      cp -r "$TMPDIR/build" "$out"
    '';
  in derivation {
    inherit system name source buildEnv;
    builder = "${bash}/bin/bash";
    buildInputs = [
      # TODO: Might need more stuff for building nodejs native dependencies
      bash coreutils nodejs
    ];
    args = [ "-c" buildScript ];
  } // { inherit nodejs packageName; };

  # Make derivation to build a npm package, with dependencies included
  mkNpmPackageWithDeps = {
    nodejs,
    packageName,
    version,
    src,
    buildEnv ? null,
    dependencies ? [],
    ...
  } @ attrs: let
    package = mkNpmPackage attrs;
    dependencyNames = map (d: getPackageNameWithVersion d) dependencies;
    # TODO: If dependencyNames length > 4, just use "with-deps"
    postfix = "with-${join "-" dependencyNames}";
    name = "${getPackageFullName attrs}-${postfix}";
    nodeEnv = mkNodeEnv {
      name = "${name}-tmp-node-env";
      inherit nodejs dependencies;
    };
  in if (dependencies == []) then package else derivation {
    inherit system name package nodeEnv;
    builder = "${bash}/bin/bash";
    buildInputs = [ coreutils ];
    args = [ ./build-with-deps.sh ];
  } // { inherit nodejs packageName dependencyNames; };

  # Make derivation to build a npm package, with the environment included
  # TODO: If production mode, build nodeEnvDev only for build
  mkNpmPackageWithEnv = {
    nodejs,
    packageName,
    version,
    src,
    buildEnv ? null,
    ...
  } @ attrs: let
    source = mkNpmPackageSource attrs;
    name = "${getPackageFullName attrs}-with-env";
    nodeEnv = mkNodeEnv (attrs // {
      name = "${name}-node-env";
    });
  in stdenv.mkDerivation {
    inherit name nodeEnv source;
    buildInputs = [
      # TODO: Might need more stuff for building nodejs native dependencies
      bash coreutils nodejs
    ];
    shellHook = ''
      source "$nodeEnv/env.sh"
    '';
    phases = [ "unpackPhase" "buildPhase" "installPhase" "fixupPhase" ];
    unpackPhase = ''
      cp -r "$source" "$TMPDIR/build"
      chmod -R +w "$TMPDIR/build"
    '';
    buildPhase = ''
      export pathToPackage="$(cat "$TMPDIR/build/package-name")"
      source "$nodeEnv/env.sh"

      cd "$TMPDIR/build/$pathToPackage"
      npm run nixbuild --if-present --no-update-notifier
      npm run preinstall --if-present --no-update-notifier
      npm run install --if-present --no-update-notifier
      npm run postinstall --if-present --no-update-notifier
      cd -
      rm -rf "$TMPDIR/build/not-built"
    '';
    installPhase = ''
      cp -r "$TMPDIR/build" "$out"
    '';
    # TODO: Patch all require('...') to absolute path, by this way we can
    # support the package to be required in another node project? No we can't
    # do this because the packages used by this package will broke due to the
    # lack of NODE_PATH.
    # The best way seems to be decoupling the pure package and it's
    # dependencies, so the pure package can be re-used in other projects
    # without dragging a bunch of its own dependencies that might not be used.
    # And let nix check for a default.nix or npm-package.nix after fetching the
    # source and determine to build it via nix or npm?
    # We need to leave the dependency resolution to npm. Hopefully npm can get
    # the package.json through a git or file source, while nix can do the
    # installation.
    fixupPhase = ''
      cd "$out"
      if [[ -d bin ]]; then
        mv bin .bin
        mkdir bin
        for b in .bin/*; do
          binName="$(basename $b)"
          echo "#!/usr/bin/env bash" >> "bin/$binName"
          echo "source '$nodeEnv/env.sh'" >> "bin/$binName"
          echo "\"\$(\"${coreutils}/bin/dirname\" \$(\"${coreutils}/bin/realpath\" \"\$0\"))/../.bin/$binName\" \"\$@\"" >> "bin/$binName"
          chmod +x "bin/$binName"
        done
        patchShebangs bin
      fi
      cd -
    '';
  } // { inherit nodeEnv; inherit (nodeEnv) nodePath path dependencies; };

  # Make derivation to build a node environment
  # TODO: If production mode, filter the dependencies
  mkNodeEnv = {
    nodejs,
    name,
    dependencies ? [],
    dontbuild ? false,
    ...
  }: let
    mkPkg = if dontbuild then mkNpmPackageSourceWithDeps else mkNpmPackageWithDeps;
    mkNpmPackageAdditionalAttrs = {
      inherit nodejs;
      buildEnv = mkNodeEnv {
        inherit nodejs dependencies;
        dontbuild = true;
        name = "${name}-build-env";
      };
    };
    deps = map ({ packageName, ... }@attrs: mkPkg (attrs // mkNpmPackageAdditionalAttrs)) dependencies;
    nodePath = join ":" deps;
    path = join ":" (map (d: "${d}/bin") deps);
    buildScript = ''
      set -e

      unset PATH
      for p in $buildInputs; do
        export PATH=$p/bin''${PATH:+:}$PATH
      done

      mkdir -p "$out"

      echo "$nodePath" > "$out/NODE_PATH"
      echo "$path" > "$out/PATH_UNFILTERED"

      unset path_filtered
      for dep in $deps; do
        if [[ -d "$dep/bin" ]]; then
          path_filtered=$dep/bin''${path_filtered:+:}$path_filtered
        fi
      done

      echo "$path_filtered" > "$out/PATH"

      echo "export PATH=$path_filtered\''${PATH:+:}\$PATH" >> "$out/env.sh"
      echo "export NODE_PATH=$nodePath" >> "$out/env.sh"
    '' + optionalString dontbuild ''
      echo "true" > "$out/not-built"
    '';
  in derivation {
    inherit system name deps nodePath path;
    builder = "${bash}/bin/bash";
    buildInputs = [
      coreutils nodejs
    ];
    getBinsScript = ./get-bins.js;
    args = [ "-c" buildScript ];
  } // { inherit nodePath path; dependencies = deps; };
}
