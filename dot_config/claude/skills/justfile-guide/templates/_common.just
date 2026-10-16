# Shared settings. Copy to ./_common.just and `import` it from the root justfile
# and from every mod: mods do not inherit `set` from the root.
# `set dotenv-load` is not here because it only works in the root.
# Pick the shell below; see guide/settings.md.

set shell := ["bash", "-c"]

# set shell := ["mise", "exec", "--", "bash", "-c"]
# set shell := ["nix", "develop", "-c", "bash", "-c"]
# set shell := ["bash", "-euo", "pipefail", "-c"]

# A module may have only one [default]: do not add another where this is imported.
[default]
_default:
    @"{{ just_executable() }}" --justfile "{{ module_file() }}" --list
