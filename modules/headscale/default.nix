{ config, ... }:
{
  security = {
    acme.certs."headscale.zaripov.net" = {
      email = "kamil@zaripov.net";
    };
  };

  services = {
    headscale = {
      enable = true;
      address = "127.0.0.1";
      port = 8080;
      settings = {
        # log.level = "debug";
        logtail.enabled = false;
        server_url = "https://headscale.zaripov.net";
        dns = {
          base_domain = "zaripov.vpn";
          extra_records = [
            {
              name = "grafana.zaripov.vpn"; # FIXME: should be moved to monitoring module probably
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "jellyfin.zaripov.vpn";
              type = "A";
              value = "100.64.0.1";
            }
            {
              name = "qbittorrent.zaripov.vpn";
              type = "A";
              value = "100.64.0.1";
            }
          ];
        };

        # allow everything for everyone in headnet)
        policy.path = ./headscale_acl.json;
      };
    };

    nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts."headscale.zaripov.net" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://localhost:${toString config.services.headscale.port}";
          proxyWebsockets = true;
        };
      };
    };
  };
}
