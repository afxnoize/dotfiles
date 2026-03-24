{ pkgs, ... }:

let
  platformMap = {
    "x86_64-linux" = {
      target = "linux_amd64";
      sha256 = "0c8800985e4d44a3910ca62bfe8a9afd51930f2366e7fc5f21708f34dece5d5c";
    };
    "aarch64-linux" = {
      target = "linux_arm64";
      sha256 = "19f2db55a624b8a210096770c22a0bf5f7245ab0194832efaf5c85582361aca7";
    };
    "aarch64-darwin" = {
      target = "darwin_arm64";
      sha256 = "296ac4d471f08558852bb9a61e468a75c7ca356cdc7dad705babce51074845d3";
    };
    "x86_64-darwin" = {
      target = "darwin_amd64";
      sha256 = "ef9ad28383a3ba9e9dc69d7ef122c0ac0b40203bb3b133a69ad6966c1b449cce";
    };
  };

  system = pkgs.stdenv.hostPlatform.system;
  platform = platformMap.${system};
  isDarwin = pkgs.stdenv.isDarwin;
  ext = if isDarwin then "zip" else "tar.gz";

  mo = pkgs.stdenv.mkDerivation rec {
    pname = "mo";
    version = "0.21.0";

    src = pkgs.fetchurl {
      url = "https://github.com/k1LoW/mo/releases/download/v${version}/mo_v${version}_${platform.target}.${ext}";
      sha256 = platform.sha256;
    };

    sourceRoot = ".";

    nativeBuildInputs = [ pkgs.autoPatchelfHook ]
      ++ pkgs.lib.optionals isDarwin [ pkgs.unzip ];
    buildInputs = pkgs.lib.optionals (!isDarwin) [ pkgs.stdenv.cc.cc.lib ];

    installPhase = ''
      install -Dm755 mo $out/bin/mo
    '';
  };
in
{
  home.packages = [ mo ];
}
