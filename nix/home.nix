{ config, pkgs, pkgs-unstable, lib, username, homeDirectory, ... }:

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
    pkgs-unstable.mise
    pkgs-unstable.usage
    bitwarden-cli
    zoxide
    devbox
    just
  ];

  # Claude Code (公式インストーラー経由)
  home.activation.installClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! command -v claude &> /dev/null; then
      ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | ${pkgs.bash}/bin/bash
    fi
  '';

  programs.zsh.enable = true;

  programs.zsh.initContent = ''
    if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
      . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    fi
  '';
}
