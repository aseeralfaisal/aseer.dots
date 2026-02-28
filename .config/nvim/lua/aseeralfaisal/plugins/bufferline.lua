return {
	"akinsho/bufferline.nvim",
	lazy = false,
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		require("bufferline").setup({
			options = {
				mode = "buffers",
				separator_style = "slant",
				offsets = {
					{
						filetype = "neo-tree",
						text = "",
						highlight = "Directory",
						text_align = "left",
					},
				},
				diagnostics = "nvim_lsp",
			},
		})

		-- Set keymaps for buffer navigation
		vim.keymap.set('n', '<S-h>', '<cmd>BufferLineCyclePrev<cr>', { desc = 'Previous buffer' })
		vim.keymap.set('n', '<S-l>', '<cmd>BufferLineCycleNext<cr>', { desc = 'Next buffer' })
		
		-- Add keymaps for closing buffers
		vim.keymap.set('n', '<leader>bc', '<cmd>bdelete<cr>', { desc = 'Close current buffer' })
		vim.keymap.set('n', '<leader>bC', '<cmd>%bdelete<cr>', { desc = 'Close all buffers' })
	end,
}
