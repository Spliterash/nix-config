{
  config,
  inputs,
  username,
  ...
}@args:
#? https://nix-community.github.io/preservation/impermanence-migration.html maybe
let
  persistentDir = if args ? persistentDir then args.persistentDir else "/persistent";
in
{
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  fileSystems.${persistentDir}.neededForBoot = true;
  fileSystems."/shit".neededForBoot = true;

  #? https://github.com/nix-community/impermanence/issues/320#issuecomment-4260870035
  boot.initrd.systemd.services.rollback-zroot = {
    description = "Rollback ZFS root to a pristine state";
    unitConfig.DefaultDependencies = false;
    # The script needs to run to completion before this service is done
    serviceConfig.Type = "oneshot";
    # This service is required for boot to succeed (requiredBy will produce kernel panic)
    wantedBy = [ "initrd.target" ];
    after = [ "zfs-import-zroot.service" ];
    # Should complete before any file systems are mounted
    before = [ "sysroot.mount" ];

    path = [ config.boot.zfs.package ];
    script = "zfs rollback -r zroot/root@blank";
  };

  environment.persistence."${persistentDir}" = {
    hideMounts = true;

    directories = [
      "/etc"
      "/var"
    ];
    users.${username} = {
      directories = [
        "Desktop"
        "Documents"
        "Downloads"
        "Games"
        "Music"
        "Pictures"
        "Videos"

        "config"
        "hax"
        "Sync"

        ".config"
        ".ssh"
        ".local"

        #? apps
        ".android"
        ".claude"
        ".claude-mem"
        ".codex"
        ".thunderbird"
        ".vscode"
        ".vscode-shared" # ? recent and trust folders
        ".sourcegit"
        ".java"

        #? games
        ".steam"
        ".wine"

        #? dev
        ".docker"
      ];

      files = [
        ".claude.json"
      ];
    };
  };
  environment.persistence."/shit" = {
    users.${username} = {
      directories = [
        ".cache"
        ".gradle"
        ".m2"

        #? dev
        ".jdks"
        ".npm"
        ".pki"
      ];
    };
  };
}
