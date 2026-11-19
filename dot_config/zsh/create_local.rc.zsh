# Machine- and account-specific zsh settings, sourced from .zshrc.
# chezmoi creates this file once and never overwrites it.

# ghtkn app per repository owner, matched against .../github.com/<owner>/ in the
# current directory. Names are those in ghtkn.yaml. Outside these owners GHTKN_APP
# is unset, so ghtkn uses the first app in ghtkn.yaml.
# typeset -A ghtkn_app_by_owner=(
#   example example/write
# )
