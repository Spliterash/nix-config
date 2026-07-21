{ ... }:
{
  programs.plasma = {
    # Keyboard layouts + switching handled at the XKB layer (Plasma's kxkbrc).
    # On Wayland this is the reliable mechanism; the KGlobalAccel "Switch to Next
    # Keyboard Layout" shortcut below is disabled because a modifier-only bind
    # (Shift+Alt) grabs Alt — stealing menubar focus — and eats a held Shift after
    # a switch, so you can't keep Shift down to type capitals.
    input.keyboard = {
      layouts = [
        { layout = "us"; }
        { layout = "ru"; }
      ];
      # Win+Space toggles the group (Windows 10/11 default; matches vladik's
      # config). No Alt in the combo, so apps never see a lone Alt → no menu
      # activation / focus loss, and a held Shift keeps capitalising after a switch.
      options = [ "grp:win_space_toggle" ];
      switchingPolicy = "global";
      # NumLock включён при старте сессии (kcminputrc [Keyboard] NumLock).
      # SDDM-настройка ниже отвечает только за экран входа; сессия Plasma при
      # старте применяет своё значение и без этого гасит нумлок после бута.
      numlockOnStartup = "on";
    };
  };
}
