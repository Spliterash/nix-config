{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  libGL,
  xorg,
  wayland,
  libxkbcommon,
}:

stdenv.mkDerivation {
  pname = "sniffcraft";
  version = "1.21.11";

  src = fetchurl {
    url = "https://github.com/adepierre/SniffCraft/releases/download/latest/sniffcraft-linux-1.21.11";
    hash = "sha256-wJVEhYcrTek561b9o/0tYvb1IS3975jEg804KXCX9qA=";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    libGL
  ];

  runtimeDependencies = [
    xorg.libX11
    xorg.libXrandr
    xorg.libXinerama
    xorg.libXcursor
    xorg.libXi
    xorg.libXext
    wayland
    libxkbcommon
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "sniffcraft";
      desktopName = "SniffCraft";
      comment = "Minecraft protocol proxy / packet sniffer";
      exec = "sniffcraft";
      terminal = false;
      categories = [
        "Network"
        "Utility"
      ];
    })
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/sniffcraft
    runHook postInstall
  '';

  meta = {
    description = "Minecraft proxy to log/inspect the protocol between client and server";
    homepage = "https://github.com/adepierre/SniffCraft";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "sniffcraft";
  };
}
