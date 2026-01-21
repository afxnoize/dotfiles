{ config, pkgs, username, homeDirectory, ... }:

{
  home.username = username;
  home.homeDirectory = homeDirectory;

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    git
    ghq
    neovim
    fzf
    ripgrep
    fd
    bat
    bottom
    eza
    mise
    usage
    bitwarden-cli
  ];

  programs.zsh.enable = true;

  programs.zsh.initExtra = ''
    if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
      . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    fi
  '';
}
