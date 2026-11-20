{
  lib,
  stdenv,
  obtainium,
  autoPatchelfHook,
  kdePackages,
  libarchive,
  libglvnd,
  qrencode,
  tomlplusplus,
  zlib,
  addDriverRunpath,
  alsa-lib,
  flite,
  gamemode,
  glfw3-minecraft,
  libjack2,
  libpulseaudio,
  libusb1,
  libx11,
  libxcursor,
  libxext,
  libxrandr,
  libxxf86vm,
  mesa-demos,
  openal,
  openjdk8,
  openjdk17,
  openjdk21,
  openjdk25,
  pciutils,
  pipewire,
  udev,
  vulkan-loader,
  xrandr,
}:

stdenv.mkDerivation {
  pname = "freesmlauncher";
  inherit (obtainium.freesmlauncher) src version;

  nativeBuildInputs = [
    autoPatchelfHook
    kdePackages.wrapQtAppsHook
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    kdePackages.qtbase
    kdePackages.qtnetworkauth
    kdePackages.qtsvg
    kdePackages.qtwayland
    libarchive
    libglvnd
    qrencode
    tomlplusplus
    zlib
  ];

  unpackCmd = "mkdir -p root; tar -xzf \"$curSrc\" -C root";
  sourceRoot = "root";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 shared/bin/freesmlauncher "$out/bin/freesmlauncher"
    # В релизе другой SONAME cmark. Остальные библиотеки берём из Nixpkgs.
    install -Dm755 shared/lib/libcmark.so.0.30.2 "$out/lib/libcmark.so.0.30.2"
    mkdir -p "$out/share"
    cp -r share/{FreesmLauncher,applications,icons,mime,metainfo,man,qlogging-categories6} "$out/share/"
    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath "$out/lib"
    qtWrapperArgs+=(
      --prefix FREESMLAUNCHER_JAVA_PATHS : ${
        lib.makeSearchPath "bin/java" [
          openjdk8
          openjdk17
          openjdk21
          openjdk25
        ]
      }
      --prefix PATH : ${
        lib.makeBinPath [
          mesa-demos
          pciutils
          xrandr
        ]
      }
      --prefix LD_LIBRARY_PATH : ${addDriverRunpath.driverLink}/lib:${
        lib.makeLibraryPath [
          stdenv.cc.cc.lib
          alsa-lib
          flite
          gamemode.lib
          glfw3-minecraft
          libglvnd
          libjack2
          libpulseaudio
          libusb1
          libx11
          libxcursor
          libxext
          libxrandr
          libxxf86vm
          openal
          pipewire
          udev
          vulkan-loader
        ]
      }
    )
  '';

  meta = {
    description = "Freesm Launcher, a fork of Prism Launcher for Minecraft";
    homepage = "https://freesmlauncher.org/";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "freesmlauncher";
  };
}
