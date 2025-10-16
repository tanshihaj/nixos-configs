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
              dfu-util
              vscodium
              cargo
              rustc
              rustfmt
              rust-analyzer
              kicad-small

              # misc
              mpv
              chromium
              firefox
              qbittorrent
              telegram-desktop
              prismlauncher
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

              jellyfin = {
                enable = true;
                openFirewall = true;
                user = "kamil";
                group = "users";
              };
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

            nixpkgs.hostPlatform = "aarch64-linux";
          };

        platform-thinkpad-x13-gen4 =
          {
            config,
            lib,
            modulesPath,
            ...
          }:
          {
            imports = [
              (modulesPath + "/installer/scan/not-detected.nix")
            ];

            boot.loader.systemd-boot.enable = true;
            boot.loader.efi.canTouchEfiVariables = true;
            boot.initrd.availableKernelModules = [
              "xhci_pci"
              "thunderbolt"
              "nvme"
            ];
            boot.initrd.kernelModules = [ ];
            boot.kernelModules = [ "kvm-intel" ];
            boot.extraModulePackages = [ ];

            hardware.bluetooth.enable = true;

            fileSystems."/" = {
              device = "/dev/disk/by-uuid/380b8b8b-de66-4a27-87ec-0e7ca93aa8e0";
              fsType = "ext4";
            };

            fileSystems."/boot" = {
              device = "/dev/disk/by-uuid/56E2-2C58";
              fsType = "vfat";
              options = [
                "fmask=0022"
                "dmask=0022"
              ];
            };

            swapDevices = [
              { device = "/dev/disk/by-uuid/42fba197-df69-4463-8778-7ab719977d61"; }
            ];

            nixpkgs.hostPlatform = "x86_64-linux";
            hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
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
    // (flake-utils.lib.eachDefaultSystem (system: {
      formatter = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    }));
}
