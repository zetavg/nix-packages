{ nginx, nginx-mod-passenger }:

nginx.override {
  modules = [ nginx-mod-passenger ];
} // { passenger = nginx-mod-passenger.passenger; }
