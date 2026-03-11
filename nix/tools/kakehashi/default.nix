{ pkgs, ... }:

let
  platformMap = {
    "x86_64-linux" = {
      target = "x86_64-unknown-linux-gnu";
      sha256 = "0c54955d12c1678aaf358cc8b67bbdb762b72b12bd0f6269a69cf481a7b6bd1a";
    };
    "aarch64-linux" = {
      target = "aarch64-unknown-linux-gnu";
      sha256 = "9847bdd0beff3f64e986211bbdc170f2a4558de2cb2e29000c909d6cf2851c89";
    };
};

  system = pkgs.stdenv.hostPlatform.system;
  platform = platformMap.${system};

  kakehashi = pkgs.stdenv.mkDerivation rec {
    pname = "kakehashi";
    version = "0.4.1";

    src = pkgs.fetchurl {
      url = "https://github.com/atusy/kakehashi/releases/download/v${version}/kakehashi-v${version}-${platform.target}.tar.gz";
      sha256 = platform.sha256;
    };

    sourceRoot = ".";

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];

    installPhase = ''
      install -Dm755 kakehashi $out/bin/kakehashi
    '';
  };
in
{
  home.packages = [ kakehashi ];
}
