{ ... }:
{
  programs.plasma.configFile = {
    "spectaclerc"."General"."autoSaveImage" = false;
    "spectaclerc"."General"."clipboardGroup" = "PostScreenshotCopyImage";
    "spectaclerc"."General"."launchAction" = "UseLastUsedCapturemode";
    "spectaclerc"."General"."ocrLanguages" = "eng,rus";
    "spectaclerc"."GuiConfig"."captureMode" = 0;
    "spectaclerc"."GuiConfig"."quitAfterSaveCopyExport" = true;
    # KConfig хранит VideoPlatform::MP4_H264 как число: 1 << 1.
    "spectaclerc"."VideoSave"."preferredVideoFormat" = 2;
    "plasma_calendar_holiday_regions"."General"."selectedRegions" = "ru_ru";

    # Не даём фуррифоксу держать включённый экран, если играет музыка
    # То что тут текстом задано кринж кнч, но оно реал так в конфиге лежит
    "powerdevilrc"."Inhibitions"."BlockedInhibitions" = "firefox:Воспроизведение звука";
  };
}
