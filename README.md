# Server

### Prerequisites

- `/mnt/var/lib/secrets/influxdb-admin-token`
- `/mnt/var/lib/secrets/influxdb-admin-passwd`
- `/mnt/var/lib/secrets/telegraf.env` with `INFLUX_TOKEN=$(cat /mnt/var/lib/secrets/influxdb-admin-token)`

### Create flake & build

    nix flake new --template github:tanshihaj/nixos-configs#server /mnt/etc/nixos
    nix build /mnt/etc/nixos#nixosConfigurations.server.config.system.build.toplevel

# Laptop

### Prerequisites
- `/mnt/home/kamil/.ssh/id_ed25519`

# Router

### Build image & flash

    nix run .#nanopi-r5c-builder -- this-is-user-passwd this-is-wifi-passwd image.bin
    sudo nix run .#nanopi-r5c-flasher -- image.bin
    rm image.bin