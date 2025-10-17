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
      nixosConfigurations.router = nixpkgs.lib.nixosSystem {
        modules = with my-configs.nixosModules; [
          base
          router
          platform-nanopi-r5c
        ];
      };
    };
}
