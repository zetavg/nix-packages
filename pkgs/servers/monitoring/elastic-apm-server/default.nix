# Originally copied from https://github.com/betaboon/nixpkgs/blob/elastic-apm-server/pkgs/servers/misc/elastic-apm-server/default.nix

{ elk7VersionForElasticAPM ? "7.4.0"
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
  shas = {
    "7.0.1" = {
      "oss" = {
        "x86-linux" = "19n96xgg5f9gdllgrrgvc40j4qy1vx2s9kvvaaq2n74l3bmifrm3";
        "x86_64-linux" = "045qg6639arb4isvxz3pkv3mnl37zgkwvzrvggfqwqi93giffz1k";
        "x86_64-darwin" = "1dnk3616706rkn6rwf9nha1kjwgagyv5w6zp4mqwc0j6gzbv9nrg";
      };
      "unfree" = {
        "x86-linux" = "17hfbnb1sh3g9823nxwa2ilwvfp7illhkw35crcalpzvlj7binm7";
        "x86_64-linux" = "0a7pjh10ayyy4il2f69zcacfa7dqybsz24v4lfcqlbwlb5yqsd8r";
        "x86_64-darwin" = "1a4qv6754g3k9z7pa89lg2lmdwiwrp0iyh7krgdsj5g4ni0b1w7l";
      };
    };
    "7.4.0" = {
      "oss" = {
        "x86-linux" = "1pm0q0xlxx8knm60x4z3mqfr8n16j4bgq9v3yrb2dnfnzsb2nkg9";
        "x86_64-linux" = "183908m4lgpwnlqygc3jjrbvca2r9cbz1967xv33a3r753b419qs";
        "x86_64-darwin" = "0gskdcx9qq2ai8s8iv8mw6d668nw269lx3wzndh867nx7rdll7x2";
      };
      "unfree" = {
        "x86-linux" = "0zshbrjdiha25q5ys2h5k9w2swmdwmmf7ck4n3318w6zkzrva053";
        "x86_64-linux" = "14hq0nch2s5x6ikjkcgr8151x9zpbjma33i6vz3fr3m49vbvzw8p";
        "x86_64-darwin" = "1xzqkqxcmdmc1q2qbfnkpn3kb96mfmbg75fhixdw2l4qmckbgj9z";
      };
    };
  };

in stdenv.mkDerivation (rec {
  name = "apm-server-${optionalString (!enableUnfree) "oss-"}${version}";
  version = elk7VersionForElasticAPM;

  src = fetchurl {
    url = "https://artifacts.elastic.co/downloads/apm-server/${name}-${plat}-${arch}.tar.gz";
    sha256 = shas."${elk7VersionForElasticAPM}"."${if enableUnfree then "unfree" else "oss"}"."${stdenv.hostPlatform.system}" or (throw "Unknown version or architecture");
  };

  buildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/{bin,share}
    cp apm-server $out/bin
    cp -r apm-server.yml fields.yml kibana $out/share
    cp -r ingest $out/share 2>/dev/null || :
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
