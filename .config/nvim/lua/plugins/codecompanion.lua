return {
  "olimorris/codecompanion.nvim",
  opts = {
    adapters = {
      gemini = function()
        return require("codecompanion.adapters").extend("gemini", {
          env = {
            api_key = os.getenv("GEMINI_API_KEY"),
          },
        })
      end,
      openai = function()
        return require("codecompanion.adapters").extend("openai", {
          env = {
            api_key = os.getenv("OPENAI_API_KEY"),
          },
        })
      end,
    },
    strategies = {
      chat = { adapter = "openai" },
      inline = { adapter = "openai" },
      agent = { adapter = "openai" },
    },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
}
