-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
-- move selection up / down
map("v", "<C-j>", ":m '>+1<CR>gv=gv")
map("v", "<C-k>", ":m '<-2<CR>gv=gv")
map("n", "<C-j>", ":m .+1<CR>==")
map("i", "<C-j>", "<Esc>:m .+1<CR>==gi")
map("n", "<C-k>", ":m .-2<CR>==")
map("i", "<C-k>", "<Esc>:m .-2<CR>==gi")
