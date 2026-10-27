{ config, lib, pkgs, ... }:
{
  services = {
    grafana = {
      enable = true;
      declarativePlugins = [
        pkgs.grafanaPlugins.victoriametrics-logs-datasource
      ];
      settings = {
        server = rec {
          http_addr = "127.0.0.1";
          http_port = 3000;
          protocol = "http";
          domain = "grafana.${config.networking.domain}";
          root_url = "${protocol}://${domain}:${toString http_port}/";
        };
        users = {
          allow_sign_up = false;
          auto_assign_org = true;
          auto_assign_org_role = "Viewer";
        };
        "auth.proxy" = {
          enabled = true;
          header_name = "Remote-User";
          header_property = "username";
          headers = "Name:Remote-Name Email:Remote-Email Groups:Remote-Groups";
          auto_sign_up = true;
          enable_login_token = false;
          whitelist = "127.0.0.1";
        };
        security.secret_key = "$__file{/var/lib/secrets/grafana-secret-key}";
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "VictoriaMetrics";
            type = "prometheus";
            access = "proxy";
            url = "http://${config.services.victoriametrics.listenAddress}";
            isDefault = true;
            editable = false;
            jsonData.timeInterval = config.services.vmagent.prometheusConfig.global.scrape_interval;
          }
          {
            name = "VictoriaLogs";
            type = "victoriametrics-logs-datasource";
            access = "proxy";
            url = "http://${config.services.victorialogs.listenAddress}";
          }
        ];
      };
    };

    nginx.virtualHosts."grafana.zaripov.net" =
      let
        authelia-endpoint = "http://unix:/run/authelia-main/authelia.sock:";

        # https://www.authelia.com/integration/proxies/nginx/#authelia-locationconf
        authelia-location-conf = pkgs.writeText "authelia-location.conf" ''
          location /internal/authelia/authz {
              ## Essential Proxy Configuration
              internal;
              proxy_pass $upstream_authelia;

              ## Headers
              ## The headers starting with X-* are required.
              proxy_set_header X-Original-Method $request_method;
              proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
              proxy_set_header X-Forwarded-For $remote_addr;
              proxy_set_header Content-Length "";
              proxy_set_header Connection "";

              ## Basic Proxy Configuration
              proxy_pass_request_body off;
              proxy_next_upstream error timeout invalid_header http_500 http_502 http_503; # Timeout if the real server is dead
              proxy_redirect http:// $scheme://;
              proxy_http_version 1.1;
              proxy_cache_bypass $cookie_session;
              proxy_no_cache $cookie_session;
              proxy_buffers 4 32k;
              client_body_buffer_size 128k;

              ## Advanced Proxy Configuration
              send_timeout 5m;
              proxy_read_timeout 240;
              proxy_send_timeout 240;
              proxy_connect_timeout 240;
          }
        '';

        # https://www.authelia.com/integration/proxies/nginx/#authelia-authrequestconf
        authelia-authrequest-conf = pkgs.writeText "authelia-authrequest.conf" ''
          ## Send a subrequest to Authelia to verify if the user is authenticated and has permission to access the resource.
          auth_request /internal/authelia/authz;

          ## Save the upstream metadata response headers from Authelia to variables.
          auth_request_set $user $upstream_http_remote_user;
          auth_request_set $groups $upstream_http_remote_groups;
          auth_request_set $name $upstream_http_remote_name;
          auth_request_set $email $upstream_http_remote_email;

          ## Inject the metadata response headers from the variables into the request made to the backend.
          proxy_set_header Remote-User $user;
          proxy_set_header Remote-Groups $groups;
          proxy_set_header Remote-Email $email;
          proxy_set_header Remote-Name $name;

          ## Configure the redirection when the authz failure occurs. Lines starting with 'Modern Method' and 'Legacy Method'
          ## should be commented / uncommented as pairs. The modern method uses the session cookies configuration's authelia_url
          ## value to determine the redirection URL here. It's much simpler and compatible with the mutli-cookie domain easily.

          ## Modern Method: Set the $redirection_url to the Location header of the response to the Authz endpoint.
          auth_request_set $redirection_url $upstream_http_location;

          ## Modern Method: When there is a 401 response code from the authz endpoint redirect to the $redirection_url.
          error_page 401 =302 $redirection_url;

          ## Legacy Method: Set $target_url to the original requested URL.
          ## This requires http_set_misc module, replace 'set_escape_uri' with 'set' if you don't have this module.
          # set_escape_uri $target_url $scheme://$http_host$request_uri;

          ## Legacy Method: When there is a 401 response code from the authz endpoint redirect to the portal with the 'rd'
          ## URL parameter set to $target_url. This requires users update 'auth.zaripov.net/' with their external authelia URL.
          # error_page 401 =302 https://auth.zaripov.net/?rd=$target_url;
        '';
      in
        {
          forceSSL = true;
          enableACME = true;

          locations."/" = {
            proxyPass = "http://localhost:${toString config.services.grafana.settings.server.http_port}";
            proxyWebsockets = true;

            extraConfig = ''
              set $upstream http://localhost:${toString config.services.grafana.settings.server.http_port};
              include ${authelia-authrequest-conf};
            '';
          };

          extraConfig = ''
            set $upstream_authelia ${authelia-endpoint}/api/authz/auth-request;
            include ${authelia-location-conf};
          '';
        };

    victoriametrics = {
      enable = true;
      listenAddress = "127.0.0.1:8428";
    };
    victorialogs = {
      enable = true;
      listenAddress = "127.0.0.1:9428";
    };

    vmagent = {
      enable = true;

      remoteWrite = {
        url = "http://${config.services.victoriametrics.listenAddress}/api/v1/write";
      };

      prometheusConfig = {
        global = {
          scrape_interval = "5s";
        };

        scrape_configs = [
          {
            job_name = "node";
            static_configs = [
              { targets = [
                  (with config.services.prometheus.exporters.node; "${listenAddress}:${toString port}" )
                  "router:9100"
                  "laptop:9100"
                ];
              }
            ];
          }
          {
            job_name = "victoriametrics";
            static_configs = [
              { targets = [ config.services.victoriametrics.listenAddress ]; }
            ];
          }
        ];
      };
    };

    prometheus.exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9100;
      enabledCollectors = [ "systemd" "processes" ];
      extraFlags = [ "--web.disable-exporter-metrics" ];
    };

    journald.upload = {
      enable = true;

      settings.Upload = {
        URL = "http://${config.services.victorialogs.listenAddress}/insert/journald";
      };
    };
  };
}

