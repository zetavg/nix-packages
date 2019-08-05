# Copied from https://github.com/betaboon/nixpkgs/blob/elastic-apm-server/pkgs/servers/misc/elastic-apm-server/default.nix

{ elk7Version ? "7.0.1"
, enableUnfree ? true
, stdenv
, fetchurl
, makeWrapper
, autoPatchelfHook
}:

with stdenv.lib;
let

  inherit (builtins) elemAt;
  info = splitString "-" stdenv.hostPlatform.system;
  arch = elemAt info 0;
  plat = elemAt info 1;
  # For "7.0.1"
  shas =
    if enableUnfree
    then {
      "x86-linux" = "17hfbnb1sh3g9823nxwa2ilwvfp7illhkw35crcalpzvlj7binm7";
      "x86_64-linux" = "0a7pjh10ayyy4il2f69zcacfa7dqybsz24v4lfcqlbwlb5yqsd8r";
      "x86_64-darwin" = "1a4qv6754g3k9z7pa89lg2lmdwiwrp0iyh7krgdsj5g4ni0b1w7l";
    }
    else {
      "x86-linux" = "19n96xgg5f9gdllgrrgvc40j4qy1vx2s9kvvaaq2n74l3bmifrm3";
      "x86_64-linux" = "045qg6639arb4isvxz3pkv3mnl37zgkwvzrvggfqwqi93giffz1k";
      "x86_64-darwin" = "1dnk3616706rkn6rwf9nha1kjwgagyv5w6zp4mqwc0j6gzbv9nrg";
    };

in stdenv.mkDerivation (rec {
  name = "apm-server-${optionalString (!enableUnfree) "oss-"}${version}";
  version = elk7Version;

  src = fetchurl {
    url = "https://artifacts.elastic.co/downloads/apm-server/${name}-${plat}-${arch}.tar.gz";
    sha256 = shas."${stdenv.hostPlatform.system}" or (throw "Unknown architecture");
  };

  buildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/{bin,share}
    cp apm-server $out/bin
    cp -r apm-server.yml fields.yml kibana $out/share
  '';

  passthru = { inherit enableUnfree; };

  meta = {
    description = "Open Source Application Performance Monitoring";
    license = if enableUnfree then licenses.elastic else licenses.asl20;
    platforms = platforms.unix;
  };
} // optionalAttrs enableUnfree {
  dontPatchELF = true;
  nativeBuildInputs = [ autoPatchelfHook ];
  postFixup = ''
    for exe in $(find $out/bin -executable -type f); do
      echo "patching $exe..."
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$exe"
    done
  '';
})
