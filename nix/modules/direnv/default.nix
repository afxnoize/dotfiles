{ config, ... }:

let
  wrapperPreamble = ''
    #!/usr/bin/env bash
    set -e
    fail() {
      echo "Error: $1" >&2
      exit 1
    }
    exec_var_or_fail() {
      local var_name="$1"
      shift
      local var_value="''${!var_name}"
      if [ -z "$var_value" ]; then
        fail "$var_name is not set."
      fi
      exec "$var_value" "$@"
    }
  '';
in
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

      # Route `nix build/shell/develop` through nom (nix-output-monitor) for
      # prettier build output. Also covers nix invocations from tools like
      # `home-manager switch`. See:
      # https://ryota2357.com/blog/2025/nix-subcmd-use-nom-in-direnv/
      if command -v nom > /dev/null; then
        export DIRENV_ORIGINAL_NIX="$(command -v nix)"
        export DIRENV_ORIGINAL_NOM="$(command -v nom)"
        export DIRENV_USE_NIX_WRAPPER=1
        export DIRENV_CUSTOM_BIN_DIR="${config.home.homeDirectory}/.config/direnv/bin"
        export PATH="$DIRENV_CUSTOM_BIN_DIR:$PATH"
      fi
    '';
  };

  home.file.".config/direnv/bin/nix" = {
    executable = true;
    text = ''
      ${wrapperPreamble}
      if [ "$DIRENV_USE_NIX_WRAPPER" = "1" ]; then
        for arg in "$@"; do
          if [ "$arg" = '--help' ]; then
            exec_var_or_fail 'DIRENV_ORIGINAL_NIX' "$@"
          fi
        done
        case "$1" in
          build|shell|develop)
            export DIRENV_USE_NIX_WRAPPER=0
            exec_var_or_fail 'DIRENV_ORIGINAL_NOM' "$@"
            ;;
        esac
      fi
      exec_var_or_fail 'DIRENV_ORIGINAL_NIX' "$@"
    '';
  };

  home.file.".config/direnv/bin/nom" = {
    executable = true;
    text = ''
      ${wrapperPreamble}
      export DIRENV_USE_NIX_WRAPPER=0
      exec_var_or_fail 'DIRENV_ORIGINAL_NOM' "$@"
    '';
  };

  home.file.".config/direnv/bin/sudo" = {
    executable = true;
    text = ''
      ${wrapperPreamble}
      if [ -z "$DIRENV_CUSTOM_BIN_DIR" ]; then
        fail 'DIRENV_CUSTOM_BIN_DIR is not set.'
      fi
      if [[ ":$PATH:" != *":$DIRENV_CUSTOM_BIN_DIR:"* ]]; then
        fail "DIRENV_CUSTOM_BIN_DIR ($DIRENV_CUSTOM_BIN_DIR) is not found in PATH."
      fi

      path_remove() {
        local path_i target="$1"
        declare -a path_array results
        IFS=: read -ra path_array <<< "$PATH"
        for path_i in "''${path_array[@]}"; do
          if [[ "$path_i" != "$target" ]]; then
            results+=("$path_i")
          fi
        done
        local result
        result="$(IFS=:; echo "''${results[*]}")"
        export PATH="$result"
      }

      path_remove "$DIRENV_CUSTOM_BIN_DIR"
      /usr/bin/sudo "$@"
    '';
  };
}
