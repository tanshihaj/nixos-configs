{ config, lib, ... }:
{
  networking = {
    firewall = {
      allowedTCPPorts = [
        # FIXME: this ports should be opened only on WAN interface
        5222
        5223
        5269
        5270
        5443
      ];
    };
  };

  services = {
    ejabberd = {
      enable = true;
      configFile = ./ejabberd.yaml;
    };

    nginx = {
      enable = true;
      virtualHosts."zaripov.net" = {
        addSSL = true;
        enableACME = true;
        root = "/var/www/zaripov.net";
        locations."/.well-known/host-meta".extraConfig = ''
          default_type 'application/xrd+xml';
          add_header Access-Control-Allow-Origin '*' always;
        '';
        locations."/.well-known/host-meta.json".extraConfig = ''
          default_type 'application/xrd+xml';
          add_header Access-Control-Allow-Origin '*' always;
        '';
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/www 0755 root root -"
    "d /var/www/zaripov.net 0755 root root -"
    "L+ /var/www/zaripov.net/index.html - - - - ${./index.html}"
    "L+ /var/www/zaripov.net/.well-known/host-meta - - - - ${./ejabberd.host-meta}"
    "L+ /var/www/zaripov.net/.well-known/host-meta.json - - - - ${./ejabberd.host-meta.json}"
  ];
}
