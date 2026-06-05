{ lib, pkgs, ... }:
let
  winePkg = with pkgs; wineWow64Packages.unstableFull;
in
{
  environment.systemPackages = with pkgs; [
    winePkg
    winetricks
  ];

  #? https://github.com/fufexan/nix-gaming/blob/9d30426090a8d274eb20dc36bd28c6e37dc3589c/modules/wine.nix#L21
  environment.sessionVariables.WINE_BIN = lib.getExe winePkg;

  # add binfmt registration
  boot.binfmt.registrations."DOSWin" = {
    interpreter = lib.getExe winePkg;
    wrapInterpreterInShell = false;
    recognitionType = "magic";
    offset = 0;
    magicOrExtension = "MZ";
  };

  # load ntsync
  boot.kernelModules = [ "ntsync" ];

  # make ntsync device accessible
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "ntsync-udev-rules";
      text = ''KERNEL=="ntsync", MODE="0660", TAG+="uaccess"'';
      destination = "/etc/udev/rules.d/70-ntsync.rules";
    })
  ];
}
