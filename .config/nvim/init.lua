vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true
vim.opt.number = true
vim.opt.mouse = "a"
vim.opt.showmode = false
vim.opt.termguicolors = true

vim.schedule(function()
	vim.opt.clipboard = "unnamedplus"
end)
vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.list = true
vim.opt.showbreak = " "
vim.opt.fillchars = {
	foldopen = "-",
	foldclose = "+",
	fold = " ",
	foldsep = "|",
	diff = "-",
	eob = " ",
}
vim.opt.laststatus = 3
vim.opt.shiftwidth = 2
vim.opt.inccommand = "split"
vim.opt.cursorline = true
vim.opt.scrolloff = 10
vim.opt.confirm = true
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, {
	desc = "Open diagnostic [Q]uickfix list",
})
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", {
	desc = "Exit terminal mode",
})
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", {
	desc = "Move focus to the left window",
})
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", {
	desc = "Move focus to the right window",
})
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", {
	desc = "Move focus to the lower window",
})
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", {
	desc = "Move focus to the upper window",
})

vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("aseeralfaisal-highlight-yank", {
		clear = true,
	}),
	callback = function()
		vim.highlight.on_yank()
	end,
})

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		error("Error cloning lazy.nvim:\n" .. out)
	end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	"tpope/vim-sleuth",
	{
		"lewis6991/gitsigns.nvim",
		opts = {
			signs = {
				add = {
					text = "+",
				},
				change = {
					text = "~",
				},
				delete = {
					text = "_",
				},
				topdelete = {
					text = "‾",
				},
				changedelete = {
					text = "~",
				},
			},
		},
	},
	{
		"folke/which-key.nvim",
		event = "VimEnter",
		opts = {
			delay = 0,
			icons = {
				mappings = vim.g.have_nerd_font,
				keys = vim.g.have_nerd_font and {} or {
					Up = "<Up> ",
					Down = "<Down> ",
					Left = "<Left> ",
					Right = "<Right> ",
					C = "<C-…> ",
					M = "<M-…> ",
					D = "<D-…> ",
					S = "<S-…> ",
					CR = "<CR> ",
					Esc = "<Esc> ",
					ScrollWheelDown = "<ScrollWheelDown> ",
					ScrollWheelUp = "<ScrollWheelUp> ",
					NL = "<NL> ",
					BS = "<BS> ",
					Space = "<Space> ",
					Tab = "<Tab> ",
					F1 = "<F1>",
					F2 = "<F2>",
					F3 = "<F3>",
					F4 = "<F4>",
					F5 = "<F5>",
					F6 = "<F6>",
					F7 = "<F7>",
					F8 = "<F8>",
					F9 = "<F9>",
					F10 = "<F10>",
					F11 = "<F11>",
					F12 = "<F12>",
				},
			},

			spec = {
				{
					"<leader>s",
					group = "[S]earch",
				},
				{
					"<leader>t",
					group = "[T]oggle",
				},
				{
					"<leader>h",
					group = "Git [H]unk",
					mode = { "n", "v" },
				},
			},
		},
	},
	{
		"nvim-telescope/telescope.nvim",
		event = "VimEnter",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "make",
				cond = function()
					return vim.fn.executable("make") == 1
				end,
			},
			{ "nvim-telescope/telescope-ui-select.nvim" },
			{
				"nvim-tree/nvim-web-devicons",
				enabled = vim.g.have_nerd_font,
			},
		},
		config = function()
			require("telescope").setup({
				-- You can put your default mappings / updates / etc. in here
				--  All the info you're looking for is in `:help telescope.setup()`
				--
				-- defaults = {
				--   mappings = {
				--     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
				--   },
				-- },
				-- pickers = {}
				extensions = {
					["ui-select"] = { require("telescope.themes").get_dropdown() },
				},
			})

			-- Enable Telescope extensions if they are installed
			pcall(require("telescope").load_extension, "fzf")
			pcall(require("telescope").load_extension, "ui-select")

			-- See `:help telescope.builtin`
			local builtin = require("telescope.builtin")
			vim.keymap.set("n", "<leader>sh", builtin.help_tags, {
				desc = "[S]earch [H]elp",
			})
			vim.keymap.set("n", "<leader>sk", builtin.keymaps, {
				desc = "[S]earch [K]eymaps",
			})
			vim.keymap.set("n", "<leader>sf", builtin.find_files, {
				desc = "[S]earch [F]iles",
			})
			vim.keymap.set("n", "<leader>ss", builtin.builtin, {
				desc = "[S]earch [S]elect Telescope",
			})
			vim.keymap.set("n", "<leader>sw", builtin.grep_string, {
				desc = "[S]earch current [W]ord",
			})
			vim.keymap.set("n", "<leader>sg", builtin.live_grep, {
				desc = "[S]earch by [G]rep",
			})
			vim.keymap.set("n", "<leader>sd", builtin.diagnostics, {
				desc = "[S]earch [D]iagnostics",
			})
			vim.keymap.set("n", "<leader>sr", builtin.resume, {
				desc = "[S]earch [R]esume",
			})
			vim.keymap.set("n", "<leader>s.", builtin.oldfiles, {
				desc = '[S]earch Recent Files ("." for repeat)',
			})
			vim.keymap.set("n", "<leader><leader>", builtin.buffers, {
				desc = "[ ] Find existing buffers",
			})

			-- Slightly advanced example of overriding default behavior and theme
			vim.keymap.set("n", "<leader>/", function()
				-- You can pass additional configuration to Telescope to change the theme, layout, etc.
				builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
					winblend = 10,
					previewer = false,
				}))
			end, {
				desc = "[/] Fuzzily search in current buffer",
			})

			-- It's also possible to pass additional configuration options.
			--  See `:help telescope.builtin.live_grep()` for information about particular keys
			vim.keymap.set("n", "<leader>s/", function()
				builtin.live_grep({
					grep_open_files = true,
					prompt_title = "Live Grep in Open Files",
				})
			end, {
				desc = "[S]earch [/] in Open Files",
			})

			-- Shortcut for searching your Neovim configuration files
			vim.keymap.set("n", "<leader>sn", function()
				builtin.find_files({
					cwd = vim.fn.stdpath("config"),
				})
			end, {
				desc = "[S]earch [N]eovim files",
			})
		end,
	},
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				{
					path = "${3rd}/luv/library",
					words = { "vim%.uv" },
				},
			},
		},
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			{
				"mason-org/mason.nvim",
				opts = {},
			},
			"mason-org/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",

			{
				"j-hui/fidget.nvim",
				opts = {},
			},
			"saghen/blink.cmp",
		},
		config = function()
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("aseeralfaisal-lsp-attach", {
					clear = true,
				}),
				callback = function(event)
					local map = function(keys, func, desc, mode)
						mode = mode or "n"
						vim.keymap.set(mode, keys, func, {
							buffer = event.buf,
							desc = "LSP: " .. desc,
						})
					end
					map("grn", vim.lsp.buf.rename, "[R]e[n]ame")

					map("gra", vim.lsp.buf.code_action, "[G]oto Code [A]ction", { "n", "x" })

					map("grr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")

					map("gri", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")

					map("grd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")

					map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

					map("gO", require("telescope.builtin").lsp_document_symbols, "Open Document Symbols")

					map("gW", require("telescope.builtin").lsp_dynamic_workspace_symbols, "Open Workspace Symbols")

					map("grt", require("telescope.builtin").lsp_type_definitions, "[G]oto [T]ype Definition")

					-- This function resolves a difference between neovim nightly (version 0.11) and stable (version 0.10)
					---@param client vim.lsp.Client
					---@param method vim.lsp.protocol.Method
					---@param bufnr? integer some lsp support methods only in specific files
					---@return boolean
					local function client_supports_method(client, method, bufnr)
						if vim.fn.has("nvim-0.11") == 1 then
							return client:supports_method(method, bufnr)
						else
							return client.supports_method(method, {
								bufnr = bufnr,
							})
						end
					end

					local client = vim.lsp.get_client_by_id(event.data.client_id)
					if
						client
						and client_supports_method(
							client,
							vim.lsp.protocol.Methods.textDocument_documentHighlight,
							event.buf
						)
					then
						local highlight_augroup = vim.api.nvim_create_augroup("aseeralfaisal-lsp-highlight", {
							clear = false,
						})
						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.document_highlight,
						})

						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.clear_references,
						})

						vim.api.nvim_create_autocmd("LspDetach", {
							group = vim.api.nvim_create_augroup("aseeralfaisal-lsp-detach", {
								clear = true,
							}),
							callback = function(event2)
								vim.lsp.buf.clear_references()
								vim.api.nvim_clear_autocmds({
									group = "aseeralfaisal-lsp-highlight",
									buffer = event2.buf,
								})
							end,
						})
					end

					-- The following code creates a keymap to toggle inlay hints in your
					-- code, if the language server you are using supports them
					--
					-- This may be unwanted, since they displace some of your code
					if
						client
						and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf)
					then
						map("<leader>th", function()
							vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({
								bufnr = event.buf,
							}))
						end, "[T]oggle Inlay [H]ints")
					end
				end,
			})

			vim.diagnostic.config({
				severity_sort = true,
				float = {
					border = "rounded",
					source = "if_many",
				},
				underline = {
					severity = vim.diagnostic.severity.ERROR,
				},
				signs = vim.g.have_nerd_font and {
					text = {
						[vim.diagnostic.severity.ERROR] = "󰅚 ",
						[vim.diagnostic.severity.WARN] = "󰀪 ",
						[vim.diagnostic.severity.INFO] = "󰋽 ",
						[vim.diagnostic.severity.HINT] = "󰌶 ",
					},
				} or {},
				virtual_text = {
					source = "if_many",
					spacing = 2,
					format = function(diagnostic)
						local diagnostic_message = {
							[vim.diagnostic.severity.ERROR] = diagnostic.message,
							[vim.diagnostic.severity.WARN] = diagnostic.message,
							[vim.diagnostic.severity.INFO] = diagnostic.message,
							[vim.diagnostic.severity.HINT] = diagnostic.message,
						}
						return diagnostic_message[diagnostic.severity]
					end,
				},
			})

			local capabilities = require("blink.cmp").get_lsp_capabilities()

			local servers = {
				lua_ls = {
					-- cmd = { ... },
					-- filetypes = { ... },
					-- capabilities = {},
					settings = {
						Lua = {
							completion = {
								callSnippet = "Replace",
							},
							-- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
							-- diagnostics = { disable = { 'missing-fields' } },
						},
					},
				},
			}

			local ensure_installed = vim.tbl_keys(servers)

			require("mason-tool-installer").setup({
				ensure_installed = { "stylua", "markdownlint" },
			})

			for server_name, server in pairs(servers) do
				server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
				vim.lsp.config(server_name, server)
			end

			require("mason-lspconfig").setup({
				ensure_installed = ensure_installed,
				automatic_enable = ensure_installed,
			})
		end,
	},
	{ -- Autoformat
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		keys = {
			{
				"<leader>f",
				function()
					require("conform").format({
						async = true,
						lsp_format = "fallback",
					})
				end,
				mode = "",
				desc = "[F]ormat buffer",
			},
		},
		opts = {
			notify_on_error = false,
			format_on_save = function(bufnr)
				local disable_filetypes = {
					c = true,
					cpp = true,
				}
				if disable_filetypes[vim.bo[bufnr].filetype] then
					return nil
				else
					return {
						timeout_ms = 500,
						lsp_format = "fallback",
					}
				end
			end,
			formatters_by_ft = {
				lua = { "stylua" },
				javascript = { "prettier" },
				typescript = { "prettier" },
				typescriptreact = { "prettier" },
				html = { "prettier" },
				css = { "prettier" },
				json = { "prettier" },
				markdown = { "prettier" },
				yaml = { "prettier" },
				sh = { "shfmt" },
				bash = { "shfmt" },
				python = { "black", "isort", "ruff" },
			},
		},
	},
	{ -- Autocompletion
		"saghen/blink.cmp",
		event = "VimEnter",
		version = "1.*",
		dependencies = { -- Snippet Engine
			{
				"L3MON4D3/LuaSnip",
				version = "2.*",
				build = (function()
					-- Build Step is needed for regex support in snippets.
					-- This step is not supported in many windows environments.
					-- Remove the below condition to re-enable on windows.
					if vim.fn.has("win32") == 1 or vim.fn.executable("make") == 0 then
						return
					end
					return "make install_jsregexp"
				end)(),
				dependencies = {
					-- `friendly-snippets` contains a variety of premade snippets.
					--    See the README about individual language/framework/plugin snippets:
					--    https://github.com/rafamadriz/friendly-snippets
					-- {
					--   'rafamadriz/friendly-snippets',
					--   config = function()
					--     require('luasnip.loaders.from_vscode').lazy_load()
					--   end,
					-- },
				},
				opts = {},
			},
			"folke/lazydev.nvim",
		},
		opts = {
			keymap = {
				preset = "default",
			},

			appearance = {
				-- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
				-- Adjusts spacing to ensure icons are aligned
				nerd_font_variant = "mono",
			},

			completion = {
				-- By default, you may press `<c-space>` to show the documentation.
				-- Optionally, set `auto_show = true` to show the documentation after a delay.
				documentation = {
					auto_show = false,
					auto_show_delay_ms = 500,
				},
			},

			sources = {
				default = { "lsp", "path", "snippets", "lazydev" },
				providers = {
					lazydev = {
						module = "lazydev.integrations.blink",
						score_offset = 100,
					},
				},
			},

			snippets = {
				preset = "luasnip",
			},

			fuzzy = {
				implementation = "lua",
			},

			-- Shows a signature help window while you type arguments for a function
			signature = {
				enabled = true,
			},
		},
	},
	{
		"folke/tokyonight.nvim",
		priority = 1000,
		config = function()
			---@diagnostic disable-next-line: missing-fields
			require("tokyonight").setup({
				styles = {
					comments = {
						italic = false,
					}, -- Disable italics in comments
				},
			})

			vim.cmd.colorscheme("tokyonight-night")
		end,
	},
	{
		"folke/todo-comments.nvim",
		event = "VimEnter",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			signs = false,
		},
	},
	{
		"echasnovski/mini.nvim",
		config = function()
			-- Better Around/Inside textobjects
			--
			-- Examples:
			--  - va)  - [V]isually select [A]round [)]paren
			--  - yinq - [Y]ank [I]nside [N]ext [Q]uote
			--  - ci'  - [C]hange [I]nside [']quote
			require("mini.ai").setup({
				n_lines = 500,
			})

			-- Add/delete/replace surroundings (brackets, quotes, etc.)
			--
			-- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
			-- - sd'   - [S]urround [D]elete [']quotes
			-- - sr)'  - [S]urround [R]eplace [)] [']
			require("mini.surround").setup()

			local statusline = require("mini.statusline")
			statusline.setup({
				use_icons = vim.g.have_nerd_font,
			})
			---@diagnostic disable-next-line: duplicate-set-field
			statusline.section_location = function()
				return "%2l:%-2v"
			end
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			local treesitter = require("nvim-treesitter")
			local parsers = {
				"bash",
				"c",
				"diff",
				"html",
				"lua",
				"luadoc",
				"markdown",
				"markdown_inline",
				"query",
				"vim",
				"vimdoc",
			}

			treesitter.setup({})
			treesitter.install(parsers)

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("aseeralfaisal-treesitter", { clear = true }),
				pattern = { "bash", "c", "html", "lua", "markdown", "query", "vim", "vimdoc" },
				callback = function(event)
					pcall(vim.treesitter.start, event.buf)
					vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})
		end,
	},
	{
		"nvim-tree/nvim-web-devicons",
		opts = {},
	},

	-- ATTACH PLUGINS HERE
	require("aseeralfaisal.plugins.lint"),
	require("aseeralfaisal.plugins.autopairs"),
	require("aseeralfaisal.plugins.gitsigns"),
	require("aseeralfaisal.plugins.neotree"),
	require("aseeralfaisal.plugins.indent-blankline"),
	require("aseeralfaisal.plugins.avante"),
	require("aseeralfaisal.plugins.bufferline"),
	require("aseeralfaisal.plugins.codediff"),
}, {
	ui = {
		icons = vim.g.have_nerd_font and {} or {
			cmd = "⌘",
			config = "🛠",
			event = "📅",
			ft = "📂",
			init = "⚙",
			keys = "🗝",
			plugin = "🔌",
			runtime = "💻",
			require = "🌙",
			source = "📄",
			start = "🚀",
			task = "📌",
			lazy = "💤 ",
		},
	},
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
