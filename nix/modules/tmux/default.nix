{ pkgs, config, lib, ... }:

let
  tpm = pkgs.fetchFromGitHub {
    owner = "tmux-plugins";
    repo = "tpm";
    rev = "v3.1.0";
    hash = "sha256-CeI9Wq6tHqV68woE11lIY4cLoNY8XWyXyMHTDmFKJKI=";
  };
in
{
  home.packages = [ pkgs.tmux ];

  # tpm を $XDG_DATA_HOME/tmux/plugins/tpm にリンク
  home.activation.tpm = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    TPM_DIR="${config.xdg.dataHome}/tmux/plugins/tpm"
    mkdir -p "$(dirname "$TPM_DIR")"
    ln -sfn "${tpm}" "$TPM_DIR"
  '';
}
