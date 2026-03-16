# git-wt Troubleshooting

## Known Issues

| Issue | Solution |
|-------|----------|
| シェル統合が動かない | `source ~/.zshrc` で再読込、`GIT_WT_SHELL_INTEGRATION` を確認 |
| Permission denied | `chmod +x /path/to/git-wt` |
| 複数バージョン競合 | `which -a git-wt` で確認、PATH 整理 |
| git not found | `git --version` で確認、PATH に追加 |

## Output Behavior

| Operation | stdout | stderr |
|-----------|--------|--------|
| List | テーブル or JSON | Git メッセージ |
| Create/Switch | worktreeパス（1行） | Git メッセージ、hook出力 |
| Delete | 確認メッセージ | エラーメッセージ |

Return codes: `0` 成功 / `1` 失敗

## Further Reference

上記で解決しない場合は [DeepWiki (k1LoW/git-wt)](https://deepwiki.com/k1LoW/git-wt) を参照。
