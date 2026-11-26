{ config, pkgs, inputs, ... }:

let
  # Hide the band above the prompt until a task tree exists, and keep the UI
  # in English whatever the language setting says.
  claude-timeline = pkgs.applyPatches {
    name = "claude-timeline";
    src = inputs.plugin-claude-timeline;
    patches = [
      ./timeline-hide-empty-band.patch
      ./timeline-english-ui.patch
    ];
  };
  # Put the newest prompt on the left of the rail, find the transcript under
  # the config dir when loaded with --plugin-dir, skip the classic hooks the
  # security default never runs, and never star the repo.
  prompt-rail = pkgs.applyPatches {
    name = "prompt-rail";
    src = "${inputs.plugin-prompt-rail}/plugins/prompt-rail";
    patches = [
      ./prompt-rail-newest-left.patch
      ./prompt-rail-config-dir.patch
      ./prompt-rail-no-star.patch
      ./prompt-rail-no-classic-hooks.patch
    ];
    postPatch = ''
      substituteInPlace hooks/index.tsx \
        --replace-fail '@claudeConfigDir@' '${config.programs.claude-code.configDir}'
    '';
  };
in
{
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
    configDir = "${config.xdg.configHome}/claude";

    skills = {
      stop-ai-slop-jp = "${inputs.skill-stop-ai-slop-jp}";
      grilling = "${inputs.skills-mattpocock}/skills/productivity/grilling";
    };

    plugins = [
      "${inputs.plugin-imozuru}"
      "${inputs.plugins-pstack}/plugins/pstack"
      "${inputs.plugins-voltagent}/categories/10-research-analysis"
      "${claude-timeline}"
      "${prompt-rail}"
      "${inputs.plugin-md-prompt}/plugins/md-prompt"
    ];
  };
}
