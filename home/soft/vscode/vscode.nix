# VSCode: ставим декларативно вместе с расширением nix-ide.
#
# settings.json НЕ генерируем через nix, а держим обычным JSONC рядом
# (./settings.json) и симлинкаем в ~/.config через mkOutOfStoreSymlink. Nix файл
# не парсит и не переписывает → комментарии и висячие запятые целы, файл остаётся
# редактируемым (правки пишутся прямо в репо и версионируются). Так у товарища;
# jq-merge через mutableJson тут не годился — падал на JSONC и стёр бы комменты.
#
# userSettings НЕ задаём, enableUpdateCheck/enableExtensionUpdateCheck оставляем
# true — иначе home-manager сам создаст Code/User/settings.json и подерётся с
# симлинком (см. mkVscodeModule.nix: файл пишется только когда merged != {}).
#
# Детальный конфиг nixd для самого этого репо — отдельно, в ./.vscode/settings.json.
{ pkgs, config, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    profiles.default.extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
    ];
  };

  xdg.configFile."Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/home/soft/vscode/settings.json";
}
