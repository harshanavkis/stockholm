{ config, lib, pkgs, ... }:

with config.krebs.lib;

{
  krebs.exim-smarthost = {
    enable = true;
    dkim = [
      { domain = "lassul.us"; }
    ];
    sender_domains = [
      "lassul.us"
    ];
    relay_from_hosts = map (host: host.nets.retiolum.ip4.addr) [
      config.krebs.hosts.mors
      config.krebs.hosts.uriel
      config.krebs.hosts.helios
    ];
    internet-aliases = with config.krebs.users; [
      { from = "postmaster@lassul.us"; to = lass.mail; } # RFC 822
      { from = "lass@lassul.us"; to = lass.mail; }
      { from = "lassulus@lassul.us"; to = lass.mail; }
      { from = "test@lassul.us"; to = lass.mail; }
    ];
    system-aliases = [
      { from = "mailer-daemon"; to = "postmaster"; }
      { from = "postmaster"; to = "root"; }
      { from = "nobody"; to = "root"; }
      { from = "hostmaster"; to = "root"; }
      { from = "usenet"; to = "root"; }
      { from = "news"; to = "root"; }
      { from = "webmaster"; to = "root"; }
      { from = "www"; to = "root"; }
      { from = "ftp"; to = "root"; }
      { from = "abuse"; to = "root"; }
      { from = "noc"; to = "root"; }
      { from = "security"; to = "root"; }
      { from = "root"; to = "lass"; }
    ];
  };

  krebs.setuid.sendmail = {
    filename = "${pkgs.exim}/bin/exim";
    mode = "4111";
  };
  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport smtp"; target = "ACCEPT"; }
  ];
}
