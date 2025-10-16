{
  inputs = {
    nixpkgs.follows = "my-configs/nixpkgs";
    my-configs.url = "github:tanshihaj/nixos-configs";
  };

  outputs =
    {
      self,
      nixpkgs,
      my-configs,
      ...
    }:
    {
      nixosConfigurations.server = nixpkgs.lib.nixosSystem {
        modules = with my-configs.nixosModules; [
          base
          server
          platform-hetzner-ampere
        ];
      };
    };
}
