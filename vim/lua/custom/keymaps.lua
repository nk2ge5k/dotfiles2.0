local telescope = require("telescope")
local builtin = require("telescope.builtin")
local actions = require("telescope.actions")

-- telescope -----------------------------------------------------
------------------------------------------------------------------

telescope.setup({
  defaults = {
    mappings = {
      i = {
        ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
      },
      n = {
        ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
      }
    },
  },
})

vim.keymap.set("n", "<C-p>", builtin.find_files)
vim.keymap.set("n", "<C-f>", builtin.current_buffer_fuzzy_find)
vim.keymap.set("n", "<leader>,", builtin.live_grep)
vim.keymap.set("n", "<leader>;", builtin.buffers)
vim.keymap.set("n", "<leader>t", builtin.treesitter)
vim.keymap.set("n", "<leader>dl", builtin.diagnostics)
vim.keymap.set("n", "<leader>fw", builtin.grep_string)
