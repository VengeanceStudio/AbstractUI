local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local CharacterPane = AbstractUI:NewModule("CharacterPane", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

---------------------------------------------------------------------------
-- CHARACTER PANEL CUSTOMIZATION
-- Equipment overlays (ilvl, enchants, gems) and custom stats panel
---------------------------------------------------------------------------

-- Equipment slot configuration
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
local equipmentRows = {}
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
-- EQUIPMENT ROWS (LEFT AND RIGHT SIDES)
---------------------------------------------------------------------------

local function CreateEquipmentRow(parent, slotInfo, yOffset, side)
    local pr, pg, pb = GetThemeColors()
    local font = GetFont()
    
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(300, 32)
    
    if side == "left" then
        row:SetPoint("TOPLEFT", 5, yOffset)
    else
        row:SetPoint("TOPRIGHT", -5, yOffset)
    end
    
    -- Item icon (clickable to match Blizzard behavior)
    row.icon = CreateFrame("Button", nil, row)
    row.icon:SetSize(32, 32)
    
    if side == "left" then
        row.icon:SetPoint("LEFT", 0, 0)
    else
        row.icon:SetPoint("RIGHT", 0, 0)
    end
    
    row.icon.texture = row.icon:CreateTexture(nil, "ARTWORK")
    row.icon.texture:SetAllPoints()
    row.icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Link icon to actual slot for clicks
    local slotButton = _G["Character" .. slotInfo.name .. "Slot"]
    if slotButton then
        row.icon:SetScript("OnClick", function(self, button)
            slotButton:Click(button)
        end)
        row.icon:SetScript("OnEnter", function(self)
            slotButton:GetScript("OnEnter")(slotButton)
        end)
        row.icon:SetScript("OnLeave", function(self)
            slotButton:GetScript("OnLeave")(slotButton)
        end)
    end
    
    -- Item name
    row.itemName = row:CreateFontString(nil, "OVERLAY")
    row.itemName:SetFont(font, 10, "OUTLINE")
    row.itemName:SetWordWrap(false)
    
    if side == "left" then
        row.itemName:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.itemName:SetPoint("RIGHT", -80, 0)
        row.itemName:SetJustifyH("LEFT")
    else
        row.itemName:SetPoint("RIGHT", row.icon, "LEFT", -6, 0)
        row.itemName:SetPoint("LEFT", 80, 0)
        row.itemName:SetJustifyH("RIGHT")
    end
    
    -- Item level
    row.ilvl = row:CreateFontString(nil, "OVERLAY")
    row.ilvl:SetFont(font, 9, "OUTLINE")
    row.ilvl:SetTextColor(1, 0.82, 0) -- Gold
    
    if side == "left" then
        row.ilvl:SetPoint("RIGHT", -2, 0)
        row.ilvl:SetJustifyH("RIGHT")
    else
        row.ilvl:SetPoint("LEFT", 2, 0)
        row.ilvl:SetJustifyH("LEFT")
    end
    
    -- Status (enchant/gem)
    row.status = row:CreateFontString(nil, "OVERLAY")
    row.status:SetFont(font, 9, "OUTLINE")
    
    if side == "left" then
        row.status:SetPoint("BOTTOMLEFT", row.itemName, "BOTTOMLEFT", 0, -14)
        row.status:SetJustifyH("LEFT")
    else
        row.status:SetPoint("BOTTOMRIGHT", row.itemName, "BOTTOMRIGHT", 0, -14)
        row.status:SetJustifyH("RIGHT")
    end
    
    row.slotInfo = slotInfo
    row.side = side
    return row
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
        row.icon.texture:SetTexture(nil)
        row.itemName:SetText("")
        row.ilvl:SetText("")
        row.status:SetText("")
        row:SetHeight(32)
        return
    end
    
    row:Show()
    
    -- Item icon
    local icon = C_Item.GetItemIconByID(itemLink)
    if icon then
        row.icon.texture:SetTexture(icon)
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
    
    -- Item level with upgrade track
    if settings.showItemLevel then
        local ilvl = GetItemLevel(slotId)
        if ilvl then
            -- Try to get upgrade track info from tooltip
            local trackText = tostring(ilvl)
            
            if C_TooltipInfo then
                local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotId)
                if tooltipData and tooltipData.lines then
                    for _, line in ipairs(tooltipData.lines) do
                        local text = line.leftText or ""
                        -- Look for patterns like "Champion 1/6" or "Hero 1/6"
                        local track, current, max = text:match("(Hero%s+)(%d+)/(%d+)")
                        if not track then
                            track, current, max = text:match("(Champion%s+)(%d+)/(%d+)")
                        end
                        if not track then
                            track, current, max = text:match("(Adventurer%s+)(%d+)/(%d+)")
                        end
                        
                        if track and current and max then
                            trackText = string.format("%d (%s%s/%s)", ilvl, track, current, max)
                            break
                        end
                    end
                end
            end
            
            row.ilvl:SetText(trackText)
        else
            row.ilvl:SetText("")
        end
    else
        row.ilvl:SetText("")
    end
    
    -- Enchant status or gem count
    local statusText = ""
    local statusColor = {r=1, g=1, b=1}
    local hasStatus = false
    
    if settings.showEnchantStatus then
        local enchant, isEnchantable = GetEnchantInfo(slotId)
        if isEnchantable and not enchant then
            statusText = "No Enchant"
            statusColor = {r=1, g=0, b=0} -- Red
            hasStatus = true
        elseif isEnchantable and enchant then
            statusText = enchant
            statusColor = {r=0, g=1, b=0} -- Green
            hasStatus = true
        end
    end
    
    if settings.showGemIndicators and statusText == "" then
        local gemCount = GetGemCount(slotId)
        if gemCount > 0 then
            statusText = "◆" .. gemCount
            statusColor = {r=0.8, g=0.5, b=1} -- Purple
            hasStatus = true
        end
    end
    
    row.status:SetText(statusText)
    row.status:SetTextColor(statusColor.r, statusColor.g, statusColor.b)
    
    -- Adjust row height if we have status text
    if hasStatus then
        row:SetHeight(46)
    else
        row:SetHeight(32)
    end
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
    panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", -30, -30)
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
    
    local panel = CreateFrame("Frame", "AbstractUI_CharSettingsPanel", CharacterFrame, "BackdropTemplate")
    panel:SetSize(240, 520)
    panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 152, -30)
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
    title:SetText("AbstractUI Character Panel")
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
-- HIDE ALL BLIZZARD ELEMENTS
---------------------------------------------------------------------------

local function HideBlizzardElements()
    -- Hide ALL equipment slot buttons completely
    for _, slotInfo in ipairs(EQUIPMENT_SLOTS) do
        local slotButton = _G["Character" .. slotInfo.name .. "Slot"]
        if slotButton then
            slotButton:Hide()
            slotButton:SetAlpha(0)
            slotButton:EnableMouse(false)
            
            -- Hide all textures and regions
            for i = 1, slotButton:GetNumRegions() do
                local region = select(i, slotButton:GetRegions())
                if region and region.Hide then
                    region:Hide()
                end
            end
        end
    end
    
    -- Hide all frame decorations and default UI
    if CharacterFramePortrait then CharacterFramePortrait:Hide() end
    if CharacterFrame.Background then CharacterFrame.Background:Hide() end
    if CharacterFrame.NineSlice then CharacterFrame.NineSlice:Hide() end
    if CharacterFrame.Inset then CharacterFrame.Inset:Hide() end
    if CharacterFrame.InsetBg then CharacterFrame.InsetBg:Hide() end
    if CharacterFrame.CloseButton then CharacterFrame.CloseButton:ClearAllPoints(); CharacterFrame.CloseButton:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -5, -5) end
    if CharacterLevelText then CharacterLevelText:Hide() end
    if CharacterFrameTitleText then CharacterFrameTitleText:Hide() end
    
    -- Hide PaperDoll specific elements
    if PaperDollSidebarTabs then PaperDollSidebarTabs:Hide() end
    if PaperDollFrame.TitleBg then PaperDollFrame.TitleBg:Hide() end
    if PaperDollFrame.Bg then PaperDollFrame.Bg:Hide() end
    
    -- Hide the item level/stats display in the center
    if PaperDollItemsFrame then PaperDollItemsFrame:Hide() end
    if CharacterStatsPane then CharacterStatsPane:Hide() end
    
    -- Hide character name text
    if CharacterNameText then CharacterNameText:Hide() end
    
    -- Hide equipment manager and flyout
    if PaperDollEquipmentManagerPane then PaperDollEquipmentManagerPane:Hide() end
    if EquipmentFlyoutFrame then EquipmentFlyoutFrame:Hide() end
    
    -- Hide any remaining background textures
    for i = 1, PaperDollFrame:GetNumRegions() do
        local region = select(i, PaperDollFrame:GetRegions())
        if region and region:GetObjectType() == "Texture" then
            region:Hide()
        end
    end
    
    -- Hide all child frames of PaperDollFrame except model and our custom elements
    for _, child in pairs({PaperDollFrame:GetChildren()}) do
        if child ~= CharacterModelScene and not child:GetName():match("AbstractUI") then
            child:Hide()
        end
    end
    
    -- Keep only the character model and bottom tabs
    if CharacterModelScene then 
        CharacterModelScene:Show()
        CharacterModelScene:ClearAllPoints()
        CharacterModelScene:SetPoint("CENTER", PaperDollFrame, "CENTER", 0, 20)
        CharacterModelScene:SetSize(300, 400)
        
        -- Hide model scene background
        if CharacterModelScene.BackgroundOverlay then
            CharacterModelScene.BackgroundOverlay:Hide()
        end
    end
    
    -- Keep bottom tab buttons visible
    if CharacterFrameTab1 then CharacterFrameTab1:Show() end
    if CharacterFrameTab2 then CharacterFrameTab2:Show() end
    if CharacterFrameTab3 then CharacterFrameTab3:Show() end
    if CharacterFrameTab4 then CharacterFrameTab4:Show() end
end

local function CreateBackground()
    if not CharacterFrame then return end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    
    if not customBg then
        customBg = CreateFrame("Frame", "AbstractUI_CharBg", PaperDollFrame, "BackdropTemplate")
        customBg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
        })
        customBg:SetFrameStrata("BACKGROUND")
        customBg:SetFrameLevel(0)
        customBg:EnableMouse(false)
        customBg:SetAllPoints(PaperDollFrame)
    end
    
    customBg:SetBackdropColor(bgr, bgg, bgb, bga)
    customBg:SetBackdropBorderColor(pr, pg, pb, pa)
    customBg:Show()
    
    HideBlizzardElements()
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
    HideBlizzardElements()
    
    -- Create ilvl display at top
    CreateIlvlDisplay()
    
    -- Define which slots go on which side
    local leftSlots = {
        {slot = EQUIPMENT_SLOTS[1], offset = -50},   -- Head
        {slot = EQUIPMENT_SLOTS[2], offset = -90},   -- Neck
        {slot = EQUIPMENT_SLOTS[3], offset = -130},  -- Shoulder
        {slot = EQUIPMENT_SLOTS[4], offset = -170},  -- Back
        {slot = EQUIPMENT_SLOTS[5], offset = -210},  -- Chest
        {slot = EQUIPMENT_SLOTS[6], offset = -250},  -- Wrist
    }
    
    local rightSlots = {
        {slot = EQUIPMENT_SLOTS[7], offset = -50},   -- Hands
        {slot = EQUIPMENT_SLOTS[8], offset = -90},   -- Waist
        {slot = EQUIPMENT_SLOTS[9], offset = -130},  -- Legs
        {slot = EQUIPMENT_SLOTS[10], offset = -170}, -- Feet
        {slot = EQUIPMENT_SLOTS[11], offset = -210}, -- Ring 1
        {slot = EQUIPMENT_SLOTS[12], offset = -250}, -- Ring 2
        {slot = EQUIPMENT_SLOTS[13], offset = -290}, -- Trinket 1
        {slot = EQUIPMENT_SLOTS[14], offset = -330}, -- Trinket 2
    }
    
    local bottomSlots = {
        {slot = EQUIPMENT_SLOTS[15], offset = -410}, -- Main Hand (left side)
        {slot = EQUIPMENT_SLOTS[16], offset = -410}, -- Off Hand (right side)
    }
    
    -- Create equipment rows on left side
    for _, data in ipairs(leftSlots) do
        if not equipmentRows[data.slot.id] then
            local row = CreateEquipmentRow(PaperDollFrame, data.slot, data.offset, "left")
            equipmentRows[data.slot.id] = row
        end
    end
    
    -- Create equipment rows on right side
    for _, data in ipairs(rightSlots) do
        if not equipmentRows[data.slot.id] then
            local row = CreateEquipmentRow(PaperDollFrame, data.slot, data.offset, "right")
            equipmentRows[data.slot.id] = row
        end
    end
    
    -- Create bottom weapon rows
    if not equipmentRows[INVSLOT_MAINHAND] then
        local row = CreateEquipmentRow(PaperDollFrame, EQUIPMENT_SLOTS[15], -410, "left")
        equipmentRows[INVSLOT_MAINHAND] = row
    end
    
    if not equipmentRows[INVSLOT_OFFHAND] then
        local row = CreateEquipmentRow(PaperDollFrame, EQUIPMENT_SLOTS[16], -410, "right")
        equipmentRows[INVSLOT_OFFHAND] = row
    end
    
    -- Create stats panel on right
    CreateStatsPanel()
    
    -- Create settings panel on far right
    CreateSettingsPanel()
    
    -- Hook frame events
    CharacterFrame:HookScript("OnShow", function()
        if IsEnabled() then
            CreateBackground()
            HideBlizzardElements()
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
    
    for slotId, row in pairs(equipmentRows) do
        UpdateEquipmentRow(row)
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
