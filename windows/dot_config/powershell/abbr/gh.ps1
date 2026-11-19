# Ported from dot_config/zabrze/gh.toml. ghtkn exec uses the app in GHTKN_APP, or the
# first app in ghtkn.yaml; it does not look at the repository owner. profile.ps1 sets
# GHTKN_APP per owner from $GhtknAppByOwner in profile.local.ps1.
@{ Name = 'gh with ghtkn token'; Trigger = 'gh'; Snippet = 'ghtkn exec -e GH_TOKEN -- gh' }
