# happy-coder from llm-agents, wrapped to default HAPPY_CLAUDE_PATH to the
# Home-Manager profile's claude. Upstream's bin/happy falls back to
# `command -v claude`, which depends on PATH order (~/.local/bin comes first).
# HAPPY_CLAUDE_PATH only affects local-mode sessions started from a terminal
# (scripts/claude_local_launcher.cjs). Sessions the daemon spawns run in remote
# mode through the bundled claude-agent-sdk and its own claude binary, which this
# setting does not change.
# The path goes through the profile rather than a claude-code store path, so a
# claude update by `claude-update` applies to the next local session.
# --set-default keeps HAPPY_CLAUDE_PATH overridable from the environment.
# HAPPY_HOME_DIR moves happy's data (settings, access.key, daemon state, logs)
# from ~/.happy to $XDG_STATE_HOME/happy. It is resolved at run time so it
# follows XDG_STATE_HOME, and the daemon inherits it from the launching happy.
# Only bin/happy is wrapped: happy starts its MCP bridge via
# `node .../bin/happy-mcp.mjs`, never through bin/happy-mcp.
{ inputs, system, claudePath }:

final: prev:
let
  happy = inputs.llm-agents.packages.${system}.happy-coder;
in
{
  happy-coder = final.symlinkJoin {
    name = "happy-coder-${happy.version}";
    inherit (happy) version meta;
    paths = [ happy ];
    nativeBuildInputs = [ final.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/happy" \
        --set-default HAPPY_CLAUDE_PATH ${final.lib.escapeShellArg claudePath} \
        --run 'export HAPPY_HOME_DIR="''${HAPPY_HOME_DIR-''${XDG_STATE_HOME:-$HOME/.local/state}/happy}"'
    '';
  };
}
