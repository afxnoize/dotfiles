vim.g.ref_source_webdict_sites = {
	wikipedia = {
		url = 'https://ja.wikipedia.org/wiki/%s',
	},
	weblio = {
		url = 'https://ejje.weblio.jp/content/%s',
		filter = function(output)
			return table.concat(vim.list_slice(vim.fn.split(output, '\n'), 19), '\n')
		end,
	},
}
