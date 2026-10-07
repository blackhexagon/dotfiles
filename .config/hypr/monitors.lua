-- https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List outputs and supported modes with: hyprctl monitors all
hl.env("GDK_SCALE", "1")
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Add machine-specific outputs here, for example:
-- hl.monitor({ output = "DP-2", mode = "3440x1440@60", position = "0x0", scale = 1 })
