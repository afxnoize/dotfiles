{
  description = "Home Manager configuration (Linux, Determinate Nix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    claude-code.url = "github:sadjow/claude-code-nix";
    llm-agents.url = "github:numtide/llm-agents.nix";
    cage.url = "github:Warashi/cage";
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, neovim-nightly-overlay, claude-code, llm-agents, cage, ... }:
    let
      system = builtins.currentSystem;
      pkgs = import nixpkgs {
        overlays = [
          neovim-nightly-overlay.overlays.default
          claude-code.overlays.default
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
          ];
          extraSpecialArgs = {
            inherit username homeDirectory pkgs-unstable llm-agents cage;
          };
        };
    };
}
