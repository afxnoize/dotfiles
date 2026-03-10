{ pkgs }:
tools:

pkgs.lib.mapAttrsToList
  (name: pkg:
    pkgs.writeShellScriptBin name ''
      exec ${pkgs.bun}/bin/bunx --bun ${pkg} "$@"
    '')
  tools
