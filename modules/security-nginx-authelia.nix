{ pkgs, lib, ... }:
{
  security.acme.defaults.email = "kamil@zaripov.net";

  systemd.services.authelia-main.serviceConfig = {
    RuntimeDirectory = "authelia-main";
  };
  services.authelia.instances.main = {
    enable = true;
    settings = {
      server.address = "unix:///run/authelia-main/authelia.sock?umask=0000";
      authentication_backend = {
        password_reset.disable = true;
        password_change.disable = true;
        file = {
          path = "/var/lib/authelia-main/users.yaml";
        };
      };
      duo_api.disable = true;
      totp.disable = true;
      webauthn = {
        disable = false;
        enable_passkey_login = true;
      };
      access_control.rules = [
        { domain = "*.zaripov.net"; policy = "two_factor"; }
      ];
      session.cookies = [
        {
          domain = "zaripov.net";
          authelia_url = "https://auth.zaripov.net";
        }
      ];
      storage.local.path = "/var/lib/authelia-main/db.sqlite3";
      notifier.filesystem.filename = "/var/lib/authelia-main/notifications.log";
    };
    secrets = {
      jwtSecretFile = "/var/lib/secrets/authelia-jwt-secret";
      storageEncryptionKeyFile = "/var/lib/secrets/authelia-storage-encryption-key";
    };
  };

  services.nginx =
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
    in {
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      logError = "syslog:server=unix:/dev/log warn";

      virtualHosts."auth.zaripov.net" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://unix:/run/authelia-main/authelia.sock";
          proxyWebsockets = true;
        };
      };

      # FXIME: wtf did I add it?
      virtualHosts."_" = {
        default = true;
        listenAddresses = [ "0.0.0.0" "100.64.0.6" ];
        addSSL = true;
        locations."/" = {
          return = "404";
        };
        sslCertificate = "/var/lib/acme/zaripov.net/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/zaripov.net/key.pem";
        sslTrustedCertificate = "/var/lib/acme/zaripov.net/chain.pem";
      };

  };
}

