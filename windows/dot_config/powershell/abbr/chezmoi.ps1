# Ported from dot_config/zabrze/chezmoi.toml.
$sub = '^chezmoi\s+\S+$'

@{ Name = 'chezmoi'; Trigger = 'cz'; Snippet = 'chezmoi' }
@{ Name = 'chezmoi edit'; TriggerPattern = '^ed?$'; Snippet = 'edit'; Global = $true; Context = $sub }
@{ Name = 'chezmoi status'; TriggerPattern = '^st?$'; Snippet = 'status'; Global = $true; Context = $sub }
@{ Name = 'chezmoi apply'; TriggerPattern = '^app?$'; Snippet = 'apply'; Global = $true; Context = $sub }
@{ Name = 'chezmoi add'; TriggerPattern = '^ad?$'; Snippet = 'add'; Global = $true; Context = $sub }
