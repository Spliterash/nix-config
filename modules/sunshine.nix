{ pkgs, ... }:
let
  #? В nixpkgs Sunshine отстаёт (2025.924.154138). Берём свежую версию
  #? 2026.516.143833 из ещё не влитого PR nixpkgs #521906 — там уже
  #? перегенерён package-lock.json веб-UI и обновлены все хеши.
  #? https://github.com/NixOS/nixpkgs/pull/521906
  #!
  #! Тянем не весь форк nixpkgs, а ровно два нужных файла по прямым
  #! raw-ссылкам (package.nix + обязательный для сборки web-UI
  #! package-lock.json) и собираем пакет из них через callPackage.
  #! Когда PR вмержат и обновится input nixpkgs — удалить этот let
  #! и строку `package =` ниже (вернётся обычный pkgs.sunshine).
  rev = "391d69d880514742b8612cbcd6480b5a8c3c08b5";
  raw =
    file: hash:
    pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/Qubasa/nixpkgs/${rev}/pkgs/by-name/su/sunshine/${file}";
      inherit hash;
    };
  # Собираем каталог пакета: package.nix внутри делает `cp ./package-lock.json`,
  # поэтому файл должен лежать рядом. updater.sh при сборке не нужен (только для
  # nix-update), но на него есть ссылка в passthru.updateScript — кладём заглушку.
  sunshineSrc = pkgs.runCommandLocal "sunshine-2026.516.143833-src" { } ''
    mkdir -p "$out"
    cp ${raw "package.nix" "sha256-uWcBTFHJoWLDUM8M7N8YAzNuTqhp5qhlIPAadgr4xBc="} "$out/package.nix"
    cp ${raw "package-lock.json" "sha256-ZTYMCd613XShVKAa0NHzOkC/Ytgk9iT0GCw5AUKEG0E="} "$out/package-lock.json"
    : > "$out/updater.sh"
  '';
  sunshinePkg = pkgs.callPackage "${sunshineSrc}/package.nix" { };
in
{
  services.sunshine = {
    enable = true;
    package = sunshinePkg;
    openFirewall = true;
    capSysAdmin = true;
    autoStart = true;
  };

  users.users.spliterash = {
    extraGroups = [
      "uinput"
      "input"
    ];
  };
}
