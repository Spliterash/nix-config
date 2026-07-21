{ ... }:
{
  programs.plasma = {
    #! broken logout session.sessionRestore.restoreOpenApplicationsOnLogin = "whenSessionWasManuallySaved";
    session.sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";

    workspace = {
      # Dark by default. Applied at login via `plasma-apply-lookandfeel -a`
      # (appearance only, so it won't reset the custom panel/layout).
      lookAndFeel = "org.kde.breezedark.desktop";
      tooltipDelay = 500;
    };
  };
}
