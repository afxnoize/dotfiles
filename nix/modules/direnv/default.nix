{ config, ... }:

{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    # zsh uses ZDOTDIR=~/.config/zsh, so HM-generated ~/.zshrc is never sourced.
    # Hook is added manually in chezmoi-managed dot_config/zsh/dot_zshrc.
    enableZshIntegration = false;

    config = {
      global = {
        warn_timeout = "30s";
        hide_env_diff = true;
      };
    };

    stdlib = ''
      # use gitconfig
      #
      # Walks up from PWD to find a file named "gitconfig" and layers it on top
      # of the user's normal global gitconfig via GIT_CONFIG_GLOBAL. Intended
      # as a replacement for [includeIf "gitdir:..."] stanzas.
      use_gitconfig() {
        local found="" dir="$PWD"
        while [[ "$dir" != "/" ]]; do
          if [[ -f "$dir/gitconfig" ]]; then
            found="$dir/gitconfig"
            break
          fi
          dir="$(dirname "$dir")"
        done

        if [[ -z "$found" ]]; then
          log_error "use gitconfig: no gitconfig found in parent directories"
          return 1
        fi

        watch_file "$found"

        local layout="$(direnv_layout_dir)"
        mkdir -p "$layout"
        local merged="$layout/gitconfig"
        local base="''${XDG_CONFIG_HOME:-$HOME/.config}/git/config"

        cat > "$merged" <<EOF
      [include]
              path = $base
      [include]
              path = $found
      EOF

        export GIT_CONFIG_GLOBAL="$merged"
      }
    '';
  };
}
