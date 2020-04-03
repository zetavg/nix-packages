{
  lib,
  writeText,
  stdenvNoCC,
  coreutils,
  gnused,
  rsync,
  bundlerEnv,
  bundler,
  bundix
}:

{
  ruby,

  name,
  src ? "",
  srcs ? [ ],

  gemfile,
  lockfile,
  gemset,

  railsEnv ? null,
  productionGemGroups ? [ "default" "production" ],
  developmentGemGroups ? [ "default" "production" "development" "test" ],
  gemGroups ?
    if railsEnv == "production" then productionGemGroups
    else developmentGemGroups
  ,
  bundleWithout ?
    if railsEnv == "production" then with lib; concatStringsSep ":" (subtractLists productionGemGroups developmentGemGroups)
    else ""
  ,

  masterKey ? null,
  developmentSecret ? null,
  databaseConfig ? null,
  actionCableConfig ? null,
  dotEnv ? null,
  applicationConfig ? null,
  pidFile ? null,

  packagePriority ? 100,

  extraNginxPassengerConfig ? null,

  ...
}:

let
  inherit (builtins) toString isString isFunction;
  inherit (lib) optionalString toYaml;

  bundleEnv = bundlerEnv {
    name = "${name}-bundler-env";
    inherit ruby gemfile lockfile gemset;
    groups = gemGroups;
  };
  gemHome = "${bundleEnv.outPath}/${bundleEnv.ruby.gemPath}";
  bundleGemfile = "${bundleEnv.confFiles.outPath}/Gemfile";
  bundlePath = gemHome;
  bundleConfig = writeText "config" ''
    ---
    BUNDLE_GEMFILE: "${bundleGemfile}"
    BUNDLE_PATH: "${bundlePath}"
    BUNDLE_WITHOUT: "${bundleWithout}"
  '';

  databaseConfigFile = if databaseConfig != null then
    writeText "database.yml" (toYaml {
      development = databaseConfig;
      test = databaseConfig;
      production = databaseConfig;
    })
  else null;
  actionCableConfigFile = if actionCableConfig != null then
    writeText "cable.yml" (toYaml {
      development = actionCableConfig;
      test = actionCableConfig;
      production = actionCableConfig;
    })
  else null;
  applicationConfigFile = if applicationConfig != null then
    writeText "application.yml" (toYaml {
      development = applicationConfig;
      test = applicationConfig;
      production = applicationConfig;
    })
  else null;
  dotEnvFile = if dotEnv != null then
    writeText "dot-env" dotEnv
  else null;

  getShellHook =
  # TODO: Paths?
    { bundleGemfile, bundlePath, bundleWithout }:
    ''
      export BUNDLE_GEMFILE=${bundleGemfile}
      export BUNDLE_PATH=${bundlePath}
      export BUNDLE_WITHOUT=${bundleWithout}
      export PATH=${toString ./bin}''${PATH:+:}$PATH
    '';

  passthru = {
    inherit ruby gemHome bundleGemfile bundlePath bundleWithout;
    publicRoot = "${drv.outPath}/public";
    nginxPassengerConfig = ''
      passenger_enabled on;
      passenger_sticky_sessions on;
      passenger_ruby ${ruby}/bin/ruby;
      passenger_env_var GEM_HOME ${gemHome};
      passenger_env_var BUNDLE_GEMFILE ${bundleGemfile};
      passenger_env_var BUNDLE_PATH ${bundlePath};
      passenger_env_var RUBYLIB '${bundleEnv.bundler}/lib/ruby/gems/${bundleEnv.bundler.ruby.version.libDir}/gems/${bundleEnv.bundler.name}/lib';
    '' + (
      if isFunction extraNginxPassengerConfig then extraNginxPassengerConfig { app = drv; }
      else if isString extraNginxPassengerConfig then extraNginxPassengerConfig
      else ""
    );
    devShell = let
      bundleEnv = bundlerEnv {
        name = "${name}-dev-bundler-env";
        inherit ruby gemfile lockfile gemset;
        groups = developmentGemGroups;
      };
      gemHome = "${bundleEnv.outPath}/${bundleEnv.ruby.gemPath}";
      bundleGemfile = "${bundleEnv.confFiles.outPath}/Gemfile";
      bundlePath = gemHome;
      bundleWithout = "";
    in drv.overrideAttrs (oldAttrs: {
      name = "${name}-dev-shell";
      shellHook = getShellHook { inherit bundleGemfile bundlePath bundleWithout; };
      phases = [ "nobuildPhase" ];
      nobuildPhase = "echo 'This derivation is not meant to be built. Producing an empty result.'; touch $out";
    });
  };

  drv = stdenvNoCC.mkDerivation {
    inherit name src srcs;

    buildInputs = [
      ruby
      coreutils
      gnused
      rsync
      bundler
      bundix
      bundleEnv
    ];

    shellHook = getShellHook { inherit bundleGemfile bundlePath bundleWithout; };

    unpackPhase = ''
      rm -rf rails-build
      if [[ ! -z "''${srcs:-}" ]]; then
        mkdir rails-build
        for s in $srcs;do
          cp -r "$s" "rails-build/$(stripHash "$s")"
        done
      elif [[ ! -z "''${src:-}" ]]; then
        mkdir rails-build
        rsync -a "$src/." "rails-build/" \
          --exclude='/.git' \
          --exclude='/.envrc' \
          --exclude='/.ruby-version' \
          --exclude='/.tool-versions' \
          --filter='dir-merge,- .gitignore'
      else
        echo 'variable $src or $srcs should point to the source'
        exit 1
      fi
      chmod -R +w rails-build
      mkdir -p rails-build/tmp
      mkdir -p rails-build/log
    '';
    postPatch = ''
      patchShebangs rails-build
    '';
    configurePhase =
      ''
        # Write bundle config
        mkdir -p rails-build/.bundle
        cp -f ${bundleConfig} rails-build/.bundle/config
        # Let Bootsnap place it's cache dir under /tmp rather then [app-dir]/tmp which
        # will not be writeable
        echo "require 'etc'; ENV['BOOTSNAP_CACHE_DIR'] = \"/tmp/rails-bootsnap-cache-#{Etc.getlogin}-$(basename $out)\"" | cat - rails-build/config/boot.rb > temp && mv temp rails-build/config/boot.rb
      '' + optionalString (railsEnv != null) ''
        awk -i inplace "NR==1 {print \"ENV['RAILS_ENV'] = '${railsEnv}'\"} NR!=0" "rails-build/config.ru"
        cd rails-build/bin
        for file in *; do
          awk -i inplace "NR==1 {print; print \"ENV['RAILS_ENV'] = '${railsEnv}'\"} NR!=1" "$file"
        done
        cd -
      '' + optionalString (developmentSecret != null) ''
        printf ${developmentSecret} > rails-build/tmp/development_secret.txt
      '' + optionalString (masterKey != null) ''
        printf ${masterKey} > rails-build/config/master.key
      '' + optionalString (databaseConfigFile != null) ''
        cp -f ${databaseConfigFile} rails-build/config/database.yml
      '' + optionalString (actionCableConfigFile != null) ''
        cp -f ${actionCableConfigFile} rails-build/config/cable.yml
      '' + optionalString (applicationConfigFile != null) ''
        cp -f ${applicationConfigFile} rails-build/config/application.yml
      '' + optionalString (dotEnvFile != null) ''
        cp -f ${dotEnvFile} rails-build/.env
      '' + optionalString (pidFile != null) ''
        awk -i inplace "NR==1 {print \"ENV['PIDFILE'] = '${pidFile}'\"} NR!=0" "rails-build/config.ru"
        cd rails-build/bin
        for file in *; do
          awk -i inplace "NR==1 {print; print \"ENV['PIDFILE'] = '${pidFile}'\"} NR!=1" "$file"
        done
        cd -
      '';
    buildPhase = ''
      cd rails-build
      # Compile static assets
      BUNDLE_GEMFILE=${bundleGemfile} BUNDLE_PATH=${bundlePath} BUNDLE_WITHOUT=${bundleWithout} RAILS_ENV=production bin/rails assets:precompile
      rm -rf tmp/cache/assets/sprockets
      cd -
    '';
    installPhase = ''
      # Copy all the stuff to the out directory
      mkdir -p $out
      rsync -a "rails-build/." "$out/" \
        --exclude='/env-vars' \
        --exclude='/.sandbox.sb' \
        --exclude='/.gitignore'
      # Pre-create the directories that Rails may attempt to create on every startup
      mkdir -p $out/tmp/cache
      mkdir -p $out/tmp/pids
      mkdir -p $out/tmp/sockets
    '';
    preFixup = ''
      # Explicity set RubyGems and Bundler config in config.ru
      cd $out
        awk -i inplace "NR==1 {\
          print \"ENV['GEM_HOME'] = '${gemHome}'\"; \
          print \"ENV['BUNDLE_GEMFILE'] = '${bundleGemfile}'\"; \
          print \"ENV['BUNDLE_PATH'] = '${bundlePath}'\"; \
          print \"ENV['BUNDLE_WITHOUT'] = '${bundleWithout}'\"; \
          print \"Gem.clear_paths\"\
        } NR!=0" "config.ru"
      cd -
      # Chdir to project root, set ENV['DISABLE_DUMP_SCHEMA_AFTER_MIGRATION'],
      # explicity set RubyGems and Bundler config in every binstub and Ruby scripts
      cd $out/bin
      for file in *; do
        awk -i inplace "NR==1 {\
          print; \
          print \"Dir::chdir('$out')\"; \
          print \"ENV['DISABLE_DUMP_SCHEMA_AFTER_MIGRATION'] = 'true'\"; \
          print \"ENV['GEM_HOME'] = '${gemHome}'\"; \
          print \"ENV['BUNDLE_GEMFILE'] = '${bundleGemfile}'\"; \
          print \"ENV['BUNDLE_PATH'] = '${bundlePath}'\"; \
          print \"ENV['BUNDLE_WITHOUT'] = '${bundleWithout}'\"; \
          print \"Gem.clear_paths\"\
        } NR!=1" "$file"
      done
      cd -
      # Prefix every executable in bin/ so there're not going to conflict with other packages
      cd $out/bin
      binfiles=(*)
      for file in *; do
        for binfile in ''${binfiles[@]}; do
          sed -i "s|bin/update-dependencies|:|g" "$file"
          sed -i "s|bin/$binfile|bin/${name}-$binfile|g" "$file"
        done
        mv "$file" "${name}-$file"
      done
      cd -
    '';

    meta = {
      priority = packagePriority;
    };

    inherit passthru;
  };

in drv
