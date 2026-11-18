-- https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
  general = {
    resize_corner = 0,
    layout = "master",
  },
  decoration = {
    rounding = 8,
  },
  master = {
    orientation = "center",
    -- Keep the main window around 1600px wide on a 3440px monitor,
    -- whether it is alone or has other windows beside it.
    mfact = 0.47,
    slave_count_for_center_master = 0,
    allow_small_split = true,
    new_status = "slave",
    special_scale_factor = 0.98,
  },
})

-- Opt another application in to Omarchy's standard transparency.
-- Find its class with: hyprctl clients
-- o.transparent_window("my-app")
-- o.transparent_window("my-app", "0.9 0.85") -- Custom active/inactive opacity.
