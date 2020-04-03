# The Passenger installer likes to download dependencies on the fly,
# since such side effects are not allowed in Nix build environments, we'll
# have to prefetch those dependencies with Nix

{ lib, fetchurl }:
{ urls, sha256s }:

let
  urlsToPrefetch = urls;
  # TODO: Should throw if an URL is not valid
  validUrlsToPrefetch = lib.intersectLists urlsToPrefetch (builtins.attrNames sha256s);
  prefetchedFiles = map (url: rec {
    inherit url;
    sha256 = sha256s.${url};
    src = fetchurl {
      inherit url sha256;
    };
  }) validUrlsToPrefetch;
  concat = seperator: lib.foldr (a: b: if b != null then "${a}${seperator}${b}" else "${a}") "";
  prefetchedFilesJsonContent = concat "," (map ({ url, src, ... }: "\"${url}\":\"${src}\"") prefetchedFiles);
  prefetchedFilesJson = "{${prefetchedFilesJsonContent}}";
in prefetchedFilesJson
