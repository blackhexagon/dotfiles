return {
  -- Enhanced spell checking with ltex-ls (grammar + spelling)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ltex = {
          filetypes = { "markdown", "text", "gitcommit", "latex" },
        },
      },
    },
  },
}
