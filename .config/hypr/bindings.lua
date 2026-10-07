-- Replace a default binding rather than running both actions on the same key.
-- Inspect the effective bindings with: omarchy menu keybindings --print
local function bind(keys, description, action)
  hl.unbind(keys)
  o.bind(keys, description, action)
end

-- Applications. Start a fresh tmux session, matching the original binding.
bind("SUPER + ALT + RETURN", "Tmux", "omarchy launch terminal tmux new")
bind("SUPER + SHIFT + T", "Terminal", { omarchy = "terminal" })
bind("SUPER + SHIFT + F", "File manager", { omarchy = "nautilus" })
bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { omarchy = "nautilus-cwd" })
bind("SUPER + SHIFT + B", "Browser", { omarchy = "browser" })
bind("SUPER + SHIFT + N", "Editor", { omarchy = "editor" })
bind("SUPER + SHIFT + D", "Docker", { tui = "lazydocker" })
bind("SUPER + SHIFT + O", "Obsidian", { launch = "obsidian", focus = "^obsidian$" })
-- Quatro default: Omawrite.
bind("SUPER + SHIFT + W", "Typora", { launch = "typora --enable-wayland-ime" })

-- Web apps. Lua strings preserve literal # characters in URLs.
-- Quatro defaults: HEY Calendar, HEY Mail, Music, ChatGPT, Signal, Google Maps.
bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://calendar.google.com/" })
bind("SUPER + SHIFT + E", "Email", { webapp = "https://gmail.com" })
bind("SUPER + SHIFT + M", "Plex", { webapp = "https://plex.trca.dev/web/index.html#!/", focus = true })
bind("SUPER + SHIFT + A", "Gemini", { webapp = "https://gemini.google.com/app", focus = true })
bind("SUPER + SHIFT + G", "Github", { webapp = "https://github.com/", focus = true })
bind("SUPER + SHIFT + S", "Tasks", { webapp = "https://tasks.google.com/", focus = true })

bind("SUPER + SHIFT + H", "Move window focus left", hl.dsp.focus({ direction = "l" }))
bind("SUPER + SHIFT + L", "Move window focus right", hl.dsp.focus({ direction = "r" }))
bind("SUPER + SHIFT + K", "Move window focus up", hl.dsp.focus({ direction = "u" }))
bind("SUPER + SHIFT + J", "Move window focus down", hl.dsp.focus({ direction = "d" }))

bind("SUPER + SHIFT + CTRL + H", "Swap window left", hl.dsp.window.swap({ direction = "l" }))
bind("SUPER + SHIFT + CTRL + L", "Swap window right", hl.dsp.window.swap({ direction = "r" }))
bind("SUPER + SHIFT + CTRL + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
bind("SUPER + SHIFT + CTRL + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))
