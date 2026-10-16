# Mod template (directory type). Copy to ./packages/<name>/justfile.
# Recipes run in this directory.
# The import path is relative to this file, so two levels up reaches the root.

import "../../_common.just"

# bun install
[group('setup')]
install:
    bun install

# bun run lint
[group('quality')]
lint:
    bun run lint

# bun run typecheck
[group('quality')]
typecheck:
    bun run typecheck

# lint + typecheck
check: lint typecheck
    @echo "All checks passed"
