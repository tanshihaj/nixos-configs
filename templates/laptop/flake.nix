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
      nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
        modules = with my-configs.nixosModules; [
          base
          laptop
          platform-thinkpad-x13-gen4
        ];
      };
    };
}
