with (import <stockholm/lib>);
{ config, lib, pkgs, ... }:

{
  imports = [
    ./bitlbee.nix
  ];

  systemd.services.chat = let
    tmux = pkgs.writeDash "tmux" ''
      exec ${pkgs.tmux}/bin/tmux -f ${pkgs.writeText "tmux.conf" ''
        set-option -g prefix `
        unbind-key C-b
        bind ` send-prefix

        set-option -g status off
        set-option -g default-terminal screen-256color

        #use session instead of windows
        bind-key c new-session
        bind-key p switch-client -p
        bind-key n switch-client -n
        bind-key C-s switch-client -l
      ''} "$@"
    '';
  in {
    description = "chat environment setup";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    restartIfChanged = false;

    path = [
      pkgs.rxvt_unicode.terminfo
    ];

    serviceConfig = {
      User = "lass";
      RemainAfterExit = true;
      Type = "oneshot";
      ExecStart = "${tmux} -2 new-session -d -s IM ${pkgs.weechat}/bin/weechat";
      ExecStop = "${tmux} kill-session -t IM";
    };
  };
}
