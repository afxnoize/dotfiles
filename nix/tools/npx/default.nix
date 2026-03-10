{ pkgs, ... }:

let
  runtime = "${pkgs.nodejs}/bin/npx --yes";
  wrappers =
    (import ../mk-runtime-wrappers.nix { inherit pkgs; })
      runtime
      (import ./registry.nix);

in
{
  home.packages =
    [ pkgs.nodejs ]
    ++ wrappers;
}
