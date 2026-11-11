-------------------------------------------------------------------------------
--  EllesmereUI PvP Indicator  -  Core.lua
--  An EllesmereUI plugin. Shows a faction PvP icon (or a short text) beside the
--  name of PvP-flagged friendly players on EllesmereUI's friendly "Name Only"
--  nameplates.
--
--  In Name Only mode EllesmereUI keeps Blizzard's own nameplate and writes the
--  name onto nameplate.UnitFrame.name, so the indicator is a small frame of our
--  own, parented to the nameplate and anchored to that name FontString. Rules:
--    * never write fields onto Blizzard/EUI frames (state lives in our tables)
--    * never hook or replace EUI functions or read EUI internals
--    * never compare secret values (restricted content): hide instead
--    * skip forbidden (restricted) plates entirely
-------------------------------------------------------------------------------
local ADDON, ns = ...

ns.DEFAULTS = {
    enabled   = true,
    style     = "icon",     -- "icon" | "text"
    iconSize  = 14,
    text      = "[PvP]",
    textColor = { r = 1, g = 0.25, b = 0.25 },
    side      = "LEFT",     -- which side of the name: "LEFT" | "RIGHT"
    offsetX   = 2,
    offsetY   = 0,
}

-- Faction PvP emblems. The modern atlas is preferred; the classic file is the
-- fallback if a client lacks the atlas.
local ATLAS = {
    Horde    = "UI-HUD-UnitFrame-Player-PVP-HordeIcon",
    Alliance = "UI-HUD-UnitFrame-Player-PVP-AllianceIcon",
}
local FILE = {
    Horde    = "Interface\\TargetingFrame\\UI-PVP-Horde",
    Alliance = "Interface\\TargetingFrame\\UI-PVP-Alliance",
}
local FILE_COORDS = { 0, 0.65625, 0, 0.65625 }

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local issecret = issecretvalue or function() return false end

-------------------------------------------------------------------------------
--  Saved variables
-------------------------------------------------------------------------------
local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function InitDB()
    if type(EllesmereUI_PvPIndicatorDB) ~= "table" then EllesmereUI_PvPIndicatorDB = {} end
    CopyDefaults(ns.DEFAULTS, EllesmereUI_PvPIndicatorDB)
    ns.db = EllesmereUI_PvPIndicatorDB
end

function ns.ResetDB()
    wipe(EllesmereUI_PvPIndicatorDB)
    CopyDefaults(ns.DEFAULTS, EllesmereUI_PvPIndicatorDB)
    ns.db = EllesmereUI_PvPIndicatorDB
end

-------------------------------------------------------------------------------
--  Indicator frames (one per nameplate, reused with it)
-------------------------------------------------------------------------------
local indicators = setmetatable({}, { __mode = "k" })  -- nameplate -> our frame
local plateByUnit = {}                                  -- unit token -> nameplate

local function CreateIndicator(nameplate)
    local f = CreateFrame("Frame", nil, nameplate)
    f:Hide()
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetPoint("CENTER")
    f.text:SetFontObject(GameFontNormalSmall)
    indicators[nameplate] = f
    return f
end

-- Anchor + paint. Repaints only when an input changed (memo on our own frame).
local function ApplyLook(f, nameFS, uf, faction, db)
    f:SetFrameLevel(uf:GetFrameLevel() + 5)

    local side, ox, oy = db.side, db.offsetX or 0, db.offsetY or 0
    if f._anchor ~= nameFS or f._side ~= side or f._ox ~= ox or f._oy ~= oy then
        f:ClearAllPoints()
        if side == "RIGHT" then
            f:SetPoint("LEFT", nameFS, "RIGHT", ox, oy)
        else
            f:SetPoint("RIGHT", nameFS, "LEFT", -ox, oy)
        end
        f._anchor, f._side, f._ox, f._oy = nameFS, side, ox, oy
    end

    if db.style == "text" then
        f.icon:Hide()
        local font, size, flags = nameFS:GetFont()
        if font and not issecret(font) and not issecret(size) then
            f.text:SetFont(font, size or 10, flags or "")
        end
        local c = db.textColor
        f.text:SetTextColor(c.r or 1, c.g or 0.25, c.b or 0.25)
        f.text:SetText(db.text or "[PvP]")
        f.text:Show()
        local w = f.text:GetStringWidth()
        local h = f.text:GetStringHeight()
        if issecret(w) or not w or w <= 0 then w = 30 end
        if issecret(h) or not h or h <= 0 then h = 12 end
        f:SetSize(w, h)
        f._art = nil
    else
        f.text:Hide()
        local size = db.iconSize or 14
        f:SetSize(size, size)
        if f._art ~= faction then
            if HasAtlas(ATLAS[faction]) then
                f.icon:SetTexCoord(0, 1, 0, 1)
                f.icon:SetAtlas(ATLAS[faction])
            else
                f.icon:SetTexture(FILE[faction])
                f.icon:SetTexCoord(unpack(FILE_COORDS))
            end
            f._art = faction
        end
        f.icon:Show()
    end
end

-------------------------------------------------------------------------------
--  State
-------------------------------------------------------------------------------
local function IsNameOnly()
    return GetCVarBool("nameplateShowOnlyNameForFriendlyPlayerUnits")
end

-- "Horde" / "Alliance" when the unit is PvP flagged, else nil (secret-safe).
local function FlaggedFaction(unit)
    local pvp = UnitIsPVP(unit)
    if issecret(pvp) or not pvp then return nil end
    local faction = UnitFactionGroup(unit)
    if issecret(faction) or not ATLAS[faction] then return nil end
    return faction
end

local function Hide(nameplate)
    local f = nameplate and indicators[nameplate]
    if f then f:Hide() end
end

local function Refresh(unit)
    local db = ns.db
    if not db or not unit then return end
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then return end
    plateByUnit[unit] = nameplate
    if nameplate:IsForbidden() then return end

    local uf = nameplate.UnitFrame
    local faction = db.enabled and IsNameOnly()
        and uf and not uf:IsForbidden() and uf.name
        and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player")
        and not UnitCanAttack("player", unit)
        and FlaggedFaction(unit)
    if not faction then
        Hide(nameplate)
        return
    end
    local f = indicators[nameplate] or CreateIndicator(nameplate)
    ApplyLook(f, uf.name, uf, faction, db)
    f:Show()
end

function ns.RefreshAll()
    for unit in pairs(plateByUnit) do
        if UnitExists(unit) then Refresh(unit) else plateByUnit[unit] = nil end
    end
    -- Also pick up any plate we have not seen yet.
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and not plateByUnit[unit] then Refresh(unit) end
    end
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
ev:RegisterEvent("UNIT_FACTION")
ev:RegisterEvent("CVAR_UPDATE")

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            InitDB()
            ev:UnregisterEvent("ADDON_LOADED")
        end
        return
    end
    if not ns.db then return end

    if event == "NAME_PLATE_UNIT_ADDED" then
        Refresh(arg1)
        -- EllesmereUI re-anchors the name in its own plate-added hook; check
        -- again next frame so we follow its final state.
        C_Timer.After(0, function() if UnitExists(arg1) then Refresh(arg1) end end)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local nameplate = plateByUnit[arg1] or C_NamePlate.GetNamePlateForUnit(arg1)
        Hide(nameplate)
        plateByUnit[arg1] = nil
    elseif event == "UNIT_FACTION" then
        -- PvP flag and faction changes both arrive here.
        if arg1 and arg1:find("^nameplate") then
            Refresh(arg1)
        elseif arg1 == "player" then
            ns.RefreshAll()  -- our own flag can change who is attackable
        end
    elseif event == "CVAR_UPDATE" then
        if arg1 == "nameplateShowOnlyNameForFriendlyPlayerUnits" then
            C_Timer.After(0, ns.RefreshAll)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(plateByUnit)
        C_Timer.After(0.5, ns.RefreshAll)
    end
end)
