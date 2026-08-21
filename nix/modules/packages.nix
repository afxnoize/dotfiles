{ pkgs, pkgs-unstable, ... }:

let
  nixTools = with pkgs; [
    nh
    nix-output-monitor
    pkgs-unstable.nix-sweep
  ];

  vcsTools = with pkgs; [
    git
    gti
    gh
    ghq
    pkgs-unstable.git-wt
  ];

  editorTools = with pkgs; [
    neovim
  ];

  shellTools = with pkgs; [
    fzf
    ripgrep
    fd
    bat
    bottom
    eza
    jq
    zoxide
    yazi
  ];

  devTools = with pkgs; [
    pkgs-unstable.mise
    devbox
    just
    chezmoi
  ];

  secretTools = with pkgs; [
    bitwarden-cli
    sops
    age
  ];

  aiTools = with pkgs; [
    claude-code
    rtk
    ccusage
  ];

  sandboxTools = with pkgs; [
    cage
  ];
in
{
  # Pull in man/info pages for every installed package.
  home.extraOutputsToInstall = [ "doc" "info" ];

  home.packages = builtins.concatLists [
    nixTools
    vcsTools
    editorTools
    shellTools
    devTools
    secretTools
    aiTools
    sandboxTools
  ];
}
