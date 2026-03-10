{ pkgs, ... }:

let
  runtime = "${pkgs.bun}/bin/bunx --bun";
  wrappers =
    (import ../mk-runtime-wrappers.nix { inherit pkgs; })
      runtime
      (import ./registry.nix);

in
{
  home.packages =
    [ pkgs.bun ]
    ++ wrappers;
}
