{ inputs, ... }:
{
  imports = [
    inputs.plasma-manager.homeManagerModules.plasma-manager
  ];

  programs.plasma = {
    enable = true;
    configFile = {
      "ksmserverrc"."General"."loginMode" = "emptySession";
      # Alt+Shift в alternative-слот (release-trigger), чтобы не угонять фокус
      # в меню приложений. См. https://discuss.kde.org/t/22698
      "kglobalshortcutsrc"."KDE Keyboard Layout Switcher"."Switch to Next Keyboard Layout" =
        "none,Alt+Shift\tnone\tSwitch to Next Keyboard Layout";
    };
  };
  # Фигня чтобы shiftalt и altshift норм работали, а то заебало
  gtk = {
    enable = true;
    gtk3.extraConfig.gtk-enable-mnemonics = 0;
    gtk4.extraConfig.gtk-enable-mnemonics = 0;
  };
}
