{ pkgs, pkgs-unstable, lib, username, homeDirectory, llm-agents, ... }:

{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];

  home.username = username;
  home.homeDirectory = homeDirectory;

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  imports = [
    ./modules
    ./tools
  ];

  home.packages = with pkgs; [
    git
    ghq
    pkgs-unstable.git-wt

    neovim

    fzf
    ripgrep
    fd
    bat
    bottom
    eza
    pkgs-unstable.mise
    pkgs-unstable.usage
    bitwarden-cli
    zoxide
    devbox
    just

    claude-code
  ]
  ++ (with llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    rtk
    ccusage
  ]);
}
