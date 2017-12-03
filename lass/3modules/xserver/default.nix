{ config, pkgs, ... }@args:
with import <stockholm/lib>;
let

  out = {
    options.lass.xserver = api;
    config = mkIf cfg.enable imp;
  };

  user = config.krebs.build.user;

  cfg = config.lass.xserver;
  api = {
    enable = mkEnableOption "lass xserver";
  };
  imp = {

    services.xserver = {
      # Don't install feh into systemPackages
      # refs <nixpkgs/nixos/modules/services/x11/desktop-managers>
      desktopManager.session = mkForce [];

      enable = true;
      display = 11;
      tty = 11;
    };

    systemd.services.display-manager.enable = false;

    systemd.services.xmonad = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "xserver.service" ];
      environment = {
        DISPLAY = ":${toString config.services.xserver.display}";

        XMONAD_STARTUP_HOOK = pkgs.writeDash "xmonad-startup-hook" ''
          ${pkgs.xorg.xhost}/bin/xhost +LOCAL: &
          ${config.services.xserver.displayManager.sessionCommands}
          wait
        '';

        XMONAD_DATA_DIR = "/tmp";
      };
      serviceConfig = {
        SyslogIdentifier = "xmonad";
        ExecStart = "${pkgs.xmonad-lass}/bin/xmonad";
        ExecStop = "${pkgs.xmonad-lass}/bin/xmonad --shutdown";
        User = user.name;
        WorkingDirectory = user.home;
      };
    };

    systemd.services.xserver = {
      after = [
        "systemd-udev-settle.service"
        "local-fs.target"
        "acpid.service"
      ];
      reloadIfChanged = true;
      environment = {
        XKB_BINDIR = "${pkgs.xorg.xkbcomp}/bin"; # Needed for the Xkb extension.
        XORG_DRI_DRIVER_PATH = "/run/opengl-driver/lib/dri"; # !!! Depends on the driver selected at runtime.
        LD_LIBRARY_PATH = concatStringsSep ":" (
          [ "${pkgs.xorg.libX11}/lib" "${pkgs.xorg.libXext}/lib" ]
          ++ concatLists (catAttrs "libPath" config.services.xserver.drivers));
      };
      serviceConfig = {
        SyslogIdentifier = "xserver";
        ExecReload = "${pkgs.coreutils}/bin/echo NOP";
        ExecStart = toString [
          "${pkgs.xorg.xorgserver}/bin/X"
          ":${toString config.services.xserver.display}"
          "vt${toString config.services.xserver.tty}"
          "-config ${import ./xserver.conf.nix args}"
          "-logfile /dev/null -logverbose 0 -verbose 3"
          "-nolisten tcp"
          "-xkbdir ${pkgs.xkeyboard_config}/etc/X11/xkb"
        ];
      };
    };
    systemd.services.urxvtd = {
      wantedBy = [ "multi-user.target" ];
      reloadIfChanged = true;
      serviceConfig = {
        SyslogIdentifier = "urxvtd";
        ExecReload = "${pkgs.coreutils}/bin/echo NOP";
        ExecStart = "${pkgs.rxvt_unicode_with-plugins}/bin/urxvtd";
        Restart = "always";
        RestartSec = "2s";
        StartLimitBurst = 0;
        User = user.name;
      };
    };
  };

in out
