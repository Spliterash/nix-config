{ ... }:
{
  programs.plasma.configFile = {
    "spectaclerc"."General"."clipboardGroup" = "PostScreenshotCopyImage";
    "spectaclerc"."General"."launchAction" = "UseLastUsedCapturemode";
    "spectaclerc"."GuiConfig"."captureMode" = 0;
    "spectaclerc"."GuiConfig"."quitAfterSaveCopyExport" = true;
    "plasma_calendar_holiday_regions"."General"."selectedRegions" = "ru_ru";

    # Не даём фуррифоксу держать включённый экран, если играет музыка
    # То что тут текстом задано кринж кнч, но оно реал так в конфиге лежит
    "powerdevilrc"."Inhibitions"."BlockedInhibitions" = "firefox:Воспроизведение звука";
  };
}
