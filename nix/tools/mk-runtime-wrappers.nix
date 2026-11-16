{ pkgs }:

mkExec: tools:

pkgs.lib.mapAttrsToList
  (cmd: pkg:
    pkgs.writeShellScriptBin cmd ''
      set -euo pipefail
      exec ${mkExec cmd pkg} "$@"
    '')
  tools
