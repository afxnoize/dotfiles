{ config, pkgs, ... }:

{
  home.username = "noize";
  home.homeDirectory = "/home/noize";

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    git
    neovim
    fzf
    ripgrep
    fd
    bat
    bottom
    eza
    mise
    ghq
    usage
    # task
  ];

  programs.zsh.enable = true;

  programs.zsh.initExtra = ''
    if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
      . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    fi
  '';
}
