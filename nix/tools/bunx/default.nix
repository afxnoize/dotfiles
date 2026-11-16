{ pkgs, ... }:

let
  wrappers = pkgs.lib.mapAttrsToList (
    cmd: pkg:
    pkgs.writeShellScriptBin cmd ''
      set -euo pipefail
      exec ${pkgs.bun}/bin/bunx --bun --package ${pkgs.lib.escapeShellArg pkg} ${pkgs.lib.escapeShellArg cmd} "$@"
    ''
  ) (import ./registry.nix);
in
{
  home.packages = [ pkgs.bun ] ++ wrappers;
}
