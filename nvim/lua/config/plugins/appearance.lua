return {
	{
		"rebelot/kanagawa.nvim",
		name = "kanagawa",
		lazy = false,
		priority = 1000,
		config = function()
			require("kanagawa").setup({
				compile = false,
				undercurl = true,
				commentStyle = { italic = true, bold = true },
				keywordStyle = { italic = true },
				statementStyle = { bold = true },
				transparent = false,
				terminalColors = true,
				theme = "wave",
				background = {
					dark = "wave",
					light = "wave",
				},
			})
			vim.cmd("colorscheme kanagawa")
		end,
	},
}
