{ pkgs-unstable, ... }:

let
  # Picks the GitHub App by repository owner (git_owner in ghtkn.yaml), which
  # needs credential.useHttpPath.
  ghtknHelper = "${pkgs-unstable.ghtkn}/bin/ghtkn git-credential";
in
{
  programs.git = {
    enable = true;

    settings = {
      # Shared settings (identity, aliases, core, tools) live in common.gitconfig.
      credential = {
        useHttpPath = true;
        "https://github.com".helper = ghtknHelper;
        "https://gist.github.com".helper = ghtknHelper;
      };
    };

    # A path literal copies the file into the Nix store, so edits to the working
    # copy take effect only after a rebuild. local.config comes last to override.
    includes = [
      { path = ./common.gitconfig; }
      { path = "~/.config/git/local.config"; }
    ];

    ignores = [
      "/.vscode"
      ".*-version" # anyenv local version
      "**/.claude/settings.local.json"
      ".plans/" # Claude Code plans directory
    ];
  };
}
