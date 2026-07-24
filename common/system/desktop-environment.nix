{ pkgs, username, ... }:
{
  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = false;
  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.settings.General.Numlock = "on";
  services.desktopManager.plasma6.enable = true;
  security.pam.services.sddm.kwallet.enable = false;
  # Автологин без экрана входа. SDDM сам пропускает выбор юзера и сразу грузит
  # единственную сессию (Plasma 6). В VM свой autoLogin внутри vmVariant
  # (modules/vm.nix) — он этот блок не отменяет, оба про одного юзера.
  services.displayManager.autoLogin = {
    enable = true;
    user = username;
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  programs.kdeconnect.enable = true;
}
