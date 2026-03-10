{ pkgs }:

runtime: tools:

pkgs.lib.mapAttrsToList
  (cmd: pkg:
    pkgs.writeShellScriptBin cmd ''
      set -euo pipefail
      exec ${runtime} ${pkgs.lib.escapeShellArg pkg} "$@"
    '')
  tools
