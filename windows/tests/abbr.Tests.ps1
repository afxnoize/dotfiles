# Specification of the expansion engine in abbr.ps1, written against rules defined here.
# Run: pwsh -NoProfile -Command 'Invoke-Pester windows/tests -Output Detailed'

BeforeAll {
  . (Join-Path $PSScriptRoot '..\dot_config\powershell\abbr.ps1')

  function New-Rules([hashtable[]] $Definitions) { @($Definitions | ForEach-Object { ConvertTo-AbbrRule $_ }) }
  function Expand-Line([object[]] $Rules, [string] $Line, [int] $Cursor = $Line.Length) {
    Expand-AbbrLine -Line $Line -Cursor $Cursor -Rules $Rules
  }
}

Describe 'Expand-AbbrLine' {
  Context 'matching the trigger' {
    BeforeAll {
      $rules = New-Rules @{ Trigger = 'g'; Snippet = 'git' }, @{ Trigger = 'a.b'; Snippet = 'dot' }, @{ TriggerPattern = '^d+$'; Snippet = 'many-d' }
    }

    It 'replaces a word equal to Trigger' {
      $r = Expand-Line $rules 'g'
      $r.Line | Should-BeString 'git' -CaseSensitive
      $r.Cursor | Should-Be 3
      $r.Placed | Should-BeFalse
    }

    It 'leaves a word that only starts with Trigger' {
      Expand-Line $rules 'gg' | Should-BeNull
    }

    It 'treats regex metacharacters in Trigger as plain characters' {
      Expand-Line $rules 'axb' | Should-BeNull
    }

    It 'replaces a word matching TriggerPattern' {
      (Expand-Line $rules 'ddd').Line | Should-BeString 'many-d' -CaseSensitive
    }

    It 'compares Trigger case-sensitively' {
      Expand-Line $rules 'G' | Should-BeNull
    }

    It 'compares TriggerPattern case-sensitively' {
      Expand-Line $rules 'DDD' | Should-BeNull
    }
  }

  Context 'the word before the cursor' {
    BeforeAll { $rules = New-Rules @{ Trigger = 'g'; Snippet = 'git' } }

    It 'keeps the text after the cursor' {
      $r = Expand-Line $rules 'g rest' -Cursor 1
      $r.Line | Should-BeString 'git rest' -CaseSensitive
      $r.Cursor | Should-Be 3
    }

    It 'expands right before <Name>' -ForEach @(
      @{ Name = 'a closing parenthesis'; Line = '(g)'; Cursor = 2; Expected = '(git)' }
      @{ Name = 'a closing brace'; Line = '{ g }'; Cursor = 3; Expected = '{ git }' }
    ) {
      (Expand-Line $rules $Line -Cursor $Cursor).Line | Should-BeString $Expected -CaseSensitive
    }

    It 'does nothing when <Name>' -ForEach @(
      @{ Name = 'the cursor is inside a word'; Line = 'gx'; Cursor = 1 }
      @{ Name = 'the cursor follows whitespace'; Line = 'g '; Cursor = 2 }
      @{ Name = 'the line is empty'; Line = ''; Cursor = 0 }
    ) {
      Expand-Line $rules $Line -Cursor $Cursor | Should-BeNull
    }
  }

  Context 'command position' {
    BeforeAll {
      $local = New-Rules @{ Trigger = 'g'; Snippet = 'git' }
      $global = New-Rules @{ Trigger = 'g'; Snippet = 'git'; Global = $true }
    }

    It 'expands a non-global rule <Name>' -ForEach @(
      @{ Name = 'at the line start'; Line = 'g'; Expected = 'git' }
      @{ Name = 'after leading spaces'; Line = '  g'; Expected = '  git' }
      @{ Name = 'after ;'; Line = 'x; g'; Expected = 'x; git' }
      @{ Name = 'after ; without a space'; Line = 'x;g'; Expected = 'x;git' }
      @{ Name = 'after |'; Line = 'x | g'; Expected = 'x | git' }
      @{ Name = 'after | without a space'; Line = 'x|g'; Expected = 'x|git' }
      @{ Name = 'after &&'; Line = 'x && g'; Expected = 'x && git' }
      @{ Name = 'after the call operator'; Line = '& g'; Expected = '& git' }
      @{ Name = 'after ('; Line = '(g'; Expected = '(git' }
      @{ Name = 'after $('; Line = 'echo $(g'; Expected = 'echo $(git' }
      @{ Name = 'after {'; Line = '{g'; Expected = '{git' }
      @{ Name = 'at the start of a later line'; Line = "echo a`ng"; Expected = "echo a`ngit" }
      @{ Name = 'on a later line inside a block'; Line = "if (1) {`n  echo a`n  g"; Expected = "if (1) {`n  echo a`n  git" }
      @{ Name = 'inside a scriptblock in a hashtable'; Line = '@{ a = { g'; Expected = '@{ a = { git' }
    ) {
      (Expand-Line $local $Line).Line | Should-BeString $Expected -CaseSensitive
    }

    It 'leaves a non-global rule <Name>' -ForEach @(
      @{ Name = 'in argument position'; Line = 'echo g' }
      @{ Name = 'as a hashtable key'; Line = '@{ g' }
      @{ Name = 'as a hashtable key after ;'; Line = '$h = @{ a = 1; g' }
      @{ Name = 'as a hashtable key on a later line'; Line = "@{`n  g" }
    ) {
      Expand-Line $local $Line | Should-BeNull
    }

    It 'expands a Global rule <Name>' -ForEach @(
      @{ Name = 'in argument position'; Line = 'echo g'; Expected = 'echo git' }
      @{ Name = 'at the line start'; Line = 'g'; Expected = 'git' }
    ) {
      (Expand-Line $global $Line).Line | Should-BeString $Expected -CaseSensitive
    }
  }

  Context 'strings and comments' {
    BeforeAll { $rules = New-Rules @{ Trigger = 'g'; Snippet = 'git'; Global = $true } }

    It 'leaves a word inside <Name>' -ForEach @(
      @{ Name = 'double quotes'; Line = 'echo "a g' }
      @{ Name = 'single quotes'; Line = "echo 'a g" }
      @{ Name = 'double quotes after an escaped quote'; Line = 'echo "a`" g' }
      @{ Name = 'single quotes after a doubled quote'; Line = "echo 'it''s g" }
      @{ Name = 'a single-quoted here-string'; Line = "@'`nit's g" }
      @{ Name = 'a double-quoted here-string'; Line = "@`"`nsay `"hi`" g" }
      @{ Name = 'a line comment'; Line = 'echo a # g' }
      @{ Name = 'a block comment'; Line = 'echo <# a g' }
    ) {
      Expand-Line $rules $Line | Should-BeNull
    }

    It 'expands a word after <Name>' -ForEach @(
      @{ Name = 'closed double quotes'; Line = 'echo "a" g'; Expected = 'echo "a" git' }
      @{ Name = 'closed single quotes'; Line = "echo 'a' g"; Expected = "echo 'a' git" }
      @{ Name = 'a backtick in single quotes'; Line = "echo 'a``' g"; Expected = "echo 'a``' git" }
      @{ Name = 'a closed here-string'; Line = "@'`nx`n'@ g"; Expected = "@'`nx`n'@ git" }
      @{ Name = 'a line comment on the previous line'; Line = "# a`necho g"; Expected = "# a`necho git" }
      @{ Name = 'a closed block comment'; Line = 'echo <# a #> g'; Expected = 'echo <# a #> git' }
      @{ Name = 'a # inside a word'; Line = 'echo a#b g'; Expected = 'echo a#b git' }
    ) {
      (Expand-Line $rules $Line).Line | Should-BeString $Expected -CaseSensitive
    }
  }

  Context 'Context' {
    BeforeAll { $rules = New-Rules @{ Trigger = 'st'; Snippet = 'status'; Global = $true; Context = '^git\s+\S+$' } }

    It 'applies when the current statement matches, <Name>' -ForEach @(
      @{ Name = 'alone'; Line = 'git st'; Expected = 'git status' }
      @{ Name = 'after leading spaces'; Line = '  git st'; Expected = '  git status' }
      @{ Name = 'after ;'; Line = 'cd x; git st'; Expected = 'cd x; git status' }
      @{ Name = 'after &&'; Line = 'cd x && git st'; Expected = 'cd x && git status' }
      @{ Name = 'on a later line'; Line = "cd x`ngit st"; Expected = "cd x`ngit status" }
      @{ Name = 'inside parentheses'; Line = '(git st'; Expected = '(git status' }
    ) {
      (Expand-Line $rules $Line).Line | Should-BeString $Expected -CaseSensitive
    }

    It 'does not apply when the current statement does not match' {
      Expand-Line $rules 'git log st' | Should-BeNull
    }

    It 'ignores the text after the cursor' {
      (Expand-Line $rules 'git st --short' -Cursor 6).Line | Should-BeString 'git status --short' -CaseSensitive
    }
  }

  Context 'choosing among rules' {
    It 'uses the first matching rule' {
      $rules = New-Rules @{ Trigger = 'x'; Snippet = 'first' }, @{ Trigger = 'x'; Snippet = 'second' }
      (Expand-Line $rules 'x').Line | Should-BeString 'first' -CaseSensitive
    }

    It 'moves on to the next rule when <Name>' -ForEach @(
      @{ Name = 'If returns false'; Skipped = @{ Trigger = 'x'; Snippet = 'skipped'; If = { $false } } }
      @{ Name = 'If throws'; Skipped = @{ Trigger = 'x'; Snippet = 'skipped'; If = { throw 'if failed' } } }
      @{ Name = 'Context does not match'; Skipped = @{ Trigger = 'x'; Snippet = 'skipped'; Global = $true; Context = '^never' } }
      @{ Name = 'Evaluate returns nothing'; Skipped = @{ Trigger = 'x'; Evaluate = { '' } } }
      @{ Name = 'Evaluate throws'; Skipped = @{ Trigger = 'x'; Evaluate = { throw 'evaluate failed' } } }
      @{ Name = 'If returns false on a rule with Evaluate'; Skipped = @{ Trigger = 'x'; Evaluate = { 'skipped' }; If = { $false } } }
    ) {
      $rules = New-Rules $Skipped, @{ Trigger = 'x'; Snippet = 'fallback' }
      (Expand-Line $rules 'x').Line | Should-BeString 'fallback' -CaseSensitive
    }

    It 'applies a rule whose If returns true' {
      $rules = New-Rules @{ Trigger = 'x'; Snippet = 'chosen'; If = { $true } }
      (Expand-Line $rules 'x').Line | Should-BeString 'chosen' -CaseSensitive
    }
  }

  Context 'Evaluate' {
    BeforeAll {
      $rules = New-Rules @{ TriggerPattern = '^d(?<s>s)?(?<i>i)?$'; Evaluate = { param($m) 'diff' + ($m.s ? ' -s' : '') + ($m.i ? ' -i' : '') } }
    }

    It 'receives the named groups that matched: <Line>' -ForEach @(
      @{ Line = 'd'; Expected = 'diff' }
      @{ Line = 'di'; Expected = 'diff -i' }
      @{ Line = 'dsi'; Expected = 'diff -s -i' }
    ) {
      (Expand-Line $rules $Line).Line | Should-BeString $Expected -CaseSensitive
    }

    It 'joins multiple outputs with newlines' {
      $lines = New-Rules @{ Trigger = 'x'; Evaluate = { 'a'; 'b' } }
      (Expand-Line $lines 'x').Line | Should-BeString "a`nb" -CaseSensitive
    }

    It 'keeps $LASTEXITCODE as it was before expanding' {
      $native = New-Rules @{ Trigger = 'x'; If = { cmd /c exit 3; $true }; Evaluate = { cmd /c exit 4; 'done' } }
      $global:LASTEXITCODE = 0
      (Expand-Line $native 'x').Line | Should-BeString 'done' -CaseSensitive
      $global:LASTEXITCODE | Should-Be 0
    }
  }

  Context 'Cursor marker' {
    It 'removes the marker and puts the cursor where it was' {
      $rules = New-Rules @{ Trigger = 'cm'; Snippet = 'commit -m "{}"'; Cursor = '{}' }
      $r = Expand-Line $rules 'x; cm --amend' -Cursor 5
      $r.Line | Should-BeString 'x; commit -m "" --amend' -CaseSensitive
      $r.Cursor | Should-Be 14
      $r.Placed | Should-BeTrue
    }

    It 'removes only the first marker' {
      $rules = New-Rules @{ Trigger = 'x'; Snippet = 'a{}b{}c'; Cursor = '{}' }
      $r = Expand-Line $rules 'x'
      $r.Line | Should-BeString 'ab{}c' -CaseSensitive
      $r.Cursor | Should-Be 1
    }

    It 'applies to the output of Evaluate' {
      $rules = New-Rules @{ Trigger = 'x'; Evaluate = { 'say "{}"' }; Cursor = '{}' }
      $r = Expand-Line $rules 'x'
      $r.Line | Should-BeString 'say ""' -CaseSensitive
      $r.Cursor | Should-Be 5
    }

    It 'leaves the cursor at the end when the snippet has no marker' {
      $rules = New-Rules @{ Trigger = 'x'; Snippet = 'plain'; Cursor = '{}' }
      $r = Expand-Line $rules 'x'
      $r.Cursor | Should-Be 5
      $r.Placed | Should-BeFalse
    }
  }
}

Describe 'Resolve-AbbrKey' {
  BeforeAll {
    $rules = New-Rules @{ Trigger = 'g'; Snippet = 'git' }, @{ Trigger = 'cm'; Snippet = 'commit -m "{}"'; Cursor = '{}' }
  }

  It '<Key> on "<Line>" then does <Then>' -ForEach @(
    @{ Key = 'Space'; Line = 'g'; Then = 'InsertSpace'; Expands = $true }
    @{ Key = 'Space'; Line = 'echo'; Then = 'InsertSpace'; Expands = $false }
    @{ Key = 'Space'; Line = 'cm'; Then = 'None'; Expands = $true }
    @{ Key = 'Enter'; Line = 'g'; Then = 'AcceptLine'; Expands = $true }
    @{ Key = 'Enter'; Line = 'echo'; Then = 'AcceptLine'; Expands = $false }
    @{ Key = 'Enter'; Line = 'cm'; Then = 'None'; Expands = $true }
  ) {
    $action = Resolve-AbbrKey -Key $Key -Line $Line -Cursor $Line.Length -Rules $rules
    $action.Then | Should-Be $Then
    ($null -ne $action.Expansion) | Should-Be $Expands
  }

  It '<Key> on "<Line>" while more keys are pending (a paste) does <Then> without expanding' -ForEach @(
    @{ Key = 'Space'; Line = 'g'; Then = 'InsertSpace' }
    @{ Key = 'Enter'; Line = 'g'; Then = 'AcceptLine' }
    @{ Key = 'Enter'; Line = 'cm'; Then = 'AcceptLine' }
  ) {
    $action = Resolve-AbbrKey -Key $Key -Line $Line -Cursor $Line.Length -Rules $rules -InputPending
    $action.Then | Should-Be $Then
    $action.Expansion | Should-BeNull
  }
}

Describe 'ConvertTo-AbbrRule' {
  It 'rejects a rule with <Name>' -ForEach @(
    @{ Name = 'both Trigger and TriggerPattern'; Rule = @{ Trigger = 'a'; TriggerPattern = '^a$'; Snippet = 'x' }; Message = '*exactly one of Trigger or TriggerPattern*' }
    @{ Name = 'neither Trigger nor TriggerPattern'; Rule = @{ Snippet = 'x' }; Message = '*exactly one of Trigger or TriggerPattern*' }
    @{ Name = 'neither Snippet nor Evaluate'; Rule = @{ Trigger = 'a' }; Message = '*exactly one of Snippet or Evaluate*' }
    @{ Name = 'both Snippet and Evaluate'; Rule = @{ Trigger = 'a'; Snippet = 'x'; Evaluate = { 'y' } }; Message = '*exactly one of Snippet or Evaluate*' }
    @{ Name = 'an Evaluate that is not a scriptblock'; Rule = @{ Trigger = 'a'; Evaluate = 'x' }; Message = '*Evaluate must be a scriptblock*' }
    @{ Name = 'an If that is not a scriptblock'; Rule = @{ Trigger = 'a'; Snippet = 'x'; If = '$true' }; Message = '*If must be a scriptblock*' }
    @{ Name = 'a Cursor that is not a string'; Rule = @{ Trigger = 'a'; Snippet = 'x'; Cursor = 1 }; Message = '*Cursor must be a string*' }
    @{ Name = 'a misspelled key'; Rule = @{ Trigger = 'a'; Snipet = 'x'; Snippet = 'y' }; Message = '*unknown key(s): Snipet*' }
    @{ Name = 'an invalid TriggerPattern'; Rule = @{ TriggerPattern = '('; Snippet = 'x' }; Message = '*Invalid pattern*' }
    @{ Name = 'an invalid Context'; Rule = @{ Trigger = 'a'; Snippet = 'x'; Context = '(' }; Message = '*Invalid pattern*' }
  ) {
    { ConvertTo-AbbrRule $Rule } | Should-Throw -ExceptionMessage $Message
  }
}

Describe 'Import-AbbrRule' {
  It 'reads only *.ps1 files, in file name order' {
    Set-Content (Join-Path $TestDrive 'a.ps1') "@{ Trigger = 'x'; Snippet = 'from-a' }; @{ Trigger = 'y'; Snippet = 'y' }"
    Set-Content (Join-Path $TestDrive '_first.ps1') "@{ Trigger = 'x'; Snippet = 'from-first' }"
    Set-Content (Join-Path $TestDrive 'c.txt') "@{ Trigger = 'x'; Snippet = 'from-txt' }"

    $rules = @(Import-AbbrRule $TestDrive)

    $rules.Count | Should-Be 3
    (Expand-Line $rules 'x').Line | Should-BeString 'from-first' -CaseSensitive
  }
}

Describe 'shipped rule files' {
  It 'load without errors' {
    $rules = @(Import-AbbrRule (Join-Path $PSScriptRoot '..\dot_config\powershell\abbr'))
    $rules.Count | Should-BeGreaterThan 0
  }
}
