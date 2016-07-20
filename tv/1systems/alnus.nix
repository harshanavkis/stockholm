{ config, pkgs, ... }:

with config.krebs.lib;

{
  imports = [
    ../.
    ../2configs/hw/x220.nix
    ../2configs/exim-retiolum.nix
    ../2configs/retiolum.nix
  ];

  # TODO remove non-hardware stuff from ../2configs/hw/x220.nix
  # networking.wireless.enable collides with networkmanager
  networking.wireless.enable = mkForce false;

  boot = {
    initrd = {
      availableKernelModules = [ "ahci" ];
      luks = {
        cryptoModules = [ "aes" "sha512" "xts" ];
        devices = [ { name = "luksroot"; device = "/dev/sda2"; } ];
      };
    };
    loader = {
      efi.canTouchEfiVariables = true;
      gummiboot.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    chromium
    firefoxWrapper
    networkmanagerapplet
    pidginotr
    pidgin-with-plugins
  ];

  fileSystems = {
    "/boot" = {
      device = "/dev/sda1";
    };
    "/" = {
      device = "/dev/mapper/main-root";
      fsType = "btrfs";
      options = [ "defaults" "noatime" ];
    };
    "/home" = {
      device = "/dev/mapper/main-home";
      fsType = "btrfs";
      options = [ "defaults" "noatime" ];
    };
  };

  hardware = {
    enableAllFirmware = true;
    opengl.driSupport32Bit = true;
    pulseaudio.enable = true;
  };

  i18n.defaultLocale = "de_DE.UTF-8";

  krebs.build = {
    host = config.krebs.hosts.alnus;
    user = mkForce config.krebs.users.dv;
    source.nixpkgs.git.ref = mkForce "d7450443c42228832c68fba203a7c15cfcfb264e";
  };

  networking.networkmanager.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    chromium.enablePepperFlash = true;
    firefox.enableAdobeFlash = true;
  };

  services.xserver = {
    enable = true;
    layout = "de";
    xkbOptions = "eurosign:e";
    synaptics = {
      enable = true;
      twoFingerScroll = true;
    };
    desktopManager.xfce.enable = true;
    displayManager.auto = {
      enable = true;
      user = "dv";
    };
  };

  swapDevices =[ ];

  users.users.dv = {
    inherit (config.krebs.users.dv) home uid;
    isNormalUser = true;
    extraGroups = [
      "audio"
      "video"
      "networkmanager"
    ];
  };
}