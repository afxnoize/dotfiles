{ config, pkgs, pkgs-unstable, lib, username, homeDirectory, llm-agents, ... }:

let
  bunxTools = import ./bunx-tools.nix;
  bunxWrapper = name: pkg:
    pkgs.writeShellScriptBin name ''
      exec ${pkgs.bun}/bin/bunx --bun ${pkg} "$@"
    '';
  bunxPackages =
    pkgs.lib.mapAttrsToList bunxWrapper bunxTools;

in {
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];

  home.username = username;
  home.homeDirectory = homeDirectory;

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

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

    bun

    claude-code
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.rtk
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.ccusage
  ]
  ++ bunxPackages;

  programs.zsh.enable = true;

  programs.zsh.initContent = ''
    if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
      . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    fi
  '';
}
