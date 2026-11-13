-- In projects with an oxfmt config, format with oxfmt instead of Prettier.
-- Other projects keep the formatters from the LazyVim extras.
local config_files = { ".oxfmtrc.json", ".oxfmtrc.jsonc", "oxfmt.config.ts" }

local filetypes = {
  "css",
  "graphql",
  "html",
  "javascript",
  "javascriptreact",
  "json",
  "jsonc",
  "less",
  "markdown",
  "scss",
  "typescript",
  "typescriptreact",
  "vue",
  "yaml",
}

local function oxfmt_root(_, ctx)
  return vim.fs.root(ctx.dirname, config_files)
end

local function uses_oxfmt(self, ctx)
  return vim.tbl_contains(filetypes, vim.bo[ctx.buf].filetype) and oxfmt_root(self, ctx) ~= nil
end

return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      for _, ft in ipairs(filetypes) do
        opts.formatters_by_ft[ft] = opts.formatters_by_ft[ft] or {}
        table.insert(opts.formatters_by_ft[ft], 1, "oxfmt")
      end

      opts.formatters = opts.formatters or {}
      opts.formatters.oxfmt = { cwd = oxfmt_root, require_cwd = true }

      local prettier = opts.formatters.prettier or {}
      local prettier_condition = prettier.condition
      prettier.condition = function(self, ctx)
        if uses_oxfmt(self, ctx) then
          return false
        end
        return prettier_condition == nil or prettier_condition(self, ctx)
      end
      opts.formatters.prettier = prettier
    end,
  },
}
