{ ... }:

{
  programs.git = {
    enable = true;

    # A path literal copies the file into the Nix store, so edits to the working
    # copy take effect only after a rebuild.
    includes = [ { path = ./common.gitconfig; } ];
  };

  xdg.configFile."git/ignore".source = ./ignore;
}
