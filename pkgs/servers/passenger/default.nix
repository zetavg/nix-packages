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
  buildStandalone ? true,
  preferredNginxVersion ? "1.17.3",
  buildNginxSupportFiles ? false,
  buildApache2Module ? false,
  sha256s ? import ./sha256s.nix,
}:

let
  # We'll start upon passenger-minimal, since it'll be a waste of time to
  # rebuild those fundamental stuff over and over again
  passenger-minimal = import ./minimal.nix {
    # TODO: Better way of doing this?
    inherit lib system stdenv fetchurl ruby bundler rake gcc curl openssl zlib pcre coreutils findutils bash lsof procps beep gnumake version optimizations sha256s;
  };

  getPrefetchedFilesJson = import ./getPrefetchedFilesJson.nix { inherit lib fetchurl; };
  getLocationsIni = import ./getLocationsIni.nix;

  prefetchedFilesJson = getPrefetchedFilesJson {
    inherit sha256s;
    urls = [];
  };

  compileTimeLocationsIni = getLocationsIni "$TMPDIR/$sourceRoot";
  outputLocationsIni = getLocationsIni "$out";

  nginxDownloadUrl = "https://nginx.org/download/nginx-${preferredNginxVersion}.tar.gz";
  nginxDownloadSha256 = sha256s.${nginxDownloadUrl};
  nginx = fetchurl { url = nginxDownloadUrl; sha256 = nginxDownloadSha256; };

  drv = stdenv.mkDerivation rec {
    name = "passenger-${version}";
    passthru = {
      # TODO: Add more of these?
      inherit optimizations ruby rake;
    };

    src = passenger-minimal;
    buildInputs = [
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
    PASSENGER_USE_PREFETCHED_FILES = true;
    PREFETCHED_FILES_JSON = prefetchedFilesJson;

    configurePhase = ''
      echo "${compileTimeLocationsIni}" > src/ruby_supportlib/phusion_passenger/locations.ini
    '';

    buildPhase = ''
    '' + lib.optionalString buildStandalone ''
      echo 'Building Passenger standalone runtime...'
      bin/passenger-config install-standalone-runtime --nginx-version ${preferredNginxVersion} --nginx-tarball ${nginx}
    '' + lib.optionalString buildNginxSupportFiles ''
      echo 'Building Nginx support files...'
      rake nginx
    '' + lib.optionalString buildApache2Module ''
      echo 'Building Apache 2 module...'
      rake apache2
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
  };
in drv // {
  nodejs_supportlib = "${drv.outPath}/src/nodejs_supportlib";
}
