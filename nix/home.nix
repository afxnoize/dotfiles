{ config, pkgs, pkgs-unstable, lib, username, homeDirectory, llm-agents, cage, ... }:

{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];

  home.username = username;
  home.homeDirectory = homeDirectory;

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.file.".local/share/chezmoi" = {
    source = config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/repos/github.com/afxnoize/dotfiles";
    force = true;
  };

  imports = [
    ./modules
    ./tools
  ];

  home.packages = with pkgs; [
    git
    gti
    gh
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
    bitwarden-cli
    jq
    sops
    age
    zoxide
    devbox
    just
    chezmoi
    yazi

    claude-code
  ]
  ++ (with llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    rtk
    ccusage
  ])
  ++ [
    cage.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

}
