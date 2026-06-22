{ pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    settings = {
      mgr.show_hidden = true;
      mgr.linemode = "size_mtime";
      plugin.prepend_previewers = [
        {
          url = "*.csv";
          run = "rich-preview";
        } # for csv files
        {
          url = "*.md";
          run = "rich-preview";
        } # for markdown (.md) files
        {
          url = "*.rst";
          run = "rich-preview";
        } # for restructured text (.rst) files
        {
          url = "*.ipynb";
          run = "rich-preview";
        } # for jupyter notebooks (.ipynb)
        {
          url = "*.json";
          run = "rich-preview";
        } # for json (.json) files
      ];
    };
    plugins = with pkgs.yaziPlugins; {
      smart-enter = smart-enter;
      rich-preview = rich-preview;
    };
    #? https://github.com/sxyazi/yazi/tree/shipped/yazi-config/preset
    keymap = {
      mgr = {
        prepend_keymap = [
          {
            on = "<F2>";
            run = "rename";
            desc = "Rename file or folder";
          }
          #? https://github.com/sxyazi/yazi/issues/1758#issuecomment-2407103834
          {
            on = "<Enter>";
            run = "plugin --sync smart-enter";
            desc = "Enter the child directory, or open the file";
          }
          {
            on = [
              "m"
              "a"
            ];
            run = "linemode size_mtime";
            desc = "Show size and modification time";
          }
        ];
      };
    };
    initLua = ./init.lua;
  };
}
