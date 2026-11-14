# happy-coder from llm-agents, wrapped to default HAPPY_CLAUDE_PATH to the
# Home-Manager profile's claude. Upstream's bin/happy falls back to
# `command -v claude`, which depends on PATH order (~/.local/bin comes first).
# The path goes through the profile rather than a claude-code store path, so a
# long-running happy daemon picks up claude updates made by `claude-update`
# without a restart (the daemon only restarts when happy's own version changes).
# --set-default keeps HAPPY_CLAUDE_PATH overridable from the environment.
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
      wrapProgram "$out/bin/happy" --set-default HAPPY_CLAUDE_PATH ${final.lib.escapeShellArg claudePath}
    '';
  };
}
