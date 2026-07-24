{ inputs, ... }:

{
  imports = [
    inputs.disko.nixosModules.disko
  ];
  boot.zfs.forceImportRoot = false;

  disko.devices = {
    disk = {
      nvme = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Micron_MTFDHBA512QFD_20432B2E2878";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "2G";
              type = "EF00";
              priority = 1;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };
    zpool = {
      "zroot" = {
        type = "zpool";
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = {
          mountpoint = "none";
          compression = "zstd";
          atime = "off";
          acltype = "posixacl";
          xattr = "sa";

          encryption = "on";
          keyformat = "passphrase";
          keylocation = "prompt";
        };

        datasets = {
          "root" = {
            type = "zfs_fs";
            mountpoint = "/";
            postCreateHook = "zfs list -t snapshot | grep -q zroot/root@blank || zfs snapshot zroot/root@blank";
            options."com.sun:auto-snapshot" = "false";
          };
          "persistent" = {
            type = "zfs_fs";
            mountpoint = "/persistent";
            options."com.sun:auto-snapshot" = "true";
          };
          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options."com.sun:auto-snapshot" = "false";
          };
          "docker" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/docker";
            options."com.sun:auto-snapshot" = "false";
          };
          "shit" = {
            type = "zfs_fs";
            mountpoint = "/shit";
            options."com.sun:auto-snapshot" = "false";
          };
        };
      };
    };
  };
}
