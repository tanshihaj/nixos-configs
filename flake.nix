{
  description = "My NixOS configs backup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    ({
      nixosModules = {
        base =
          { pkgs, ... }:
          {
            environment.systemPackages = with pkgs; [
              # admin
              file
              htop
              iw
              lm_sensors
              lsof
              mtr
              nix-tree
              pciutils
              pstree
              tcpdump
              tio
              tmux
              usbutils
              vim
              wget

              # dev
              gcc
              gdb
              git
              gnumake
              nixfmt-rfc-style
              nodejs_24
              patchelf
              python3
            ];

            nix = {
              settings = {
                experimental-features = [
                  "nix-command"
                  "flakes"
                ];
              };
            };

            services = {
              openssh = {
                enable = true;
                openFirewall = false;
                settings = {
                  PermitRootLogin = "no";
                  PasswordAuthentication = false;
                  KbdInteractiveAuthentication = false;
                  PubkeyAuthentication = true;
                  AuthenticationMethods = "publickey";
                  X11Forwarding = false;
                  AllowUsers = [ "kamil" ];
                };
              };

              tailscale.enable = true;
            };

            system.stateVersion = "25.05";

            users.users.kamil = {
              isNormalUser = true;
              extraGroups = [ "wheel" ];

              openssh.authorizedKeys.keys = [
                # laptop
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC4Cw8HotJM4mvtqy5xF3tWAiR94nbFOOEmwKeXMFDvi kamil@laptop"

                # yubikey
                "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICW80fIM/gag5OkCl7UVGspgSBlCvvIvSMoyvJWN8Y8uAAAAC3NzaDp5dWJpa2V5 kamil@laptop"

                # router
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0h7nw/wXl7Uz+FjqRU9htpOVGuqH776n5ZoFIwwTRz kamil@router"

                # phone
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINrTaXf5AVooNl+oIi8Op9gQBeqQ6Z+5LvuzXv6TNsOk u0_a291@localhost"
              ];
            };
          };

        server =
          { config, pkgs, ... }:
          {
            imports = [
              ./modules/ejabberd
              ./modules/headscale
              ./modules/monitoring
            ];

            environment.systemPackages = with pkgs; [
              influxdb2-cli
            ];

            systemd.network = {
              enable = true;
              networks.enp1s0 = {
                matchConfig.Name = "enp1s0";
                networkConfig.DHCP = "ipv4";
              };
            };

            networking = {
              hostName = "server";
              domain = "zaripov.net";
              useDHCP = false;
              firewall = {
                enable = true;
                interfaces.enp1s0.allowedTCPPorts = [
                  80
                  443
                  5201 # iperf3
                ];
                interfaces.enp1s0.allowedUDPPorts = [
                  5201 # iperf3
                  config.services.tailscale.port
                ];
                interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
                  80
                  443
                  22 # ssh
                ];
              };
            };

            nix = {
              settings = {
                trusted-substituters = [ "https://cache.nixos.org" ];
                trusted-users = [ "kamil" ];
                # require-sigs = false;
              };
              extraOptions = ''
                builders-use-substitutes = true
              '';
            };

            security = {
              sudo.wheelNeedsPassword = false;
              acme = {
                acceptTerms = true;
                certs."zaripov.net" = {
                  email = "kamil@zaripov.net";
                  extraDomainNames = [
                    # FIXME: move to the ejabberd module
                    "upload.zaripov.net"
                    "conference.zaripov.net"
                    "pubsub.zaripov.net"
                  ];
                };
              };
            };

            services = {
              tailscale.useRoutingFeatures = "server";
            };

            users = {
              groups.nginx.members = [ "ejabberd" ];
            };
          };

        laptop =
          { pkgs, lib, ... }:
          {
            environment.systemPackages = with pkgs; [
              # admin
              resources
              wireshark
              yubioath-flutter

              # dev
              cargo
              dfu-util
              kicad-small
              rust-analyzer
              rustc
              rustfmt
              tio
              vscodium

              # misc
              mpv
              chromium
              firefox
              telegram-desktop
              prismlauncher
              dino
              binaryninja-free
            ];

            environment.variables = {
              RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
            };

            networking = {
              hostName = "laptop";
              # domain = "zaripov.net";
              networkmanager.enable = true;
            };

            services = {
              tailscale.useRoutingFeatures = "client";

              pcscd.enable = true;

              # sadly the only DE that both support fractional display scale AND stable enough to be usable is KDE
              desktopManager.plasma6.enable = true;
              displayManager.sddm.enable = true;
            };
            virtualisation.docker.enable = true;
            virtualisation.libvirtd.enable = true;
            programs.steam.enable = true;
            programs.virt-manager.enable = true;

            # sorry RMS but I like to play GTA
            nixpkgs.config.allowUnfreePredicate =
              pkg:
              builtins.elem (lib.getName pkg) [
                "steam"
                "steam-unwrapped"
                "binaryninja-free"
              ];

            nix.distributedBuilds = true;
            nix.buildMachines = [
              {
                hostName = "server";
                sshUser = "kamil";
                sshKey = "/home/kamil/.ssh/id_ed25519";
                system = "aarch64-linux";
                maxJobs = 12;
                supportedFeatures = [
                  "kvm"
                  "benchmark"
                  "big-parallel"
                ];
              }
            ];

            services.fprintd.enable = true;
            security.pam.services.login.fprintAuth = true;
            security.pam.services.sudo.fprintAuth = true;
            security.pam.services.polkit-1.fprintAuth = true;
            security.pam.services.sddm.fprintAuth = true;

            users.users.kamil = {
              extraGroups = [
                "libvirtd"
                "kvm"
                "wheel"
                "docker"
              ];
            };
          };
        router =
          { config, pkgs, ... }:
          {
            environment.systemPackages = with pkgs; [
              wpa_supplicant
            ];

            networking = {
              hostName = "router";
              useDHCP = false;
              firewall = {
                logRefusedConnections = false;
                enable = true;
                interfaces = {
                  wlp1s0.allowedTCPPorts = [
                    22
                    8096 # jellyfin API + WebUI
                  ];
                  wlp1s0.allowedUDPPorts = [
                    67
                    68
                    1900 # DLNA
                    7359 # jellyfin discovery
                  ];
                  enP2p1s0.allowedTCPPorts = [
                    22
                    8096 # jellyfin API + WebUI
                  ];
                  enP2p1s0.allowedUDPPorts = [
                    67
                    68
                    1900 # DLNA
                    7359 # jellyfin discovery
                  ];
                  # usb-front-2.allowedUDPPorts = [
                  #   67
                  #   68
                  # ];
                  ${config.services.tailscale.interfaceName}.allowedTCPPorts = [
                    22
                    80
                  ];
                };
                allowedUDPPorts = [ config.services.tailscale.port ];
              };
            };

            systemd.network = {
              enable = true;
              wait-online.enable = false;
              # links = {
              #   "90-usb-front-2" = {
              #     matchConfig = {
              #       Path = "platform-xhci-hcd.*.auto-usb-0:1:1.1";
              #     };
              #     linkConfig = {
              #       Name = "usb-front-2";
              #     };
              #   };
              # };
              networks = {
                wlp1s0 = {
                  matchConfig.Name = "wlp1s0";
                  address = [ "192.168.1.1/24" ];
                  networkConfig = {
                    DHCPServer = true;
                    IPMasquerade = "ipv4";
                  };
                  dhcpServerConfig = {
                    EmitDNS = true;
                    DNS = [ "1.1.1.1" "8.8.8.8" ];
                  };
                };
                enP1p1s0 = {
                  matchConfig.Name = "enP1p1s0";
                  networkConfig = {
                    DHCP = true;
                    IPv6AcceptRA = true;
                  };
                };
                enP2p1s0 = {
                  matchConfig.Name = "enP2p1s0";
                  address = [ "192.168.2.1/24" ];
                  networkConfig = {
                    DHCPServer = true;
                    IPMasquerade = "ipv4";
                  };
                  dhcpServerConfig = {
                    EmitDNS = true;
                    DNS = [ "1.1.1.1" "8.8.8.8" ];
                  };
                };
                # usb-front-2 = {
                #   matchConfig.Name = "usb-front-2";
                #   address = [ "192.168.3.1/24" ];
                #   networkConfig = {
                #     DHCPServer = true;
                #     IPMasquerade = "ipv4";
                #   };
                # };
              };
            };
            services = {
              resolved.enable = true;

              qbittorrent = {
                enable = true;
                user = "kamil";
                group = "users";
                serverConfig = {
                  LegalNotice.Accepted = true;
                  Preferences = {
                    WebUI = {
                      Address = "127.0.0.1";
                      LocalHostAuth = false;
                      ServerDomains = "qbittorrent.zaripov.vpn";
                    };
                  };
                };
              };
              jellyfin = {
                enable = true;
                user = "kamil";
                group = "users";
              };
              nginx = {
                enable = true;
                recommendedProxySettings = true;

                defaultListen = [
                  { addr = "100.64.0.1"; port = 80; ssl = false; }
                ];
                virtualHosts."qbittorrent.zaripov.vpn" = {
                  locations."/" = {
                    proxyPass = "http://127.0.0.1:${toString config.services.qbittorrent.webuiPort}";
                  };
                };
                virtualHosts."jellyfin.zaripov.vpn" = {
                  locations."/" = {
                    proxyPass = "http://127.0.0.1:8096";
                  };
                  locations."/socket" = {
                    proxyPass = "http://127.0.0.1:8096";
                    proxyWebsockets = true;
                  };
                };
              };


              hostapd = {
                enable = true;
                radios.wlp1s0 = {
                  countryCode = "IL";
                  channel = 36;
                  settings = {
                    "he_oper_centr_freq_seg0_idx" = "42";
                    "vht_oper_centr_freq_seg0_idx" = "42";
                    "preamble" = 1;
                  };
                  band = "5g";
                  wifi6 = {
                    enable = true;
                    operatingChannelWidth = "80";
                  };
                  wifi5 = {
                    enable = true;
                    operatingChannelWidth = "80";
                    capabilities = [
                      "MAX-MPDU-11454"
                      "RXLDPC"
                      "SHORT-GI-80"
                      "TX-STBC-2BY1"
                      "MU-BEAMFORMEE"
                      "SU-BEAMFORMEE"
                      "RX-ANTENNA-PATTERN"
                      "TX-ANTENNA-PATTERN"
                    ];
                  };
                  wifi4 = {
                    enable = true;
                    capabilities = [
                      "LDPC"
                      "HT40+"
                      "SHORT-GI-40"
                      "TX-STBC"
                      "RX-STBC1"
                      "MAX-AMSDU-7935"
                      "SHORT-GI-20"
                    ];
                  };
                  networks.wlp1s0 = {
                    ssid = "very-unique-ssid";
                    authentication = {
                      mode = "wpa3-sae-transition";
                      wpaPasswordFile = "/var/lib/secrets/wifi-passwd";
                      saePasswordsFile = "/var/lib/secrets/wifi-passwd";
                    };
                  };
                };
              };
            };

            users.users.kamil = {
              hashedPasswordFile = "/var/lib/secrets/user-kamil-passwd-hash";
            };
          };

        platform-hetzner-ampere = import ./platforms/hetzner-ampere/default.nix;
        platform-thinkpad-x13-gen4 = import ./platforms/thinkpad-x13-gen4/default.nix;
        platform-nanopi-r5c = {
          imports = [
            (import ./platforms/nanopi-r5c/default.nix)
          ];
          nixpkgs.overlays = [ self.overlays.nanopi-r5c-stuff ];
        };
      };

      nixosConfigurations.router = nixpkgs.lib.nixosSystem {
        modules = with self.nixosModules; [
          base
          router
          platform-nanopi-r5c
        ];
      };

      overlays.nanopi-r5c-stuff = final: prev: {
        rkbin = final.fetchzip {
          url = "https://github.com/rockchip-linux/rkbin/archive/b4558da0860ca48bf1a571dd33ccba580b9abe23.zip";
          hash = "sha256-KUZQaQ+IZ0OynawlYGW99QGAOmOrGt2CZidI3NTxFw8=";
        };
      };

      templates = {
        server = {
          path = ./templates/server;
        };
        laptop = {
          path = ./templates/laptop;
        };
      };
    })
    // (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.nanopi-r5c-stuff ];
        };
      in
      {
        formatter = pkgs.nixfmt-tree;

        packages = rec {
          nanopi-r5c-builder = pkgs.writeShellScriptBin "nanopi-r5c-builder" (
            let
              rootfs = pkgs.callPackage "${pkgs.path}/nixos/lib/make-ext4-fs.nix" ({
                storePaths = [ self.nixosConfigurations.router.config.system.build.toplevel ];
                compressImage = false;
                populateImageCommands = ''
                  mkdir -p ./files/boot
                  cp -r ${self.nixosConfigurations.router.config.system.build.bootFolder}/* ./files/boot

                  mkdir -p ./files/etc/nixos
                  cp ${./templates/router/flake.nix} ./files/etc/nixos/flake.nix
                  chmod +w ./files/etc/nixos/flake.nix
                '';
                volumeLabel = "nixos";
              });
            in
            ''
              set -euo pipefail

              if [ "$#" -ne "3" ]; then
                echo "Usage: $0 USER_PASSWORD WIFI_PASSWORD OUTPUT_IMAGE_PATH"
                exit 1
              fi

              TEMP_DIR=$(mktemp -d -t nanopi-r5c-builder.XXXXXXXXXX)
              trap 'rm -rf "$TEMP_DIR"' EXIT

              echo "Appending secerts into the rootfs..."
              cp ${rootfs} "$TEMP_DIR/rootfs.ext4"
              chmod +w "$TEMP_DIR/rootfs.ext4"

              ${pkgs.e2tools}/bin/e2mkdir -G0 -O0 -P700 "$TEMP_DIR/rootfs.ext4:/var/lib/secrets"
              mkpasswd -m yescrypt "$1" > "$TEMP_DIR/user-kamil-passwd-hash"
              ${pkgs.e2tools}/bin/e2cp -G0 -O0 -P700 "$TEMP_DIR/user-kamil-passwd-hash" "$TEMP_DIR/rootfs.ext4:/var/lib/secrets/user-kamil-passwd-hash"
              echo "$2" > "$TEMP_DIR/wifi-passwd"
              ${pkgs.e2tools}/bin/e2cp -G0 -O0 -P700 "$TEMP_DIR/wifi-passwd" "$TEMP_DIR/rootfs.ext4:/var/lib/secrets/wifi-passwd"
              rm "$TEMP_DIR/user-kamil-passwd-hash" "$TEMP_DIR/wifi-passwd"

              rootfsSizeBytes=$( stat -c %s "$TEMP_DIR/rootfs.ext4" )
              imageSizeUnalignedBytes=$(( 24576*512 + $rootfsSizeBytes + 33*512 ))
              imageSizeAlignedBytes=$(( (($imageSizeUnalignedBytes + 511)/512)*512 ))
              ${pkgs.coreutils}/bin/truncate -s $imageSizeAlignedBytes "$TEMP_DIR/image"
              ${pkgs.gptfdisk}/bin/sgdisk \
                --new=1:16384:+8192 \
                --change-name=1:uboot \
                "$TEMP_DIR/image"

              ${pkgs.gptfdisk}/bin/sgdisk \
                --new=2:24576:0 \
                --change-name=2:rootfs \
                --attributes=2:set:2 \
                "$TEMP_DIR/image"
              dd if=${self.nixosConfigurations.router.config.system.build.uboot}/idbloader.img of="$TEMP_DIR/image" seek=64 conv=notrunc
              dd if=${self.nixosConfigurations.router.config.system.build.uboot}/u-boot.itb of="$TEMP_DIR/image" seek=16384 conv=notrunc
              dd if="$TEMP_DIR/rootfs.ext4" of="$TEMP_DIR/image" seek=24576 conv=notrunc
              cp "$TEMP_DIR/image" "$3"
            ''
          );

          nanopi-r5c-flasher = pkgs.writeShellScriptBin "flash" (
            let
              # FIXME: I do not remember how to combile rk356x_spl_loader_v1.23.114.bin
              # from the rk3566_ddr_1056MHz_v1.18.bin and rk356x_usbplug_v1.17.bin...
              splLoader = pkgs.fetchurl {
                url = "https://github.com/radxa/rkbin/raw/refs/heads/develop-v2025.04/bin/rk35/rk356x_spl_loader_v1.23.114.bin";
                hash = "sha256-5gVg4Em1ge6no4cdze15mGcfdYcSUHaz/i1dm04hrvE=";
              };
            in
            ''
              set -euo pipefail

              if [ "$#" -ne "1" ]; then
                echo "Usage: $0 IMAGE_PATH"
                exit 1
              fi

              ${pkgs.rkdeveloptool}/bin/rkdeveloptool db ${splLoader}
              ${pkgs.rkdeveloptool}/bin/rkdeveloptool wl 0x0 "$1"
              ${pkgs.rkdeveloptool}/bin/rkdeveloptool rd
            ''
          );

        };
      }
    ));
}
