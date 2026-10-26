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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    claude-code.url = "github:sadjow/claude-code-nix";
    llm-agents.url = "github:numtide/llm-agents.nix";
    cage.url = "github:Warashi/cage";

    # Latest upstream bun release, locked by narHash.
    # Refresh with `nix flake update bun-linux-x64 bun-linux-aarch64`.
    bun-linux-x64 = {
      url = "file+https://github.com/oven-sh/bun/releases/latest/download/bun-linux-x64-baseline.zip";
      flake = false;
    };
    bun-linux-aarch64 = {
      url = "file+https://github.com/oven-sh/bun/releases/latest/download/bun-linux-aarch64.zip";
      flake = false;
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, neovim-nightly-overlay, claude-code, llm-agents, cage, nix-index-database, ... }@inputs:
    let
      system = builtins.currentSystem;
      pkgs = import nixpkgs {
        overlays = [
          neovim-nightly-overlay.overlays.default
          claude-code.overlays.default
          (final: prev: {
            cage = cage.packages.${system}.default;
            rtk = llm-agents.packages.${system}.rtk;
            ccusage = llm-agents.packages.${system}.ccusage;
          })
          (import ./overlays/bun.nix { inherit inputs system; })
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
