{ config, pkgs, pkgs-unstable, lib, username, homeDirectory, ... }:

{
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
    nix-output-monitor
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

    rtk
    ccusage
    cage
  ];

  services.pueue = {
    enable = true;
    package = pkgs-unstable.pueue;
  };

  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

}
