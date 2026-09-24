{ username, ... }:
rec {
  name = "agent";
  unit = "microvm@${name}.service";

  vsockCid = 4242;
  nixDaemonPort = 54545;

  # ssh-ключ, config.yml и диски VM; disks bind-монтируется в /run/avm/disks
  stateDir = "/home/${username}/agent-vm";
  configFile = "${stateDir}/config.yml";
  sshKey = "${stateDir}/ssh/id_ed25519";

  # Хост готовит перед стартом, гость видит по тем же путям
  hostDir = "/run/avm/host";
  sharesDir = "/run/avm/shares";
  disksDir = "/run/avm/disks";
  gateway = "172.30.42.1";
  guest = "172.30.42.2";
}
