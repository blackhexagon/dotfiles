require "nvchad.mappings"
local map = vim.keymap.set
local harpoon = require "harpoon"
harpoon:setup {}
local builtin = require "telescope.builtin"
local telescopeUtils = require "telescope.utils"

map("n", "<leader>ff", function()
  builtin.find_files { cwd = telescopeUtils.buffer_dir() }
end, { desc = "Find files in cwd" })
-- add yours here
map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
-- move selection up / down
map("v", "<C-j>", ":m '>+1<CR>gv=gv")
map("v", "<C-k>", ":m '<-2<CR>gv=gv")
map("n", "<C-j>", ":m .+1<CR>==")
map("n", "<C-k>", ":m .-2<CR>==")
map("i", "<C-j>", "<Esc>:m .+1<CR>==gi")
map("i", "<C-k>", "<Esc>:m .-2<CR>==gi")
-- save on command s
map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
-- exit terminal
map("t", "<Esc>", "<C-\\><C-n>")

-- harpoon
local conf = require("telescope.config").values
local function toggle_telescope(harpoon_files)
  local finder = function()
    local paths = {}
    for _, item in ipairs(harpoon_files.items) do
      table.insert(paths, item.value)
    end

    return require("telescope.finders").new_table {
      results = paths,
    }
  end
  require("telescope.pickers")
    .new({}, {
      prompt_title = "Harpoon",
      finder = finder(),
      previewer = conf.file_previewer {},
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, teleMap)
        teleMap("i", "<C-d>", function()
          local state = require "telescope.actions.state"
          local selected_entry = state.get_selected_entry()
          local current_picker = state.get_current_picker(prompt_bufnr)

          table.remove(harpoon_files.items, selected_entry.index)
          current_picker:refresh(finder())
        end)
        return true
      end,
    })
    :find()
end

map("n", "<C-h>", function()
  toggle_telescope(harpoon:list())
end, { desc = "Open harpoon window" })

map("n", "<C-x>", function()
  harpoon:list():add()
end, { desc = "add to harpoon list" })

map("v", "<leader>d", ":lua DebugSelection()<CR>", {
  noremap = true,
  silent = true,
  desc = "Debug Selection",
})
-- vim.keymap.set("n", "<C-h>", function(
--   harpoon:list():select(1)
-- end)
-- vim.keymap.set("n", "<C-t>", function()
--   harpoon:list():select(2)
-- end)
-- vim.keymap.set("n", "<C-n>", function()
--   harpoon:list():select(3)
-- end)
-- vim.keymap.set("n", "<C-s>", function()
--   harpoon:list():select(4)
-- end)
--
-- -- Toggle previous & next buffers stored within Harpoon list
-- vim.keymap.set("n", "<C-S-P>", function()
--   harpoon:list():prev()
-- end)
-- vim.keymap.set("n", "<C-S-N>", function()
--   harpoon:list():next()
-- end)
