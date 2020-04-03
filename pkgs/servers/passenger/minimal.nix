{
  lib,
  system,
  stdenv,
  fetchurl,
  ruby,
  bundler,
  rake,
  gcc,
  curl,
  openssl,
  zlib,
  pcre,
  coreutils,
  findutils,
  bash,
  lsof,
  procps,
  beep,
  gnumake,
  version ? "6.0.4",
  optimizations ? true,
  sha256s ? import ./sha256s.nix,
}:

let
  srcUrl = "https://github.com/phusion/passenger/releases/download/release-${version}/passenger-${version}.tar.gz";

  getPrefetchedFilesJson = import ./getPrefetchedFilesJson.nix { inherit lib fetchurl; };
  getLocationsIni = import ./getLocationsIni.nix;

  prefetchedFilesJson = getPrefetchedFilesJson {
    inherit sha256s;
    urls = [
      "https://github.com/phusion/passenger/releases/download/release-${version}/agent-${system}.tar.gz"
    ];
  };

  compileTimeLocationsIni = getLocationsIni "$TMPDIR/$sourceRoot";
  outputLocationsIni = getLocationsIni "$out";

in stdenv.mkDerivation rec {
  name = "passenger-${version}-minimal";
  src = fetchurl {
    url = srcUrl;
    sha256 = sha256s.${srcUrl};
  };

  buildInputs = [
    # Seems that Passenger dependencies are listed in:
    # https://github.com/phusion/passenger/blob/stable-6.0/src/ruby_supportlib/phusion_passenger/config/agent_compiler.rb#L41
    ruby
    bundler
    rake
    curl
    gcc
    openssl
    zlib
    pcre
  ];

  PASSENGER_ALLOW_WRITE_TO_BUILD_SYSTEM_DIR = true;
  PASSENGER_AGENT_OPTIMIZE = if optimizations then "true" else "false";
  PASSENGER_USE_PREFETCHED_FILES = true;
  PREFETCHED_FILES_JSON = prefetchedFilesJson;

  patches = [
    ./patches/simulate-process-euid-zero.patch
    ./patches/enable-optimizations.patch
    ./patches/use-prefetched-files-for-downloads.patch
    ./patches/install-agent.patch
    ./patches/install-standalone-runtime.patch
    ./patches/dont-check-download-tool.patch
    ./patches/dont-write-to-build-system-dir.patch
  ];
  commandStringsInSourceCodePatch = import ./patches/commandStringsInSourceCodePatch.nix {
    inherit coreutils findutils bash lsof procps gnumake curl;
    beep = if stdenv.isDarwin then "" else beep;
  };
  postPatch = ''
    echo "$commandStringsInSourceCodePatch" | patch -p0
  '';

  configurePhase = ''
    echo "${compileTimeLocationsIni}" > src/ruby_supportlib/phusion_passenger/locations.ini
  '';
  buildPhase = ''
    echo 'Building native support for default environment...'
    bin/passenger-config build-native-support
  '' + ''
    echo 'Building Passenger agent...'
    bin/passenger-config install-agent
  '';
  installPhase = ''
    cp -r . $out
  '';
  preFixup = ''
    echo "${outputLocationsIni}" > "$out/src/ruby_supportlib/phusion_passenger/locations.ini"
  '';

  meta = with lib; {
    description = "A fast and robust web application server for Ruby, Python and Node.js that runs and automanages your apps with ease";
    homepage    = https://www.phusionpassenger.com/;
    license     = licenses.mit;
    platforms   = platforms.all;
    broken      = stdenv.isDarwin;
  };
}
