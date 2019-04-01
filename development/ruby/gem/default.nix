# Override buildRubyGem to share one copy of gem source across different
# varients of the same gem just collocated with different dependencies

{
  nixpkgs,
  lib,
  fetchurl,
  fetchgit,
  makeWrapper,
  git,
  darwin,
  ruby,
  bundler
} @ defs:

lib.makeOverridable (

  {
    gemName,
    version ? null,
    type ? "gem",
    ruby ? defs.ruby,
    stdenv ? ruby.stdenv,
    namePrefix ? (let
      rubyName = builtins.parseDrvName ruby.name;
    in "${rubyName.name}${rubyName.version}-"),
    meta ? {},
    gemPath ? [],
    propagatedBuildInputs ? [],
    propagatedUserEnvPkgs ? [],
    passthru ? {},
    ...
  } @ attrs:

  let
    buildRubyGem = import ./gem.nix defs;
  in if type == "gem" then
    # Build the gem with no dependency info (dontDoPostBuild, fixupPhase = null),
    # and wrap it in a wrapper that contains the dependency info
    let
      name = attrs.name or "${namePrefix}${gemName}-${version}";
      gem = buildRubyGem (attrs // {
        name = "${name}-gem";
        dontDoPostBuild = true;
        fixupPhase = ":";
        gemPath = [];
        propagatedBuildInputs = [];
        propagatedUserEnvPkgs = [];
      });
    in stdenv.mkDerivation ((builtins.removeAttrs attrs ["source"]) // {
      inherit name meta;
      buildInputs = [ ruby ];
      propagatedBuildInputs = gemPath ++ propagatedBuildInputs;
      propagatedUserEnvPkgs = gemPath ++ propagatedUserEnvPkgs;
      passthru = passthru // { isRubyGem = true; };
      phases = [ "installPhase" "fixupPhase" ];
      installPhase = ''
        mkdir -p $out
        ln -s ${gem}/* $out/
        export GEM_HOME=$out/${ruby.gemPath}
        spec=$(echo $out/${ruby.gemPath}/specifications/*.gemspec)
        ruby ${./gem-post-build.rb} "$spec"
      '';
    })
  else
    # Use the original buildRubyGem to build the gem
    buildRubyGem attrs

)
