# Server

### Prerequisites

- `/mnt/var/lib/secrets/influxdb-admin-token`
- `/mnt/var/lib/secrets/influxdb-admin-passwd`
- `/mnt/var/lib/secrets/telegraf.env` with `INFLUX_TOKEN=$(cat /mnt/var/lib/secrets/influxdb-admin-token)`

# Laptop

### Prerequisites
- `/mnt/home/kamil/.ssh/id_ed25519`


# Create flake & build

    nix flake new --template github:tanshihaj/nixos-configs#server /mnt/etc/nixos
    nix build /mnt/etc/nixos#nixosConfigurations.server.config.system.build.toplevel
