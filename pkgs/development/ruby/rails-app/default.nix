{
  lib,
  writeText,
  stdenv,
  coreutils,
  gnused,
  rsync,
  ruby,
  bundlerEnv,
  bundler,
  bundix,
  ...
} @ defs:

{
  src,
  gemfile,
  lockfile,
  gemset,
  name ? "rails-app",
  railsEnv ? null,
  gemGroups ? if railsEnv == "production" then
    [ "default" "production" ]
  else
    [ "default" "production" "development" "test" ],
  bundleWithout ? if railsEnv == "production" then
    "development:test"
  else
    "",
  masterKey ? null,
  developmentSecret ? null,
  actionCableConfig ? null,
  packagePriority ? 100,
  ruby ? defs.ruby,
  stdenv ? defs.stdenv,
  coreutils ? defs.coreutils,
  gnused ? defs.gnused,
  rsync ? defs.rsync,
  bundlerEnv ? defs.bundlerEnv,
  bundler ? defs.bundler,
  bundix ? defs.bundix,
  ...
}:

let
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
  actionCableConfigFile = if actionCableConfig != null then
    writeText "cable.yml" (toYaml {
      development = actionCableConfig;
      test = actionCableConfig;
      production = actionCableConfig;
    })
  else null;
in stdenv.mkDerivation {
  inherit name src;
  meta = {
    priority = packagePriority;
  };
  buildInputs = [
    coreutils
    gnused
    rsync
    ruby
    bundler
    bundix
    bundleEnv
  ];
  shellHook = ''
    export BUNDLE_GEMFILE=${bundleGemfile}
    export BUNDLE_PATH=${bundlePath}
    export BUNDLE_WITHOUT=${bundleWithout}
    PATH=${builtins.toString ./bin}:$PATH
  '';
  unpackPhase = ''
    # Copy the source code
    rsync -a "$src/." "$TMPDIR/" \
      --exclude='/.git' \
      --exclude='/.envrc' \
      --exclude='/.ruby-version' \
      --exclude='/.tool-versions' \
      --filter='dir-merge,- .gitignore'
    # Add read permission to the unpacked source, which is read-only by default
    chmod -R +w $TMPDIR
  '';
  postPatch = ''
    patchShebangs .
  '';
  configurePhase = ''
    # Write bundle config
    mkdir -p .bundle
    cp -f ${bundleConfig} .bundle/config
    # Let Bootsnap place it's cache dir under /tmp rather then [app-dir]/tmp which
    # will not be writeable
    echo "require 'etc'; ENV['BOOTSNAP_CACHE_DIR'] = \"/tmp/rails-bootsnap-cache-#{Etc.getlogin}-$(basename $out)\"" | cat - config/boot.rb > temp && mv temp config/boot.rb
    '' + optionalString (railsEnv != null) ''
        awk -i inplace "NR==1 {print \"ENV['RAILS_ENV'] = '${railsEnv}'\"} NR!=0" "config.ru"
      cd bin
      for file in *; do
        awk -i inplace "NR==1 {print; print \"ENV['RAILS_ENV'] = '${railsEnv}'\"} NR!=1" "$file"
      done
      cd -
    '' + optionalString (developmentSecret != null) ''
      printf ${developmentSecret} > tmp/development_secret.txt
    '' + optionalString (masterKey != null) ''
      printf ${masterKey} > config/master.key
    '' + optionalString (actionCableConfigFile != null) ''
      cp -f ${actionCableConfigFile} config/cable.yml
    '';
  buildPhase = ''
    # Compile static assets
    BUNDLE_GEMFILE=${bundleGemfile} BUNDLE_PATH=${bundlePath} BUNDLE_WITHOUT=${bundleWithout} RAILS_ENV=production bin/rails assets:precompile
  '';
  installPhase = ''
    # Copy all the stuff to the out directory
    mkdir -p $out
    rsync -a "." "$out/" \
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
    # Explicity set RubyGems and Bundler config in every binstub and Ruby scripts
    cd $out/bin
    for file in *; do
      awk -i inplace "NR==1 {\
        print; \
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
} // { inherit ruby gemHome bundleGemfile bundlePath bundleWithout; }
