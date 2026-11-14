{ pkgs, ... }:

let
  # Serves the token of the requested account, independent of `gh auth switch`.
  # Referenced by store path so git does not depend on PATH.
  ghUserCredential = pkgs.writeShellApplication {
    name = "git-credential-gh-user";
    runtimeInputs = [ pkgs.gh pkgs.git ];
    text = builtins.readFile ./git-credential-gh-user.sh;
  };
  ghUserHelper = "${ghUserCredential}/bin/git-credential-gh-user";
in
{
  programs.git = {
    enable = true;

    settings = {
      # Shared settings (identity, aliases, core, tools) live in common.gitconfig.
      credential = {
        useHttpPath = true;
        "https://github.com" = {
          username = "afxnoize";
          helper = ghUserHelper;
        };
        "https://gist.github.com".helper = ghUserHelper;
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

