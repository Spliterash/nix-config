{ pkgs, ... }: {
  home.packages = with pkgs; [
    ffmpeg-full
  ];
  programs = {
    yt-dlp = {
      enable = true;
    };
  };
}
