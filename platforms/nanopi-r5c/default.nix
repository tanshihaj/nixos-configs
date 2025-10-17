{
  config,
  lib,
  pkgs,
  ...
}:
{
  hardware.deviceTree.name = "rockchip/rk3568-nanopi-r5c.dtb";
  hardware.firmware = [ pkgs.firmwareLinuxNonfree ];
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
  powerManagement.cpuFreqGovernor = "performance";

  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible = {
        enable = true;
        useGenerationDeviceTree = true;
      };
    };

    kernelParams = [
      "console=tty1"
      "console=ttyS2,1500000"

      # these two options pretty useful for debugging booting issues
      # "earlycon=uart8250,mmio32,0xfe660000"
      # "ignore_loglevel"
    ];

    initrd.postDeviceCommands = ''
      partitionName=$(basename $(readlink -f /dev/disk/by-partlabel/rootfs))
      partitionNumber=$(cat /sys/class/block/$partitionName/partition)
      deviceName=$(basename $(readlink -f /sys/class/block/$partitionName/../))
      deviceSize=$(cat /sys/class/block/$deviceName/size)
      partitionStart=$(cat /sys/class/block/$deviceName/$partitionName/start)
      partitionSize=$(cat /sys/class/block/$deviceName/$partitionName/size)
      parititonEnd=$(($partitionStart + $partitionSize + 33))

      if [ "$deviceSize" -gt "$parititonEnd" ]; then
        echo "Resizing $partitionName to fill whole disk..."
        ${pkgs.gptfdisk}/bin/sgdisk --delete=$partitionNumber /dev/$deviceName
        ${pkgs.gptfdisk}/bin/sgdisk --largest-new=$partitionNumber --change-name=$partitionNumber:rootfs --attributes=$partitionNumber:set:2 /dev/$deviceName
      fi
    '';

    postBootCommands = ''
      if [ -f /nix-path-registration ]; then
        ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration && rm /nix-path-registration
      fi

      ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system

      # resize the ext4 image to occupy the full partition
      rootPart=$(readlink -f /dev/disk/by-partlabel/rootfs)
      ${pkgs.e2fsprogs}/bin/resize2fs $rootPart
    '';
  };

  fileSystems."/" = {
    device = "/dev/disk/by-partlabel/rootfs";
  };

  system.build = {
    uboot =
      (pkgs.buildUBoot rec {
        version = "2023.10";
        src = pkgs.fetchurl {
          url = "https://ftp.denx.de/pub/u-boot/u-boot-${version}.tar.bz2";
          hash = "sha256-4A5sbwFOBGEBc50I0G8yiBHOvPWuEBNI9AnLvVXOaQA=";
        };
        defconfig = "nanopi-r5c-rk3568_defconfig";
        filesToInstall = [
          "u-boot.itb"
          "idbloader.img"
        ];
      }).override
        {
          patches = [
            (pkgs.fetchpatch {
              url = "https://github.com/u-boot/u-boot/commit/a63456b9191fae2fe49f4b121e025792022e3950.patch";
              hash = "sha256-N97cXu2XmCdoA6sSAbBM9s/1GcUMZfgP7iOMaYydcPo=";
            })
          ];
          makeFlags = [
            "CROSS_COMPILE=${pkgs.stdenv.cc.targetPrefix}"
            "ROCKCHIP_TPL=${pkgs.rkbin}/bin/rk35/rk3568_ddr_1560MHz_v1.18.bin"
            # FIXME: we can build bl31 from ATF
            "BL31=${pkgs.rkbin}/bin/rk35/rk3568_bl31_v1.43.elf"
          ];
        };

    # FIXME: generic-extlinux-compatible.populateCmd _copies_ kernel, initrd & dtbs from
    # /nix/store to /boot which is a bit useless since both folders are in same FS
    bootFolder = pkgs.runCommand "boot-folder" { } ''
      mkdir $out
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d $out
    '';
  };

  nixpkgs.hostPlatform = "aarch64-linux";

  nixpkgs.config.allowUnfree = true; # FIXME: we need it for hardware.enableAllFirmware = true; but maybe there is a better solution
}
