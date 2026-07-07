# disk-config.nix — Declarative disk layout for initial install
#
# Usage (on the NixOS live ISO after connecting to WiFi):
#   lsblk                                          # check your disk name
#   nix --extra-experimental-features "nix-command flakes" run \
#     github:nix-community/disko -- --mode disko ./disk-config.nix
#
# This partitions, formats, mounts everything to /mnt, and creates swap.
# Then run: nixos-generate-config --root /mnt

{
  disko.devices.disk.ssd = {
    type = "disk";
    device = "/dev/sda";  # ← Change to /dev/nvme0n1 if your SSD is NVMe
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        swap = {
          size = "4G";
          content = {
            type = "swap";
            discard = true;
            randomEncryption = true;
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
