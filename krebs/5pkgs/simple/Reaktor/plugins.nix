{ stdenv, lib, pkgs, makeWrapper }:

rec {
  # Begin API
  buildBaseReaktorPlugin = { name
                        , config # python extra configuration for plugin
                        , phases ? []
                        , ... } @ attrs:
    stdenv.mkDerivation (attrs // {
      name = "Reaktor-plugin-" + name;
      isReaktorPlugin = true;
    });

  buildSimpleReaktorPlugin = name: { script
                        , path ? []
                        , env ? {}
                        , append_rule ? false # append the rule instead of insert
                        , pattern ? ""
                        , ... } @ attrs:
    let
      path_env = { "PATH" = lib.makeSearchPath "bin" (path ++ [ pkgs.coreutils ]); };
      src_dir = pkgs.substituteAll ( {
        inherit name;
        dir = "bin";
        isExecutable = true;
        src = script;
      });
      src_file = "${src_dir}/bin/${name}";
      config = ''
        public_commands.${if append_rule then "append(" else "insert(0," }{
          'capname' : "${name}",
          'pattern' : ${if pattern == "" then
                          ''indirect_pattern.format("${name}")'' else
                          ''"${pattern}"'' },
          'argv'    : ["${src_file}"],
          'env'     : ${builtins.toJSON (path_env // env)} })
      '';
      config_file = pkgs.writeText "plugin.py" config;
    in buildBaseReaktorPlugin (attrs // rec {
      inherit name config;

      phases = [ "installPhase" ];
      buildInputs = [ makeWrapper ];
      installPhase = ''
        mkdir -p $out/bin $out/etc/Reaktor
        ln -s ${src_file} $out/bin
        wrapProgram $out/bin/${name} \
          --prefix PATH : ${path_env.PATH}
        ln -s ${config_file} $out/etc/Reaktor/plugin.py
      '';

    });
  # End API

  # Begin Plugins
  random-emoji = buildSimpleReaktorPlugin "emoji" {
    path = with pkgs; [ gnused gnugrep xmlstarlet curl ];
    script = ./scripts/random-emoji.sh;
  };

  sed-plugin = buildSimpleReaktorPlugin "sed-plugin" {
    path = [ pkgs.gnused pkgs.python3 ];
    # only support s///gi the plugin needs to see every msg
    # TODO: this will eat up the last regex, fix Reaktor to support fallthru
    append_rule = true;
    pattern = "^(?P<args>.*)$$";
    script = ./scripts/sed-plugin.py;
  };

  shack-correct = buildSimpleReaktorPlugin "shack-correct" {
    path = [ pkgs.gnused ];
    pattern = "^(?P<args>.*Shack.*)$$";
    script = ./scripts/shack-correct.sh;
  };

  nixos-version = buildSimpleReaktorPlugin "nixos-version" {
    script = pkgs.writeDash "nixos-version" ''
      . /etc/os-release
      echo "$PRETTY_NAME"
      '';
  };
  stockholm-issue = buildSimpleReaktorPlugin "stockholm-issue" {
    script = ./scripts/random-issue.sh;
    path = with pkgs; [ git gnused haskellPackages.lentil ];
    env = { "origin" = "http://cgit.gum/stockholm"; };
  };

  titlebot =
  let
    pypkgs = pkgs.python3Packages;
    titlebot_cmds =  pypkgs.buildPythonPackage {
      name = "titlebot_cmds";
      propagatedBuildInputs =  with pypkgs; [ setuptools ];
      src = pkgs.fetchurl {
        url = "https://github.com/makefu/reaktor-titlebot/archive/2.1.0.tar.gz";
        sha256 = "0wvf09wmk8b52f9j65qrw81nwrhs9pfhijwrlkzp5l7l2q8cjkp6";
        };
      };
  in buildBaseReaktorPlugin rec {
    name = "titlebot";
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out
      ln -s ${titlebot_cmds}/* $out
    '';
    config = ''
      def titlebot_cmd(cmd):
        from os import environ
        return {  'capname': None,
                  'env': { 'TITLEDB':
                    environ['state_dir']+'/suggestions.json' },
                  'pattern': '^\\.' + cmd + '\\s*(?:\\s+(?P<args>.*))?$$',
                  'argv': [ '${titlebot_cmds}/bin/' + cmd ] }
      for i in ['up','help','list','top','new']:
        public_commands.insert(0,titlebot_cmd(i))
      commands.insert(0,titlebot_cmd('clear'))
    '';
  };

  url-title = (buildSimpleReaktorPlugin "url-title" {
    pattern = "^.*(?P<args>http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\(\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+).*$$";
    path = with pkgs; [ curl perl ];
    script = pkgs.writePython3 "url-title" { deps = with pkgs.python3Packages; [ beautifulsoup4 lxml ]; } ''
      import cgi
      import sys
      import urllib.request
      from bs4 import BeautifulSoup

      try:
          req = urllib.request.Request(sys.argv[1])
          req.add_header('user-agent', 'Reaktor-url-title')
          resp = urllib.request.urlopen(req)
          if resp.headers['content-type'].find('text/html') >= 0:
              soup = BeautifulSoup(resp.read(16000), "lxml")
              title = soup.find('title').string

              if len(title.split('\n')) > 5:
                  title = '\n'.join(title.split('\n')[:5])

              print(title[:450])
          else:
              cd_header = resp.headers['content-disposition']
              print(cgi.parse_header(cd_header)[1]['filename'])
      except:  # noqa: E722
          pass
    '';
  });

  task = name: let
    rcFile = builtins.toFile "taskrc" ''
      confirmation=no
    '';
  in {
    add = buildSimpleReaktorPlugin "${name}-task-add" {
      pattern = "^${name}-add: (?P<args>.*)$$";
      script = pkgs.writeDash "${name}-add" ''
        TASKDATA=$HOME/${name} ${pkgs.taskwarrior}/bin/task rc:${rcFile} add "$*"
      '';
    };

    list = buildSimpleReaktorPlugin "task-list" {
      pattern = "^${name}-list";
      script = pkgs.writeDash "task-list" ''
        TASKDATA=$HOME/${name} ${pkgs.taskwarrior}/bin/task rc:${rcFile} export | ${pkgs.jq}/bin/jq -r '.[] | select(.id != 0) | "\(.id) \(.description)"'
      '';
    };

    delete = buildSimpleReaktorPlugin "task-delete" {
      pattern = "^${name}-delete: (?P<args>.*)$$";
      script = pkgs.writeDash "task-delete" ''
        TASKDATA=$HOME/${name} ${pkgs.taskwarrior}/bin/task rc:${rcFile} delete "$*"
      '';
    };

    done = buildSimpleReaktorPlugin "task-done" {
      pattern = "^${name}-done: (?P<args>.*)$$";
      script = pkgs.writeDash "task-done" ''
        TASKDATA=$HOME/${name} ${pkgs.taskwarrior}/bin/task rc:${rcFile} done "$*"
      '';
    };
  };
}
