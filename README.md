# Server

### Prerequisites

- `/mnt/var/lib/secrets/authelia-jwt-secret` with `openssl rand -hex 64`
- `/mnt/var/lib/secrets/authelia-storage-encryption-key` with `openssl rand -hex 64`
- `/mnt/var/lib/secrets/grafana-secret-key` with `openssl rand -hex 32`

### Create flake & build

    nix flake new --template github:tanshihaj/nixos-configs#server /mnt/etc/nixos
    nix build /mnt/etc/nixos#nixosConfigurations.server.config.system.build.toplevel

# Router

### Build image & flash

    nix run .#nanopi-r5c-builder -- this-is-user-passwd this-is-wifi-passwd image.bin
    sudo nix run .#nanopi-r5c-flasher -- image.bin
    rm image.bin

