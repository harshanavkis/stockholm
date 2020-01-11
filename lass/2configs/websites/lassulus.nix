{ config, pkgs, lib, ... }:

with lib;
let
  inherit (import <stockholm/lib>)
    genid_uint31
  ;

in {
  imports = [
    ./default.nix
    ../git.nix
  ];

  security.acme = {
    certs."lassul.us" = {
      allowKeysForGroup = true;
      group = "lasscert";
    };
  };

  krebs.tinc_graphs.enable = true;

  users.groups.lasscert.members = [
    "dovecot2"
    "ejabberd"
    "exim"
    "nginx"
  ];

  services.nginx.virtualHosts."lassul.us" = {
    addSSL = true;
    enableACME = true;
    locations."/".extraConfig = ''
      root /srv/http/lassul.us;
    '';
    locations."= /retiolum-hosts.tar.bz2".extraConfig = ''
      alias ${config.krebs.tinc.retiolum.hostsArchive};
    '';
    locations."= /hosts".extraConfig = ''
      alias ${pkgs.krebs-hosts_combined};
    '';
    locations."= /retiolum.hosts".extraConfig = ''
      alias ${pkgs.krebs-hosts-retiolum};
    '';
    locations."= /wireguard-key".extraConfig = ''
      alias ${pkgs.writeText "prism.wg" config.krebs.hosts.prism.nets.wiregrill.wireguard.pubkey};
    '';
    locations."/tinc/".extraConfig = ''
      index index.html;
      alias ${config.krebs.tinc_graphs.workingDir}/external/;
    '';
    locations."= /krebspage".extraConfig = ''
      default_type "text/html";
      alias ${pkgs.krebspage}/index.html;
    '';
    locations."= /init".extraConfig = let
      initscript = pkgs.init.override {
        pubkey = config.krebs.users.lass.pubkey;
      };
    in ''
      alias ${initscript};
    '';
    locations."= /blue.pub".extraConfig = ''
      alias ${pkgs.writeText "pub" config.krebs.users.lass.pubkey};
    '';
    locations."= /mors.pub".extraConfig = ''
      alias ${pkgs.writeText "pub" config.krebs.users.lass-mors.pubkey};
    '';
  };

  security.acme.certs."cgit.lassul.us" = {
    email = "lassulus@lassul.us";
    webroot = "/var/lib/acme/acme-challenge";
    plugins = [
      "account_key.json"
      "fullchain.pem"
      "key.pem"
    ];
    group = "nginx";
    user = "nginx";
  };


  services.nginx.virtualHosts.cgit = {
    serverName = "cgit.lassul.us";
    addSSL = true;
    sslCertificate = "/var/lib/acme/cgit.lassul.us/fullchain.pem";
    sslCertificateKey = "/var/lib/acme/cgit.lassul.us/key.pem";
    locations."/.well-known/acme-challenge".extraConfig = ''
      root /var/lib/acme/acme-challenge;
    '';
  };

  users.users.blog = {
    uid = genid_uint31 "blog";
    description = "lassul.us blog deployment";
    home = "/srv/http/lassul.us";
    useDefaultShell = true;
    createHome = true;
    openssh.authorizedKeys.keys = with config.krebs.users; [
      lass.pubkey
      lass-mors.pubkey
    ];
  };
}

