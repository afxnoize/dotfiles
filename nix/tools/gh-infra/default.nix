{ pkgs-unstable, ... }:

let
  gh-infra = pkgs-unstable.buildGoModule rec {
    pname = "gh-infra";
    version = "0.20.0";

    src = pkgs-unstable.fetchFromGitHub {
      owner = "babarot";
      repo = "gh-infra";
      rev = "v${version}";
      hash = "sha256-b0typWimVILRfIV5lP6sBO6cbYWQJNneRLqSSwGUDH8=";
    };

    vendorHash = "sha256-w0Ix1xpJQ5H4NttZCjF1ZWE0/o2US5K76X2bxMrtBF4=";

    subPackages = [ "cmd/gh-infra" ];
    env.CGO_ENABLED = 0;
    ldflags = [
      "-s"
      "-w"
      "-X main.version=v${version}"
    ];
    doCheck = false;
  };
in
{
  home.packages = [ gh-infra ];
}
