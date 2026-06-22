# Вливает декларативные значения в JSON-конфиги, которые программа пишет сама.
# В отличие от home.file/xdg.configFile — не перетирает файл целиком и не делает
# его read-only: мердж происходит в activation-скрипте через jq поверх того,
# что уже лежит на диске. Твои значения имеют приоритет, остальное сохраняется.
#
# Два способа задавать значения на каждый путь:
#
#   # 1) settings — рекурсивный мердж объекта в корень (массивы заменяются целиком)
#   mutableJson."${config.home.homeDirectory}/.config/Foo/config.json".settings = {
#     theme = "dark";
#     nested.foo = "bar";
#   };
#
#   # 2) set — точечное присваивание по jq-пути (работают индексы массивов).
#   #    Скаляр заменяет значение, объект — сливается с тем, что было по пути.
#   mutableJson."${config.home.homeDirectory}/.sourcegit/preference.json".set = [
#     { path = [ "Workspaces" 0 "DefaultCloneDir" ]; value = "/home/spliterash/projects"; }
#   ];
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.mutableJson;
  jsonFormat = pkgs.formats.json { };

  # jq-фильтр для одного точечного присваивания: объект сливается, скаляр заменяет.
  setFilter =
    i: _:
    let
      v = "$v${toString i}";
      p = "$p${toString i}";
    in
    "\n  | setpath(${p}; ((getpath(${p}) // null) as $cur"
    + " | if ($cur|type) == \"object\" and (${v}|type) == \"object\""
    + " then ($cur * ${v}) else ${v} end))";

  setArg =
    i: e:
    "--argjson p${toString i} ${lib.escapeShellArg (builtins.toJSON e.path)} "
    + "--argjson v${toString i} ${lib.escapeShellArg (builtins.toJSON e.value)}";

  mergeOne =
    path: opts:
    let
      managed = jsonFormat.generate "mutable-json.json" opts.settings;
      p = lib.escapeShellArg path;
      args = lib.concatStringsSep " " (lib.imap0 setArg opts.set);
      filter = "(. * $managed[0])" + lib.concatStrings (lib.imap0 setFilter opts.set);
    in
    ''
      mkdir -p ${lib.escapeShellArg (builtins.dirOf path)}
      [ -e ${p} ] || echo '{}' > ${p}
      ${pkgs.jq}/bin/jq --slurpfile managed ${managed} ${args} '${filter}' ${p} > ${p}.hm-tmp
      chmod u+w ${p}.hm-tmp
      mv -f ${p}.hm-tmp ${p}
    '';

  pathEntry = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = with lib.types; listOf (either str int);
        example = [
          "Workspaces"
          0
          "DefaultCloneDir"
        ];
        description = "jq-путь до значения (строки — ключи, числа — индексы массивов).";
      };
      value = lib.mkOption {
        type = jsonFormat.type;
        description = "Значение: объект сольётся с тем, что по пути, скаляр заменит.";
      };
    };
  };

  fileEntry = lib.types.submodule {
    options = {
      settings = lib.mkOption {
        type = jsonFormat.type;
        default = { };
        description = "Объект для рекурсивного мерджа в корень файла.";
      };
      set = lib.mkOption {
        type = lib.types.listOf pathEntry;
        default = [ ];
        description = "Точечные присваивания по jq-пути (для глубоких путей и массивов).";
      };
    };
  };
in
{
  options.mutableJson = lib.mkOption {
    type = lib.types.attrsOf fileEntry;
    default = { };
    description = "Мердж декларативных значений в мутабельные JSON-конфиги программ.";
  };

  config = lib.mkIf (cfg != { }) {
    home.activation.mutableJson = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      lib.concatStringsSep "\n" (lib.mapAttrsToList mergeOne cfg)
    );
  };
}
