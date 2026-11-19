#!/usr/bin/env bash
# Move every GitHub release pinned in the Windows configuration files to the latest release
# of its repository, rewriting the download URL and its SHA256.
#
# Usage (from the repository root): windows-release-bump.sh [--check]
#   --check  only report what would change; change nothing
#
# A pin is an Install-Release call whose -Sha256 '<hex>' line is directly followed by
#   -Url 'https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>'
# The configuration files are the only list of pins; downloads without a hash (WezTerm nightly)
# and URLs outside GitHub releases (NirCmd) are not pins and are left alone.
#
# The new asset name is the old one with the old version replaced by the new version
# (v5.0.3 -> v5.1.0 turns Cica_v5.0.3.zip into Cica_v5.1.0.zip). When the latest release has no
# asset of that name (the project renamed its files), the pin is left as is and reported as failed.
# The old hash is replaced everywhere in the file, which also updates the TestScript copy.
#
# Env: DSC_FILES (space-separated paths), GITHUB_OUTPUT (set by Actions).
set -euo pipefail

DSC_FILES=${DSC_FILES:-"windows/configuration.dev.dsc.yaml windows/configuration.personal.dsc.yaml"}

# pins <file>: print one tab-separated line per pin: repo, tag, asset, sha256.
pins() {
  awk '
    match($0, /-Sha256 '\''[0-9a-f]+'\''/) { sha = substr($0, RSTART + 9, RLENGTH - 10); next_is_url = 1; next }
    next_is_url && match($0, /-Url '\''https:\/\/github\.com\/[^\/]+\/[^\/]+\/releases\/download\/[^\/]+\/[^'\'']+'\''/) {
      split(substr($0, RSTART + 25, RLENGTH - 26), p, "/")
      print p[1] "/" p[2] "\t" p[5] "\t" p[6] "\t" sha
    }
    { next_is_url = 0 }
  ' "$1"
}

# next_asset <asset> <old tag> <new tag>: the asset name for the new release.
next_asset() {
  local old=${2#v} new=${3#v}
  echo "${1//"$old"/"$new"}"
}

# newer <a> <b>: succeed when version a is newer than version b.
newer() {
  local a=${1#v} b=${2#v}
  [ "$a" != "$b" ] && [ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1)" = "$a" ]
}

# replace_all <file> <old> <new>: replace every literal occurrence of old with new.
replace_all() {
  local content
  content=$(<"$1")
  printf '%s\n' "${content//"$2"/"$3"}" >"$1"
}

# latest_release <repo>: print the tag on the first line, then "<name>\t<digest>" per asset.
latest_release() {
  gh api "repos/$1/releases/latest" --jq '.tag_name, (.assets[] | .name + "\t" + (.digest // ""))'
}

# asset_sha256 <url> <digest>: the SHA256 GitHub records for the asset, or of the download
# for assets uploaded before GitHub started recording digests.
asset_sha256() {
  if [[ $2 == sha256:* ]]; then
    echo "${2#sha256:}"
  else
    curl -fsSL "$1" | sha256sum | cut -d' ' -f1
  fi
}

# emit <key> <value>: expose a step output when running under Actions.
emit() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s<<EOF_OUTPUT\n%s\nEOF_OUTPUT\n' "$1" "$2" >>"$GITHUB_OUTPUT"
  fi
}

main() {
  local check=0 file repo tag asset sha release latest new_asset digest new_sha old_url new_url
  local updated="" failed=""
  if [ "${1:-}" = "--check" ]; then check=1; fi

  for file in $DSC_FILES; do
    while IFS=$'\t' read -r repo tag asset sha; do
      release=$(latest_release "$repo")
      latest=$(head -1 <<<"$release")
      if ! newer "$latest" "$tag"; then
        echo "$repo: $tag is the latest"
        continue
      fi
      new_asset=$(next_asset "$asset" "$tag" "$latest")
      if ! digest=$(awk -F'\t' -v n="$new_asset" 'NR > 1 && $1 == n { print $2; found = 1 } END { exit !found }' <<<"$release"); then
        echo "$repo: $latest has no asset named $new_asset" >&2
        failed+="- $repo: $latest に $new_asset がない（asset 名が変わった可能性）"$'\n'
        continue
      fi
      old_url="https://github.com/$repo/releases/download/$tag/$asset"
      new_url="https://github.com/$repo/releases/download/$latest/$new_asset"
      echo "$repo: $tag -> $latest"
      updated+="- $repo: $tag → $latest"$'\n'
      if [ "$check" = 1 ]; then continue; fi
      new_sha=$(asset_sha256 "$new_url" "$digest")
      replace_all "$file" "$old_url" "$new_url"
      replace_all "$file" "$sha" "$new_sha"
    done < <(pins "$file")
  done

  emit bumped "$([ -n "$updated" ] && echo true || echo false)"
  emit updated "${updated%$'\n'}"
  emit failed "${failed%$'\n'}"
}

# Sourced by the tests, which call the functions directly.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
