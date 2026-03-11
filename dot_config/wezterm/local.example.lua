local wezterm = require 'wezterm';

local config = {}
if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.default_domain = 'WSL:Ubuntu'
config.wsl_domains = {
	{
		name = "WSL:Ubuntu",
		distribution = "Ubuntu",
		default_cwd = "~",
		default_prog = { "zsh" },
	},
}

config.ssh_domains = {
	{
        	name = "SSH:sample",
        	remote_address= "192.168.0.1:22",
        	username = "user",
        	ssh_option = {
        		identityfile = "$HOME\\ssh\\key"
		},
	},
}

return config
