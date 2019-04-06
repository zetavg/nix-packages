# Override nixpkgs.buildRubyGem to support the attribute "dontDoPostBuild"
# for building outputs having no information about it's dependencies

{
  lib,
  buildRubyGem,
  ...
} @ defs:

lib.makeOverridable (
  {
    ruby ? defs.ruby,
    type ? "gem",
    gemName,
    version ? null,
    buildFlags ? [],
    document ? [], # e.g. [ "ri" "rdoc" ]
    dontDoPostBuild ? false,
    dontInstallManpages ? false,
    ...
  } @ attrs:
  (buildRubyGem attrs).overrideAttrs (oldAttrs: let
    inherit (oldAttrs) src;
    documentFlag =
      if document == []
      then "-N"
      else "--document ${lib.concatStringsSep "," document}";
  in {
    installPhase = attrs.installPhase or ''
      runHook preInstall

      export GEM_HOME=$out/${ruby.gemPath}
      mkdir -p $GEM_HOME
      echo "buildFlags: $buildFlags"

      ${lib.optionalString (type ==  "url") ''
      ruby ${./nix-bundle-install.rb} \
        "path" \
        '${gemName}' \
        '${version}' \
        '${lib.escapeShellArgs buildFlags}'
      ''}
      ${lib.optionalString (type == "git") ''
      ruby ${./nix-bundle-install.rb} \
        "git" \
        '${gemName}' \
        '${version}' \
        '${lib.escapeShellArgs buildFlags}' \
        '${attrs.source.url}' \
        '${src}' \
        '${attrs.source.rev}'
      ''}

      ${lib.optionalString (type == "gem") ''
      if [[ -z "$gempkg" ]]; then
        echo "failure: \$gempkg path unspecified" 1>&2
        exit 1
      elif [[ ! -f "$gempkg" ]]; then
        echo "failure: \$gempkg path invalid" 1>&2
        exit 1
      fi
      gem install \
        --local \
        --force \
        --http-proxy 'http://nodtd.invalid' \
        --ignore-dependencies \
        --install-dir "$GEM_HOME" \
        --build-root '/' \
        --backtrace \
        --no-env-shebang \
        ${documentFlag} \
        $gempkg $gemFlags -- $buildFlags
      # looks like useless files which break build repeatability and consume space
      rm -fv $out/${ruby.gemPath}/doc/*/*/created.rid || true
      rm -fv $out/${ruby.gemPath}/gems/*/ext/*/mkmf.log || true

      ${lib.optionalString (!dontDoPostBuild) ''
      # write out metadata and binstubs
      spec=$(echo $out/${ruby.gemPath}/specifications/*.gemspec)
      ruby ${./gem-post-build.rb} "$spec"
      ''}
      ''}

      ${lib.optionalString (!dontInstallManpages) ''
      for section in {1..9}; do
        mandir="$out/share/man/man$section"
        find $out/lib \( -wholename "*/man/*.$section" -o -wholename "*/man/man$section/*.$section" \) \
          -execdir mkdir -p $mandir \; -execdir cp '{}' $mandir \;
      done
      ''}

      runHook postInstall
    '';
  })
)
