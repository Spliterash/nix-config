{ inputs, ... }:

{
  imports = [
    inputs.disko.nixosModules.disko
  ];
  boot.zfs.forceImportRoot = false;

  disko.devices = {
    disk = {
      nvme = {
        device = "/dev/disk/by-id/REPLACE_ME_AT_INSTALL";
        destroy = false;
        content = {
          type = "gpt";
        };
      };
    };
    zpool = {
      "zroot" = {
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
