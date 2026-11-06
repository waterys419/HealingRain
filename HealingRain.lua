-- Healing Rain 1.9.3 - original addon for Audrey.
-- Grid raid cells + click-cast (mouse + wheel + modifiers) + hover keys + GUI config.
-- Secure clicks; health values go directly to native display widgets.
local addonName = ...
local ready = false
local pendingBindings = false
local configureHover
local openConfig, updateMinimap

local LOW_HP = 0.35
local LOW_MANA = 0.30
local COLS = 6
local CW, CH, GAP = 86, 36, 4

local CLASS_COLORS = {
    WARRIOR = {0.62, 0.50, 0.38}, PALADIN = {0.83, 0.55, 0.62},
    HUNTER = {0.45, 0.60, 0.30}, ROGUE = {0.75, 0.70, 0.30},
    PRIEST = {0.72, 0.72, 0.68}, DEATHKNIGHT = {0.55, 0.12, 0.20},
    SHAMAN = {0.25, 0.45, 0.75}, MAGE = {0.45, 0.60, 0.78},
    WARLOCK = {0.55, 0.48, 0.72}, MONK = {0.25, 0.70, 0.45},
    DRUID = {0.78, 0.45, 0.15}, DEMONHUNTER = {0.50, 0.20, 0.62},
    EVOKER = {0.25, 0.50, 0.42},
}
local CLASS_LIST = { "WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","DEATHKNIGHT","SHAMAN","MAGE","WARLOCK","MONK","DRUID","DEMONHUNTER" }
local DEMO_NAMES = { "Water","Wolfy","Bubbles","Wendy","Bloop","Gimli","Bruno","Sabina","Fenwick","Bladric","Lithia","Shielda","Rhali","Aela","Grunh","Sneak","Celia","Stormy","Korsik","Jina","Quill","Beary","Byte","Nack","Fires","Bloomi","Dina","Shoo","Vermi","Steely","Fancy","Fenny","Tanks","Heals","Deeps","Buffy","Ouch","Rezzy","Mana","Wipey" }

local MOUSE_SLOTS, WHEEL_SLOTS = {}, {}
local modifiers = {
    { id = "", label = "", pre = "", key = "" },
    { id = "Shift", label = "Shift + ", pre = "shift-", key = "SHIFT-" },
    { id = "Alt", label = "Alt + ", pre = "alt-", key = "ALT-" },
    { id = "Ctrl", label = "Ctrl + ", pre = "ctrl-", key = "CTRL-" },
}
for _, button in ipairs({
    { "Left", "Left click", "1" }, { "Right", "Right click", "2" },
    { "Middle", "Wheel click", "3" }, { "Button4", "Side button 1", "4" },
    { "Button5", "Side button 2", "5" },
}) do
    for _, m in ipairs(modifiers) do
        MOUSE_SLOTS[#MOUSE_SLOTS + 1] = { id = m.id .. button[1],
            label = m.label .. button[2], pre = m.pre, btn = button[3] }
    end
end
for _, direction in ipairs({ { "Up", "Scroll up", "MOUSEWHEELUP" },
                             { "Down", "Scroll down", "MOUSEWHEELDOWN" } }) do
    for _, m in ipairs(modifiers) do
        local id = m.id == "" and ("Wheel" .. direction[1]) or (m.id .. direction[1])
        WHEEL_SLOTS[#WHEEL_SLOTS + 1] = { id = id, label = m.label .. direction[2],
            key = m.key .. direction[3] }
    end
end
local DEFAULT_BINDS = {
    ShiftLeft = "Flash Heal",
    AltLeft = "Lesser Heal",
    Right = "Dispel Magic",
    Middle = "Power Word: Fortitude",
    WheelUp = "Lesser Heal",
    WheelDown = "Flash Heal",
}
local HOVER_SLOTS = 4
local NAME_STYLES = {
    { "full", "Full name: Water Storm" },
    { "initials", "Initials: W. S." },
    { "first_last_initial", "First + last initial: Water S." },
    { "three", "First 3 of each: Wat Sto" },
    { "first", "First name: Water" },
    { "last", "Last name: Storm" },
}
local HEALTH_STYLES = {
    { "percent", "Percent: 75%" },
    { "current", "Health: 750" },
    { "current_max", "Health / maximum: 750 / 1000" },
    { "both", "Health + percent: 750 (75%)" },
    { "none", "No health text" },
}
local function validStyle(options, value, fallback)
    for _, option in ipairs(options) do if option[1] == value then return value end end
    return fallback
end
local function dimension(value, fallback, low, high)
    local number = tonumber(value)
    if not number or number ~= number then number = fallback end
    return math.max(low, math.min(high, math.floor(number)))
end

local function initDB()
    if type(HealingRainDB) ~= "table" then HealingRainDB = {} end
    if type(HealingRainDB.binds) ~= "table" then HealingRainDB.binds = {} end
    if type(HealingRainDB.hover) ~= "table" then HealingRainDB.hover = {} end
    -- Earlier versions stored the user's small heal separately.
    if HealingRainDB.binds.AltLeft == nil and type(HealingRainDB.small) == "string" then
        HealingRainDB.binds.AltLeft = HealingRainDB.small
    end
    for _, slots in ipairs({ MOUSE_SLOTS, WHEEL_SLOTS }) do
        for _, slot in ipairs(slots) do
            if type(HealingRainDB.binds[slot.id]) ~= "string" then
                HealingRainDB.binds[slot.id] = DEFAULT_BINDS[slot.id] or ""
            end
        end
    end
    for i = 1, HOVER_SLOTS do
        local h = HealingRainDB.hover[i]
        if type(h) ~= "table" then h = {}; HealingRainDB.hover[i] = h end
        if type(h.key) ~= "string" then h.key = "" end
        if type(h.spell) ~= "string" then h.spell = "" end
    end
    if type(HealingRainDB.frames) ~= "table" then HealingRainDB.frames = {} end
    local v = HealingRainDB.frames
    v.width = dimension(v.width, 86, 60, 240)
    v.height = dimension(v.height, 36, 32, 100)
    v.nameStyle = validStyle(NAME_STYLES, v.nameStyle, "full")
    v.healthStyle = validStyle(HEALTH_STYLES, v.healthStyle, "percent")
    if type(v.showTarget) ~= "boolean" then v.showTarget = true end
    if type(HealingRainDB.minimap) ~= "table" then HealingRainDB.minimap = {} end
    HealingRainDB.minimap.angle = dimension(HealingRainDB.minimap.angle, 225, 0, 360)
    HealingRainDB.version = 190
    ready = true
    if updateMinimap then updateMinimap() end
end

local function secret(v)
    return issecretvalue and issecretvalue(v)
end

local function fracOf(a, b)
    if secret(a) or secret(b) then return nil end
    if not a or not b or b == 0 then return nil end
    return a / b
end

-- Count UTF-8 characters, not bytes, when shortening names.
local function firstChars(text, count)
    local result, n = {}, 0
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        n = n + 1
        if n > count then break end
        result[#result + 1] = char
    end
    return table.concat(result)
end
local function formatName(name)
    -- Opaque names may be displayed, but must not be split or inspected.
    if secret(name) then return name end
    if type(name) ~= "string" or name == "" then return "?" end
    local style = HealingRainDB.frames.nameStyle
    if style == "full" then return name end
    local first = name:match("^%s*(%S+)") or name
    local last = name:match("%s+(%S+)%s*$")
    if style == "first" then return first end
    if style == "last" then return last or first end
    if style == "initials" then
        return firstChars(first, 1) .. "." .. (last and (" " .. firstChars(last, 1) .. ".") or "")
    end
    if style == "three" then
        return firstChars(first, 3) .. (last and (" " .. firstChars(last, 3)) or "")
    end
    return first .. (last and (" " .. firstChars(last, 1) .. ".") or "")
end
local function healthText(label, current, maximum, percent, dead)
    local style = HealingRainDB.frames.healthStyle
    if style == "none" then label:SetText(""); return end
    if not secret(dead) and dead then label:SetText("DEAD"); return end
    -- Native formatting accepts secret values; never do arithmetic on them here.
    if style == "current" then label:SetFormattedText("%.0f", current)
    elseif style == "current_max" then label:SetFormattedText("%.0f / %.0f", current, maximum)
    elseif style == "both" and (secret(percent) or percent ~= nil) then
        label:SetFormattedText("%.0f (%.0f%%)", current, percent)
    elseif secret(percent) or percent ~= nil then label:SetFormattedText("%.0f%%", percent)
    elseif style == "both" then label:SetFormattedText("%.0f", current)
    else label:SetText("--") end
end

local panel = CreateFrame("Frame", addonName .. "Panel", UIParent, "BackdropTemplate")
panel:SetSize(COLS * (CW + GAP) + 14, 60)
panel:SetPoint("LEFT", 24, 40)
panel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
panel:SetBackdropColor(0.03, 0.04, 0.07, 0.92)
panel:SetBackdropBorderColor(0.55, 0.65, 0.75, 0.9)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:Show()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -6)
title:SetText("|cffffd200Raid|r")
title:SetFont(title:GetFont(), 14, "OUTLINE")

local heading = CreateFrame("Button", addonName .. "Heading", panel)
heading:SetPoint("TOPLEFT", 4, -2)
heading:SetPoint("TOPRIGHT", -4, -2)
heading:SetHeight(22)
heading:RegisterForClicks("RightButtonUp")
heading:RegisterForDrag("LeftButton")
heading:SetScript("OnClick", function(_, button)
    if button == "RightButton" and openConfig then openConfig() end
end)
heading:SetScript("OnDragStart", function() if not InCombatLockdown() then panel:StartMoving() end end)
heading:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)

local cells = {}
local targetPanel, targetCell
local pendingRefresh = false
local demoMode = false
local soloLayout = false

local function applyClicksToButton(btn)
    if InCombatLockdown() then return end
    for _, s in ipairs(MOUSE_SLOTS) do
        local spell = HealingRainDB.binds[s.id]
        local action = type(spell) == "string" and spell:match("^%s*(.-)%s*$"):lower() or ""
        if action == "target" then
            btn:SetAttribute(s.pre .. "type" .. s.btn, "target")
            btn:SetAttribute(s.pre .. "spell" .. s.btn, nil)
        elseif spell and spell ~= "" then
            btn:SetAttribute(s.pre .. "type" .. s.btn, "spell")
            btn:SetAttribute(s.pre .. "spell" .. s.btn, spell)
        else
            btn:SetAttribute(s.pre .. "type" .. s.btn, s.id == "Left" and "target" or nil)
            btn:SetAttribute(s.pre .. "spell" .. s.btn, nil)
        end
    end
end

local function ensureCell(i, parent, buttonName)
    if not parent and cells[i] then return cells[i] end
    local col = (i - 1) % COLS
    local row = math.floor((i - 1) / COLS)
    local vf = CreateFrame("Frame", nil, parent or panel, "BackdropTemplate")
    vf:SetSize(CW, CH)
    vf:SetPoint("TOPLEFT", 8 + col * (CW + GAP), -26 - row * (CH + GAP))
    vf:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    vf:SetBackdropColor(0.2, 0.2, 0.2, 0.95)
    vf:SetBackdropBorderColor(0, 0, 0, 0.9)
    local hp = CreateFrame("StatusBar", nil, vf)
    hp:SetPoint("TOPLEFT", 2, -2)
    hp:SetPoint("BOTTOMRIGHT", -2, 7)
    hp:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    hp:SetMinMaxValues(0, 1)
    hp:SetValue(1)
    hp:SetStatusBarColor(0.3, 0.3, 0.3, 1)
    local mp = CreateFrame("StatusBar", nil, vf)
    mp:SetPoint("BOTTOMLEFT", 2, 2)
    mp:SetSize(CW - 4, 4)
    mp:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    mp:SetMinMaxValues(0, 1)
    mp:SetValue(1)
    mp:SetStatusBarColor(0.15, 0.35, 0.85, 1)
    local name = hp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOP", 0, -4)
    name:SetFont(name:GetFont(), 11, "OUTLINE")
    name:SetShadowOffset(1, -1)
    local pct = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pct:SetPoint("BOTTOM", 0, 8)
    pct:SetFont(pct:GetFont(), 12, "OUTLINE")
    pct:SetShadowOffset(1, -1)
    local b = CreateFrame("Button", buttonName or (addonName .. "Cell" .. i), vf, "SecureActionButtonTemplate,SecureHandlerEnterLeaveTemplate")
    -- Use our configured spell attributes, without Blizzard click-binding overrides.
    b:SetAllPoints(vf)
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetAttribute("useOnKeyDown", false)
    b:SetFrameLevel(hp:GetFrameLevel() + 2)
    applyClicksToButton(b)
    local cell = { vf = vf, btn = b, hp = hp, mp = mp, name = name, pct = pct }
    if not parent then cells[i] = cell end
    if configureHover then configureHover(b) end
    return cell
end

local drink = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
drink:SetPoint("TOP", panel, "BOTTOM", 0, -8)
drink:SetFont(drink:GetFont(), 15, "OUTLINE")
drink:SetTextColor(1, 0.45, 0.45)
drink:SetText("")
drink:Hide()

local function paintCell(c, nm, col, frac, mfrac, dead)
    c.hp:SetMinMaxValues(0, 1)
    c.mp:SetMinMaxValues(0, 1)
    c.name:SetText(formatName(nm))
    c.name:SetTextColor(col[1], col[2], col[3])
    if dead then
        c.hp:SetStatusBarColor(0.15, 0.05, 0.05, 1)
        c.hp:SetValue(1)
        healthText(c.pct, 0, 1000, 0, true)
        c.pct:SetTextColor(1, 0.3, 0.3)
        c.vf:SetBackdropBorderColor(0.4, 0.1, 0.1, 1)
        c.mp:SetValue(0)
        return
    end
    if frac == nil then
        c.hp:SetStatusBarColor(col[1], col[2], col[3], 1)
        c.hp:SetValue(1)
        healthText(c.pct, 1000, 1000, nil, false)
        c.pct:SetTextColor(1, 0.85, 0.3)
        c.vf:SetBackdropBorderColor(0, 0, 0, 0.9)
    else
        c.hp:SetStatusBarColor(col[1], col[2], col[3], 1)
        c.hp:SetValue(frac)
        healthText(c.pct, math.floor(frac * 1000 + 0.5), 1000, frac * 100, false)
        if frac < LOW_HP then
            c.vf:SetBackdropBorderColor(1, 0.2, 0.2, 1)
            c.pct:SetTextColor(1, 0.35, 0.35)
        else
            c.vf:SetBackdropBorderColor(0, 0, 0, 0.9)
            c.pct:SetTextColor(1, 0.85, 0.3)
        end
    end
    if mfrac == nil then
        c.mp:SetStatusBarColor(0.1, 0.1, 0.15, 1)
        c.mp:SetValue(1)
    else
        c.mp:SetStatusBarColor(0.15, 0.35, 0.95, 1)
        c.mp:SetValue(mfrac)
    end
end

local function layoutCell(c, i, isTarget)
    c.vf:SetSize(CW, CH)
    c.vf:ClearAllPoints()
    local compact = soloLayout and not isTarget
    c.vf:SetPoint("TOPLEFT", (compact and 0 or 8) + ((i - 1) % COLS) * (CW + GAP),
        -(compact and 0 or 26) - math.floor((i - 1) / COLS) * (CH + GAP))
    c.mp:SetWidth(CW - 4)
    c.name:ClearAllPoints()
    c.name:SetPoint("TOP", 0, -2)
    c.name:SetFont(c.name:GetFont(), math.min(11, math.floor((CH - 12) / 2)), "OUTLINE")
    c.pct:ClearAllPoints()
    c.pct:SetPoint("BOTTOM", 0, 1)
    c.pct:SetFont(c.pct:GetFont(), math.min(12, math.floor((CH - 12) / 2)), "OUTLINE")
    c.name:SetWidth(CW - 8)
    c.name:SetWordWrap(false)
    c.pct:SetWidth(CW - 8)
    c.pct:SetWordWrap(false)
end
local function layoutTarget()
    if not targetPanel then
        targetPanel = CreateFrame("Frame", addonName .. "TargetPanel", UIParent, "BackdropTemplate")
        targetPanel:SetPoint("LEFT", panel, "RIGHT", 16, 0)
        targetPanel:SetMovable(true)
        targetPanel:SetClampedToScreen(true)
        targetPanel:EnableMouse(true)
        targetPanel:RegisterForDrag("LeftButton")
        targetPanel:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        targetPanel:SetBackdropColor(0.03, 0.04, 0.07, 0.92)
        targetPanel:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
        targetPanel:SetScript("OnDragStop", targetPanel.StopMovingOrSizing)
        local label = targetPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOP", 0, -6)
        label:SetText("Target")
        targetCell = ensureCell(1, targetPanel, addonName .. "TargetButton")
        targetCell.unit = "target"
        -- This secure unit token follows target changes without writing attributes in combat.
        targetCell.btn:SetAttribute("unit", "target")
        targetCell.hp:SetStatusBarColor(0.15, 0.55, 0.65, 1)
        targetCell.name:SetTextColor(0.6, 0.9, 1)
    end
    layoutCell(targetCell, 1, true)
    targetPanel:SetSize(CW + 16, CH + 34)
    if not soloLayout and HealingRainDB.frames.showTarget then targetPanel:Show() else targetPanel:Hide() end
end

local function applyFrameLayout(count, solo)
    soloLayout = solo or false
    CW, CH = HealingRainDB.frames.width, HealingRainDB.frames.height
    if soloLayout then
        panel:SetSize(CW, CH)
        panel:SetBackdropColor(0, 0, 0, 0)
        panel:SetBackdropBorderColor(0, 0, 0, 0)
        title:Hide()
        heading:Hide()
        drink:Hide()
    else
        panel:SetWidth(COLS * (CW + GAP) + 14)
        panel:SetHeight(34 + math.ceil(count / COLS) * (CH + GAP))
        panel:SetBackdropColor(0.03, 0.04, 0.07, 0.92)
        panel:SetBackdropBorderColor(0.55, 0.65, 0.75, 0.9)
        title:Show()
        heading:Show()
    end
    for i, c in ipairs(cells) do layoutCell(c, i) end
    layoutTarget()
end

local function DemoRoster()
    if InCombatLockdown() then return end
    demoMode = true
    applyFrameLayout(40)
    for i = 1, 40 do
        local c = ensureCell(i)
        layoutCell(c, i)
        c.btn:SetAttribute("unit", nil)
        c.vf:Show()
        local cls = CLASS_LIST[((i - 1) % #CLASS_LIST) + 1]
        local nm = DEMO_NAMES[((i - 1) % #DEMO_NAMES) + 1]
        if i % 2 == 1 then nm = nm .. " Storm" end
        local frac, dead = 1.0, false
        local r = i % 10
        if r == 3 then frac = 0.79
        elseif r == 5 then frac = 0.66
        elseif r == 7 then frac = 0.53
        elseif r == 8 then frac = 0.22
        elseif r == 9 then dead = true end
        paintCell(c, nm, CLASS_COLORS[cls], frac, 0.6 + (i % 4) * 0.1, dead)
    end
    for i = 41, #cells do cells[i].vf:Hide() end
end

local function updateVitals()
    if not ready then return end
    local displayed = {}
    if not demoMode then for _, c in ipairs(cells) do displayed[#displayed + 1] = c end end
    if targetCell then displayed[#displayed + 1] = targetCell end
    for _, c in ipairs(displayed) do
        local u = c.unit
        if u then
            local exists = UnitExists(u)
            if not secret(exists) and not exists then
                c.hp:SetMinMaxValues(0, 1); c.hp:SetValue(0)
                c.mp:SetMinMaxValues(0, 1); c.mp:SetValue(0)
                c.name:SetText(u == "target" and "No target" or "?")
                c.pct:SetText("")
            else
            -- Native bars accept opaque combat values. Never compare or divide them.
            c.hp:SetMinMaxValues(0, UnitHealthMax(u))
            c.hp:SetValue(UnitHealth(u))
            c.mp:SetMinMaxValues(0, UnitPowerMax(u, 0))
            c.mp:SetValue(UnitPower(u, 0))
            c.name:SetText(formatName(GetUnitName(u, false)))
            local percent
            if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
                percent = UnitHealthPercent(u, true, CurveConstants.ScaleTo100)
            else
                local frac = fracOf(UnitHealth(u), UnitHealthMax(u))
                if frac then percent = frac * 100 end
            end
            healthText(c.pct, UnitHealth(u), UnitHealthMax(u), percent, UnitIsDeadOrGhost(u))
            end
        end
    end
    -- The drink hint is only evaluated outside combat, using non-secret mana.
    drink:Hide()
    if not soloLayout and not InCombatLockdown() then
        local mfrac = fracOf(UnitPower("player", 0), UnitPowerMax("player", 0))
        local dead = UnitIsDeadOrGhost("player")
        if mfrac and mfrac < LOW_MANA and not secret(dead) and not dead then
            drink:SetText("DRINK!")
            drink:Show()
        end
    end
end

local function RefreshRoster()
    if not ready then return end
    if InCombatLockdown() then pendingRefresh = true; updateVitals(); return end
    pendingRefresh = false
    if demoMode then DemoRoster(); return end
    local units = {}
    if IsInRaid() then
        for i = 1, math.min(GetNumGroupMembers(), 40) do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        for i = 1, 4 do
            if UnitExists("party" .. i) then units[#units + 1] = "party" .. i end
        end
    end
    local grouped = IsInRaid() or (IsInGroup and IsInGroup()) or #units > 1
    applyFrameLayout(#units, not grouped)
    for i, u in ipairs(units) do
        local c = ensureCell(i)
        layoutCell(c, i)
        c.unit = u
        c.btn:SetAttribute("unit", u)
        c.vf:Show()
        local _, cls = UnitClass(u)
        local col = not secret(cls) and CLASS_COLORS[cls] or nil
        col = col or { 0.4, 0.4, 0.4 }
        c.hp:SetStatusBarColor(col[1], col[2], col[3], 1)
        c.mp:SetStatusBarColor(0.15, 0.35, 0.95, 1)
        c.name:SetTextColor(col[1], col[2], col[3])
        c.pct:SetTextColor(1, 0.85, 0.3)
        c.vf:SetBackdropBorderColor(0, 0, 0, 0.9)
    end
    for i = #units + 1, #cells do
        cells[i].unit = nil
        cells[i].btn:SetAttribute("unit", nil)
        cells[i].vf:Hide()
    end
    updateVitals()
end

local keyButtons, activeKeys = {}, {}
configureHover = function(btn)
    local snippets = { "local unit = self:GetAttribute('unit')", "if unit then" }
    for i, binding in ipairs(activeKeys) do
        btn:SetFrameRef("key" .. i, binding.button)
        snippets[#snippets + 1] = string.format(
            "local b = self:GetFrameRef(%q); b:SetAttribute('unit', unit); self:SetBindingClick(true, %q, b:GetName(), 'LeftButton')",
            "key" .. i, binding.key)
    end
    snippets[#snippets + 1] = "end"
    btn:SetAttribute("_onenter", table.concat(snippets, "\n"))
    btn:SetAttribute("_onleave", "self:ClearBindings()")
end

local function applyBindings()
    if not ready then return end
    if InCombatLockdown() then pendingBindings = true; return end
    pendingBindings = false
    activeKeys = {}
    local used = {}
    local function addKey(id, key, spell)
        if key == "" or spell == "" or used[key] then return end
        used[key] = true
        local b = keyButtons[id]
        if not b then
            b = CreateFrame("Button", addonName .. "Key" .. id, UIParent, "SecureActionButtonTemplate")
            b:RegisterForClicks("AnyDown", "AnyUp")
            b:SetAttribute("useOnKeyDown", false)
            b:Hide()
            keyButtons[id] = b
        end
        b:SetAttribute("type", "spell")
        b:SetAttribute("spell", spell)
        activeKeys[#activeKeys + 1] = { key = key, button = b }
    end
    for i = 1, HOVER_SLOTS do
        local h = HealingRainDB.hover[i]
        addKey("Hover" .. i, h.key, h.spell)
    end
    for _, slot in ipairs(WHEEL_SLOTS) do
        addKey(slot.id, slot.key, HealingRainDB.binds[slot.id])
    end
    local clickable = {}
    for _, c in ipairs(cells) do clickable[#clickable + 1] = c end
    if targetCell then clickable[#clickable + 1] = targetCell end
    for _, c in ipairs(clickable) do
        -- SecureHandlerExecute releases only our temporary hover overrides.
        if SecureHandlerExecute then SecureHandlerExecute(c.btn, "self:ClearBindings()") end
        applyClicksToButton(c.btn)
        configureHover(c.btn)
    end
end

local cfg = nil
local cfgEdits = {}
local function buildConfig()
    if cfg then return cfg end
    cfg = CreateFrame("Frame", addonName .. "Config", UIParent, "BackdropTemplate")
    cfg:SetSize(570, 560)
    cfg:SetFrameStrata("DIALOG")
    cfg:SetClampedToScreen(true)
    cfg:SetScale(math.min(1, UIParent:GetHeight() / 620))
    cfg:SetPoint("CENTER")
    cfg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    cfg:SetBackdropColor(0.04, 0.05, 0.09, 0.97)
    cfg:SetBackdropBorderColor(0.45, 0.75, 1.0, 0.9)
    cfg:SetMovable(true)
    cfg:EnableMouse(true)
    cfg:RegisterForDrag("LeftButton")
    cfg:SetScript("OnDragStart", cfg.StartMoving)
    cfg:SetScript("OnDragStop", cfg.StopMovingOrSizing)
    local t = cfg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOP", 0, -10)
    t:SetText("|cffffd200Healing Rain - settings|r")
    local sub = cfg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetPoint("TOP", 0, -30)
    sub:SetText("Choose a look, then Save. Scroll down for mouse and keys.")
    local scroll = CreateFrame("ScrollFrame", addonName .. "ConfigScroll", cfg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -52)
    scroll:SetPoint("BOTTOMRIGHT", -32, 55)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(520, 1100)
    scroll:SetScrollChild(content)
    local y = -10
    cfgEdits = {}
    local choices = {}
    local function editRow(label, get, set, name)
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 16, y)
        fs:SetText(label)
        local eb = CreateFrame("EditBox", name, content, "InputBoxTemplate")
        eb:SetSize(230, 20)
        eb:SetPoint("TOPLEFT", 220, y + 4)
        eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); cfg:Hide() end)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        eb:SetText(get() or "")
        cfgEdits[#cfgEdits + 1] = { box = eb, set = set }
        y = y - 26
    end
    local function choiceRow(label, options, field)
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 16, y)
        fs:SetText(label)
        local button = CreateFrame("Button", addonName .. "Option" .. field, content, "UIPanelButtonTemplate")
        button:SetSize(290, 24)
        button:SetPoint("TOPLEFT", 210, y + 5)
        local index = 1
        for i, option in ipairs(options) do
            if option[1] == HealingRainDB.frames[field] then index = i end
        end
        button:SetText(options[index][2])
        button:SetScript("OnClick", function()
            index = index % #options + 1
            button:SetText(options[index][2])
        end)
        choices[#choices + 1] = function() HealingRainDB.frames[field] = options[index][1] end
        y = y - 32
    end
    choiceRow("Target window (click)", { { true, "Show target window" }, { false, "Hide target window" } }, "showTarget")
    choiceRow("Name style (click to change)", NAME_STYLES, "nameStyle")
    choiceRow("Health text (click to change)", HEALTH_STYLES, "healthStyle")
    editRow("Bar width (60-240)", function() return tostring(HealingRainDB.frames.width) end,
        function(v) HealingRainDB.frames.width = dimension(v, HealingRainDB.frames.width, 60, 240) end,
        addonName .. "BarWidth")
    editRow("Bar height (32-100)", function() return tostring(HealingRainDB.frames.height) end,
        function(v) HealingRainDB.frames.height = dimension(v, HealingRainDB.frames.height, 32, 100) end,
        addonName .. "BarHeight")
    local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 16, y)
    hint:SetText("Mouse actions: spell name or target. /hr demo previews your saved look.")
    y = y - 36
    for _, s in ipairs(MOUSE_SLOTS) do
        local id = s.id
        editRow(s.label, function() return HealingRainDB.binds[id] or "" end,
            function(v) HealingRainDB.binds[id] = (v or ""):gsub("^%s+", ""):gsub("%s+$", "") end)
    end
    for _, s in ipairs(WHEEL_SLOTS) do
        local id = s.id
        editRow(s.label, function() return HealingRainDB.binds[id] or "" end,
            function(v) HealingRainDB.binds[id] = (v or ""):gsub("^%s+", ""):gsub("%s+$", "") end)
    end
    y = y - 6
    local hs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hs:SetPoint("TOPLEFT", 16, y)
    hs:SetText("Hover keys (press key while mouse is over a frame)")
    y = y - 22
    for i = 1, HOVER_SLOTS do
        local idx = i
        local kf = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        kf:SetPoint("TOPLEFT", 16, y)
        kf:SetText("Key " .. i)
        local kb = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        kb:SetSize(60, 20)
        kb:SetPoint("TOPLEFT", 70, y + 4)
        kb:SetAutoFocus(false)
        kb:SetText((HealingRainDB.hover[idx] or {}).key or "")
        local sb = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        sb:SetSize(230, 20)
        sb:SetPoint("TOPLEFT", 150, y + 4)
        sb:SetAutoFocus(false)
        sb:SetText((HealingRainDB.hover[idx] or {}).spell or "")
        cfgEdits[#cfgEdits + 1] = { box = kb, set = function(v) HealingRainDB.hover[idx].key = (v or ""):gsub("^%s+", ""):gsub("%s+$", ""):upper() end }
        cfgEdits[#cfgEdits + 1] = { box = sb, set = function(v) HealingRainDB.hover[idx].spell = (v or ""):gsub("^%s+", ""):gsub("%s+$", "") end }
        y = y - 26
    end
    content:SetHeight(-y + 15)
    local save = CreateFrame("Button", nil, cfg, "UIPanelButtonTemplate")
    save:SetSize(110, 24)
    save:SetPoint("BOTTOMLEFT", 16, 14)
    save:SetText("Save")
    save:SetScript("OnClick", function()
        for _, e in ipairs(cfgEdits) do e.set(e.box:GetText()) end
        for _, commit in ipairs(choices) do commit() end
        applyBindings()
        RefreshRoster()
        print(pendingBindings and "[Healing Rain] Saved. Changes apply after combat." or "[Healing Rain] Saved. Frame look updated; move off a box and back for key changes.")
    end)
    local close = CreateFrame("Button", nil, cfg, "UIPanelButtonTemplate")
    close:SetSize(110, 24)
    close:SetPoint("BOTTOMRIGHT", -16, 14)
    close:SetText("Close")
    close:SetScript("OnClick", function() cfg:Hide() end)
    UISpecialFrames[#UISpecialFrames + 1] = cfg:GetName()
    cfg:Hide()
    return cfg
end

openConfig = function() buildConfig():Show() end

-- Native water-elemental artwork; no library or other addon's code required.
local mini = CreateFrame("Button", addonName .. "MinimapButton", Minimap)
mini:SetSize(32, 32)
mini:SetFrameStrata("MEDIUM")
mini:SetFrameLevel(Minimap:GetFrameLevel() + 8)
mini:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mini:RegisterForDrag("LeftButton")
local water = mini:CreateTexture(nil, "ARTWORK")
water:SetTexture("Interface\\Icons\\Spell_Frost_SummonWaterElemental")
water:SetPoint("TOPLEFT", 5, -5)
water:SetPoint("BOTTOMRIGHT", -5, 5)
water:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local rim = mini:CreateTexture(nil, "OVERLAY")
rim:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
rim:SetSize(54, 54)
rim:SetPoint("TOPLEFT", 0, 0)
mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
updateMinimap = function()
    if not ready then return end
    local a = math.rad(HealingRainDB.minimap.angle)
    mini:ClearAllPoints()
    mini:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(a) * (Minimap:GetWidth() / 2 + 8),
        math.sin(a) * (Minimap:GetHeight() / 2 + 8))
end
mini:SetScript("OnDragStart", function(self)
    if not IsControlKeyDown() or not ready then return end
    self.dragged = true
    self:SetScript("OnUpdate", function()
        local x, y = GetCursorPosition()
        local cx, cy = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        local angle = math.deg(math.atan2(y / scale - cy, x / scale - cx)) % 360
        HealingRainDB.minimap.angle = angle
        updateMinimap()
    end)
end)
mini:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
mini:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
mini:SetScript("OnClick", function(self)
    if self.dragged or IsControlKeyDown() then self.dragged = false; return end
    openConfig()
end)
mini:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Healing Rain")
    GameTooltip:AddLine("Click: settings", 1, 1, 1)
    GameTooltip:AddLine("Ctrl + drag: move this button", 1, 1, 1)
    GameTooltip:Show()
end)
mini:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

local f = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "GROUP_ROSTER_UPDATE",
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_NAME_UPDATE", "PLAYER_TARGET_CHANGED" }) do
    f:RegisterEvent(event)
end
f:SetScript("OnEvent", function(_, ev, name)
    if ev == "ADDON_LOADED" then
        if name == addonName then initDB() end
        return
    end
    if not ready then return end
    if ev == "PLAYER_LOGIN" then applyBindings(); RefreshRoster()
    elseif ev == "PLAYER_REGEN_ENABLED" then
        if pendingBindings then applyBindings() end
        RefreshRoster()
    elseif ev == "GROUP_ROSTER_UPDATE" or ev == "PLAYER_ENTERING_WORLD" then RefreshRoster()
    else updateVitals() end
end)

SLASH_HEALINGRAIN1 = "/healingrain"
SLASH_HEALINGRAIN2 = "/hr"
-- Retain old command shortcuts for convenience.
SLASH_HEALINGRAIN3 = "/hh"
SLASH_HEALINGRAIN4 = "/healhelper"
SlashCmdList["HEALINGRAIN"] = function(msg)
    if not ready then initDB() end
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local low = msg:lower()
    if InCombatLockdown() and low ~= "config" and low ~= "clicks" then
        print("[Healing Rain] Change the layout after combat.")
        return
    end
    if low == "hide" then panel:Hide(); print("[Healing Rain] hidden (/hr show)")
    elseif low == "show" then panel:Show(); demoMode = false; RefreshRoster(); print("[Healing Rain] shown")
    elseif low == "refresh" then demoMode = false; RefreshRoster(); print("[Healing Rain] roster refreshed")
    elseif low == "demo" then panel:Show(); DemoRoster(); print("[Healing Rain] demo 40-raid - /hr live to go back")
    elseif low == "live" then demoMode = false; RefreshRoster(); print("[Healing Rain] live roster")
    elseif low == "target" then
        HealingRainDB.frames.showTarget = not HealingRainDB.frames.showTarget
        RefreshRoster()
        print(HealingRainDB.frames.showTarget and "[Healing Rain] Target window shown" or "[Healing Rain] Target window hidden")
    elseif low == "config" then openConfig()
    elseif low == "clicks" then
        local parts = {}
        for _, s in ipairs(MOUSE_SLOTS) do
            local sp = HealingRainDB.binds[s.id]
            if sp and sp ~= "" then parts[#parts + 1] = s.label .. ": " .. sp end
        end
        for _, s in ipairs(WHEEL_SLOTS) do
            local sp = HealingRainDB.binds[s.id]
            if sp and sp ~= "" then parts[#parts + 1] = s.label .. ": " .. sp end
        end
        print("[Healing Rain] " .. (#parts > 0 and table.concat(parts, " | ") or "no clicks set - /hr config"))
    else print("[Healing Rain] /hr show | /hr hide | /hr refresh | /hr demo | /hr live | /hr target | /hr clicks | /hr config")
    end
end
