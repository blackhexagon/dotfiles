-- Install the custom symbols with scripts/keyboard.sh before loading this file.
-- https://wiki.hypr.land/Configuring/Basics/Variables/#input
hl.config({
  input = {
    kb_layout = "u2b22",
    kb_options = "caps:super,compose:menu",
    repeat_rate = 40,
    repeat_delay = 600,
    numlock_by_default = true,
    touchpad = {
      natural_scroll = true,
      scroll_factor = 0.4,
    },
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/
o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })
