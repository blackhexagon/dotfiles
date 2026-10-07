-- Omarchy Quatro: load packaged defaults before personal overrides.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

require("default.hypr.omarchy")

require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Generated toggle state is loaded last so the Omarchy toggle commands work.
require("default.hypr.toggles")
