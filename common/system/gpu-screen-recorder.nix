{
  config,
  lib,
  pkgs,
  ...
}:
let
  outputDir = "%h/Videos/Replays";

  #? Каждый -a — отдельная дорожка. Имена приложений только статические, поэтому
  #? последней дорожкой идёт app-inverse-остаток: туда попадают игры и всё, что
  #? не перечислено выше. Префикс обязателен на каждом имени — сегмент без него
  #? gsr считает устройством, а не приложением.
  apps = [
    "firefox"
    "vesktop"
  ];

  audio = [
    "default_output"
    "default_input"
  ]
  ++ map (app: "app:${app}") apps
  ++ [ (lib.concatMapStringsSep "|" (app: "app-inverse:${app}") apps) ];

  saveNotify = pkgs.writeShellScript "gsr-replay-saved" ''
    ${lib.getExe pkgs.libnotify} -a "GPU Screen Recorder" -i com.dec05eba.gpu_screen_recorder \
      "Реплей сохранён" "$(basename "$1")"
  '';

  flags = [
    "-v no"
    "-w ${config.gpuScreenRecorder.monitor}"
    "-c mp4"
    #! Без -bm, то есть дефолтный auto → qp: постоянное качество, битрейт плавает.
    #! Ровно так же запускает GUI. Цена — размер буфера в ОЗУ заранее не известен,
    #! на динамичной картинке 10 минут могут вылезти в несколько ГБ.
    "-q very_high"
    "-r 600"
    "-df yes"
    "-sc ${saveNotify}"
    "-o ${outputDir}"
  ]
  ++ map (source: "-a ${source}") audio;
in
{
  options.gpuScreenRecorder.monitor = lib.mkOption {
    type = lib.types.str;
    default = "screen";
    description = "Имя выхода из `kscreen-doctor -o` либо `screen` — первый попавшийся монитор.";
  };

  config = {
    programs.gpu-screen-recorder.enable = true;

    environment.systemPackages = with pkgs; [
      gpu-screen-recorder-gtk # GUI app
    ];

    systemd.user.services.gpu-screen-recorder = {
      description = "GPU Screen Recorder replay buffer";

      #? Не default.target: нужно окружение сессии (WAYLAND_DISPLAY и прочее),
      #? иначе захват не поднимется.
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];

      serviceConfig = {
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${outputDir}";
        ExecStart = lib.concatStringsSep " " (
          [ (lib.getExe config.programs.gpu-screen-recorder.package) ] ++ flags
        );
        KillSignal = "SIGINT"; # в режиме реплея это «выйти без сохранения»
        Restart = "on-failure"; # монитор может быть не готов сразу после логина
        RestartSec = "5s";
      };
    };
  };
}
