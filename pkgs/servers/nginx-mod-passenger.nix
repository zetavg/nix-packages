{ passenger, ruby, rake }:

let
  psg = passenger.override { buildNginxSupportFiles = true; };
in {
  src = "${psg}/src/nginx_module";
  inputs = [ psg ruby rake ];
  passenger = psg;
}
