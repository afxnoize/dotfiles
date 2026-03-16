{ pkgs, lib, ... }:

let
  skillsDir = "\${CLAUDE_CONFIG_DIR:-$HOME/.config/claude}/skills";

  installScript = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: entry:
    ''
      if [ ! -d "${skillsDir}/${name}" ]; then
        echo "Installing skill: ${name} from ${entry.source}"
        ${lib.getExe pkgs.bun} x skills add ${entry.source} -s ${name} -a claude-code -g -y
      fi
    ''
  ) (import ./registry.nix));

  stateDir = "\${XDG_STATE_HOME:-$HOME/.local/state}/agent-skills";

in {
  home.activation.agent-skills =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      PATH="${lib.makeBinPath [ pkgs.bun pkgs.git ]}:$PATH"
      mkdir -p "${stateDir}"
      cd "${stateDir}"
      ${installScript}
    '';
}
