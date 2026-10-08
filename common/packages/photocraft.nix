{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  libGL,
  vulkan-loader,
  libx11,
  libxcursor,
  libxi,
  libxcb,
  wayland,
  libxkbcommon,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "photocraft";
  version = "0.3.0";

  src = fetchurl {
    url = "https://github.com/storytold/photocraft/releases/download/v${finalAttrs.version}/photocraft-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-6POvavrlOopNbrE6v7zPdLj/whQ+SHBH1yTlaD1c/z0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r bin share $out/
    wrapProgram $out/bin/photocraft \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libGL
          vulkan-loader
          libx11
          libxcursor
          libxi
          libxcb
          wayland
          libxkbcommon
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Image editor with layers, masks and PSD support";
    homepage = "https://github.com/storytold/photocraft";
    license = with lib.licenses; [
      mit
      asl20
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "photocraft";
  };
})
