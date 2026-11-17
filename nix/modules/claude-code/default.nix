{ config, pkgs, inputs, ... }:

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
    ];
  };
}
