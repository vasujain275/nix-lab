{
  description = "nix-lab homelab configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, nixos-hardware, ... }: {
    nixosConfigurations.nix-lab = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Dell Inspiron 5000 series hardware tweaks
        nixos-hardware.nixosModules.common-pc-laptop
        nixos-hardware.nixosModules.common-pc-laptop-hdd

        ./hardware-configuration.nix
        ./configuration.nix
      ];
    };
  };
}
