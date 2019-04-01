{
  stdenv,
  system,
  lib,
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
  version ? "6.0.2",
  nginxVersion ? "1.15.8",
  buildStandalone ? true,
  buildNginxSupportFiles ? false,
  buildApache2Module ? false,
  optimizations ? true,
  sha256s ? {
    "https://github.com/phusion/passenger/releases/download/release-6.0.2/passenger-6.0.2.tar.gz" =
      "1g26hgapb59cg25k6h8bb845k1rvb20y70xsys09ip7628rjgcjn";
    "https://github.com/phusion/passenger/releases/download/release-6.0.2/agent-x86_64-linux.tar.gz" =
      "07ikn83mq4cdgymnqxyq5md58gjqyxhm462ihgqwairm004c3l06";
    "https://github.com/phusion/passenger/releases/download/release-6.0.2/nginx-1.15.8-x86_64-linux.tar.gz" =
      "0i88fp81k4pq1rqpq6hq6qdrrr48cim1xz2qcpchpmr1cy83sjps";
    "https://nginx.org/download/nginx-1.15.8.tar.gz" =
      "11q7njr0khv8hb96bclyw5f75gvm12nw3jjgmq9rifbym2yazgd8";
  }
}:

let
  concat = seperator: lib.foldr (a: b: if b != null then "${a}${seperator}${b}" else "${a}") null;

  srcUrl = "https://github.com/phusion/passenger/releases/download/release-${version}/passenger-${version}.tar.gz";

  urlsToPrefetch = [
    "https://github.com/phusion/passenger/releases/download/release-${version}/agent-${system}.tar.gz"
    "https://github.com/phusion/passenger/releases/download/release-${version}/nginx-${nginxVersion}-${system}.tar.gz"
    "https://nginx.org/download/nginx-${nginxVersion}.tar.gz"
  ];
  validUrlsToPrefetch = lib.intersectLists urlsToPrefetch (builtins.attrNames sha256s);
  prefetchedFiles = map (url: rec {
    inherit url;
    sha256 = sha256s.${url};
    src = fetchurl {
      inherit url sha256;
    };
  }) validUrlsToPrefetch;
  prefetchedFilesJsonContent = concat "," (map ({ url, src, ... }: "\"${url}\":\"${src}\"") prefetchedFiles);
  prefetchedFilesJson = "{${prefetchedFilesJsonContent}}";

  generateLocationsIni = root: ''
    [locations]
    packaging_method=unknown
    bin_dir=${root}/bin
    support_binaries_dir=${root}/buildout/support-binaries
    lib_dir=${root}/buildout
    helper_scripts_dir=${root}/src/helper-scripts
    resources_dir=${root}/resources
    include_dir=${root}/src
    doc_dir=${root}/doc
    ruby_libdir=${root}/src/ruby_supportlib
    node_libdir=${root}/src/nodejs_supportlib
    apache2_module_path=${root}/buildout/apache2/mod_passenger.so
    ruby_extension_source_dir=${root}/src/ruby_native_extension
    nginx_module_source_dir=${root}/src/nginx_module
    download_cache_dir=/tmp/passenger_download_cache_dir
    build_system_dir=${root}
  '';
in stdenv.mkDerivation rec {
  name = "passenger-${version}";
  src = fetchurl {
    url = srcUrl;
    sha256 = sha256s.${srcUrl};
  };
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
  PASSENGER_AGENT_OPTIMIZE = if optimizations then "true" else "false";
  PREFETCHED_FILES_JSON = prefetchedFilesJson;
  patches = [
    ./simulate-process-euid-zero.patch
    ./enable-optimizations.patch
    ./use-prefetched-files-for-downloads.patch
  ];
  commandStringsInSourceCodePatch = import ./commandStringsInSourceCodePatch.nix {
    inherit coreutils findutils bash lsof procps beep;
  };
  binLoadPathPatch = import ./binLoadPathPatch.nix { };
  postPatch = ''
    echo "$commandStringsInSourceCodePatch" | patch -p0
    echo "$binLoadPathPatch" | sed "s|\$out|\"$out\"|g" | patch -p0
    patchShebangs .
  '';
  configurePhase = ''
    echo "${generateLocationsIni "$TMPDIR/$sourceRoot"}" > src/ruby_supportlib/phusion_passenger/locations.ini
  '';
  buildPhase = ''
    echo 'Building native support...'
    bin/passenger-config build-native-support
    echo 'Building Passenger agent...'
    bin/passenger-config install-agent
  '' + lib.optionalString buildStandalone ''
    echo 'Building Passenger standalone runtime...'
    bin/passenger-config install-standalone-runtime
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
    echo "${generateLocationsIni "$out"}" > "$out/src/ruby_supportlib/phusion_passenger/locations.ini"
  '';
}
