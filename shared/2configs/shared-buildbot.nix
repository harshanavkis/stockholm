{ lib, config, pkgs, ... }:
# The buildbot config is seilf-contained and provides a way to test "shared"
# configuration (infrastructure to be used by every krebsminister).

# You can add your own test, test steps as required. Deploy the config on a
# shared host like wolf and everything should be fine.
{
  networking.firewall.allowedTCPPorts = [ 8010 9989 ];
  krebs.buildbot.master = {
    secrets = [ "retiolum-ci.rsa_key.priv" "cac.json" ];
    slaves = {
      testslave =  "krebspass";
    };
    change_source.stockholm = ''
  stockholm_repo = 'http://cgit.wolf/stockholm-mirror'
  cs.append(changes.GitPoller(
          stockholm_repo,
          workdir='stockholm-poller', branches=True,
          project='stockholm',
          pollinterval=120))
    '';
    scheduler = {
        force-scheduler = ''
  sched.append(schedulers.ForceScheduler(
                              name="force",
                              builderNames=["full-tests"]))
        '';
        fast-tests-scheduler = ''
  # test the master real quick
  sched.append(schedulers.SingleBranchScheduler(
                              ## all branches
                              change_filter=util.ChangeFilter(branch_re=".*"),
                              # change_filter=util.ChangeFilter(branch="master"),
                              treeStableTimer=10, #only test the latest push
                              name="fast-master-test",
                              builderNames=["fast-tests"]))
        '';
        test-cac-infest-master = ''
  # files everyone depends on or are part of the share branch
  def shared_files(change):
    r =re.compile("^((krebs|shared)/.*|Makefile|default.nix)")
    for file in change.files:
      if r.match(file):
        return True
    return False

  sched.append(schedulers.SingleBranchScheduler(
                              change_filter=util.ChangeFilter(branch="master"),
                              fileIsImportant=shared_files,
                              treeStableTimer=60*60, # master was stable for the last hour
                              name="full-master-test",
                              builderNames=["full-tests"]))
        '';
    };
    builder_pre = ''
  # prepare grab_repo step for stockholm
  grab_repo = steps.Git(repourl=stockholm_repo, mode='incremental')

  env = {"LOGNAME": "shared", "NIX_REMOTE": "daemon"}

  # prepare nix-shell
  # the dependencies which are used by the test script
  deps = [ "gnumake", "jq","nix","rsync",
            "(import <stockholm>).pkgs.test.infest-cac-centos7" ]
  # TODO: --pure , prepare ENV in nix-shell command:
  #                   SSL_CERT_FILE,LOGNAME,NIX_REMOTE
  nixshell = ["nix-shell",
                "-I", "stockholm=.",
                "-I", "nixpkgs=/var/src/upstream-nixpkgs",
                "-p" ] + deps + [ "--run" ]

  # prepare addShell function
  def addShell(factory,**kwargs):
    factory.addStep(steps.ShellCommand(**kwargs))
    '';
    builder = {
      fast-tests = ''
  f = util.BuildFactory()
  f.addStep(grab_repo)
  for i in [ "test-centos7", "wolf", "test-failing" ]:
    addShell(f,name="populate-{}".format(i),env=env,
            command=nixshell + \
                      ["{}( make system={} eval.config.krebs.build.populate \
                         | jq -er .)".format("!" if "failing" in i else "",i)])

  # XXX we must prepare ./retiolum.rsa_key.priv for secrets to work
  addShell(f,name="instantiate-test-all-modules",env=env,
            command=nixshell + \
                      ["touch retiolum.rsa_key.priv; \
                        nix-instantiate --eval -A \
                            users.shared.test-all-krebs-modules.system \
                            -I stockholm=. \
                            --show-trace \
                            -I secrets=. '<stockholm>' \
                            --strict --json"])

  addShell(f,name="instantiate-test-minimal-deploy",env=env,
            command=nixshell + \
                      ["nix-instantiate --eval -A \
                            users.shared.test-minimal-deploy.system \
                            -I stockholm=. \
                            -I secrets=. '<stockholm>' \
                            --show-trace \
                            --strict --json"])

  bu.append(util.BuilderConfig(name="fast-tests",
        slavenames=slavenames,
        factory=f))
      '';
      slow-tests = ''
  s = util.BuildFactory()
  s.addStep(grab_repo)

  # slave needs 2 files:
  # * cac.json
  # * retiolum
  s.addStep(steps.FileDownload(mastersrc="${config.krebs.buildbot.master.workDir}/cac.json", slavedest="cac.json"))
  s.addStep(steps.FileDownload(mastersrc="${config.krebs.buildbot.master.workDir}/retiolum-ci.rsa_key.priv", slavedest="retiolum.rsa_key.priv"))

  addShell(s, name="infest-cac-centos7",env=env,
              sigtermTime=60,           # SIGTERM 1 minute before SIGKILL
              timeout=10800,             # 3h
              command=nixshell + ["infest-cac-centos7"])

  bu.append(util.BuilderConfig(name="full-tests",
        slavenames=slavenames,
        factory=s))
      '';
    };
    enable = true;
    web = {
      enable = true;
    };
    irc = {
      enable = true;
      nick = "shared-buildbot";
      server = "cd.retiolum";
      channels = [ "retiolum" ];
      allowForce = true;
    };
  };

  krebs.buildbot.slave = {
    enable = true;
    masterhost = "localhost";
    username = "testslave";
    password = "krebspass";
    packages = with pkgs;[ git nix ];
    # all nix commands will need a working nixpkgs installation
    extraEnviron = { NIX_PATH="/var/src"; };
  };
}
