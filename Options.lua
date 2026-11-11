-------------------------------------------------------------------------------
--  EllesmereUI PvP Indicator  -  Options.lua
--  Registers this plugin's settings page through EllesmereUI's public plugin
--  API (EllesmereUI/PLUGINS_API.md). It gets its own sidebar section; EUI does
--  not allow plugins to add rows to its own Nameplates page.
-------------------------------------------------------------------------------
local ADDON, ns = ...
if not (EllesmereUI and EllesmereUI.RegisterPlugin) then return end

local PLUGIN_ID = "EllesmereUI_PvPIndicator"

local STYLE_VALUES = { icon = "Faction Icon", text = "Text" }
local STYLE_ORDER  = { "icon", "text" }

local SIDE_VALUES = { LEFT = "Left of Name", RIGHT = "Right of Name" }
local SIDE_ORDER  = { "LEFT", "RIGHT" }

local TEXT_VALUES = { ["[PvP]"] = "[PvP]", ["PvP"] = "PvP", ["(PvP)"] = "(PvP)", ["*"] = "*" }
local TEXT_ORDER  = { "[PvP]", "PvP", "(PvP)", "*" }

local NAME_ONLY_TIP = "Requires EllesmereUI Nameplates > Friendly > Name Only."

local function DB() return ns.db or ns.DEFAULTS end

local function Set(key, value, refreshPage)
    local db = ns.db
    if not db then return end
    db[key] = value
    if ns.RefreshAll then ns.RefreshAll() end
    if refreshPage then EllesmereUI:RefreshPage() end
end

local function NotIcon() return not DB().enabled or DB().style ~= "icon" end
local function NotText() return not DB().enabled or DB().style ~= "text" end
local function Off() return not DB().enabled end

local function BuildDisplayPage(_, parent, yOffset)
    local W = EllesmereUI.Widgets
    local y = yOffset
    local _, h

    -- GENERAL
    _, h = W:SectionHeader(parent, "GENERAL", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Enable",
          tooltip = "Show an indicator beside PvP-flagged friendly players. " .. NAME_ONLY_TIP,
          getValue = function() return DB().enabled end,
          setValue = function(v) Set("enabled", v, true) end },
        { type = "dropdown", text = "Style",
          values = STYLE_VALUES, order = STYLE_ORDER,
          disabled = Off, disabledTooltip = "Enable the indicator first.", rawTooltip = true,
          getValue = function() return DB().style end,
          setValue = function(v) Set("style", v, true) end }
    ); y = y - h

    -- ICON
    _, h = W:SectionHeader(parent, "ICON", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "slider", text = "Icon Size", min = 8, max = 32, step = 1,
          disabled = NotIcon, disabledTooltip = "Set Style to Faction Icon.", rawTooltip = true,
          getValue = function() return DB().iconSize end,
          setValue = function(v) Set("iconSize", v) end },
        { type = "spacer" }
    ); y = y - h

    -- TEXT
    _, h = W:SectionHeader(parent, "TEXT", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Text",
          values = TEXT_VALUES, order = TEXT_ORDER,
          disabled = NotText, disabledTooltip = "Set Style to Text.", rawTooltip = true,
          getValue = function() return DB().text end,
          setValue = function(v) Set("text", v) end },
        { type = "colorpicker", text = "Text Color",
          disabled = NotText, disabledTooltip = "Set Style to Text.", rawTooltip = true,
          getValue = function()
              local c = DB().textColor
              return c.r, c.g, c.b
          end,
          setValue = function(r, g, b)
              local db = ns.db
              if not db then return end
              db.textColor = { r = r, g = g, b = b }
              if ns.RefreshAll then ns.RefreshAll() end
          end }
    ); y = y - h

    -- POSITION
    _, h = W:SectionHeader(parent, "POSITION", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Side",
          values = SIDE_VALUES, order = SIDE_ORDER,
          disabled = Off, disabledTooltip = "Enable the indicator first.", rawTooltip = true,
          getValue = function() return DB().side end,
          setValue = function(v) Set("side", v) end },
        { type = "slider", text = "X Offset", min = -10, max = 20, step = 1,
          disabled = Off, disabledTooltip = "Enable the indicator first.", rawTooltip = true,
          getValue = function() return DB().offsetX end,
          setValue = function(v) Set("offsetX", v) end }
    ); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "slider", text = "Y Offset", min = -10, max = 10, step = 1,
          disabled = Off, disabledTooltip = "Enable the indicator first.", rawTooltip = true,
          getValue = function() return DB().offsetY end,
          setValue = function(v) Set("offsetY", v) end },
        { type = "spacer" }
    ); y = y - h

    return math.abs(y)
end

EllesmereUI.RegisterPlugin(PLUGIN_ID, {
    label = "PvP Indicator (EUI Plugin)",
    modules = {
        {
            key         = "General",
            title       = "PvP Indicator",
            description = "An EllesmereUI plugin: marks PvP-flagged players on friendly name-only nameplates.",
            pages       = { "Display" },
            buildPage   = BuildDisplayPage,
            onReset     = function()
                if ns.ResetDB then ns.ResetDB() end
                if ns.RefreshAll then ns.RefreshAll() end
                EllesmereUI:RefreshPage()
            end,
        },
    },
})

SLASH_EUIPVP1 = "/euipvp"
SlashCmdList.EUIPVP = function()
    if InCombatLockdown() then return end
    EllesmereUI.OpenPlugin(PLUGIN_ID)
end
