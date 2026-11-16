{ pkgs, ... }:

let
  esc = pkgs.lib.escapeShellArg;
  mkExec = cmd: pkg: "${pkgs.bun}/bin/bunx --bun --package ${esc pkg} ${esc cmd}";
  wrappers =
    (import ../mk-runtime-wrappers.nix { inherit pkgs; })
      mkExec
      (import ./registry.nix);

in
{
  home.packages =
    [ pkgs.bun ]
    ++ wrappers;
}
