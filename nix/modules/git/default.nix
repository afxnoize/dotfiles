{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name= "noize";
        email = "22848261+afxnoize@users.noreply.github.com";
      };

      alias = {
        graph = "log --graph --date=short --decorate=short --pretty=format:'%Cgreen%h %Creset%cn %Cred%d %Creset%s'";
        gr = "graph";
        b = "branch";
        br = "branch";
        s = "status";
        a = "add";
        ad = "add";
        cm = "commit";
        sw = "switch";
        d = "diff";
        df = "diff";
        # staged diff
        ds = "diff --cached";
        cp = "cherry-pick";
        st = "stash push -m";
        sta = "stash apply";
        stp = "stash pop";
        stl = "stash list";
        ft = "fetch";
        ftp = "fetch -p";
        ignore = "!gi() { curl -sL https://www.toptal.com/developers/gitignore/api/$@ ;}; gi";
      };

      credential = {
        useHttpPath = true;
        "https://github.com".username = "afxnoize";
      };
      github.user = "afxnoize";
      core = {
        editor = "nvim";
        whitespace = "cr-at-eol";
        autocrlf = "input";
      };

      gpg.program = "gpg";
      commit.gpgsign = false;

      push.autoSetupRemote = true;
      pull.rebase = true;
      diff.tool = "nvimdiff";
      difftool = {
        prompt = false;
        "nvimdiff".cmd = ''nvim -d "$LOCAL" "$REMOTE"'';
      };
      merge.tool = "nvimdiff";
      mergetool = {
        prompt = false;
        keepBackup = false;
        "diffview".cmd = ''nvim -n -c "DiffviewOpen" "$MERGE"'';
        "nvimdiff".layout = "LOCAL,BASE,REMOTE / MERGED";
      };
      init.defaultBranch = "main";

      ghq.root = "~/repos";
      wt = {
        basedir = ".worktrees";
        nocd = false;
      };
    };

    includes = [
      { path = "~/.config/git/local.config"; }
    ];

    ignores = [
      "/.vscode"
      ".*-version" # anyenv local version
      ".worktrees" # git worktree
      "**/.claude/settings.local.json"
      ".plans/" # Claude Code plans directory
    ];
  };

  programs.zsh.initContent = ''
    eval "$(git wt --init zsh)"
  '';
}

