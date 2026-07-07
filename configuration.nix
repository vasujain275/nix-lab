{ config, pkgs, ... }:

{
  # ============================================================
  # BOOTLOADER
  # ============================================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ============================================================
  # HOSTNAME & NETWORKING
  # ============================================================
  networking.hostName = "nix-lab";

  # Use networkd + wpa_supplicant instead of NetworkManager
  # for reliable headless WiFi with static IP
  networking.networkmanager.enable = false;
  networking.wireless = {
    enable = true;
    # WiFi password lives in /etc/secrets/wireless.env
    # which is NOT in the Nix store (world-readable)
    # Format of that file: password=YOUR_ACTUAL_PASSWORD
    environmentFile = "/etc/secrets/wireless.env";
    networks."VJ-Wifi-2.4G" = {
      # @password@ is substituted from environmentFile at build time
      psk = "@password@";
    };
  };

  # Static IP via systemd-networkd
  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    networks."10-wlan" = {
      matchConfig.Name = "wl*";   # matches wlan0, wlp2s0, etc.
      address = [ "192.168.1.75/24" ];
      routes = [{ routeConfig.Gateway = "192.168.1.1"; }];
      dns = [ "1.1.1.1" "8.8.8.8" ];
      linkConfig.RequiredForOnline = "routable";
    };
  };

  # ============================================================
  # LOCALE & TIMEZONE
  # ============================================================
  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN";

  # ============================================================
  # SSH
  # Password auth enabled for now — switch to key-only later:
  #   settings.PasswordAuthentication = false;
  #   settings.KbdInteractiveAuthentication = false;
  # ============================================================
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  # ============================================================
  # USER
  # ============================================================
  users.users.vasu = {
    isNormalUser = true;
    description = "Vasu Jain";
    extraGroups = [ "wheel" "docker" "networkmanager" ];
    # Uncomment and add your key when switching to key-only auth:
    # openssh.authorizedKeys.keys = [
    #   "ssh-ed25519 AAAA... your-key-here"
    # ];
  };

  # Passwordless sudo for wheel group
  security.sudo.wheelNeedsPassword = false;

  # ============================================================
  # DOCKER + COMPOSE
  # ============================================================
  virtualisation.docker = {
    enable = true;
    # Auto-prune unused images/containers/volumes weekly
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
    # Start Docker on boot
    enableOnBoot = true;
  };

  # ============================================================
  # TAILSCALE
  # ============================================================
  services.tailscale.enable = true;
  # Allow Tailscale through firewall
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];

  # ============================================================
  # HDD MOUNT (/dev/sdb1 -> /mnt/data)
  # nofail = don't block boot if HDD isn't connected
  # ============================================================
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-label/data";
    fsType = "ext4";
    options = [ "defaults" "nofail" "x-systemd.device-timeout=10" ];
  };



  # ============================================================
  # FIREWALL
  # ============================================================
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH
      80    # HTTP (Caddy)
      443   # HTTPS (Caddy)
    ];
  };

  # ============================================================
  # SYSTEM PACKAGES
  # ============================================================
  environment.systemPackages = with pkgs; [
    # Essentials
    git
    vim
    curl
    wget
    htop
    btop

    # Docker compose (v2, plugin style)
    docker-compose

    # Disk health
    smartmontools
    hdparm

    # Network utils
    tailscale
    nmap
    dig

    # System utils
    lsof
    unzip
    rsync
    tmux
  ];

  # ============================================================
  # AUTOMATIC UPDATES (security patches only)
  # ============================================================
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;       # Never auto-reboot, you decide
    dates = "04:00";           # 4 AM IST
    flake = "github:vasujain275/homelab-nix#nix-lab"; # update this
  };

  # ============================================================
  # LID CLOSE / SLEEP / POWER — headless laptop fixes
  # ============================================================

  # Disable all sleep/suspend/hibernate triggers
  services.logind = {
    lidSwitch = "ignore";              # Do nothing when lid closed
    lidSwitchExternalPower = "ignore"; # Same when on AC power
    lidSwitchDocked = "ignore";        # Same when docked
    extraConfig = ''
      HandleSuspendKey=ignore
      HandleHibernateKey=ignore
      HandlePowerKey=ignore
      IdleAction=ignore
      IdleActionSec=0
    '';
  };

  # Disable systemd sleep targets entirely
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    "hybrid-sleep".enable = false;
  };

  # ============================================================
  # MISC
  # ============================================================

  # Don't install unnecessary default packages
  environment.defaultPackages = [ ];

  # Faster boot — skip fsck on every boot
  boot.initrd.checkJournalingFS = false;

  # Keep last 5 generations in bootloader
  boot.loader.systemd-boot.configurationLimit = 5;

  system.stateVersion = "24.11";
}
