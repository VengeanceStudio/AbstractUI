local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local CharacterPane = AbstractUI:NewModule("CharacterPane", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

---------------------------------------------------------------------------
-- CHARACTER PANEL CUSTOMIZATION
-- Equipment overlays (ilvl, enchants, gems) and custom stats panel
---------------------------------------------------------------------------

-- Equipment slot configuration (in order for left-side display)
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
local customBg = nil
local equipmentLabels = {}
local ilvlDisplay = nil
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
-- EQUIPMENT LABELS (LEFT SIDE)
---------------------------------------------------------------------------

local function CreateEquipmentLabel(parent, slotInfo, index)
    local pr, pg, pb = GetThemeColors()
    local font = GetFont()
    
    local label = CreateFrame("Frame", nil, parent)
    label:SetSize(280, 24)
    label:SetPoint("TOPLEFT", 10, -30 - (index * 26))
    
    -- Item icon
    label.icon = label:CreateTexture(nil, "ARTWORK")
    label.icon:SetSize(22, 22)
    label.icon:SetPoint("LEFT", 2, 0)
    label.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Item name
    label.itemName = label:CreateFontString(nil, "OVERLAY")
    label.itemName:SetFont(font, 10, "OUTLINE")
    label.itemName:SetPoint("LEFT", label.icon, "RIGHT", 4, 0)
    label.itemName:SetPoint("RIGHT", -90, 0)
    label.itemName:SetJustifyH("LEFT")
    label.itemName:SetWordWrap(false)
    
    -- Item level
    label.ilvl = label:CreateFontString(nil, "OVERLAY")
    label.ilvl:SetFont(font, 10, "OUTLINE")
    label.ilvl:SetPoint("RIGHT", -40, 0)
    label.ilvl:SetTextColor(1, 0.82, 0) -- Gold color
    
    -- Enchant/gem status
    label.status = label:CreateFontString(nil, "OVERLAY")
    label.status:SetFont(font, 9, "OUTLINE")
    label.status:SetPoint("RIGHT", -2, 0)
    
    label.slotInfo = slotInfo
    return label
end

local function UpdateEquipmentLabel(label)
    if not label or not label.slotInfo then return end
    
    local settings = CharacterPane.db.profile
    local slotId = label.slotInfo.id
    local itemLink = GetInventoryItemLink("player", slotId)
    
    if not itemLink then
        label.icon:SetTexture(nil)
        label.itemName:SetText("")
        label.ilvl:SetText("")
        label.status:SetText("")
        return
    end
    
    -- Icon
    local icon = C_Item.GetItemIconByID(itemLink)
    if icon then
        label.icon:SetTexture(icon)
    end
    
    -- Item name with quality color
    if settings.showEquipmentName then
        local itemName, _, quality = C_Item.GetItemInfo(itemLink)
        if itemName then
            local r, g, b = GetQualityColor(quality)
            label.itemName:SetText(itemName)
            label.itemName:SetTextColor(r, g, b)
        end
    end
    
    -- Item level
    if settings.showItemLevel then
        local ilvl = GetItemLevel(slotId)
        if ilvl then
            label.ilvl:SetText(tostring(ilvl))
        else
            label.ilvl:SetText("")
        end
    end
    
    -- Enchant/gem status
    local statusText = ""
    if settings.showEnchantStatus then
        local enchant, isEnchantable = GetEnchantInfo(slotId)
        if isEnchantable and not enchant then
            statusText = "No Enchant"
            label.status:SetTextColor(1, 0, 0) -- Red
        end
    end
    
    if settings.showGemIndicators and statusText == "" then
        local gemCount = GetGemCount(slotId)
        if gemCount > 0 then
            statusText = "◆" .. gemCount
            label.status:SetTextColor(0.8, 0.5, 1) -- Purple
        end
    end
    
    label.status:SetText(statusText)
end

---------------------------------------------------------------------------
-- ITEM LEVEL DISPLAY (TOP CENTER)
---------------------------------------------------------------------------

local function CreateIlvlDisplay()
    if ilvlDisplay then return ilvlDisplay end
    if not PaperDollFrame then return nil end
    
    local pr, pg, pb = GetThemeColors()
    local font = GetFont()
    
    local display = PaperDollFrame:CreateFontString(nil, "OVERLAY")
    display:SetFont(font, 18, "OUTLINE")
    display:SetPoint("TOP", PaperDollFrame, "TOP", 0, -8)
    display:SetTextColor(1, 1, 1)
    
    ilvlDisplay = display
    return display
end

local function UpdateIlvlDisplay()
    if not ilvlDisplay then return end
    
    local equipped, overall = GetAverageItemLevel()
    if equipped and overall then
        ilvlDisplay:SetText(string.format("%.1f | %.1f", equipped, overall))
    end
end

---------------------------------------------------------------------------
-- STATS PANEL (RIGHT SIDE)
---------------------------------------------------------------------------

local function CreateStatsPanel()
    if statsPanel then return statsPanel end
    if not PaperDollFrame then return nil end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    local font = GetFont()
    
    local panel = CreateFrame("Frame", "AbstractUI_StatsPanel", PaperDollFrame, "BackdropTemplate")
    panel:SetSize(180, 520)
    panel:SetPoint("TOPLEFT", PaperDollFrame, "TOPRIGHT", -30, -30)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(bgr, bgg, bgb, 0.7)
    panel:SetBackdropBorderColor(pr, pg, pb, pa)
    panel:SetFrameStrata("HIGH")
    
    -- Title
    panel.title = panel:CreateFontString(nil, "OVERLAY")
    panel.title:SetFont(font, 11, "OUTLINE")
    panel.title:SetPoint("TOP", 0, -8)
    panel.title:SetText("Character Stats")
    panel.title:SetTextColor(pr, pg, pb)
    
    -- Create stat rows with label/value pairs
    local yOffset = -28
    local function CreateSection(header, color)
        local section = panel:CreateFontString(nil, "OVERLAY")
        section:SetFont(font, 10, "OUTLINE")
        section:SetPoint("TOPLEFT", 8, yOffset)
        section:SetText(header)
        section:SetTextColor(color.r, color.g, color.b)
        yOffset = yOffset - 16
        return section
    end
    
    local function CreateStatRow(label)
        local row = CreateFrame("Frame", nil, panel)
        row:SetSize(164, 14)
        row:SetPoint("TOPLEFT", 10, yOffset)
        
        row.label = row:CreateFontString(nil, "OVERLAY")
        row.label:SetFont(font, 9, "OUTLINE")
        row.label:SetPoint("LEFT", 0, 0)
        row.label:SetText(label)
        row.label:SetTextColor(0.85, 0.85, 0.85)
        
        row.value = row:CreateFontString(nil, "OVERLAY")
        row.value:SetFont(font, 9, "OUTLINE")
        row.value:SetPoint("RIGHT", 0, 0)
        row.value:SetTextColor(1, 1, 1)
        
        yOffset = yOffset - 16
        return row
    end
    
    local function CreateSpacer()
        yOffset = yOffset - 4
    end
    
    -- Basic section
    CreateSection("Basic", {r=pr, g=pg, b=pb})
    panel.health = CreateStatRow("Health")
    panel.power = CreateStatRow("Power")
    panel.ilvl = CreateStatRow("Item Level")
    CreateSpacer()
    
    -- Attributes section
    CreateSection("Attributes", {r=0.7, g=0.4, b=0.9})
    panel.str = CreateStatRow("Strength")
    panel.agi = CreateStatRow("Agility")
    panel.sta = CreateStatRow("Stamina")
    panel.int = CreateStatRow("Intellect")
    CreateSpacer()
    
    -- Secondary section
    CreateSection("Secondary", {r=0.7, g=0.4, b=0.9})
    panel.crit = CreateStatRow("Crit")
    panel.haste = CreateStatRow("Haste")
    panel.mastery = CreateStatRow("Mastery")
    panel.vers = CreateStatRow("Versatility")
    CreateSpacer()
    
    -- Attack section
    CreateSection("Attack", {r=0.7, g=0.4, b=0.9})
    panel.attackPower = CreateStatRow("Attack Power")
    panel.spellPower = CreateStatRow("Spell Power")
    panel.attackSpeed = CreateStatRow("Attack Speed")
    CreateSpacer()
    
    -- Defense section
    CreateSection("Defense", {r=0.7, g=0.4, b=0.9})
    panel.armor = CreateStatRow("Armor")
    panel.dodge = CreateStatRow("Dodge")
    panel.parry = CreateStatRow("Parry")
    panel.block = CreateStatRow("Block")
    CreateSpacer()
    
    -- General section
    CreateSection("General", {r=0.7, g=0.4, b=0.9})
    panel.leech = CreateStatRow("Leech")
    panel.speed = CreateStatRow("Speed")
    
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
    
    -- Basic
    local health = UnitHealthMax("player")
    local power = UnitPowerMax("player")
    statsPanel.health.value:SetText(BreakUpLargeNumbers(health))
    statsPanel.power.value:SetText(BreakUpLargeNumbers(power))
    
    local _, avgEquipped = GetAverageItemLevel()
    if avgEquipped then
        statsPanel.ilvl.value:SetText(math.floor(avgEquipped))
    end
    
    -- Attributes
    local str = UnitStat("player", 1)
    local agi = UnitStat("player", 2)
    local sta = UnitStat("player", 3)
    local int = UnitStat("player", 4)
    statsPanel.str.value:SetText(str)
    statsPanel.agi.value:SetText(agi)
    statsPanel.sta.value:SetText(sta)
    statsPanel.int.value:SetText(int)
    
    -- Secondary
    local crit = GetCritChance()
    local haste = GetHaste()
    local mastery = GetMasteryEffect()
    local vers = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)
    statsPanel.crit.value:SetText(string.format("%.2f%%", crit))
    statsPanel.haste.value:SetText(string.format("%.2f%%", haste))
    statsPanel.mastery.value:SetText(string.format("%.2f%%", mastery))
    statsPanel.vers.value:SetText(string.format("%.2f%%", vers))
    
    -- Attack
    local base, posBuff, negBuff = UnitAttackPower("player")
    local attackPower = base + posBuff + negBuff
    local spellPower = GetSpellBonusDamage(2)
    local attackSpeed = UnitAttackSpeed("player")
    statsPanel.attackPower.value:SetText(BreakUpLargeNumbers(attackPower))
    statsPanel.spellPower.value:SetText(BreakUpLargeNumbers(spellPower))
    if attackSpeed then
        statsPanel.attackSpeed.value:SetText(string.format("%.2fs", attackSpeed))
    end
    
    -- Defense
    local armor = select(2, UnitArmor("player"))
    local dodge = GetDodgeChance()
    local parry = GetParryChance()
    local block = GetBlockChance()
    statsPanel.armor.value:SetText(BreakUpLargeNumbers(armor))
    statsPanel.dodge.value:SetText(string.format("%.2f%%", dodge))
    statsPanel.parry.value:SetText(string.format("%.2f%%", parry))
    statsPanel.block.value:SetText(string.format("%.2f%%", block))
    
    -- General
    local leech = GetLifesteal()
    local speed = GetSpeed()
    statsPanel.leech.value:SetText(string.format("%.2f%%", leech or 0))
    statsPanel.speed.value:SetText(string.format("%.2f%%", speed or 0))
end

---------------------------------------------------------------------------
-- SETTINGS PANEL (FAR RIGHT)
---------------------------------------------------------------------------

local function CreateCheckbox(parent, label, setting, yOffset)
    local pr, pg, pb = GetThemeColors()
    local font = GetFont()
    
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(18, 18)
    check:SetPoint("TOPLEFT", 10, yOffset)
    check:SetChecked(CharacterPane.db.profile[setting])
    
    check.text = check:CreateFontString(nil, "OVERLAY")
    check.text:SetFont(font, 10, "OUTLINE")
    check.text:SetPoint("LEFT", check, "RIGHT", 4, 0)
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
    if not PaperDollFrame then return nil end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    local font = GetFont()
    
    local panel = CreateFrame("Frame", "AbstractUI_CharSettingsPanel", PaperDollFrame, "BackdropTemplate")
    panel:SetSize(240, 520)
    panel:SetPoint("TOPLEFT", PaperDollFrame, "TOPRIGHT", 152, -30)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(bgr, bgg, bgb, 0.7)
    panel:SetBackdropBorderColor(pr, pg, pb, pa)
    panel:SetFrameStrata("HIGH")
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFont(font, 11, "OUTLINE")
    title:SetPoint("TOP", 0, -8)
    title:SetText("QUI Character Panel")
    title:SetTextColor(pr, pg, pb)
    
    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(font, 9, "OUTLINE")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText("Settings")
    subtitle:SetTextColor(0.7, 0.7, 0.7)
    
    local yOffset = -46
    
    -- Appearance header
    local appearanceHeader = panel:CreateFontString(nil, "OVERLAY")
    appearanceHeader:SetFont(font, 10, "OUTLINE")
    appearanceHeader:SetPoint("TOPLEFT", 10, yOffset)
    appearanceHeader:SetText("Appearance")
    appearanceHeader:SetTextColor(pr, pg, pb)
    yOffset = yOffset - 18
    
    -- Slot Overlays section
    local slotHeader = panel:CreateFontString(nil, "OVERLAY")
    slotHeader:SetFont(font, 9, "OUTLINE")
    slotHeader:SetPoint("TOPLEFT", 10, yOffset)
    slotHeader:SetText("Slot Overlays")
    slotHeader:SetTextColor(0.8, 0.8, 0.8)
    yOffset = yOffset - 18
    
    CreateCheckbox(panel, "Show Equipment Name", "showEquipmentName", yOffset)
    yOffset = yOffset - 22
    
    CreateCheckbox(panel, "Show Item Level & Track", "showItemLevel", yOffset)
    yOffset = yOffset - 22
    
    CreateCheckbox(panel, "Show Enchant Status", "showEnchantStatus", yOffset)
    yOffset = yOffset - 22
    
    CreateCheckbox(panel, "Show Gem Indicators", "showGemIndicators", yOffset)
    yOffset = yOffset - 22
    
    CreateCheckbox(panel, "Show Durability Bars", "showDurabilityBars", yOffset)
    yOffset = yOffset - 28
    
    -- Stats Panel section
    local statsHeader = panel:CreateFontString(nil, "OVERLAY")
    statsHeader:SetFont(font, 9, "OUTLINE")
    statsHeader:SetPoint("TOPLEFT", 10, yOffset)
    statsHeader:SetText("Stats Panel")
    statsHeader:SetTextColor(0.8, 0.8, 0.8)
    yOffset = yOffset - 18
    
    CreateCheckbox(panel, "Show Stats Panel", "showStatsPanel", yOffset)
    yOffset = yOffset - 22
    
    CreateCheckbox(panel, "Show Stat Tooltips", "showStatTooltips", yOffset)
    yOffset = yOffset - 28
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(100, 22)
    resetBtn:SetPoint("BOTTOM", 0, 10)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function()
        CharacterPane.db.profile.showEquipmentName = true
        CharacterPane.db.profile.showItemLevel = true
        CharacterPane.db.profile.showEnchantStatus = true
        CharacterPane.db.profile.showGemIndicators = true
        CharacterPane.db.profile.showDurabilityBars = false
        CharacterPane.db.profile.showStatsPanel = true
        CharacterPane.db.profile.showStatTooltips = false
        CharacterPane:UpdateAll()
    end)
    
    settingsPanel = panel
    return panel
end

---------------------------------------------------------------------------
-- BACKGROUND AND DECORATION
---------------------------------------------------------------------------

local function HideBlizzardElements()
    -- Hide default equipment slot buttons
    for _, slotInfo in ipairs(EQUIPMENT_SLOTS) do
        local slotButton = _G["Character" .. slotInfo.name .. "Slot"]
        if slotButton then
            slotButton:Hide()
        end
    end
    
    -- Hide frame decorations
    if CharacterFramePortrait then CharacterFramePortrait:Hide() end
    if CharacterFrame.Background then CharacterFrame.Background:Hide() end
    if CharacterFrame.NineSlice then CharacterFrame.NineSlice:Hide() end
    if CharacterLevelText then CharacterLevelText:Hide() end
    if CharacterFrameTitleText then CharacterFrameTitleText:SetText("") end
    
    -- Keep model visible
    if CharacterModelScene then CharacterModelScene:Show() end
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
    
    -- Create ilvl display at top
    CreateIlvlDisplay()
    
    -- Create equipment labels on left side
    for index, slotInfo in ipairs(EQUIPMENT_SLOTS) do
        if not equipmentLabels[slotInfo.id] then
            local label = CreateEquipmentLabel(PaperDollFrame, slotInfo, index - 1)
            equipmentLabels[slotInfo.id] = label
        end
    end
    
    -- Create stats panel on right
    CreateStatsPanel()
    
    -- Create settings panel on far right
    CreateSettingsPanel()
    
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
    
    UpdateIlvlDisplay()
    
    for slotId, label in pairs(equipmentLabels) do
        UpdateEquipmentLabel(label)
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
        statsPanel:SetBackdropColor(bgr, bgg, bgb, 0.7)
        statsPanel:SetBackdropBorderColor(pr, pg, pb, pa)
        if statsPanel.title then
            statsPanel.title:SetTextColor(pr, pg, pb)
        end
    end
    
    if settingsPanel then
        settingsPanel:SetBackdropColor(bgr, bgg, bgb, 0.7)
        settingsPanel:SetBackdropBorderColor(pr, pg, pb, pa)
    end
    
    self:UpdateAll()
end
