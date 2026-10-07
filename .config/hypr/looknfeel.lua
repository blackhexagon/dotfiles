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
    mfact = 0.4,
    slave_count_for_center_master = 1,
    allow_small_split = true,
    new_status = "slave",
    special_scale_factor = 0.98,
  },
  layout = {
    single_window_aspect_ratio = { 1, 1 },
  },
})
