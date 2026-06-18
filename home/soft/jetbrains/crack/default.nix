# Stolen from https://github.com/bebert64/nix-configs/blob/2f0a6f0bbc2b7ac85c3a8101c45566c8ca3ce1cd/programs/datagrip/jetbrains.nix
{
  pkgs,
  lib,
  ...
}:

let
  ja-jetfilter-base-url = "https://3.jetbra.in";
  ja-netfilter = pkgs.stdenv.mkDerivation {
    # https://jetbra.in/s
    name = "ja-netfilter";
    src = pkgs.fetchzip {
      url = "${ja-jetfilter-base-url}/files/jetbra-5a50fc03d68a014f893b7fc3aa465380d59f9095.zip";
      hash = "sha256-iCtLAmJ1uBU2VtU/EbgASI5Ws9pUJUpWxOB6xsZjgVs=";
    };
    installPhase = ''
      mkdir -p $out
      cp -ra --reflink=auto -- ./{ja-netfilter.jar,config-jetbrains,plugins-jetbrains} "$out"
    '';
  };
  product_code_overrides = {
    "pycharm" = "PC";
    "idea" = "II";
  };
  jetbrains-keys = pkgs.callPackage (
    { pkgs, stdenvNoCC }:
    stdenvNoCC.mkDerivation {
      name = "jetbrains-keys";

      src = pkgs.fetchurl {
        url = ja-jetfilter-base-url;
        hash = "sha256-cQc/LU13zDlv7f0ymBg7OBUJ7ISc+/TDrLpubQzAn1o=";
      };
      dontUnpack = true;

      env = {
        jetbrains_keys_bin_path = lib.makeBinPath (
          with pkgs;
          [
            jq
            xclip
            iconv
          ]
        );
        ja_netfilter_base_url = ja-jetfilter-base-url;
      };

      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin
        cat "$src" | grep "let jbKeys = " | sed -E 's/^[^{]*(\{.*\})+.*$/\1/' > "$out/jetbrains-keys.json"
        substituteAll ${./jetbrains-keys.sh} "$out/bin/jetbrains-keys"
        chmod 555 "$out/bin/jetbrains-keys"
        chmod 444 "$out/jetbrains-keys.json"
        chmod 555 "$out"

        runHook postInstall
      '';
    }
  ) { };
  # Подключает к одной IDE javaagent ja-netfilter (обход проверки лицензии).
  with-ja-netfilter =
    product:
    product.overrideAttrs (oldAttrs: {
      postFixup = (oldAttrs.postFixup or "") + ''
        set -eo pipefail

        VM_OPTIONS_FILE_PATH=$(${pkgs.jq}/bin/jq -r '.launch[].vmOptionsFilePath' "$out/$pname/product-info.json")
        cat <<EOF >> $out/$pname/$VM_OPTIONS_FILE_PATH

        --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED
        --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED

        -javaagent:${ja-netfilter}/ja-netfilter.jar=jetbrains
        EOF
      '';
    });
  # Добавляет автоматическую генерацию ключа активации при каждом запуске.
  # `name` нужен только для подбора product code (см. product_code_overrides).
  with-auto-activation =
    name: product:
    product.overrideAttrs (oldAttrs: {
      postFixup = (oldAttrs.postFixup or "") + ''
        PRODUCT_INFO_JSON="$out/$pname/product-info.json"
        IDE_BIN_PATH=$(${pkgs.jq}/bin/jq -r '.launch[].launcherPath' "$PRODUCT_INFO_JSON")
        PRODUCT_CODE="${
          product_code_overrides.${name}
            or (product_code_overrides.${builtins.head (lib.splitString "-" name)}
            or ''$(${pkgs.jq}/bin/jq -r '.productCode' "$PRODUCT_INFO_JSON")''
            )
        }"
        APPDATA=$(${pkgs.jq}/bin/jq -r '.dataDirectoryName' $PRODUCT_INFO_JSON)
        APPDATA="\$HOME/.config/JetBrains/$APPDATA"
        APPDATA_DIR_WITHOUT_VERSION=$(echo "$APPDATA" | sed -E 's/20[0-9.]+$//')
        KEY_FILE_PREFIX=$(${pkgs.jq}/bin/jq -r '.launch[].launcherPath' $PRODUCT_INFO_JSON)
        KEY_FILE_PREFIX=$(basename $KEY_FILE_PREFIX)
        KEY_FILE_PREFIX=''${KEY_FILE_PREFIX%.*}
        sed -i "2i${jetbrains-keys}/bin/jetbrains-keys '$PRODUCT_CODE' \"$APPDATA/$KEY_FILE_PREFIX.key\" \"$APPDATA_DIR_WITHOUT_VERSION\" " "$out/$pname/$IDE_BIN_PATH"
      '';
    });
  # Полная обёртка для одной IDE: ja-netfilter + автоактивация.
  # Применять ДО buildIdeWithPlugins (плагины копируют уже пропатченную IDE).
  wrap = name: product: with-auto-activation name (with-ja-netfilter product);
in

# Готовый набор всех IDE (как pkgs.jetbrains, но пропатченный) + функции-обёртки.
builtins.mapAttrs wrap pkgs.jetbrains
// {
  inherit
    jetbrains-keys
    wrap
    with-ja-netfilter
    with-auto-activation
    ;
  no-auto-activation = builtins.mapAttrs (_: with-ja-netfilter) pkgs.jetbrains;
}
