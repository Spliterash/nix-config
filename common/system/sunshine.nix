{ pkgs, username, ... }:
{
  services.sunshine = {
    enable = true;
    openFirewall = true;
    capSysAdmin = true;
    autoStart = true;
  };

  users.users.${username} = {
    extraGroups = [
      "uinput"
      "input"
    ];
  };
}
