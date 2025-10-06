return {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    -- Add smarty to the list of installed parsers
    vim.list_extend(opts.ensure_installed, { "smarty" })

    -- Add highlighting config
    opts.highlight = opts.highlight or {}
    opts.highlight.enable = true
    opts.highlight.additional_vim_regex_highlighting = true

    -- Register custom parser
    -- local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
    -- parser_config.smarty = {
    --   install_info = {
    --     url = "https://github.com/Kibadda/tree-sitter-smarty",
    --     files = { "src/parser.c" },
    --     branch = "main",
    --   },
    --   filetype = "smarty",
    -- }
  end,
}
