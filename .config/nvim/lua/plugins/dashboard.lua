-- Single dashboard: override LazyVim's built-in snacks.dashboard with a
-- week-style block-letter header (mirrors the look of dashboard-nvim's
-- week_header). Avoids the previous duplicate-dashboard race that produced
-- E21 / flash.nvim / man.lua "Quit" errors on `nvim .`.

-- 5-row block-letter font for A-Z and space. Each glyph is 5 chars wide.
local FONT = {
  A = { " ███ ", "█   █", "█████", "█   █", "█   █" },
  B = { "████ ", "█   █", "████ ", "█   █", "████ " },
  C = { " ████", "█    ", "█    ", "█    ", " ████" },
  D = { "████ ", "█   █", "█   █", "█   █", "████ " },
  E = { "█████", "█    ", "███  ", "█    ", "█████" },
  F = { "█████", "█    ", "███  ", "█    ", "█    " },
  G = { " ████", "█    ", "█  ██", "█   █", " ████" },
  H = { "█   █", "█   █", "█████", "█   █", "█   █" },
  I = { "█████", "  █  ", "  █  ", "  █  ", "█████" },
  J = { "█████", "    █", "    █", "█   █", " ███ " },
  K = { "█   █", "█  █ ", "███  ", "█  █ ", "█   █" },
  L = { "█    ", "█    ", "█    ", "█    ", "█████" },
  M = { "█   █", "██ ██", "█ █ █", "█   █", "█   █" },
  N = { "█   █", "██  █", "█ █ █", "█  ██", "█   █" },
  O = { " ███ ", "█   █", "█   █", "█   █", " ███ " },
  P = { "████ ", "█   █", "████ ", "█    ", "█    " },
  Q = { " ███ ", "█   █", "█   █", "█  █ ", " ██ █" },
  R = { "████ ", "█   █", "████ ", "█  █ ", "█   █" },
  S = { " ████", "█    ", " ███ ", "    █", "████ " },
  T = { "█████", "  █  ", "  █  ", "  █  ", "  █  " },
  U = { "█   █", "█   █", "█   █", "█   █", " ███ " },
  V = { "█   █", "█   █", "█   █", " █ █ ", "  █  " },
  W = { "█   █", "█   █", "█ █ █", "██ ██", "█   █" },
  X = { "█   █", " █ █ ", "  █  ", " █ █ ", "█   █" },
  Y = { "█   █", " █ █ ", "  █  ", "  █  ", "  █  " },
  Z = { "█████", "   █ ", "  █  ", " █   ", "█████" },
  [" "] = { "     ", "     ", "     ", "     ", "     " },
}

local function render_word(word)
  local rows = { "", "", "", "", "" }
  for i = 1, #word do
    local ch = word:sub(i, i):upper()
    local glyph = FONT[ch] or FONT[" "]
    for r = 1, 5 do
      rows[r] = rows[r] .. glyph[r] .. " "
    end
  end
  return rows
end

local function week_header()
  local days = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY" }
  local day = days[tonumber(os.date("%w")) + 1]
  local rows = render_word(day)
  table.insert(rows, 1, "")
  table.insert(rows, "")
  table.insert(rows, os.date("%Y-%m-%d  %H:%M"))
  table.insert(rows, "")
  return table.concat(rows, "\n")
end

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.dashboard = opts.dashboard or {}
    opts.dashboard.preset = opts.dashboard.preset or {}
    opts.dashboard.preset.header = week_header()
    return opts
  end,
}
