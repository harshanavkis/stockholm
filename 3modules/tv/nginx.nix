{ config, pkgs, lib, ... }:

with builtins;
with lib;
let
  cfg = config.tv.nginx;

  out = {
    options.tv.nginx = api;
    config = mkIf cfg.enable imp;
  };

  api = {
    enable = mkEnableOption "tv.nginx";

    servers = mkOption {
      type = with types; attrsOf optionSet;
      options = singleton {
        server-names = mkOption {
          type = with types; listOf str;
          default = [
            "${config.networking.hostName}"
            "${config.networking.hostName}.retiolum"
          ];
        };
        locations = mkOption {
          type = with types; listOf (attrsOf str);
        };
      };
      default = {};
    };
  };

  imp = {
    services.nginx = {
      enable = true;
      httpConfig = ''
        include           ${pkgs.nginx}/conf/mime.types;
        default_type      application/octet-stream;
        sendfile          on;
        keepalive_timeout 65;
        gzip              on;
        server {
          listen 80 default_server;
          server_name _;
          return 404;
        }
        ${concatStrings (mapAttrsToList (_: to-server) cfg.servers)}
      '';
    };
  };

  
  indent = replaceChars ["\n"] ["\n  "];

  to-location = { name, value }: ''
    location ${name} {
      ${indent value}
    }
  '';

  to-server = { server-names, locations, ... }: ''
    server {
      listen 80;
      server_name ${toString server-names};
      ${indent (concatStrings (map to-location locations))}
    }
  '';

in
out


#let
#  cfg = config.tv.nginx;
#  arg' = arg // { inherit cfg; };
#in
#
#{
#  options.tv.nginx = import ./options.nix arg';
#  config = lib.mkIf cfg.enable (import ./config.nix arg');
#}
