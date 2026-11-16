# Standing policy: bun is pinned to the upstream latest release on purpose, not
# to nixpkgs (which lags upstream and once bundled a vulnerable brotli, fixed in
# bun 1.4.4). claude-update refreshes the bun-linux-* inputs daily. Keep this
# overlay even when nixpkgs catches up. Other systems keep the nixpkgs bun.
{ inputs, system }:

final: prev:
let
  zip = {
    x86_64-linux = inputs.bun-linux-x64;
    aarch64-linux = inputs.bun-linux-aarch64;
  }.${system} or null;
in
prev.lib.optionalAttrs (zip != null) {
  bun = prev.bun.overrideAttrs (_: {
    version = "latest";
    src = final.runCommand "bun-${system}.zip" { } "cp ${zip} $out";
  });
}
