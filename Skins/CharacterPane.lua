local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local CharacterPane = AbstractUI:NewModule("CharacterPane", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

---------------------------------------------------------------------------
-- CHARACTER PANEL CUSTOMIZATION
-- Equipment overlays (ilvl, enchants, gems) and custom stats panel
---------------------------------------------------------------------------

-- Equipment slot configuration (with positioning)
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
-- EQUIPMENT SLOT OVERLAYS
---------------------------------------------------------------------------

local function CreateSlotOverlay(slotButton, slotInfo)
    if not slotButton then return nil end
    
    local pr, pg, pb = GetThemeColors()
    local font = GetFont()
    
    local overlay = CreateFrame("Frame", nil, slotButton)
    overlay:SetAllPoints(slotButton)
    overlay:SetFrameLevel(slotButton:GetFrameLevel() + 5)
    
    -- Item name text
    overlay.itemName = overlay:CreateFontString(nil, "OVERLAY")
    overlay.itemName:SetFont(font, 11, "OUTLINE")
    overlay.itemName:SetWordWrap(false)
    
    -- Item level and track text
    overlay.ilvlTrack = overlay:CreateFontString(nil, "OVERLAY")
    overlay.ilvlTrack:SetFont(font, 10, "OUTLINE")
    overlay.ilvlTrack:SetTextColor(1, 0.82, 0) -- Gold
    
    -- Enchant/gem status text
    overlay.status = overlay:CreateFontString(nil, "OVERLAY")
    overlay.status:SetFont(font, 10, "OUTLINE")
    
    -- Position based on slot side
    if slotInfo.side == "left" then
        overlay.itemName:SetPoint("LEFT", overlay, "RIGHT", 6, 8)
        overlay.itemName:SetJustifyH("LEFT")
        overlay.ilvlTrack:SetPoint("LEFT", overlay, "RIGHT", 6, -8)
        overlay.ilvlTrack:SetJustifyH("LEFT")
        overlay.status:SetPoint("LEFT", overlay.ilvlTrack, "RIGHT", 4, 0)
    elseif slotInfo.side == "right" then
        overlay.itemName:SetPoint("RIGHT", overlay, "LEFT", -6, 8)
        overlay.itemName:SetJustifyH("RIGHT")
        overlay.ilvlTrack:SetPoint("RIGHT", overlay, "LEFT", -6, -8)
        overlay.ilvlTrack:SetJustifyH("RIGHT")
        overlay.status:SetPoint("RIGHT", overlay.ilvlTrack, "LEFT", -4, 0)
    else -- bottom (weapons)
        overlay.itemName:SetPoint("LEFT", overlay, "RIGHT", 6, 10)
        overlay.itemName:SetJustifyH("LEFT")
        overlay.ilvlTrack:SetPoint("LEFT", overlay, "RIGHT", 6, -6)
        overlay.ilvlTrack:SetJustifyH("LEFT")
        overlay.status:SetPoint("LEFT", overlay.ilvlTrack, "RIGHT", 4, 0)
    end
    
    overlay.slotInfo = slotInfo
    return overlay
end

local function UpdateSlotOverlay(overlay)
    if not overlay or not overlay.slotInfo then return end
    if not IsEnabled() then
        overlay.itemName:SetText("")
        overlay.ilvlTrack:SetText("")
        overlay.status:SetText("")
        return
    end
    
    local settings = CharacterPane.db.profile
    local slotId = overlay.slotInfo.id
    local itemLink = GetInventoryItemLink("player", slotId)
    
    if not itemLink then
        overlay.itemName:SetText("")
        overlay.ilvlTrack:SetText("")
        overlay.status:SetText("")
        return
    end
    
    -- Item name with quality color
    if settings.showEquipmentName then
        local itemName, _, quality = C_Item.GetItemInfo(itemLink)
        if itemName then
            local r, g, b = GetQualityColor(quality)
            overlay.itemName:SetText(itemName)
            overlay.itemName:SetTextColor(r, g, b)
        end
    else
        overlay.itemName:SetText("")
    end
    
    -- Item level and upgrade track
    if settings.showItemLevel then
        local ilvl = GetItemLevel(slotId)
        if ilvl then
            overlay.ilvlTrack:SetText(tostring(ilvl))
        else
            overlay.ilvlTrack:SetText("")
        end
    else
        overlay.ilvlTrack:SetText("")
    end
    
    -- Enchant status or gem count
    local statusText = ""
    local statusColor = {r=1, g=1, b=1}
    
    if settings.showEnchantStatus then
        local enchant, isEnchantable = GetEnchantInfo(slotId)
        if isEnchantable and not enchant then
            statusText = "No Enchant"
            statusColor = {r=1, g=0, b=0} -- Red
        elseif isEnchantable and enchant then
            statusText = enchant
            statusColor = {r=0, g=1, b=0} -- Green
        end
    end
    
    if settings.showGemIndicators and statusText == "" then
        local gemCount = GetGemCount(slotId)
        if gemCount > 0 then
            statusText = "◆" .. gemCount
            statusColor = {r=0.8, g=0.5, b=1} -- Purple
        end
    end
    
    overlay.status:SetText(statusText)
    overlay.status:SetTextColor(statusColor.r, statusColor.g, statusColor.b)
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
    -- Hide frame decorations but KEEP equipment slots visible
    if CharacterFramePortrait then CharacterFramePortrait:Hide() end
    if CharacterFrame.Background then CharacterFrame.Background:Hide() end
    if CharacterFrame.NineSlice then CharacterFrame.NineSlice:Hide() end
    if CharacterLevelText then CharacterLevelText:Hide() end
    if CharacterFrameTitleText then CharacterFrameTitleText:SetText("") end
    
    -- Keep model and equipment slots visible
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
    
    for slotId, overlay in pairs(slotOverlays) do
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
