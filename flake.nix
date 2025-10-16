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
              tmux
              usbutils
              vim

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

            # programs.sysdig.enable = true;

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
                experimental-features = [
                  "nix-command"
                  "flakes"
                ];
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

        # laptop = {
        #   environment.systemPackages = with pkgs; [
        #     # admin
        #     resources
        #     wireshark
        #     yubioath-flutter

        #     # dev
        #     dfu-util
        #     vscodium
        #     cargo
        #     rustc
        #     rustfmt
        #     rust-analyzer
        #     kicad-small

        #     # misc
        #     mpv
        #     chromium
        #     firefox
        #     qbittorrent
        #     telegram-desktop
        #     prismlauncher
        #   ];
        # };

        platform-hetzner-ampere =
          # most of these options was copy-pasted from hardware-configuration.nix generated by nixos installer image
          { lib, modulesPath, ... }:
          {
            imports = [
              (modulesPath + "/profiles/qemu-guest.nix")
            ];

            boot.loader.systemd-boot.enable = true;
            boot.loader.efi.canTouchEfiVariables = true;
            boot.initrd.availableKernelModules = [
              "xhci_pci"
              "virtio_scsi"
              "sr_mod"
            ];
            boot.initrd.kernelModules = [ ];
            boot.kernelModules = [ ];
            boot.extraModulePackages = [ ];

            fileSystems."/" = {
              device = "/dev/disk/by-uuid/676809cd-fd0e-4b4a-afae-c234d109bbe8";
              fsType = "ext4";
            };

            fileSystems."/boot" = {
              device = "/dev/disk/by-uuid/C35A-1B20";
              fsType = "vfat";
              options = [
                "fmask=0077"
                "dmask=0077"
              ];
            };

            swapDevices = [ ];

            nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
          };
      };
      templates = {
        server = {
          path = ./templates/server;
        };
      };
    })
    // (flake-utils.lib.eachDefaultSystem (system: {
      formatter = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    }));
}
