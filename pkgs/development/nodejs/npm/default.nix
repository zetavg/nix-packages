{ lib, system, stdenv, bash, coreutils, gnutar, gzip, bzip2, rsync, ... }:

let
  inherit (builtins) map filter stringLength isAttrs attrNames;
  inherit (lib) mapAttrsToList optionalString join;
  getNameFromAttrs = { name, version, ... }: "${name}-${version}";
  getNameWithNodePrefixFromAttrs = { name, version, ... }: "nodejs-${name}-${version}";
  getNameWithNodejsVersionFromAttrs = { nodejs,name, version, ... }: "${nodejs.name}-${name}-${version}";
  prepareBuildScript = ''
    set -e
    unset PATH
    for p in $buildInputs; do
      export PATH=$p/bin''${PATH:+:}$PATH
    done
  '';
  packageNameFileName = ".package-name";
  notBuiltIndicationFileName = ".not-built";
in rec {
  /*
   * Derivation to produce a npm package without doing anything, such as build
   * it's native dependencies.
   */
  mkNpmPackageWithoutBuild = {
    # Package Info
    name,
    packageName,
    version,
    src,
    bin ? null,
    buildNeeded ? false,
    ...
  } @ attrs: let
    name = getNameWithNodePrefixFromAttrs attrs;
    bins = if isAttrs bin then attrNames bin else [];
    binDataList = if isAttrs bin
      then mapAttrsToList (name: path: "${name}|${path}") bin
      else [];
    buildScript = prepareBuildScript + ''
      # Create output dir
      mkdir -p "$out/$packageName"

      # Write data
      echo "$packageName" > "$out/${packageNameFileName}"

      # Unpack and move the source to "$out/$packageName"
      # If is dir, use rsync to copy files
      if [ -d "$src" ]; then
        # TODO: Support npm exclude rules in package.json
        rsync -a "$src/." "$out/$packageName/" \
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
      # Not dir, assume it's a tarball
      else
        # Try to unpack
        case "$src" in
          *.tar | *.tar.* | *.tgz | *.tbz2 | *.tbz)
            # GNU tar can automatically select the decompression method
            # (info "(tar) gzip").
            # Add --warning=no-unknown-keyword to suppress messages like
            # tar: Ignoring unknown extended header keyword 'NODETAR...'
            tar xf "$src" --warning=no-unknown-keyword
            ;;
          *)
            echo "don't know how to unpack $src"
            exit 1
            ;;
        esac
        # Move to out
        for i in *; do
          if [ -d "$i" ]; then
            rm -rf "$out/$packageName"
            mv -f "$i" "$out/$packageName"
            break
          fi
        done
      fi

      # Link bins
      for b in $binDataList; do
        IFS='|' read -r -a arr <<< "$b"
        binName=''${arr[0]}
        binPath=''${arr[1]}
        mkdir -p "$out/.bin"
        cd "$out/.bin"
        ln -sf "../$packageName/$binPath" "$binName"
        chmod +x "$binName"
        cd -
      done
    '' + optionalString (buildNeeded == true) ''
      echo true > "$out/${notBuiltIndicationFileName}"
    '';
  in derivation {
    inherit system name;
    inherit packageName src binDataList;
    builder = "${bash}/bin/bash";
    buildInputs = [
      bash
      coreutils
      rsync
      gnutar gzip bzip2.bin
    ];
    args = [ "-c" buildScript ];
  } // {
    # Add additional attrs that might be useful
    nodejs = null;
    inherit packageName bins;
    includedDependencies = [ ];
    nodeEnv = null;
  };

  /*
   * Derivation to produce a npm package.
   */
  mkNpmPackage = {
    # Node.js
    nodejs,

    # Package Info
    name,
    packageName,
    version,
    src,
    bin ? null,
    buildNeeded ? false,

    # Environment Required For Building
    buildEnv ? null,
    ...
  } @ attrs: let
    name = getNameWithNodejsVersionFromAttrs attrs;
    packageWithoutBuild = mkNpmPackageWithoutBuild attrs;
    buildScript = prepareBuildScript + ''
      # Get Source
      cp -r "$packageWithoutBuild" "$TMPDIR/build"
      chmod -R +w "$TMPDIR/build"

      # Prepare Build Environment
      export pathToPackage="$(cat "$TMPDIR/build/${packageNameFileName}")"
    '' + optionalString (buildEnv != null) ''
      source "$buildEnv/env.sh"
    '' + ''

      # Build
      cd "$TMPDIR/build/$pathToPackage"
      npm run nix-preinstall --if-present --no-update-notifier
      npm run preinstall --if-present --no-update-notifier
      npm run install --if-present --no-update-notifier
      npm run postinstall --if-present --no-update-notifier
      npm run nix-postinstall --if-present --no-update-notifier
      cd -
      rm -rf "$TMPDIR/build/${notBuiltIndicationFileName}"

      # Install
      cp -r "$TMPDIR/build" "$out"
    '';
  in if buildNeeded != true then packageWithoutBuild else derivation {
    inherit system name;
    inherit packageWithoutBuild buildEnv;
    builder = "${bash}/bin/bash";
    buildInputs = [
      # TODO: Might need more stuff for building nodejs native dependencies
      bash coreutils nodejs
    ];
    args = [ "-c" buildScript ];
  } // {
    inherit nodejs;
    inherit (packageWithoutBuild) packageName bins;
    includedDependencies = [ ];
    nodeEnv = null;
  };

  /*
   * Derivation to produce a npm package with dependencies included under
   * node_modules, equivalent of a package installed via npm install.
   */
  mkNpmPackageWithDeps = {
    # Node.js
    nodejs,

    # Options
    production ? true,
    dontbuild ? false,

    # Package Info
    name,
    packageName,
    version,
    src,
    bin ? null,
    buildNeeded ? false,

    # Dependencies
    dependencies ? [],
    devDependencies ? [],
    ...
  } @ attrs: let
    mkPkg = if dontbuild then mkNpmPackageWithoutBuild else mkNpmPackage;
    package = mkPkg attrs;
    includedDependencies = if production then dependencies else dependencies ++ devDependencies;
    dependencyNames = map getNameFromAttrs includedDependencies;
    nameDependenciesPostfix = "${join "+" dependencyNames}";
    namePostfix = if (stringLength nameDependenciesPostfix > 128)
      then "some-deps"
      else nameDependenciesPostfix;
    name = "${getNameWithNodejsVersionFromAttrs attrs}+${namePostfix}";
    nodeEnv = mkNodeEnv {
      name = "tmp-env-for-building-${name}";
      inherit nodejs dependencies devDependencies production dontbuild;
    };
    buildScript = prepareBuildScript + ''
      mkdir -p "$out"
      cd "$out"

      cp -rf "$package/"* .

      mkdir node_modules
      cd node_modules
      rm -rf ${packageNameFileName}
      IFS=':' read -r -a nodePath <<< "$(cat "$nodeEnv/NODE_PATH")"
      for pkg in $nodePath; do
        rsync -a "$pkg/." ./
      done
    '';
  in if (includedDependencies == []) then package else derivation {
    inherit system name;
    inherit package nodeEnv;
    builder = "${bash}/bin/bash";
    buildInputs = [ coreutils rsync ];
    args = [ "-c" buildScript ];
  } // {
    # Add additional attrs that might be useful
    inherit (package) nodejs packageName bins;
    inherit includedDependencies nodeEnv;
  };

  /*
   * Derivation to produce a npm package and a nodeEnv which satisfies the
   * production dependency of that npm package, and also binstubs for
   * that package.
   */
  mkNpmPackageWithRuntime = {
    nodejs,
    dependencies,
    devDependencies,
    ...
  } @ attrs: let
    packageName = getNameWithNodejsVersionFromAttrs attrs;
    name = "${packageName}+runtime";
    package = mkNpmPackage attrs;
    nodeEnvAttrs = {
      inherit nodejs dependencies devDependencies;
    };
    nodeEnv = mkNodeEnv (nodeEnvAttrs // {
      name = "${packageName}-node-env";
    });
    nodeDevEnv = mkNodeEnv (nodeEnvAttrs // {
      name = "${packageName}-node-dev-env";
      production = false;
    });
    buildScript = prepareBuildScript + ''
      mkdir -p "$out"
      cd "$out"

      # Link all files from the package
      for path in "$package/"*; do
        ln -sf "$path" .
      done

      # Link bins from the package
      ln -sf "$package/.bin" .

      # Generate binstubs
      if [[ -d .bin ]]; then
        mkdir bin
        for binFile in .bin/*; do
          binName="$(basename $binFile)"
          echo "#!${bash}/bin/bash" >> "bin/$binName"
          echo "source '${nodeEnv}/env.sh'" >> "bin/$binName"
          echo "\"\$(\"${coreutils}/bin/dirname\" \$(\"${coreutils}/bin/realpath\" \"\$0\"))/../.bin/$binName\" \"\$@\"" >> "bin/$binName"
          chmod +x "bin/$binName"
        done
      fi
      cd -
    '';
  in derivation {
    inherit system name;
    inherit package;
    builder = "${bash}/bin/bash";
    buildInputs = [ bash coreutils ];
    args = [ "-c" buildScript ];
  } // {
    # Add additional attrs that might be useful
    inherit package;
    inherit (package) nodejs packageName bins;
    inherit nodeEnv;
    inherit (nodeEnv) nodePath path;
    shell = stdenv.mkDerivation {
      name = "${name}-shell";
      phases = [ ];
      inherit nodeDevEnv;
      shellHook = ''
        source $nodeDevEnv/env.sh
      '';
    };
  };

  /*
   * Derivation to produce a node envirement which has PATH and NODE_PATH
   * prepared.
   */
  mkNodeEnv = {
    # Node.js
    nodejs,

    # Options
    production ? true,
    dontbuild ? false,

    # Env Info
    name,

    # Dependencies
    dependencies ? [],
    devDependencies ? [],
    ...
  }: let
    includedDependencies = if production then dependencies else dependencies ++ devDependencies;
    mkPkgAdditionalAttrs = {
      inherit nodejs production dontbuild;
      # TODO: Add devBuildEnv to support pacakgeing npm packages with nix, or
      # say publishing npm packages that can be installd into other npm-nix
      # projects with nix instead of npm?
      buildEnv = mkNodeEnv {
        inherit nodejs production dependencies devDependencies;
        dontbuild = true;
        name = "tmp-build-env-for-${name}";
      };
    };
    deps = map (attrs: mkNpmPackageWithDeps (attrs // mkPkgAdditionalAttrs)) includedDependencies;

    nodePath = join ":" deps;
    depsThatHaveBins = filter (d: (d.bins or []) != []) deps;
    path = join ":" ([ "${bash}/bin" "${nodejs}/bin" ] ++ (map (d: "${d}/.bin") depsThatHaveBins));
    buildScript = prepareBuildScript + ''
      mkdir -p "$out"

      echo "$nodePath" > "$out/NODE_PATH"
      echo "$path" > "$out/PATH"

      echo "export PATH=$path\''${PATH:+:}\$PATH" >> "$out/env.sh"
      echo "export NODE_PATH=$nodePath" >> "$out/env.sh"
    '' + optionalString dontbuild ''
      echo "true" > "$out/${notBuiltIndicationFileName}"
    '';
  in derivation {
    inherit system name;
    inherit deps nodePath path;
    builder = "${bash}/bin/bash";
    buildInputs = [ coreutils ];
    args = [ "-c" buildScript ];
  } // {
    # Add additional attrs that might be useful
    inherit nodejs;
    inherit nodePath path;
    inherit dependencies devDependencies includedDependencies;
    inherit production dontbuild;
  };
}
