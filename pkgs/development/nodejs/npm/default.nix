{
  lib,
  system,
  fetchurl,
  fetchgit,
  stdenv,
  bash,
  coreutils,
  gnutar,
  gzip,
  bzip2,
  rsync,
  npm-package-to-nix,
  ...
}:

let
  inherit (builtins) map filter toString stringLength isAttrs attrNames;
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

      # Unpack and move the source to "$out/$packageName"
      # If is dir, use rsync to copy files
      if [ -d "$src" ]; then
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
          --filter='dir-merge,- .npmignore' \
          --filter='dir-merge,- .gitignore'
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
        # chmod +x "$binName" # Might not be build now and will chmod: cannot operate on dangling symlink
        cd -
      done

      # Write data
      echo "$packageName" > "$out/${packageNameFileName}"
      if [ -f "$out/$packageName/npm-package.nix" ]; then
        cd "$out"
        ln -sf "$packageName/npm-package.nix" .
        cd -
      fi
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
   * If the source didn't come from npm, it might not be compiled. Here we
   * handle that.
   */
  mkCustomNpmPackageWithoutBuild = {
    # Node.js
    nodejs,

    # Package Info
    name,
    packageName,
    version,
    src,
    bin ? null,
    buildNeeded ? false,
    ...
  } @ attrs: let
    packageSrc = mkNpmPackageWithoutBuild attrs;
    tryImportPackageInfo = builtins.tryEval (import "${packageSrc}/npm-package.nix");
    hasNpmPackageNix = tryImportPackageInfo.success;
    npmPackageNix = tryImportPackageInfo.value { inherit fetchurl fetchgit; };
    buildEnv = mkNodeEnv (npmPackageNix // {
      inherit nodejs;
      name = "tmp-env-for-building-${name}";
      production = false;
    });
    buildScript = prepareBuildScript + ''
      # Get Source
      cp -r "${packageSrc}" "$TMPDIR/build"
      chmod -R +w "$TMPDIR/build"
      echo true > "$TMPDIR/build/.pbnix" # Make a mark

      # Prepare Build Environment
      source "${buildEnv}/env.sh"
      export pathToPackage="$(cat "$TMPDIR/build/${packageNameFileName}")"

      # Build
      cd "$TMPDIR/build/$pathToPackage"
      npm run build --if-present --no-update-notifier

      # Copy Files
      mkdir -p "$out/$packageName"
      [ -d "$TMPDIR/build/.bin" ] && cp -rf "$TMPDIR/build/.bin" "$out/"
      cp -rf "$TMPDIR/build/${packageNameFileName}" "$out/"
      # TODO: Support exclude rules in package.json
      rsync -a "$TMPDIR/build/$pathToPackage/." "$out/$pathToPackage/" \
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
    '';
  in if (!hasNpmPackageNix) then packageSrc else derivation {
    name = packageSrc.name;
    inherit system;
    builder = "${bash}/bin/bash";
    buildInputs = [
      bash
      coreutils
      rsync
    ];
    args = [ "-c" buildScript ];
  } // {
    # Add additional attrs that might be useful
    inherit nodejs;
    inherit (packageSrc) packageName bins;
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

    srcMaybeNotFromNpm ? false,

    # Environment Required For Building
    buildEnv ? null,
    ...
  } @ attrs: let
    name = getNameWithNodejsVersionFromAttrs attrs;
    mkPkgWithoutBuild = if srcMaybeNotFromNpm then mkCustomNpmPackageWithoutBuild else mkNpmPackageWithoutBuild;
    packageWithoutBuild = mkPkgWithoutBuild attrs;
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
      # TODO: Do we need to run "prepare" here? Where?
      # npm run prepare --if-present --no-update-notifier
      npm run preinstall --if-present --no-update-notifier
      # this is not "npm install"
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

    srcMaybeNotFromNpm ? false,

    # Dependencies
    dependencies ? [],
    devDependencies ? [],
    ...
  } @ attrs: let
    mkPkgWithoutBuild = if srcMaybeNotFromNpm then mkCustomNpmPackageWithoutBuild else mkNpmPackageWithoutBuild;
    mkPkg = if dontbuild then mkPkgWithoutBuild else mkNpmPackage;
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
      cp -rf "$package" "$out"
      cd "$out"
      chmod +w .
      mkdir node_modules
      cd node_modules
      IFS=':' read -r -a nodePath <<< "$(cat "$nodeEnv/NODE_PATH")"
      for pkg in $nodePath; do
        rsync -a "$pkg/." ./ \
          --exclude=/${packageNameFileName}
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

    env ? {},
    devEnv ? {},

    runtimeInputs ? [],
    ...
  } @ attrs: let
    packageName = getNameWithNodejsVersionFromAttrs attrs;
    name = "${packageName}+runtime";
    package = mkNpmPackage attrs;
    nodeEnvAttrs = {
      inherit nodejs dependencies devDependencies runtimeInputs;
    };
    nodeEnv = mkNodeEnv (nodeEnvAttrs // {
      name = "${packageName}-node-env";
      env = env;
    });
    nodeDevEnv = mkNodeEnv (nodeEnvAttrs // {
      name = "${packageName}-node-dev-env";
      production = false;
      env = devEnv;
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
    inherit nodeEnv nodeDevEnv env devEnv;
    inherit (nodeEnv) nodePath path;
    shell = stdenv.mkDerivation { # I don't know how to shellHook without
      name = "${name}-shell";     # stdenv.mkDerivation, so it's used here.
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
    env ? {},

    # Env Info
    name,

    # Dependencies
    dependencies ? [],
    devDependencies ? [],

    # System Dependencies
    runtimeInputs ? [],
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

    nodePathExpanded = join ":" deps;
    depsThatHaveBins = filter (d: (d.bins or []) != []) deps;
    path = join ":" (
      [ "${bash}/bin" "${coreutils}/bin" "${nodejs}/bin" ] ++
      (map (d: "${d}/bin") runtimeInputs) ++
      (map (d: "${d}/.bin") depsThatHaveBins)
    );
    envVarsList = map ({ n, v }: "${n}=${toString v}") (filter ({ v, ... }: v != null) (mapAttrsToList (n: v: { inherit n v; }) env));
    envVars = join "\n" envVarsList;
    envVarsExport = join "\n" (map (v: "export ${v}") envVarsList);
    buildScript = prepareBuildScript + ''
      mkdir -p "$out"

      mkdir -p "$out/modules"
      for d in $deps; do
        packageName="$(cat "$d/${packageNameFileName}")"
        source="$d/$packageName"
        target="$out/modules/$packageName"
        mkdir -p "$(dirname "$target")"
        ln -s "$source" "$target"
      done

      echo "$path" > "$out/PATH"
      echo "$nodePathExpanded" > "$out/NODE_PATH"
      echo "$envVars" > "$out/ENV"

      echo "export PATH=$path\''${PATH:+:}\$PATH" >> "$out/env.sh"
      echo "export NODE_PATH='$out/modules'" >> "$out/env.sh"
      echo "$envVarsExport" >> "$out/env.sh"
    '' + optionalString dontbuild ''
      echo "true" > "$out/${notBuiltIndicationFileName}"
    '';
    drv = derivation {
      inherit system name;
      inherit deps path nodePathExpanded envVars envVarsExport;
      builder = "${bash}/bin/bash";
      buildInputs = [ coreutils ];
      args = [ "-c" buildScript ];
    };
  in drv // {
    # Add additional attrs that might be useful
    inherit nodejs;
    inherit path env;
    nodePath = "${drv.outPath}/modules";
    inherit dependencies devDependencies includedDependencies;
    inherit production dontbuild;
  };
}
