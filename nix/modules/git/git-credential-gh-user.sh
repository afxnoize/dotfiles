# git credential helper: serve the token of the requested GitHub account.
#
# `gh auth git-credential` only answers for the active gh account, so a per-repo
# credential.username (set via includeIf) fails whenever `gh auth switch` points
# elsewhere. Look the token up by username with `gh auth token --user` instead.

[ "${1:-}" = get ] || exit 0

host=
user=
while IFS='=' read -r key value; do
  [ -n "$key" ] || break
  case $key in
    host) host=$value ;;
    username) user=$value ;;
    *) ;;
  esac
done

case $host in
  github.com | gist.github.com) ;;
  *) exit 0 ;;
esac

# credential.username is scoped to https://github.com and does not reach gist.
[ -n "$user" ] || user=$(git config --get github.user 2>/dev/null || true)
[ -n "$user" ] || exit 0

# A token from the environment (e.g. direnv) must not override --user.
unset GH_TOKEN GITHUB_TOKEN
token=$(gh auth token --hostname github.com --user "$user" 2>/dev/null || true)
if [ -z "$token" ]; then
  echo "git-credential-gh-user: no gh token for '$user' (try: gh auth login)" >&2
  exit 0
fi

printf 'username=%s\npassword=%s\n' "$user" "$token"
