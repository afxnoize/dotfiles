# nixpkgs bun lags upstream and bundles a vulnerable brotli (fixed in bun 1.4.4).
# Drop this overlay and the bun-linux-* inputs once nixpkgs ships bun >= 1.4.4.
# Other systems keep the nixpkgs bun.
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
