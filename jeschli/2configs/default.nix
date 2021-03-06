{ config, pkgs, ... }:
with import <stockholm/lib>;
{
  imports = [
#    ./vim.nix
    ./retiolum.nix
    ./zsh.nix
    <stockholm/lass/2configs/security-workarounds.nix>
    {
      environment.variables = {
        NIX_PATH = mkForce "secrets=/var/src/stockholm/null:/var/src";
      };
    }
  ];

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
  #stockholm
    git
    gnumake
    jq
    parallel
    proot
    populate

  # aliases
    (writeDashBin "irc" "ssh chat@enklave -t tmux a")

  #style
    most
    rxvt_unicode.terminfo

  #monitoring tools
    htop
    iotop

  #network
    iptables
    iftop

  #stuff for dl
    aria2

  #neat utils
    file
    kpaste
    krebspaste
    mosh
    pciutils
    psmisc
   # q
   # rs
    tmux
    untilport
    usbutils
  #  logify
    goify
    vim
  #unpack stuff
    p7zip
    unzip
    unrar

    (pkgs.writeDashBin "sshn" ''
      ${pkgs.openssh}/bin/ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$@"
    '')
  ];

  krebs.enable = true;
  networking.hostName = config.krebs.build.host.name;
}
