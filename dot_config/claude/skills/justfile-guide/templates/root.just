# Root router. Copy to ./justfile.
# dotenv is honored in the root only; mods never read their own .env.

set dotenv-load := true

import "_common.just"

# Next.js frontend
mod web "packages/web"
# systemd units
mod ops

# web::check
check: web::check
    @echo "All checks passed"
