{ config, pkgs, pkgs-unstable, lib, username, homeDirectory, ... }:

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

  services.pueue = {
    enable = true;
    package = pkgs-unstable.pueue;
  };

  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

}
