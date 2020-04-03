{ stdenv, nginx, passenger }:

let
  nginx-mod-passenger = import ./nginx-mod-passenger.nix { inherit nginx passenger; };
in (nginx.override {
   modules = [ nginx-mod-passenger ];
}).overrideAttrs (oldAttrs: {
  meta = oldAttrs.meta // {
    broken = stdenv.isDarwin;
  };
  patches = (oldAttrs.patches or [ ]) ++ [
    (builtins.toFile "patch" ''
      --- ./src/core/ngx_conf_file.c
      +++ ./src/core/ngx_conf_file.c
      @@ -8,7 +8,7 @@
       #include <ngx_config.h>
       #include <ngx_core.h>

      -#define NGX_CONF_BUFFER  4096
      +#define NGX_CONF_BUFFER  131072

       static ngx_int_t ngx_conf_add_dump(ngx_conf_t *cf, ngx_str_t *filename);
       static ngx_int_t ngx_conf_handler(ngx_conf_t *cf, ngx_int_t last);
    '')
  ];
}) // { passenger = nginx-mod-passenger.passenger; }
