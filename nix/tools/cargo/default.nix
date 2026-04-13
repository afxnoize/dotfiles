{ pkgs, ... }:

{
  home.packages = [
    pkgs.rustc
    pkgs.cargo
    pkgs.clippy
  ];
}
