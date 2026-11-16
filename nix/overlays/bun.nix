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
