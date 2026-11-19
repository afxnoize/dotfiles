# stable リリースの自動追従（nixos-release-bump）

nixpkgs と home-manager の stable ブランチを、新しいリリースに上げる PR を毎月自動で出す仕組み。

いつ読むか: `nixpkgs` / `home-manager` の URL を変えるとき、`chore/nixos-release-bump` の PR を確認するとき、workflow やスクリプトを編集するとき。

- 週次の `flake-update`（`nix flake update`）は、URL に書いたブランチの中でしか追従しない。`nixos-25.11` のままでは 26.05 に上がらず、EOL したブランチには cacert などの修正が届かなくなる
- `.github/workflows/nixos-release-bump.yaml` が毎月 2 日 05:00 JST に最新の stable を検出し、`nixpkgs` と `home-manager` の URL を書き換えて PR を出す（ブランチ `chore/nixos-release-bump`）。実体は `.github/scripts/nixos-release-bump.sh`
- 採用するのは、nixpkgs の `nixos-YY.MM` と home-manager の `release-YY.MM` が両方あり、現在の pin より新しいリリース。home-manager は nixpkgs と同じリリースに揃える（ずれると警告や破損の原因になる）
- beta を拾わないよう、リリース名 `YY.MM` の翌月 1 日以降のものだけを採用する。ブランチがいつ作られるかに依存しないため
- CI は `nix eval` による評価だけを行う。ビルドは重いので、PR の確認者が手元で `nix build --impure` する。評価に失敗した場合は draft PR になる
- `home.stateVersion` は自動では上げない。互換性の記録であり、上げると既定値が静かに変わりうるため、リリースの追従とは別に判断する
- 動作確認は `bash .github/scripts/nixos-release-bump.sh --check`（変更せずに採用候補だけ表示）と `bash .github/scripts/nixos-release-bump.test.sh`（判定ロジックのテスト）
- merge すると、次回の [`flake-latest-update`](flake-latest-update.md) が main の内容でビルドして switch する。起きているうちに手元で `hms` を実行し、activation の問題を先に確認する
