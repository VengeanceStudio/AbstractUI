local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local CharacterPane = AbstractUI:NewModule("CharacterPane", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

---------------------------------------------------------------------------
-- CUSTOM CHARACTER PANEL - QUAZII STYLE
-- Complete replacement of default character frame layout
---------------------------------------------------------------------------

-- Equipment slot configuration (in display order)
local EQUIPMENT_SLOTS = {
    { name = "Head", id = INVSLOT_HEAD, label = "Head" },
    { name = "Neck", id = INVSLOT_NECK, label = "Neck" },
    { name = "Shoulder", id = INVSLOT_SHOULDER, label = "Shoulder" },
    { name = "Back", id = INVSLOT_BACK, label = "Back" },
    { name = "Chest", id = INVSLOT_CHEST, label = "Chest" },
    { name = "Wrist", id = INVSLOT_WRIST, label = "Wrist" },
    { name = "Hands", id = INVSLOT_HAND, label = "Hands" },
    { name = "Waist", id = INVSLOT_WAIST, label = "Waist" },
    { name = "Legs", id = INVSLOT_LEGS, label = "Legs" },
    { name = "Feet", id = INVSLOT_FEET, label = "Feet" },
    { name = "Finger0", id = INVSLOT_FINGER1, label = "Ring 1" },
    { name = "Finger1", id = INVSLOT_FINGER2, label = "Ring 2" },
    { name = "Trinket0", id = INVSLOT_TRINKET1, label = "Trinket 1" },
    { name = "Trinket1", id = INVSLOT_TRINKET2, label = "Trinket 2" },
    { name = "MainHand", id = INVSLOT_MAINHAND, label = "Main Hand" },
    { name = "SecondaryHand", id = INVSLOT_OFFHAND, label = "Off Hand" },
}

-- Module state
local ColorPalette = nil
local FontKit = nil
local mainPanel = nil
local equipmentList = {}
local statsPanel = nil
local settingsPanel = nil
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
            showEquipmentName = true,
            showItemLevel = true,
            showEnchantStatus = true,
            showGemIndicators = true,
            showDurabilityBars = false,
            showStatsPanel = true,
            showStatTooltips = false,
            statDisplayFormat = "both", -- "both", "number", "percent"
            equipmentListWidth = 240,
            statsPanelWidth = 200,
            settingsPanelWidth = 260,
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

-- Get item level from tooltip
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

-- Get gem count
local function GetGemCount(slotId)
    local itemLink = GetInventoryItemLink("player", slotId)
    if not itemLink then return 0 end
    
    local count = 0
    for i = 1, 3 do
        local _, gemLink = GetItemGem(itemLink, i)
        if gemLink then
            count = count + 1
        end
    end
    
    return count
end

-- Get quality color
local function GetQualityColor(quality)
    if quality then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        return r, g, b
    end
    return 1, 1, 1
end

---------------------------------------------------------------------------
-- EQUIPMENT LIST (LEFT PANEL)
---------------------------------------------------------------------------

local function CreateEquipmentRow(parent, slotInfo, yOffset)
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    local font = GetFont()
    local settings = CharacterPane.db.profile
    
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(settings.equipmentListWidth - 10, 30)
    row:SetPoint("TOPLEFT", 5, yOffset)
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    row:SetBackdropColor(bgr, bgg, bgb, 0.3)
    row:SetBackdropBorderColor(pr * 0.5, pg * 0.5, pb * 0.5, 0.5)
    
    -- Icon
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Slot label
    row.slotLabel = row:CreateFontString(nil, "OVERLAY")
    row.slotLabel:SetFont(font, 10, "OUTLINE")
    row.slotLabel:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, -2)
    row.slotLabel:SetTextColor(0.7, 0.7, 0.7)
    row.slotLabel:SetText(slotInfo.label)
    
    -- Item name
    row.itemName = row:CreateFontString(nil, "OVERLAY")
    row.itemName:SetFont(font, 11, "OUTLINE")
    row.itemName:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 4, 2)
    row.itemName:SetPoint("RIGHT", -40, 0)
    row.itemName:SetJustifyH("LEFT")
    row.itemName:SetWordWrap(false)
    
    -- Item level
    row.ilvl = row:CreateFontString(nil, "OVERLAY")
    row.ilvl:SetFont(font, 11, "OUTLINE")
    row.ilvl:SetPoint("RIGHT", -4, 6)
    row.ilvl:SetTextColor(1, 1, 1)
    
    -- Enchant status indicator
    row.enchantStatus = row:CreateFontString(nil, "OVERLAY")
    row.enchantStatus:SetFont(font, 9, "OUTLINE")
    row.enchantStatus:SetPoint("RIGHT", -4, -6)
    
    -- Gem indicator
    row.gemIndicator = row:CreateFontString(nil, "OVERLAY")
    row.gemIndicator:SetFont(font, 9, "OUTLINE")
    row.gemIndicator:SetPoint("BOTTOMRIGHT", row.ilvl, "BOTTOMLEFT", -4, 0)
    row.gemIndicator:SetTextColor(0.8, 0.5, 1)
    
    row.slotInfo = slotInfo
    return row
end

local function CreateEquipmentList()
    if not mainPanel then return end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    local font = GetFont()
    local settings = CharacterPane.db.profile
    
    local panel = CreateFrame("Frame", "AbstractUI_EquipmentList", mainPanel, "BackdropTemplate")
    panel:SetSize(settings.equipmentListWidth, 520)
    panel:SetPoint("TOPLEFT", mainPanel, "TOPLEFT", 5, -30)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(bgr, bgg, bgb, 0.5)
    panel:SetBackdropBorderColor(pr, pg, pb, pa)
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFont(font, 12, "OUTLINE")
    title:SetPoint("TOP", 0, -5)
    title:SetText("Equipment")
    title:SetTextColor(pr, pg, pb)
    
    -- Average ilvl display
    panel.avgIlvl = panel:CreateFontString(nil, "OVERLAY")
    panel.avgIlvl:SetFont(font, 16, "OUTLINE")
    panel.avgIlvl:SetPoint("TOP", title, "BOTTOM", 0, -4)
    panel.avgIlvl:SetTextColor(1, 1, 1)
    
    -- Create equipment rows
    local yOffset = -50
    for i, slotInfo in ipairs(EQUIPMENT_SLOTS) do
        local row = CreateEquipmentRow(panel, slotInfo, yOffset)
        equipmentList[slotInfo.id] = row
        yOffset = yOffset - 32
    end
    
    return panel
end

local function UpdateEquipmentRow(row)
    if not row or not row.slotInfo then return end
    if not IsEnabled() then
        row:Hide()
        return
    end
    
    local settings = CharacterPane.db.profile
    local slotId = row.slotInfo.id
    local itemLink = GetInventoryItemLink("player", slotId)
    
    if not itemLink then
        row.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. row.slotInfo.name:gsub("%d", ""))
        row.icon:SetDesaturated(true)
        row.itemName:SetText("")
        row.ilvl:Hide()
        row.enchantStatus:Hide()
        row.gemIndicator:Hide()
        return
    end
    
    row:Show()
    
    -- Icon
    local icon = C_Item.GetItemIconByID(itemLink)
    if icon then
        row.icon:SetTexture(icon)
        row.icon:SetDesaturated(false)
    end
    
    -- Item name with quality color
    if settings.showEquipmentName then
        local itemName, _, quality = C_Item.GetItemInfo(itemLink)
        if itemName then
            local r, g, b = GetQualityColor(quality)
            row.itemName:SetText(itemName)
            row.itemName:SetTextColor(r, g, b)
        end
    else
        row.itemName:SetText("")
    end
    
    -- Item level
    if settings.showItemLevel then
        local ilvl = GetItemLevel(slotId)
        if ilvl then
            row.ilvl:SetText(tostring(ilvl))
            row.ilvl:Show()
        else
            row.ilvl:Hide()
        end
    else
        row.ilvl:Hide()
    end
    
    -- Enchant status
    if settings.showEnchantStatus then
        local enchant, isEnchantable = GetEnchantInfo(slotId)
        if isEnchantable then
            if enchant then
                row.enchantStatus:SetText("✓")
                local pr, pg, pb = GetThemeColors()
                row.enchantStatus:SetTextColor(0, 1, 0)
            else
                row.enchantStatus:SetText("✗")
                row.enchantStatus:SetTextColor(1, 0, 0)
            end
            row.enchantStatus:Show()
        else
            row.enchantStatus:Hide()
        end
    else
        row.enchantStatus:Hide()
    end
    
    -- Gem indicator
    if settings.showGemIndicators then
        local gemCount = GetGemCount(slotId)
        if gemCount > 0 then
            row.gemIndicator:SetText("◆" .. gemCount)
            row.gemIndicator:Show()
        else
            row.gemIndicator:Hide()
        end
    else
        row.gemIndicator:Hide()
    end
end

local function UpdateEquipmentList()
    if not mainPanel or not next(equipmentList) then return end
    if not IsEnabled() then return end
    
    -- Update average ilvl
    local equipped, overall = GetAverageItemLevel()
    if equipped then
        local panel = mainPanel:GetChildren()
        for child in pairs({mainPanel:GetChildren()}) do
            if child.avgIlvl then
                child.avgIlvl:SetText(string.format("%.1f | %.1f", equipped, overall))
            end
        end
    end
    
    -- Update all rows
    for slotId, row in pairs(equipmentList) do
        UpdateEquipmentRow(row)
    end
end

---------------------------------------------------------------------------
-- STATS PANEL (RIGHT SIDE)
---------------------------------------------------------------------------

local function CreateStatsPanel()
    if statsPanel then return statsPanel end
    if not mainPanel then return nil end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    local font = GetFont()
    local settings = CharacterPane.db.profile
    
    local panel = CreateFrame("Frame", "AbstractUI_StatsPanel", mainPanel, "BackdropTemplate")
    panel:SetSize(settings.statsPanelWidth, 520)
    panel:SetPoint("TOPLEFT", mainPanel, "TOP", 130, -30)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(bgr, bgg, bgb, 0.5)
    panel:SetBackdropBorderColor(pr, pg, pb, pa)
    panel:SetFrameStrata("HIGH")
    
    -- Title
    panel.title = panel:CreateFontString(nil, "OVERLAY")
    panel.title:SetFont(font, 12, "OUTLINE")
    panel.title:SetPoint("TOP", 0, -8)
    panel.title:SetText("Character Stats")
    panel.title:SetTextColor(pr, pg, pb)
    
    -- Create stat rows
    local yOffset = -35
    local function CreateStatRow(label)
        local row = CreateFrame("Frame", nil, panel)
        row:SetSize(settings.statsPanelWidth - 16, 16)
        row:SetPoint("TOPLEFT", 8, yOffset)
        
        row.label = row:CreateFontString(nil, "OVERLAY")
        row.label:SetFont(font, 10, "OUTLINE")
        row.label:SetPoint("LEFT", 0, 0)
        row.label:SetTextColor(0.7, 0.7, 0.7)
        row.label:SetText(label)
        
        row.value = row:CreateFontString(nil, "OVERLAY")
        row.value:SetFont(font, 10, "OUTLINE")
        row.value:SetPoint("RIGHT", 0, 0)
        row.value:SetTextColor(1, 1, 1)
        
        yOffset = yOffset - 18
        return row
    end
    
    local function CreateSeparator()
        local sep = panel:CreateTexture(nil, "ARTWORK")
        sep:SetSize(settings.statsPanelWidth - 16, 1)
        sep:SetPoint("TOPLEFT", 8, yOffset)
        sep:SetColorTexture(pr * 0.5, pg * 0.5, pb * 0.5, 0.5)
        yOffset = yOffset - 8
        return sep
    end
    
    local function CreateHeader(text)
        local header = panel:CreateFontString(nil, "OVERLAY")
        header:SetFont(font, 11, "OUTLINE")
        header:SetPoint("TOPLEFT", 8, yOffset)
        header:SetTextColor(pr, pg, pb)
        header:SetText(text)
        yOffset = yOffset - 20
        return header
    end
    
    -- Basic stats
    CreateHeader("Basic")
    panel.health = CreateStatRow("Health")
    panel.power = CreateStatRow("Power")
    panel.ilvl = CreateStatRow("Item Level")
    
    CreateSeparator()
    
    -- Primary stats
    CreateHeader("Attributes")
    panel.str = CreateStatRow("Strength")
    panel.agi = CreateStatRow("Agility")
    panel.int = CreateStatRow("Intellect")
    panel.sta = CreateStatRow("Stamina")
    
    CreateSeparator()
    
    -- Secondary stats
    CreateHeader("Secondary")
    panel.crit = CreateStatRow("Crit")
    panel.haste = CreateStatRow("Haste")
    panel.mastery = CreateStatRow("Mastery")
    panel.vers = CreateStatRow("Versatility")
    
    CreateSeparator()
    
    -- Attack stats
    CreateHeader("Attack")
    panel.attackPower = CreateStatRow("Attack Power")
    panel.spellPower = CreateStatRow("Spell Power")
    panel.attackSpeed = CreateStatRow("Attack Speed")
    
    CreateSeparator()
    
    -- Defense stats
    CreateHeader("Defense")
    panel.armor = CreateStatRow("Armor")
    panel.dodge = CreateStatRow("Dodge")
    panel.parry = CreateStatRow("Parry")
    panel.block = CreateStatRow("Block")
    
    statsPanel = panel
    return panel
end

local function FormatStatValue(value, format, isPercent)
    local settings = CharacterPane.db.profile
    
    if format == "both" and isPercent then
        return string.format("%s (%.2f%%)", BreakUpLargeNumbers(value), value)
    elseif format == "percent" and isPercent then
        return string.format("%.2f%%", value)
    else
        return BreakUpLargeNumbers(value)
    end
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
    
    local format = CharacterPane.db.profile.statDisplayFormat
    
    -- Basic stats
    local health = UnitHealthMax("player")
    local power = UnitPowerMax("player")
    statsPanel.health.value:SetText(BreakUpLargeNumbers(health))
    statsPanel.power.value:SetText(BreakUpLargeNumbers(power))
    
    -- Item level
    local _, avgEquipped = GetAverageItemLevel()
    if avgEquipped then
        statsPanel.ilvl.value:SetText(math.floor(avgEquipped))
    end
    
    -- Primary stats
    local str = UnitStat("player", 1)
    local agi = UnitStat("player", 2)
    local int = UnitStat("player", 4)
    local sta = UnitStat("player", 3)
    statsPanel.str.value:SetText(str)
    statsPanel.agi.value:SetText(agi)
    statsPanel.int.value:SetText(int)
    statsPanel.sta.value:SetText(sta)
    
    -- Secondary stats
    local crit = GetCritChance()
    local haste = GetHaste()
    local mastery = GetMasteryEffect()
    local vers = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)
    
    statsPanel.crit.value:SetText(string.format("%.2f%%", crit))
    statsPanel.haste.value:SetText(string.format("%.2f%%", haste))
    statsPanel.mastery.value:SetText(string.format("%.2f%%", mastery))
    statsPanel.vers.value:SetText(string.format("%.2f%%", vers))
    
    -- Attack stats
    local base, posBuff, negBuff = UnitAttackPower("player")
    local attackPower = base + posBuff + negBuff
    local spellPower = GetSpellBonusDamage(2)
    local attackSpeed = UnitAttackSpeed("player")
    
    statsPanel.attackPower.value:SetText(BreakUpLargeNumbers(attackPower))
    statsPanel.spellPower.value:SetText(BreakUpLargeNumbers(spellPower))
    if attackSpeed then
        statsPanel.attackSpeed.value:SetText(string.format("%.2fs", attackSpeed))
    end
    
    -- Defense stats
    local armor = select(2, UnitArmor("player"))
    local dodge = GetDodgeChance()
    local parry = GetParryChance()
    local block = GetBlockChance()
    
    statsPanel.armor.value:SetText(BreakUpLargeNumbers(armor))
    statsPanel.dodge.value:SetText(string.format("%.2f%%", dodge))
    statsPanel.parry.value:SetText(string.format("%.2f%%", parry))
    statsPanel.block.value:SetText(string.format("%.2f%%", block))
end

---------------------------------------------------------------------------
-- SETTINGS PANEL (FAR RIGHT)
---------------------------------------------------------------------------

local function CreateCheckbox(parent, label, setting, yOffset)
    local pr, pg, pb = GetThemeColors()
    local font = GetFont()
    
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetPoint("TOPLEFT", 10, yOffset)
    check:SetChecked(CharacterPane.db.profile[setting])
    
    check.text = check:CreateFontString(nil, "OVERLAY")
    check.text:SetFont(font, 10, "OUTLINE")
    check.text:SetPoint("LEFT", check, "RIGHT", 5, 0)
    check.text:SetText(label)
    check.text:SetTextColor(0.9, 0.9, 0.9)
    
    check:SetScript("OnClick", function(self)
        CharacterPane.db.profile[setting] = self:GetChecked()
        CharacterPane:UpdateAll()
    end)
    
    return check
end

local function CreateSettingsPanel()
    if settingsPanel then return settingsPanel end
    if not mainPanel then return nil end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    local font = GetFont()
    local settings = CharacterPane.db.profile
    
    local panel = CreateFrame("Frame", "AbstractUI_CharSettingsPanel", mainPanel, "BackdropTemplate")
    panel:SetSize(settings.settingsPanelWidth, 520)
    panel:SetPoint("TOPLEFT", mainPanel, "TOP", 335, -30)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(bgr, bgg, bgb, 0.5)
    panel:SetBackdropBorderColor(pr, pg, pb, pa)
    panel:SetFrameStrata("HIGH")
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFont(font, 12, "OUTLINE")
    title:SetPoint("TOP", 0, -8)
    title:SetText("QUI Character Panel")
    title:SetTextColor(pr, pg, pb)
    
    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(font, 9, "OUTLINE")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText("Settings")
    subtitle:SetTextColor(0.7, 0.7, 0.7)
    
    -- Create sections
    local yOffset = -50
    
    -- Appearance section
    local appearanceHeader = panel:CreateFontString(nil, "OVERLAY")
    appearanceHeader:SetFont(font, 11, "OUTLINE")
    appearanceHeader:SetPoint("TOPLEFT", 10, yOffset)
    appearanceHeader:SetText("Appearance")
    appearanceHeader:SetTextColor(pr, pg, pb)
    yOffset = yOffset - 22
    
    -- Slot Overlays section
    local slotHeader = panel:CreateFontString(nil, "OVERLAY")
    slotHeader:SetFont(font, 10, "OUTLINE")
    slotHeader:SetPoint("TOPLEFT", 10, yOffset)
    slotHeader:SetText("Slot Overlays")
    slotHeader:SetTextColor(0.8, 0.8, 0.8)
    yOffset = yOffset - 20
    
    local showNameCheck = CreateCheckbox(panel, "Show Equipment Name", "showEquipmentName", yOffset)
    yOffset = yOffset - 24
    
    local showIlvlCheck = CreateCheckbox(panel, "Show Item Level & Track", "showItemLevel", yOffset)
    yOffset = yOffset - 24
    
    local showEnchantCheck = CreateCheckbox(panel, "Show Enchant Status", "showEnchantStatus", yOffset)
    yOffset = yOffset - 24
    
    local showGemsCheck = CreateCheckbox(panel, "Show Gem Indicators", "showGemIndicators", yOffset)
    yOffset = yOffset - 24
    
    local showDurabilityCheck = CreateCheckbox(panel, "Show Durability Bars", "showDurabilityBars", yOffset)
    yOffset = yOffset - 30
    
    -- Stats Panel section
    local statsHeader = panel:CreateFontString(nil, "OVERLAY")
    statsHeader:SetFont(font, 10, "OUTLINE")
    statsHeader:SetPoint("TOPLEFT", 10, yOffset)
    statsHeader:SetText("Stats Panel")
    statsHeader:SetTextColor(0.8, 0.8, 0.8)
    yOffset = yOffset - 20
    
    local showStatsPanelCheck = CreateCheckbox(panel, "Show Stats Panel", "showStatsPanel", yOffset)
    yOffset = yOffset - 24
    
    local showStatTooltipsCheck = CreateCheckbox(panel, "Show Stat Tooltips", "showStatTooltips", yOffset)
    yOffset = yOffset - 30
    
    -- Secondary Stats section
    local secondaryHeader = panel:CreateFontString(nil, "OVERLAY")
    secondaryHeader:SetFont(font, 10, "OUTLINE")
    secondaryHeader:SetPoint("TOPLEFT", 10, yOffset)
    secondaryHeader:SetText("Secondary Stats")
    secondaryHeader:SetTextColor(0.8, 0.8, 0.8)
    yOffset = yOffset - 20
    
    -- Display Format dropdown placeholder
    local formatLabel = panel:CreateFontString(nil, "OVERLAY")
    formatLabel:SetFont(font, 9, "OUTLINE")
    formatLabel:SetPoint("TOPLEFT", 15, yOffset)
    formatLabel:SetText("Display Format")
    formatLabel:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - 16
    
    local formatText = panel:CreateFontString(nil, "OVERLAY")
    formatText:SetFont(font, 10, "OUTLINE")
    formatText:SetPoint("TOPLEFT", 15, yOffset)
    formatText:SetTextColor(pr, pg, pb)
    
    local formatOptions = {
        both = "Both (1,234 (19.5%))",
        number = "Number (1,234)",
        percent = "Percent (19.5%)"
    }
    formatText:SetText(formatOptions[settings.statDisplayFormat] or formatOptions.both)
    
    yOffset = yOffset - 40
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 25)
    resetBtn:SetPoint("BOTTOM", 0, 10)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function()
        -- Reset to defaults
        CharacterPane.db.profile.showEquipmentName = true
        CharacterPane.db.profile.showItemLevel = true
        CharacterPane.db.profile.showEnchantStatus = true
        CharacterPane.db.profile.showGemIndicators = true
        CharacterPane.db.profile.showDurabilityBars = false
        CharacterPane.db.profile.showStatsPanel = true
        CharacterPane.db.profile.showStatTooltips = false
        CharacterPane.db.profile.statDisplayFormat = "both"
        
        -- Update checkboxes
        showNameCheck:SetChecked(true)
        showIlvlCheck:SetChecked(true)
        showEnchantCheck:SetChecked(true)
        showGemsCheck:SetChecked(true)
        showDurabilityCheck:SetChecked(false)
        showStatsPanelCheck:SetChecked(true)
        showStatTooltipsCheck:SetChecked(false)
        
        CharacterPane:UpdateAll()
    end)
    
    settingsPanel = panel
    return panel
end

---------------------------------------------------------------------------
-- MAIN PANEL AND BACKGROUND
---------------------------------------------------------------------------

local function HideBlizzardElements()
    -- Hide default equipment slots
    for _, slotInfo in ipairs(EQUIPMENT_SLOTS) do
        local slotButton = _G["Character" .. slotInfo.name .. "Slot"]
        if slotButton then
            slotButton:Hide()
        end
    end
    
    -- Hide other default elements
    if CharacterFramePortrait then CharacterFramePortrait:Hide() end
    if CharacterFrame.Background then CharacterFrame.Background:Hide() end
    if CharacterFrame.NineSlice then CharacterFrame.NineSlice:Hide() end
    if CharacterLevelText then CharacterLevelText:Hide() end
    if CharacterFrameTitleText then CharacterFrameTitleText:SetText("") end
    
    -- Keep character model visible
    if CharacterModelScene then CharacterModelScene:Show() end
end

local function CreateMainPanel()
    if mainPanel then return mainPanel end
    if not CharacterFrame then return nil end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    
    local panel = CreateFrame("Frame", "AbstractUI_CharacterPanel", PaperDollFrame, "BackdropTemplate")
    panel:SetAllPoints(PaperDollFrame)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    panel:SetBackdropColor(bgr, bgg, bgb, 0.8)
    panel:SetBackdropBorderColor(pr, pg, pb, pa)
    panel:SetFrameStrata("BACKGROUND")
    panel:SetFrameLevel(0)
    
    mainPanel = panel
    return panel
end

---------------------------------------------------------------------------
-- MAIN SETUP
---------------------------------------------------------------------------

function CharacterPane:Setup()
    if not IsEnabled() then return end
    if not CharacterFrame then return end
    
    -- Create main panel
    CreateMainPanel()
    HideBlizzardElements()
    
    -- Create sub-panels
    CreateEquipmentList()
    CreateStatsPanel()
    CreateSettingsPanel()
    
    -- Hook frame events
    CharacterFrame:HookScript("OnShow", function()
        if IsEnabled() then
            HideBlizzardElements()
            self:UpdateAll()
        end
    end)
    
    PaperDollFrame:HookScript("OnShow", function()
        if IsEnabled() then
            HideBlizzardElements()
            self:UpdateAll()
        end
    end)
    
    -- Register update events
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "ScheduleUpdate")
    self:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE", "ScheduleUpdate")
    self:RegisterEvent("UNIT_STATS", "ScheduleUpdate")
    self:RegisterEvent("UNIT_ATTACK_POWER", "ScheduleUpdate")
    self:RegisterEvent("UNIT_SPELL_POWER", "ScheduleUpdate")
    self:RegisterEvent("UNIT_ATTACK_SPEED", "ScheduleUpdate")
    
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
    
    UpdateEquipmentList()
    UpdateStatsPanel()
end

function CharacterPane:OnThemeChanged()
    if not IsEnabled() then return end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    
    -- Update main panel
    if mainPanel then
        mainPanel:SetBackdropColor(bgr, bgg, bgb, 0.8)
        mainPanel:SetBackdropBorderColor(pr, pg, pb, pa)
    end
    
    -- Update equipment list panel
    for _, row in pairs(equipmentList) do
        if row and row:GetParent() then
            local parent = row:GetParent()
            parent:SetBackdropColor(bgr, bgg, bgb, 0.5)
            parent:SetBackdropBorderColor(pr, pg, pb, pa)
            break
        end
    end
    
    -- Update stats panel
    if statsPanel then
        statsPanel:SetBackdropColor(bgr, bgg, bgb, 0.5)
        statsPanel:SetBackdropBorderColor(pr, pg, pb, pa)
        if statsPanel.title then
            statsPanel.title:SetTextColor(pr, pg, pb)
        end
    end
    
    -- Update settings panel
    if settingsPanel then
        settingsPanel:SetBackdropColor(bgr, bgg, bgb, 0.5)
        settingsPanel:SetBackdropBorderColor(pr, pg, pb, pa)
    end
    
    self:UpdateAll()
end
