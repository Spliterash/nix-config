{ pkgs, ... }:
#? https://wiki.nixos.org/wiki/Nix-ld
#? https://unix.stackexchange.com/a/522823
{
  # Фигня чтобы работало в жабагадюке (java+python)
  environment.sessionVariables.LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
  ];

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries =
    with pkgs;
    builtins.concatLists [
      #? nix-locate lib/libgobject-2.0.so.0
      [
        nss
        nspr
        cups
        # fuse3
        # icu
        expat
        # vulkan-headers
        # vulkan-tools

        libx11
        libxcb
        libxcomposite
        libxcursor
        libxdamage
        libxext
        libxfixes
        libxi
        libxkbcommon
        libxrandr
        libxrender
        libxtst
        # Чтобы работала штука для физике в майнкрафтееееее
        stdenv.cc.cc.lib

        at-spi2-atk
        alsa-lib
        cairo
        dbus
        fontconfig
        freetype
        gdk-pixbuf
        glib
        gtk3
        pango
        zlib # libz.so.1
      ]
      (steam-run.args.multiPkgs pkgs)
    ];
}
