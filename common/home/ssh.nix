{ config, ... }:
{
  home.file.".ssh/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Sync/SSH/config";
  home.file.".ssh/known_hosts".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Sync/SSH/known_hosts";
}
