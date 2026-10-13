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
    -- ~1593px wide centered master on 3440px ultrawide (>=1536px web breakpoints),
    -- leaving ~890px for side windows
    mfact = 0.47,
    slave_count_for_center_master = 1,
    allow_small_split = true,
    new_status = "slave",
    special_scale_factor = 0.98,
  },
  layout = {
    -- 15:13 => single window ~1593px wide, same as the centered master,
    -- so it doesn't resize when a second window opens
    single_window_aspect_ratio = { 15, 13 },
  },
})
