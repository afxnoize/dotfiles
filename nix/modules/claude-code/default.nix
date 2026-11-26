{ config, pkgs, inputs, ... }:

let
  # Hide the band above the prompt until a task tree exists.
  claude-timeline = pkgs.applyPatches {
    name = "claude-timeline";
    src = inputs.plugin-claude-timeline;
    patches = [ ./timeline-hide-empty-band.patch ];
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
    ];
  };
}
