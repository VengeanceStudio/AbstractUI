local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local CharacterPane = AbstractUI:NewModule("CharacterPane", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

---------------------------------------------------------------------------
-- CHARACTER PANEL CUSTOMIZATION
-- Equipment overlays (ilvl, enchants, gems) and custom stats panel
---------------------------------------------------------------------------

-- Equipment slot configuration
local EQUIPMENT_SLOTS = {
    { name = "Head", id = INVSLOT_HEAD, side = "left" },
    { name = "Neck", id = INVSLOT_NECK, side = "left" },
    { name = "Shoulder", id = INVSLOT_SHOULDER, side = "left" },
    { name = "Back", id = INVSLOT_BACK, side = "left" },
    { name = "Chest", id = INVSLOT_CHEST, side = "left" },
    { name = "Wrist", id = INVSLOT_WRIST, side = "left" },
    { name = "Hands", id = INVSLOT_HAND, side = "right" },
    { name = "Waist", id = INVSLOT_WAIST, side = "right" },
    { name = "Legs", id = INVSLOT_LEGS, side = "right" },
    { name = "Feet", id = INVSLOT_FEET, side = "right" },
    { name = "Finger0", id = INVSLOT_FINGER1, side = "right" },
    { name = "Finger1", id = INVSLOT_FINGER2, side = "right" },
    { name = "Trinket0", id = INVSLOT_TRINKET1, side = "right" },
    { name = "Trinket1", id = INVSLOT_TRINKET2, side = "right" },
    { name = "MainHand", id = INVSLOT_MAINHAND, side = "bottom" },
    { name = "SecondaryHand", id = INVSLOT_OFFHAND, side = "bottom" },
}

-- Module state
local ColorPalette = nil
local FontKit = nil
local customBg = nil
local slotOverlays = {}
local statsPanel = nil
local updatePending = false

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function CharacterPane:OnInitialize()
    self:RegisterMessage("AbstractUI_DB_READY", "OnDBReady")
end

function CharacterPane:OnDBReady()
    ColorPalette = _G.AbstractUI_ColorPalette
    FontKit = _G.AbstractUI_FontKit
    
    if not ColorPalette or not FontKit then
        return
    end
    
    self.db = AbstractUI.db:RegisterNamespace("CharacterPane", {
        profile = {
            enabled = true,
            showItemLevel = true,
            showEnchants = true,
            showGems = true,
            showStatsPanel = true,
            overlayTextSize = 11,
        }
    })
    
    self:RegisterEvent("ADDON_LOADED")
    
    if CharacterFrame then
        self:Setup()
    end
end

function CharacterPane:ADDON_LOADED(event, addon)
    if addon == "Blizzard_CharacterFrame" or (addon == "AbstractUI" and CharacterFrame) then
        C_Timer.After(0.1, function()
            if CharacterFrame then
                self:Setup()
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

---------------------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------------------

local function GetThemeColors()
    if not ColorPalette then
        return 0.55, 0.60, 0.70, 1, 0.05, 0.05, 0.05, 0.65
    end
    local pr, pg, pb, pa = ColorPalette:GetColor('primary')
    local bgr, bgg, bgb, bga = ColorPalette:GetColor('panel-bg')
    return pr, pg, pb, pa, bgr, bgg, bgb, bga
end

local function GetFont()
    if FontKit then
        return FontKit:GetFont('body')
    end
    return STANDARD_TEXT_FONT
end

local function IsEnabled()
    return CharacterPane.db and CharacterPane.db.profile.enabled
end

-- Get item level from tooltip (most accurate)
local function GetItemLevel(slotId)
    if not C_TooltipInfo then return nil end
    
    local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotId)
    if not tooltipData or not tooltipData.lines then return nil end
    
    local pattern = ITEM_LEVEL and ITEM_LEVEL:gsub("%%d", "(%%d+)") or "Item Level (%d+)"
    for _, line in ipairs(tooltipData.lines) do
        local text = line.leftText or ""
        local ilvl = text:match(pattern)
        if ilvl then
            return tonumber(ilvl)
        end
    end
    
    return nil
end

-- Get enchant information
local function GetEnchantInfo(slotId)
    local enchantableSlots = {
        [INVSLOT_CHEST] = true, [INVSLOT_BACK] = true, [INVSLOT_WRIST] = true,
        [INVSLOT_LEGS] = true, [INVSLOT_FEET] = true, [INVSLOT_FINGER1] = true,
        [INVSLOT_FINGER2] = true, [INVSLOT_MAINHAND] = true, [INVSLOT_OFFHAND] = true,
    }
    
    if not enchantableSlots[slotId] then
        return nil, false
    end
    
    if not C_TooltipInfo then return nil, true end
    
    local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotId)
    if not tooltipData or not tooltipData.lines then return nil, true end
    
    for _, line in ipairs(tooltipData.lines) do
        local text = line.leftText or ""
        local enchant = text:match("Enchanted:%s*(.+)")
        if enchant then
            enchant = enchant:gsub("|c%x+", ""):gsub("|r", ""):gsub("Enchant%s+%w+%s*%-?%s*", "")
            return enchant:match("^%s*(.-)%s*$"), true
        end
    end
    
    return nil, true
end

-- Get gem information
local function GetGemInfo(slotId)
    local itemLink = GetInventoryItemLink("player", slotId)
    if not itemLink then return {} end
    
    local gems = {}
    for i = 1, 3 do
        local _, gemLink = GetItemGem(itemLink, i)
        if gemLink then
            local itemID = GetItemInfoInstant(gemLink)
            local icon = itemID and C_Item.GetItemIconByID(itemID)
            if icon then
                table.insert(gems, icon)
            end
        end
    end
    
    return gems
end

---------------------------------------------------------------------------
-- SLOT OVERLAY CREATION
---------------------------------------------------------------------------

local function CreateSlotOverlay(slotButton, slotInfo)
    if not slotButton then return nil end
    
    local overlay = CreateFrame("Frame", nil, slotButton)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(slotButton:GetFrameLevel() + 5)
    
    local font = GetFont()
    local textSize = CharacterPane.db.profile.overlayTextSize
    
    -- Item level text
    overlay.ilvl = overlay:CreateFontString(nil, "OVERLAY")
    overlay.ilvl:SetFont(font, textSize, "OUTLINE")
    overlay.ilvl:SetTextColor(1, 1, 1)
    
    -- Enchant text
    overlay.enchant = overlay:CreateFontString(nil, "OVERLAY")
    overlay.enchant:SetFont(font, textSize - 2, "OUTLINE")
    
    -- Gem icons
    overlay.gems = {}
    for i = 1, 3 do
        local gem = overlay:CreateTexture(nil, "OVERLAY")
        gem:SetSize(12, 12)
        gem:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        gem:Hide()
        overlay.gems[i] = gem
    end
    
    -- Position elements based on slot side
    if slotInfo.side == "left" then
        overlay.ilvl:SetPoint("LEFT", overlay, "RIGHT", 4, 6)
        overlay.enchant:SetPoint("LEFT", overlay, "RIGHT", 4, -6)
        for i, gem in ipairs(overlay.gems) do
            gem:SetPoint("TOPRIGHT", overlay, "TOPLEFT", -2, -(i-1)*14)
        end
    elseif slotInfo.side == "right" then
        overlay.ilvl:SetPoint("RIGHT", overlay, "LEFT", -4, 6)
        overlay.enchant:SetPoint("RIGHT", overlay, "LEFT", -4, -6)
        for i, gem in ipairs(overlay.gems) do
            gem:SetPoint("TOPLEFT", overlay, "TOPRIGHT", 2, -(i-1)*14)
        end
    else -- bottom (weapons)
        overlay.ilvl:SetPoint("BOTTOM", overlay, "TOP", 0, 2)
        overlay.enchant:SetPoint("TOP", overlay, "BOTTOM", 0, -2)
        for i, gem in ipairs(overlay.gems) do
            gem:SetPoint("LEFT", overlay, "RIGHT", 2 + (i-1)*14, 0)
        end
    end
    
    overlay.slotInfo = slotInfo
    return overlay
end

---------------------------------------------------------------------------
-- SLOT OVERLAY UPDATE
---------------------------------------------------------------------------

local function UpdateSlotOverlay(overlay)
    if not overlay or not overlay.slotInfo then return end
    if not IsEnabled() then
        overlay:Hide()
        return
    end
    
    local settings = CharacterPane.db.profile
    local slotId = overlay.slotInfo.id
    local itemLink = GetInventoryItemLink("player", slotId)
    
    if not itemLink then
        overlay:Hide()
        return
    end
    
    overlay:Show()
    
    -- Update item level
    if settings.showItemLevel then
        local ilvl = GetItemLevel(slotId)
        if ilvl then
            overlay.ilvl:SetText(tostring(ilvl))
            overlay.ilvl:Show()
        else
            overlay.ilvl:Hide()
        end
    else
        overlay.ilvl:Hide()
    end
    
    -- Update enchant
    if settings.showEnchants then
        local enchant, isEnchantable = GetEnchantInfo(slotId)
        if isEnchantable then
            if enchant then
                overlay.enchant:SetText(enchant)
                local pr, pg, pb = GetThemeColors()
                overlay.enchant:SetTextColor(pr, pg, pb)
            else
                overlay.enchant:SetText("No Enchant")
                overlay.enchant:SetTextColor(0.7, 0.7, 0.7)
            end
            overlay.enchant:Show()
        else
            overlay.enchant:Hide()
        end
    else
        overlay.enchant:Hide()
    end
    
    -- Update gems
    if settings.showGems then
        local gems = GetGemInfo(slotId)
        for i, gemTex in ipairs(overlay.gems) do
            if gems[i] then
                gemTex:SetTexture(gems[i])
                gemTex:Show()
            else
                gemTex:Hide()
            end
        end
    else
        for _, gem in ipairs(overlay.gems) do
            gem:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- STATS PANEL
---------------------------------------------------------------------------

local function CreateStatsPanel()
    if statsPanel then return statsPanel end
    if not CharacterFrame then return nil end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    local font = GetFont()
    
    local panel = CreateFrame("Frame", "AbstractUI_StatsPanel", CharacterFrame, "BackdropTemplate")
    panel:SetSize(200, 380)
    panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", -50, -60)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(bgr, bgg, bgb, bga)
    panel:SetBackdropBorderColor(pr, pg, pb, pa)
    panel:SetFrameStrata("HIGH")
    
    -- Title
    panel.title = panel:CreateFontString(nil, "OVERLAY")
    panel.title:SetFont(font, 14, "OUTLINE")
    panel.title:SetPoint("TOP", 0, -10)
    panel.title:SetText("Character Stats")
    panel.title:SetTextColor(pr, pg, pb)
    
    -- Create stat rows
    local yOffset = -35
    local function CreateRow()
        local row = panel:CreateFontString(nil, "OVERLAY")
        row:SetFont(font, 11, "OUTLINE")
        row:SetPoint("TOPLEFT", 8, yOffset)
        row:SetPoint("TOPRIGHT", -8, yOffset)
        row:SetJustifyH("LEFT")
        row:SetTextColor(0.9, 0.9, 0.9)
        yOffset = yOffset - 18
        return row
    end
    
    panel.health = CreateRow()
    panel.power = CreateRow()
    panel.ilvl = CreateRow()
    yOffset = yOffset - 8
    panel.str = CreateRow()
    panel.agi = CreateRow()
    panel.int = CreateRow()
    panel.sta = CreateRow()
    yOffset = yOffset - 8
    panel.crit = CreateRow()
    panel.haste = CreateRow()
    panel.mastery = CreateRow()
    panel.vers = CreateRow()
    
    statsPanel = panel
    return panel
end

local function UpdateStatsPanel()
    if not statsPanel or not IsEnabled() then
        if statsPanel then statsPanel:Hide() end
        return
    end
    
    if not CharacterPane.db.profile.showStatsPanel then
        statsPanel:Hide()
        return
    end
    
    statsPanel:Show()
    
    -- Basic stats
    local health = UnitHealthMax("player")
    local power = UnitPowerMax("player")
    statsPanel.health:SetText("Health: " .. BreakUpLargeNumbers(health))
    statsPanel.power:SetText("Power: " .. BreakUpLargeNumbers(power))
    
    -- Item level
    local _, avgEquipped = GetAverageItemLevel()
    if avgEquipped then
        statsPanel.ilvl:SetText("Item Level: " .. math.floor(avgEquipped))
    end
    
    -- Primary stats
    local str = UnitStat("player", 1)
    local agi = UnitStat("player", 2)
    local int = UnitStat("player", 4)
    local sta = UnitStat("player", 3)
    statsPanel.str:SetText("Strength: " .. str)
    statsPanel.agi:SetText("Agility: " .. agi)
    statsPanel.int:SetText("Intellect: " .. int)
    statsPanel.sta:SetText("Stamina: " .. sta)
    
    -- Secondary stats
    local crit = GetCritChance()
    local haste = GetHaste()
    local mastery = GetMasteryEffect()
    local vers = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)
    statsPanel.crit:SetText(string.format("Crit: %.2f%%", crit))
    statsPanel.haste:SetText(string.format("Haste: %.2f%%", haste))
    statsPanel.mastery:SetText(string.format("Mastery: %.2f%%", mastery))
    statsPanel.vers:SetText(string.format("Versatility: %.2f%%", vers))
end

---------------------------------------------------------------------------
-- BACKGROUND AND DECORATION
---------------------------------------------------------------------------

local function HideBlizzardElements()
    if CharacterFramePortrait then CharacterFramePortrait:Hide() end
    if CharacterFrame.Background then CharacterFrame.Background:Hide() end
    if CharacterFrame.NineSlice then CharacterFrame.NineSlice:Hide() end
end

local function CreateBackground()
    if not CharacterFrame then return end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    
    if not customBg then
        customBg = CreateFrame("Frame", "AbstractUI_CharBg", CharacterFrame, "BackdropTemplate")
        customBg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        customBg:SetFrameStrata("BACKGROUND")
        customBg:SetFrameLevel(0)
        customBg:EnableMouse(false)
        customBg:SetAllPoints(CharacterFrame)
    end
    
    customBg:SetBackdropColor(bgr, bgg, bgb, bga)
    customBg:SetBackdropBorderColor(pr, pg, pb, pa)
    customBg:Show()
    
    HideBlizzardElements()
end

---------------------------------------------------------------------------
-- MAIN SETUP
---------------------------------------------------------------------------

function CharacterPane:Setup()
    if not IsEnabled() then return end
    if not CharacterFrame then return end
    
    CreateBackground()
    
    -- Create overlays for equipment slots
    for _, slotInfo in ipairs(EQUIPMENT_SLOTS) do
        local slotButton = _G["Character" .. slotInfo.name .. "Slot"]
        if slotButton and not slotOverlays[slotInfo.id] then
            local overlay = CreateSlotOverlay(slotButton, slotInfo)
            if overlay then
                slotOverlays[slotInfo.id] = overlay
            end
        end
    end
    
    -- Create stats panel
    CreateStatsPanel()
    
    -- Hook frame events
    CharacterFrame:HookScript("OnShow", function()
        if IsEnabled() then
            CreateBackground()
            self:UpdateAll()
        end
    end)
    
    PaperDollFrame:HookScript("OnShow", function()
        if IsEnabled() then
            self:UpdateAll()
        end
    end)
    
    -- Register update events
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "ScheduleUpdate")
    self:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE", "ScheduleUpdate")
    self:RegisterEvent("UNIT_STATS", "ScheduleUpdate")
    
    -- Initial update
    if CharacterFrame:IsShown() and PaperDollFrame:IsShown() then
        self:UpdateAll()
    end
    
    self:RegisterMessage("AbstractUI_THEME_CHANGED", "OnThemeChanged")
end

function CharacterPane:ScheduleUpdate()
    if updatePending then return end
    updatePending = true
    C_Timer.After(0.1, function()
        updatePending = false
        self:UpdateAll()
    end)
end

function CharacterPane:UpdateAll()
    if not IsEnabled() then return end
    
    for _, overlay in pairs(slotOverlays) do
        UpdateSlotOverlay(overlay)
    end
    
    UpdateStatsPanel()
end

function CharacterPane:OnThemeChanged()
    if not IsEnabled() then return end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    
    if customBg then
        customBg:SetBackdropColor(bgr, bgg, bgb, bga)
        customBg:SetBackdropBorderColor(pr, pg, pb, pa)
    end
    
    if statsPanel then
        statsPanel:SetBackdropColor(bgr, bgg, bgb, bga)
        statsPanel:SetBackdropBorderColor(pr, pg, pb, pa)
        if statsPanel.title then
            statsPanel.title:SetTextColor(pr, pg, pb)
        end
    end
    
    self:UpdateAll()
end
