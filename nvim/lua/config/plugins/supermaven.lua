return {
	"supermaven-inc/supermaven-nvim",
	opts = {
		keymaps = {
			accept_suggestion = "<Tab>",
			clear_suggestion = "<C-]>",
			accept_word = "<C-j>",
		},
		ignore_filetypes = {},
		color = {
			suggestion_color = "#808080",
			cterm = 244,
		},
		log_level = "info", -- "info", "warn", "error", "debug"
		disable_inline_completion = false, -- disables inline completion for use with cmp
		disable_keymaps = false, -- disables built in keymaps for more control
	},
	keys = {
		{ "<leader>tm", "<cmd>SupermavenToggle<cr>", desc = "Toggle Supermaven" },
	},
}

