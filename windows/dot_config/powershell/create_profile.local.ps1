# Machine- and account-specific PowerShell settings, dot-sourced from profile.ps1.
# chezmoi creates this file once and never overwrites it.

# ghtkn app per repository owner, matched against ...\github.com\<owner>\ in the
# current directory. Names are those in ghtkn.yaml. Outside these owners GHTKN_APP
# is unset, so ghtkn uses the first app in ghtkn.yaml.
# $GhtknAppByOwner = @{
#   'example' = 'example/write'
# }
