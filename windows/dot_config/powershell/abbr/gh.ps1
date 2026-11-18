# Ported from dot_config/zabrze/gh.toml. ghtkn exec picks the app for the
# repository owner, so gh runs as that account without switching gh's login.
@{ Name = 'gh with ghtkn token'; Trigger = 'gh'; Snippet = 'ghtkn exec -e GH_TOKEN -- gh' }
