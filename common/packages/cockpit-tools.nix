{
  lib,
  stdenv,
  obtainium,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  openssl,
  gtk3,
  webkitgtk_4_1,
  glib-networking,
  libayatana-appindicator,
  libsecret,
  desktop-file-utils,
  xdg-utils,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "cockpit-tools";
  inherit (obtainium.cockpit-tools) src version;

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    openssl
    gtk3
    webkitgtk_4_1
    glib-networking
  ];

  # Вход лежит в store как "source" без .deb, хук dpkg его не распознаёт
  unpackCmd = "dpkg -x $curSrc root";
  sourceRoot = "root";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r usr/bin usr/lib usr/share $out/
    substituteInPlace "$out/share/applications/Cockpit Tools.desktop" \
      --replace-fail 'Exec=cockpit-tools' "Exec=$out/bin/cockpit-tools"

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]}
      --suffix PATH : ${
        lib.makeBinPath [
          libsecret
          desktop-file-utils
          xdg-utils
        ]
      }
    )
  '';

  meta = {
    description = "AI IDE account manager with quota monitoring and multi-instance support";
    homepage = "https://github.com/jlcodes99/cockpit-tools";
    changelog = "https://github.com/jlcodes99/cockpit-tools/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.cc-by-nc-sa-40;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "cockpit-tools";
  };
})
