{
  description = "Home Manager configuration (Linux, Determinate Nix)";

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    llm-agents.url = "github:numtide/llm-agents.nix";
    cage.url = "github:Warashi/cage";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, neovim-nightly-overlay, llm-agents, cage, nix-index-database, ... }:
    let
      system = builtins.currentSystem;
      pkgs = import nixpkgs {
        overlays = [
          neovim-nightly-overlay.overlays.default
          (final: prev: {
            cage = cage.packages.${system}.default;
            rtk = llm-agents.packages.${system}.rtk;
            ccusage = llm-agents.packages.${system}.ccusage;
          })
        ];
        inherit system;
      };
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
      username = builtins.getEnv "USER";
      homeDirectory = builtins.getEnv "HOME";
    in {
      homeConfigurations.${username} =
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./home.nix
            nix-index-database.homeModules.nix-index
          ];
          extraSpecialArgs = {
            inherit username homeDirectory pkgs-unstable;
          };
        };
    };
}
