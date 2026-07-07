# nix-lab

> NixOS flake configuration for Dell Inspiron 5000 (i3-6006U, 8GB DDR4) running as a headless homelab server.

## Hardware

| Component | Spec |
|-----------|------|
| CPU | Intel i3-6006U |
| RAM | 8GB DDR4 |
| OS Drive | 512GB SSD (sda) |
| Data Drive | 1TB HDD (sdb) mounted at `/mnt/data` |
| Network | WiFi — VJ-Wifi-2.4G @ 192.168.1.75 (static) |

## What's included

- NixOS 24.11 (stable)
- Docker + Docker Compose
- Tailscale
- WiFi with static IP via systemd-networkd
- Lid close / sleep fully disabled (headless laptop)
- SSH with password auth (key-only migration guide below)
- Weekly Docker auto-prune
- HDD auto-mount with `nofail`
- Firewall with ports 22, 80, 443 open

---

## First-time Installation

### Prerequisites

- NixOS minimal ISO flashed to USB
- New SSD installed in the laptop
- Your WiFi password handy

---

### Step 1 — Flash NixOS ISO

On your Arch desktop:

```bash
# Download NixOS 24.11 minimal ISO from https://nixos.org/download
# Select: NixOS -> Minimal ISO -> x86_64-linux

# Flash to USB (replace sdX with your USB drive — check with lsblk first)
sudo dd if=nixos-minimal-24.11-x86_64-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

---

### Step 2 — Boot into NixOS Installer

- Plug USB into Dell Inspiron
- Power on and spam **F12** to get boot menu
- Select your USB drive
- Wait for shell prompt

---

### Step 3 — Connect to WiFi in live environment

```bash
# Start wpa_supplicant temporarily
sudo systemctl start wpa_supplicant

# Connect to your WiFi
wpa_cli
> add_network
> set_network 0 ssid "VJ-Wifi-2.4G"
> set_network 0 psk "YOUR_PASSWORD"
> enable_network 0
> quit

# Verify you have internet
ping -c 3 1.1.1.1
```

---

### Step 4 — Clone the repo and run disko

**disko** is a declarative partitioning tool. Instead of typing fdisk commands
manually, the disk layout is defined in [`disk-config.nix`](disk-config.nix) —
the exact same partitioning, just in code.

```bash
# Install git in the live environment
nix-shell -p git

# Clone the repo to /tmp (we'll move it after mounting)
git clone https://github.com/vasujain275/nix-lab /tmp/nix-lab
cd /tmp/nix-lab

# Identify your SSD — should be sda (SATA) or nvme0n1 (NVMe)
lsblk

# If your SSD shows as /dev/nvme0n1 instead of /dev/sda,
# edit disk-config.nix before running disko:
#   nano disk-config.nix  → change "/dev/sda" to "/dev/nvme0n1"

# Run disko — this partitions, formats, mounts to /mnt, and creates a 4GB swapfile
nix run github:nix-community/disko -- --mode disko ./disk-config.nix
```

**What disko does for you (all in one command):**
1. Creates GPT partition table on the SSD
2. 512MB EFI partition (fat32, mounted at `/boot`)
3. Rest of SSD as ext4 root (`/`)
4. 4GB swapfile at `/swapfile`
5. Mounts everything to `/mnt`

---

### Step 5 — Move repo and generate hardware config

```bash
# Now the SSD is mounted at /mnt — move the repo there
mv /tmp/nix-lab /mnt/etc/nixos/nix-lab

# Generate hardware config (detects CPU modules, filesystems, etc.)
cd /mnt/etc/nixos/nix-lab
nixos-generate-config --root /mnt

# Copy the generated hardware config into the repo and commit later
cp /mnt/etc/nixos/hardware-configuration.nix ./hardware-configuration.nix
```

This creates:
- `hardware-configuration.nix` — auto-detected hardware, committed after install

---

### Step 6 — Create the WiFi secrets file

This is the most important step for security. The WiFi password must NOT go in configuration.nix (it would end up world-readable in the Nix store).

```bash
# Create secrets directory with restricted permissions
sudo mkdir -p /mnt/etc/secrets
sudo chmod 700 /mnt/etc/secrets

# Create the secrets file
sudo nano /mnt/etc/secrets/wireless.env
```

Add this single line (replace with your actual password):
```
password=YOUR_ACTUAL_WIFI_PASSWORD
```

Save and exit (`Ctrl+X`, `Y`, `Enter`), then lock it down:
```bash
sudo chmod 600 /mnt/etc/secrets/wireless.env
```

> **Security note:** This file is on the root filesystem, owned by root, readable only
> by root. It is NOT tracked by Git (see `.gitignore`). The Nix config references it via
> `environmentFile` which substitutes `@password@` at activation time — the password
> never touches the Nix store.

---

### Step 7 — Check your gateway IP

The config defaults to `192.168.1.1` as the gateway. Verify this is correct for your router:

```bash
# In the live environment, after connecting to WiFi:
ip route show default
```

If your gateway is different (e.g. `192.168.0.1`), edit `configuration.nix` before installing:
```nix
routes = [{ routeConfig.Gateway = "192.168.0.1"; }];  # ← change this
```

---

### Step 8 — Install NixOS

```bash
sudo nixos-install --flake /mnt/etc/nixos/nix-lab#nix-lab
```

This will:
- Download all required packages (takes a while on first run)
- Build the system
- Ask you to set a **root password** at the end — set one even if you won't use it

---

### Step 9 — Set user password

Before rebooting, set the password for the `vasu` user:

```bash
sudo nixos-enter --root /mnt
passwd vasu
# Enter and confirm your password
exit
```

---

### Step 10 — Reboot

```bash
sudo reboot
# Remove the USB drive when the screen goes blank during shutdown
```

---

### Step 11 — SSH in from your Arch desktop

Wait about 30 seconds for boot, then:

```bash
ssh vasu@192.168.1.75
```

If it connects — you're done with installation.

---

### Step 12 — Set up Tailscale

```bash
sudo tailscale up
# Follow the auth URL printed in the terminal
# Open it on your phone/desktop browser and authenticate
```

After this you can SSH via Tailscale IP from anywhere, not just your home network.

---

## Post-install: Switch to Key-based SSH (recommended)

Once you've confirmed everything works:

**On your Arch desktop:**
```bash
# Copy your public key to the server
ssh-copy-id vasu@192.168.1.75

# Test key auth works before disabling passwords
ssh vasu@192.168.1.75
```

**In `configuration.nix`, make two changes:**

```nix
# 1. Add your public key to the user block:
users.users.vasu = {
  openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA...your-full-public-key-here"
  ];
};

# 2. Disable password auth:
services.openssh.settings = {
  PasswordAuthentication = false;
  KbdInteractiveAuthentication = false;
  PermitRootLogin = "no";
};
```

Get your public key:
```bash
cat ~/.ssh/id_ed25519.pub
```

Then rebuild:
```bash
sudo nixos-rebuild switch --flake .#nix-lab
```

---

## Day-to-day Usage

### Rebuild after config changes

```bash
# On the server
cd /etc/nixos/nix-lab
sudo nixos-rebuild switch --flake .#nix-lab
```

### Rollback if something breaks

```bash
sudo nixos-rebuild switch --rollback
```

Or pick a specific generation at boot from the systemd-boot menu (last 5 kept).

### Update nixpkgs (get newer packages)

```bash
cd /etc/nixos/nix-lab
nix flake update
sudo nixos-rebuild switch --flake .#nix-lab
```

### Check what changed between generations

```bash
nix profile diff-closures /nix/var/nix/profiles/system-{N}-link /nix/var/nix/profiles/system-{N+1}-link
```

### Check current generation

```bash
nixos-version
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

---

## Useful Commands

```bash
# Docker
docker ps -a                        # list all containers
docker compose up -d                # start services
docker compose logs -f              # follow logs
docker system df                    # disk usage

# Disk health
sudo smartctl -H /dev/sda           # quick SSD health check
sudo smartctl -H /dev/sdb           # quick HDD health check
sudo smartctl -A /dev/sdb | grep -E "Pending|Reallocated|Uncorrectable"

# Network
ip addr show                        # check IP
tailscale status                    # tailscale peers
ss -tlnp                            # listening ports

# System
btop                                # resource monitor
journalctl -f                       # follow system logs
journalctl -u docker                # Docker service logs
df -h                               # disk space
```

---

## File Structure

```
nix-lab/
├── disk-config.nix            # Disko partition layout (install only)
├── flake.nix                  # Flake inputs and outputs
├── configuration.nix          # Main system config
├── hardware-configuration.nix # Auto-generated (add after install)
├── wireless.env.template      # Template for WiFi secrets file
├── .gitignore                 # Prevents secrets from being committed
└── README.md                  # This file
```

> `hardware-configuration.nix` is not in the repo initially.
> It gets generated during install and should be committed after.

---

## Secrets Management

Currently using environment file approach (`/etc/secrets/wireless.env`).

For future expansion (Vaultwarden secrets, API keys, etc.) consider migrating to:
- **`agenix`** — age-encrypted secrets, committed to Git, decrypted at activation. Best long-term option.
- **`sops-nix`** — similar to agenix, more tooling around it.

Both integrate cleanly with flakes.

---

## Troubleshooting

**Can't SSH after install:**
- Check WiFi connected: `ping 192.168.1.75` from another device
- Check SSH is running: connect keyboard/monitor temporarily, run `systemctl status sshd`
- Verify user password was set correctly in Step 11

**WiFi not connecting:**
- Verify `/etc/secrets/wireless.env` exists and has correct password
- Check SSID matches exactly (case sensitive): `VJ-Wifi-2.4G`
- Check interface name: `ip link show` — should see `wl*` interface
- Check wpa_supplicant: `journalctl -u wpa_supplicant`

**HDD not mounting:**
- Verify label: `sudo blkid /dev/sdb1` — should show `LABEL="data"`
- Re-label if needed: `sudo e2label /dev/sdb1 data`
- Check mount: `systemctl status mnt-data.mount`

**Wrong gateway / no internet:**
- Edit `configuration.nix`, change gateway IP, rebuild
- Check current default route: `ip route show default`

**Lid close waking up:**
- Should not happen with this config, but verify: `systemctl status sleep.target`
- Should show `Unit sleep.target is masked`
