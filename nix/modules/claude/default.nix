{ config, lib, pkgs, ... }:

let
  # A regular file, not a store symlink: some tools (e.g. happy) resolve claude
  # through ~/.local/bin/claude and need a real file there.
  # The shebang is /bin/sh rather than a store bash, because the copied file is
  # not a GC root and a store path in it would dangle after garbage collection.
  shim = pkgs.writeText "claude-shim" ''
    #!/bin/sh
    exec "${config.home.profileDirectory}/bin/claude" "$@"
  '';
in
{
  home.activation.claudeShim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -D -m 755 ${shim} "$HOME/.local/bin/claude"
  '';
}
