{ nginx, passenger }:

let
  nginx-passenger = passenger.override {
    buildNginxSupportFiles = true;
    buildStandalone = false;
    buildApache2Module = false;
  };
in {
  src = "${nginx-passenger}/src/nginx_module";
  inputs = [ nginx-passenger nginx-passenger.ruby nginx-passenger.rake ];
  passenger = nginx-passenger;
}
