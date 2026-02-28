return {
	"nvim-neo-tree/neo-tree.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
		"MunifTanjim/nui.nvim",
	},
	lazy = false,
	config = function()
		vim.keymap.set("n", "<leader>e", function()
			vim.cmd([[
      Neotree toggle
      ]])
		end, { desc = "Toggle Neo-tree" })
	end,
}