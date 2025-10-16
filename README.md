# Server

### Prerequisites

- `/mnt/var/lib/secrets/influxdb-admin-token`
- `/mnt/var/lib/secrets/influxdb-admin-passwd`
- `/mnt/var/lib/secrets/telegraf.env` with `INFLUX_TOKEN=$(cat /mnt/var/lib/secrets/influxdb-admin-token)`

### Create flake & build

    nix flake new --template github:tanshihaj/nixos-configs#server /mnt/etc/nixos
    nix build /mnt/etc/nixos#nixosConfigurations.server.config.system.build.toplevel
