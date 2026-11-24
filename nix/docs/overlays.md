# overlays

`nix/overlays/` の各 overlay がある理由と、版の決め方。

いつ読むか: `overlays/` のファイルを編集・削除するとき、または bun の挙動を調べるとき。

## bun
- upstream の latest release に意図して固定し、nixpkgs の版には頼らない。理由は、nixpkgs の版が upstream より遅れ、同梱の brotli に脆弱性（bun 1.4.4 で修正）が残っていたため
- `bun-linux-x64` / `bun-linux-aarch64` を `flake = false` のファイル入力（upstream の latest release の zip）として持ち、`overlays/bun.nix` の overlay で `pkgs.bun` の `src` だけを差し替える（`flake.nix` の `overlays` から import する）
- `tools/bunx` と PATH 上の `bun` は同じ `pkgs.bun` なのでまとめて追従する
- 更新は [`flake-latest-update`](flake-latest-update.md) が毎日行う。手で上げるなら `nix flake update bun-linux-x64 bun-linux-aarch64`
- nixpkgs が追いついても、入力と overlay は削除しない
- linux 以外の system は nixpkgs の bun のまま
