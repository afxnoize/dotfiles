{ pkgs, lib, ... }:

let
  installScript = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: entry:
    let
      source = if entry ? path
        then "${entry.source} --full-depth"
        else entry.source;
    in ''
      if [ ! -d "$HOME/.agents/skills/${name}" ]; then
        echo "Installing skill: ${name} from ${entry.source}"
        ${lib.getExe pkgs.bun} x skills add ${source} -s ${name} -a claude-code -y
      fi
    ''
  ) (import ./registry.nix));

in {
  home.activation.agent-skills =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      PATH="${lib.makeBinPath [ pkgs.bun pkgs.git ]}:$PATH"
      ${installScript}
    '';
}
