# Ported from dot_config/zabrze/git.toml.
$sub = '^git\s+\S+$'

@{ Name = 'git'; Trigger = 'g'; Snippet = 'git' }
@{ Name = 'git status -sb'; Trigger = 'gst'; Snippet = 'git status -sb' }
@{ Name = 'git add .'; Trigger = 'gad'; Snippet = 'git add .' }
@{ Name = 'git push origin HEAD'; Trigger = 'gpoh'; Snippet = 'git push origin HEAD' }
@{ Name = 'git log -n 10 (formatted)'; Trigger = 'gl'; Snippet = 'git log --pretty=format:"%C(auto)%h (%C(blue)%cd%C(auto))%d %s %C(blue)%cn%Creset" --date=format:"%Y/%m/%d %H:%M:%S" -n 10' }

# subcommands
@{ Name = 'git status'; TriggerPattern = '^st?$'; Snippet = 'status'; Global = $true; Context = $sub }
@{ Name = 'git add'; TriggerPattern = '^ad?$'; Snippet = 'add'; Global = $true; Context = $sub }
@{ Name = 'git add -vA'; Trigger = 'aa'; Snippet = 'add -vA'; Global = $true; Context = $sub }
@{ Name = 'git restore [--staged]'; TriggerPattern = '^re?s(?<staged>s)?$'; Global = $true; Context = $sub
  Evaluate = { param($m) 'restore' + ($m.staged ? ' --staged' : '') } }
@{ Name = 'git diff [--staged] [--ignore-all-space]'; TriggerPattern = '^df?(?<staged>s)?(?<ignore>i)?$'; Global = $true; Context = $sub
  Evaluate = { param($m) 'diff' + ($m.staged ? ' --staged' : '') + ($m.ignore ? ' --ignore-all-space' : '') } }
@{ Name = 'git commit'; Trigger = 'c'; Snippet = 'commit'; Global = $true; Context = $sub }
@{ Name = 'git commit -m'; Trigger = 'cm'; Snippet = 'commit -m "{}"'; Cursor = '{}'; Global = $true; Context = $sub }
@{ Name = 'git commit --amend --no-edit'; Trigger = 'cam'; Snippet = 'commit --amend --no-edit'; Global = $true; Context = $sub }
@{ Name = 'git push'; Trigger = 'ph'; Snippet = 'push'; Global = $true; Context = $sub }
@{ Name = 'git fetch [--prune]'; TriggerPattern = '^fe?(?<prune>p)?$'; Global = $true; Context = $sub
  Evaluate = { param($m) 'fetch' + ($m.prune ? ' --prune' : '') } }
@{ Name = 'git pull'; Trigger = 'pl'; Snippet = 'pull'; Global = $true; Context = $sub }
@{ Name = 'git branch [-v/-vv]'; TriggerPattern = '^br?(?<verbose>v{1,2})?$'; Global = $true; Context = $sub
  Evaluate = { param($m) 'branch' + ($m.verbose ? " -$($m.verbose)" : '') } }
@{ Name = 'git switch'; Trigger = 'sw'; Snippet = 'switch'; Global = $true; Context = $sub }
@{ Name = 'git log [--oneline] [--name-status]'; TriggerPattern = '^l(?<oneline>o)?(?<filename>f)?$'; Global = $true; Context = $sub
  Evaluate = { param($m) 'log' + ($m.oneline ? ' --oneline' : '') + ($m.filename ? ' --name-status' : '') } }
@{ Name = 'git log --graph'; TriggerPattern = '^(gr|graph)$'; Snippet = "log --graph --date=short --decorate=short --pretty=format:'%Cgreen%h %Creset%cn %Cred%d %Creset%s'"; Global = $true; Context = $sub }
@{ Name = 'git stash'; Trigger = 'sh'; Snippet = 'stash'; Global = $true; Context = $sub }
@{ Name = 'git wt'; Trigger = 'w'; Snippet = 'wt'; Global = $true; Context = $sub }

# flags and arguments
@{ Name = 'git restore --staged'; Trigger = 's'; Snippet = '--staged'; Global = $true; Context = '^git\s+restore\s+' }
@{ Name = 'git diff HEAD~N HEAD'; TriggerPattern = '^(?<n>\d+)$'; Global = $true; Context = '^git\s+diff\s+'
  Evaluate = { param($m) "HEAD~$($m.n) HEAD" } }
@{ Name = 'git rebase|merge|cherry-pick --abort'; Trigger = 'a'; Snippet = '--abort'; Global = $true; Context = '^git\s+(cherry-pick|rebase|merge)\s+' }
@{ Name = 'git rebase|merge|cherry-pick --continue'; Trigger = 'c'; Snippet = '--continue'; Global = $true; Context = '^git\s+(cherry-pick|rebase|merge)\s+' }
@{ Name = 'git push --force-with-lease'; Trigger = 'f'; Snippet = '--force-with-lease'; Global = $true; Context = '^git\s+push\s+' }
@{ Name = 'git branch -v/-vv'; TriggerPattern = '^(?<v>v{1,2})$'; Global = $true; Context = '^git\s+branch\s+'
  Evaluate = { param($m) "-$($m.v)" } }
@{ Name = 'git log -N'; TriggerPattern = '^(?<n>\d+)$'; Global = $true; Context = '^git\s+log\s+'
  Evaluate = { param($m) "-$($m.n)" } }
@{ Name = 'git log --grep'; TriggerPattern = '^gp?$'; Snippet = '--grep="{}"'; Cursor = '{}'; Global = $true; Context = '^git\s+log\s+\S+$' }
@{ Name = 'git stash push -m'; Trigger = 'ph'; Snippet = 'push -m'; Global = $true; Context = '^git\s+stash\s+' }

# refs
@{ Name = 'git current branch name'; Trigger = 'B'; Global = $true; Context = '^git\s+'
  Evaluate = { git symbolic-ref --short HEAD 2>$null } }
@{ Name = 'git main/master'; Trigger = 'M'; Global = $true; Context = '^git\s+'
  Evaluate = { git show-ref --verify --quiet refs/heads/main 2>$null; $LASTEXITCODE -eq 0 ? 'main' : 'master' } }
