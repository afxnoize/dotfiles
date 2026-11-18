# Ported from dot_config/zabrze/tailscale.toml.
$sub = '^tailscale\s+\S+$'
$serve = '^tailscale\s+serve\s+'

@{ Name = 'tailscale'; Trigger = 'ts'; Snippet = 'tailscale' }
@{ Name = 'tailscale serve'; Trigger = 'sv'; Snippet = 'serve'; Global = $true; Context = $sub }
@{ Name = 'tailscale funnel --bg'; TriggerPattern = '^fn?$'; Snippet = 'funnel --bg'; Global = $true; Context = $sub }
@{ Name = 'tailscale serve status'; Trigger = 'st'; Snippet = 'status'; Global = $true; Context = $serve }
@{ Name = 'tailscale serve --bg'; TriggerPattern = '^bg?$'; Snippet = '--bg'; Global = $true; Context = $serve }
@{ Name = 'tailscale serve --set-path'; TriggerPattern = '^pa?t?h?$'; Snippet = '--set-path'; Global = $true; Context = '^tailscale\s+(serve|funnel)\s+' }
