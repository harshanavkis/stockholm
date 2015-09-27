{ lib, ... }:

with builtins;
with lib;
with types;

types // rec {

  host = submodule ({ config, ... }: {
    options = {
      name = mkOption {
        type = label;
      };
      dc = mkOption {
        type = label;
      };
      cores = mkOption {
        type = positive;
      };
      nets = mkOption {
        type = attrsOf net;
        apply = x: assert hasAttr "retiolum" x; x;
      };

      extraZones = mkOption {
        default = {};
        # TODO: string is either MX, NS, A or AAAA
        type = with types; attrsOf string;
      };

      infest = {
        addr = mkOption {
          type = str;
        };
        port = mkOption {
          type = int;
          default = 22;
        };
      };

      secure = mkOption {
        type = bool;
        default = false;
        description = ''
          If true, then the host is capable of keeping secret information.

          TODO define minimum requirements for secure hosts
        '';
      };

      ssh.pubkey = mkOption {
        type = nullOr str;
        default = null;
        apply = x:
          if x != null
            then x
            else trace "The option `krebs.hosts.${config.name}.ssh.pubkey' is unused." null;
      };
      ssh.privkey = mkOption {
        type = either path str;
        apply = x: {
          path = toString x;
          string = x;
        }.${typeOf x};
      };

    };
  });

  net = submodule ({ config, ... }: {
    options = {
      via = mkOption {
        type = nullOr net;
        default = null;
      };
      addrs = mkOption {
        type = listOf addr;
        default = config.addrs4 ++ config.addrs6;
        # TODO only default addrs make sense
      };
      addrs4 = mkOption {
        type = listOf addr4;
        default = [];
      };
      addrs6 = mkOption {
        type = listOf addr6;
        default = [];
      };
      aliases = mkOption {
        # TODO nonEmptyListOf hostname
        type = listOf hostname;
        default = [];
      };
      ssh = mkOption {
        type = submodule {
          options = {
            port = mkOption {
              type = nullOr int;
              default = null;
            };
          };
        };
        default = {};
      };
      tinc = mkOption {
        type = let net-config = config; in nullOr (submodule ({ config, ... }: {
          options = {
            config = mkOption {
              type = str;
              default = ''
                ${optionalString (net-config.via != null)
                  (concatMapStringsSep "\n" (a: "Address = ${a}") net-config.via.addrs)}
                ${concatMapStringsSep "\n" (a: "Subnet = ${a}") net-config.addrs}
                ${config.pubkey}
              '';
            };
            pubkey = mkOption {
              type = str;
            };
          };
        }));
        default = null;
      };
    };
  });

  positive = mkOptionType {
    name = "positive integer";
    check = x: isInt x && x > 0;
    merge = mergeOneOption;
  };

  user = submodule {
    options = {
      mail = mkOption {
        type = str; # TODO retiolum mail address
      };
      name = mkOption {
        type = str; # TODO
      };
      pubkey = mkOption {
        type = str;
      };
      pubkeys = mkOption {
        type = attrsOf str;
        default = {};
      };
    };
  };

  # TODO
  addr = str;
  addr4 = str;
  addr6 = str;
  hostname = str;
  label = str;
}
