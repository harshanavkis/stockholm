{ lib, config, pkgs, ... }:

with import <stockholm/lib>;

let
  sshHostConfig = pkgs.writeText "ssh-config" ''
    ControlMaster auto
    ControlPath /tmp/%u_sshmux_%r@%h:%p
    ControlPersist 4h
  '';

in {
  config.services.nginx.virtualHosts.build = {
    serverAliases = [ "build.prism.r" ];
    locations."/".extraConfig = ''
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_pass http://localhost:${toString config.krebs.buildbot.master.web.port};
    '';
  };

  config.krebs.buildbot.master = let
    stockholm-mirror-url = http://cgit.prism.r/stockholm ;
  in {
    slaves = {
      testslave = "lasspass";
    };
    change_source.stockholm = ''
      stockholm_repo = '${stockholm-mirror-url}'
      cs.append(
          changes.GitPoller(
              stockholm_repo,
              workdir='stockholm-poller', branches=True,
              project='stockholm',
              pollinterval=10
          )
      )
    '';
    scheduler = {
      build-scheduler = ''
        # build all hosts
        sched.append(
              schedulers.SingleBranchScheduler(
                  change_filter=util.ChangeFilter(branch_re=".*"),
                  treeStableTimer=10,
                  name="build-all-branches",
                  builderNames=["build-hosts"]
              )
        )
      '';
    };
    builder_pre = ''
      # prepare grab_repo step for stockholm
      grab_repo = steps.Git(
          repourl=stockholm_repo,
          mode='full'
      )

      # prepare addShell function
      def addShell(factory,**kwargs):
        factory.addStep(steps.ShellCommand(**kwargs))
    '';
    builder = {
      build-hosts = ''
        f = util.BuildFactory()
        f.addStep(grab_repo)

        def build_host(user, host):
            addShell(f,
                name="{}".format(i),
                env={
                  "LOGNAME": user,
                  "NIX_PATH": "secrets=/var/src/stockholm/null:/var/src",
                  "NIX_REMOTE": "daemon",
                  "dummy_secrets": "true",
                },
                command=[
                  "nix-shell", "--run",
                  "test --system={} --target=buildbotSlave@${config.krebs.build.host.name}$HOME/$LOGNAME".format(host)
                ]
            )

        for i in [ "hotdog", "puyak", "test-all-krebs-modules", "test-centos7", "test-minimal-deploy", "wolf" ]:
            build_host("krebs", i)

        for i in [ "mors", "uriel", "shodan", "icarus", "cloudkrebs", "echelon", "dishfire", "prism" ]:
            build_host("lass", i)

        for i in [ "x", "wry", "vbob", "wbob", "shoney" ]:
            build_host("makefu", i)

        for i in [ "hiawatha", "onondaga" ]:
            build_host("nin", i)

        for i in [ "alnus", "mu", "nomic", "wu", "xu", "zu" ]:
            build_host("tv", i)

        bu.append(
            util.BuilderConfig(
                name="build-hosts",
                slavenames=slavenames,
                factory=f
            )
        )

      '';
    };
    enable = true;
    web.enable = true;
    irc = {
      enable = true;
      nick = "buildbot-lass";
      server = "ni.r";
      channels = [ "retiolum" "noise" ];
      allowForce = true;
    };
    extraConfig = ''
      c['buildbotURL'] = "http://build.prism.r/"
    '';
  };

  config.krebs.buildbot.slave = {
    enable = true;
    masterhost = "localhost";
    username = "testslave";
    password = "lasspass";
    packages = with pkgs; [ gnumake jq nix populate ];
  };
  config.krebs.iptables = {
    tables = {
      filter.INPUT.rules = [
        { predicate = "-p tcp --dport 9989"; target = "ACCEPT"; }
      ];
    };
  };

  #ssh workaround for make test
  options.lass.build-ssh-privkey = mkOption {
    type = types.secret-file;
    default = {
      path = "${config.users.users.buildbotSlave.home}/.ssh/id_rsa";
      owner = { inherit (config.users.users.buildbotSlave ) name uid;};
      source-path = toString <secrets> + "/build.ssh.key";
    };
  };
  config.krebs.secret.files = {
    build-ssh-privkey = config.lass.build-ssh-privkey;
  };
  config.users.users.buildbotSlave = {
    useDefaultShell = true;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDiV0Xn60aVLHC/jGJknlrcxSvKd/MVeh2tjBpxSBT3II9XQGZhID2Gdh84eAtoWyxGVFQx96zCHSuc7tfE2YP2LhXnwaxHTeDc8nlMsdww53lRkxihZIEV7QHc/3LRcFMkFyxdszeUfhWz8PbJGL2GYT+s6CqoPwwa68zF33U1wrMOAPsf/NdpSN4alsqmjFc2STBjnOd9dXNQn1VEJQqGLG3kR3WkCuwMcTLS5eu0KLwG4i89Twjy+TGp2QsF5K6pNE+ZepwaycRgfYzGcPTn5d6YQXBgcKgHMoSJsK8wqpr0+eFPCDiEA3HDnf76E4mX4t6/9QkMXCLmvs0IO/WP"
    ];
  };
}
