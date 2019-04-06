{ stdenv, nginx, nginx-mod-passenger }:

(nginx.override {
   modules = [ nginx-mod-passenger ];
}).overrideAttrs (oldAttrs: {
  meta = oldAttrs.meta // {
    broken = stdenv.isDarwin;
  };
}) // { passenger = nginx-mod-passenger.passenger; }
