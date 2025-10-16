{ config, lib, ... }:
{
  services = {
    grafana = {
      enable = true;
      settings = {
        server = rec {
          http_addr = "127.0.0.1";
          http_port = 3000;
          protocol = "http";
          domain = "grafana.${config.networking.domain}";
          root_url = "${protocol}://${domain}:${toString http_port}/";
        };
      };
    };

    influxdb2 = {
      enable = true;
      provision = {
        enable = true;
        initialSetup = {
          bucket = "main";
          username = "admin";
          organization = "main";

          retention = 7 * 24 * 60 * 60;

          tokenFile = "/var/lib/secrets/influxdb-admin-token";
          passwordFile = "/var/lib/secrets/influxdb-admin-passwd";
        };
      };
    };

    telegraf = {
      enable = true;
      environmentFiles = [ "/var/lib/secrets/telegraf.env" ];
      extraConfig = {
        inputs = {
          cpu = {
            percpu = true;
            totalcpu = true;
            collect_cpu_time = false;
          };
          mem = { };
          disk = {
            mount_points = [ "/" ];
          };
          net = { };
          system = { };
          processes = { };
          x509_cert = {
            sources = [
              "https://zaripov.net"
              "https://headscale.zaripov.net"
            ];
            exclude_root_certs = true;
          };
        };
        outputs = {
          influxdb_v2 = {
            urls = [ "http://127.0.0.1:8086" ]; # FIXME: hard-coded port
            token = "$INFLUX_TOKEN";
            organization = "main";
            bucket = "main";
          };
        };
      };
    };

    nginx = {
      enable = true;
      virtualHosts."grafana.zaripov.vpn" = {
        listenAddresses = [ "100.64.0.6" ]; # FIXME, I should not hardcode VPN addresses probably...
        locations."/" = {
          proxyPass = "http://localhost:${toString config.services.grafana.settings.server.http_port}";
          proxyWebsockets = true;
          recommendedProxySettings = true;
        };
      };
    };
  };
}
