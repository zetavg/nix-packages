{
  lib,
  stdenvNoCC,
  fetchurl,
  bash,
  adoptopenjdk-hotspot-bin-11,
  filebeat7,
  version ? "7.6.2",
  sha256s ? import ./sha256s.nix,
}:

let
  srcUrl = "https://artifacts.elastic.co/downloads/app-search/app-search-${version}.tar.gz";
  src = fetchurl {
    url = srcUrl;
    sha256 = sha256s."${srcUrl}";
  };
in stdenvNoCC.mkDerivation {
  name = "elastic-app-search";
  inherit src;

  phases = [
    # "$prePhases"
    "unpackPhase"
    "patchPhase"
    # "$preConfigurePhases"
    # "configurePhase"
    # "$preBuildPhases"
    # "buildPhase"
    # "checkPhase"
    # "$preInstallPhases"
    "installPhase"
    "fixupPhase"
    # "installCheckPhase"
    # "$preDistPhases"
    # "distPhase"
    # "$postPhases"
  ];

  patches = [];
  pathsPatch = import ./patches/pathsPatch.nix {
    inherit bash filebeat7 adoptopenjdk-hotspot-bin-11;
  };
  postPatch = ''
    echo "$pathsPatch" | patch -p0
  '';

  installPhase = ''
    cp -r . $out
  '';

  meta = with lib; {
    homepage    = https://www.elastic.co/app-search/;
    platforms   = platforms.x86_64;
  };
}
