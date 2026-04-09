-- AbstractUI Consumables Module
-- Tracks missing buffs and consumables on the player
-- Based on ConsumableWatcher implementation

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local Consumables = AbstractUI:NewModule("Consumables", "AceEvent-3.0")

-- Cache framework systems
local FrameFactory, ColorPalette, FontKit

-- Module frames
local trackerFrame
local globalTextLine
local iconGroups = {}

-- State tracking
local readyCheckTimer = nil
local textJumpAnimation = nil
local lastUpdate = 0
local THROTTLE = 0.2

-- Database defaults
local defaults = {
    profile = {
        enabled = true,
        showSolo = false,
        textSize = 14,
        iconSize = 64,
        iconSpacing = 10,
        position = {
            point = "CENTER",
            x = 0,
            y = 0,
        },
    }
}

-- Buff/consumable groups to track
local BUFF_GROUPS = {
    {
        id = "mainhand_enchant",
        icon = 7548987,
        label = "Main Hand Enchant MISSING!",
        checkFunc = function()
            local hasMain = GetWeaponEnchantInfo()
            return not hasMain
        end,
    },
    {
        id = "offhand_enchant",
        icon = 3622196,
        label = "Offhand Enchant MISSING!",
        checkFunc = function()
            local _, _, _, _, hasOff = GetWeaponEnchantInfo()
            local itemID = GetInventoryItemID("player", 17)
            if not itemID then return false end
            local classID = select(6, GetItemInfoInstant(itemID))
            local isWeapon = (classID == 2) -- 2 == Weapon
            return isWeapon and not hasOff
        end,
    },
    {
        id = "flask",
        icon = 7548903,
        label = "Flask MISSING!",
        spells = { 46376, 1235110, 1235111, 1235057, 1235108 },
        checkFunc = function(self)
            return not Consumables:HasBuffBySpellIDs(self.spells)
        end,
    },
    {
        id = "food",
        icon = 136000,
        label = "Food Buff MISSING!",
        checkFunc = function()
            return not Consumables:HasFoodBuff()
        end,
    },
    {
        id = "mainhand_poison",
        icon = 136066,
        label = "Main Hand Poison MISSING!",
        spells = { 315584, 8679 },
        requireClass = "ROGUE",
        checkFunc = function(self)
            local _, playerClass = UnitClass("player")
            if playerClass ~= "ROGUE" then return false end
            return not Consumables:HasBuffBySpellIDs(self.spells)
        end,
    },
    {
        id = "offhand_poison",
        icon = 136066,
        label = "Offhand Poison MISSING!",
        spells = { 3408, 5761 },
        requireClass = "ROGUE",
        checkFunc = function(self)
            local _, playerClass = UnitClass("player")
            if playerClass ~= "ROGUE" then return false end
            local itemID = GetInventoryItemID("player", 17)
            if not itemID then return false end
            local classID = select(6, GetItemInfoInstant(itemID))
            local isWeapon = (classID == 2)
            return isWeapon and not Consumables:HasBuffBySpellIDs(self.spells)
        end,
    },
    {
        id = "healthstone",
        icon = 538745,
        label = "Healthstone MISSING!",
        itemIDs = { 5512, 224464 },
        checkFunc = function(self)
            if not Consumables:GroupHasWarlock() then return false end
            return not Consumables:PlayerHasHealthstone(self.itemIDs)
        end,
    },
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function Consumables:OnInitialize()
    self:RegisterMessage("AbstractUI_DB_READY", "OnDBReady")
end

function Consumables:OnDBReady()
    if not AbstractUI.db or not AbstractUI.db.profile or not AbstractUI.db.profile.modules then
        self:Disable()
        return
    end
    
    -- Register namespace with defaults
    self.db = AbstractUI.db:RegisterNamespace("Consumables", defaults)
    
    -- Cache framework systems
    FrameFactory = AbstractUI.FrameFactory
    ColorPalette = _G.AbstractUI_ColorPalette
    FontKit = AbstractUI.FontKit
    
    -- Only initialize if module is enabled
    if AbstractUI.db.profile.modules.consumables then
        self:CreateTrackerFrame()
        self:RegisterEvents()
        self:RegisterSlashCommands()
    end
end

function Consumables:OnEnable()
    if trackerFrame then
        self:UpdateBuffStatus()
    end
end

function Consumables:OnDisable()
    if trackerFrame then
        trackerFrame:Hide()
    end
    self:UnregisterAllEvents()
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

function Consumables:CreateTrackerFrame()
    if trackerFrame then return end
    
    local iconSize = self.db.profile.iconSize
    local spacing = self.db.profile.iconSpacing
    local frameWidth = (#BUFF_GROUPS * iconSize) + ((#BUFF_GROUPS - 1) * spacing)
    
    -- Main tracker frame
    trackerFrame = CreateFrame("Frame", "AbstractUI_ConsumablesFrame", UIParent)
    trackerFrame:SetSize(frameWidth, iconSize)
    trackerFrame:SetFrameStrata("HIGH")
    trackerFrame:SetMovable(true)
    trackerFrame:EnableMouse(true)
    trackerFrame:RegisterForDrag("LeftButton")
    trackerFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    trackerFrame:SetScript("OnDragStop", function(self) 
        self:StopMovingOrSizing()
        Consumables:SavePosition()
    end)
    trackerFrame:Hide()
    
    -- Restore saved position
    local pos = self.db.profile.position
    trackerFrame:ClearAllPoints()
    trackerFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    
    -- Create icon groups for each buff/consumable
    for i, group in ipairs(BUFF_GROUPS) do
        local iconFrame = CreateFrame("Frame", nil, trackerFrame)
        iconFrame:SetSize(iconSize, iconSize)
        iconFrame:SetPoint("LEFT", trackerFrame, "LEFT", (i - 1) * (iconSize + spacing), 0)
        
        -- Icon texture
        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(group.icon)
        
        -- Border
        local border = iconFrame:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\WHITE8X8")
        border:SetAllPoints()
        border:SetVertexColor(1, 0, 0, 0.3)
        
        iconGroups[i] = {
            frame = iconFrame,
            icon = icon,
            border = border,
            data = group,
        }
    end
    
    -- Global text line (below icons)
    globalTextLine = trackerFrame:CreateFontString(nil, "OVERLAY")
    globalTextLine:SetFont(STANDARD_TEXT_FONT, self.db.profile.textSize, "OUTLINE")
    globalTextLine:SetPoint("TOP", trackerFrame, "BOTTOM", 0, -10)
    globalTextLine:SetTextColor(1, 0, 0, 1)
    globalTextLine:SetText("")
    
    -- Create jump animation for text
    self:CreateJumpAnimation()
end

function Consumables:CreateJumpAnimation()
    if not globalTextLine then return end
    
    textJumpAnimation = globalTextLine:CreateAnimationGroup()
    textJumpAnimation:SetLooping("REPEAT")
    
    local up = textJumpAnimation:CreateAnimation("Translation")
    up:SetOrder(1)
    up:SetDuration(0.12)
    up:SetOffset(0, 18)
    up:SetSmoothing("OUT")
    
    local down = textJumpAnimation:CreateAnimation("Translation")
    down:SetOrder(2)
    down:SetDuration(0.18)
    down:SetOffset(0, -22)
    down:SetSmoothing("IN")
    
    local settle = textJumpAnimation:CreateAnimation("Translation")
    settle:SetOrder(3)
    settle:SetDuration(0.10)
    settle:SetOffset(0, 4)
    settle:SetSmoothing("OUT")
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

function Consumables:RegisterEvents()
    self:RegisterEvent("READY_CHECK")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED")
end

function Consumables:READY_CHECK()
    self:UpdateBuffStatus()
    if trackerFrame then
        trackerFrame:Show()
    end
    
    -- Auto-hide after 20 seconds
    if readyCheckTimer then
        readyCheckTimer:Cancel()
    end
    readyCheckTimer = C_Timer.NewTimer(20, function()
        if trackerFrame then
            trackerFrame:Hide()
        end
        readyCheckTimer = nil
    end)
end

function Consumables:UNIT_AURA(event, unit)
    if unit == "player" then
        self:ThrottledUpdate()
    end
end

function Consumables:UNIT_INVENTORY_CHANGED(event, unit)
    if unit == "player" then
        self:ThrottledUpdate()
    end
end

function Consumables:ThrottledUpdate()
    local now = GetTime()
    if now - lastUpdate >= THROTTLE then
        lastUpdate = now
        self:UpdateBuffStatus()
    end
end

-- ============================================================================
-- BUFF CHECKING FUNCTIONS
-- ============================================================================

function Consumables:ForEachAuraSafe(unit, filter, maxCount, func)
    if not AuraUtil or not AuraUtil.ForEachAura then return end
    pcall(function()
        AuraUtil.ForEachAura(unit, filter, maxCount, function(...)
            local name, _, _, _, _, _, _, _, _, spellId = ...
            if func({ name = name, spellId = spellId }) then
                return true
            end
        end)
    end)
end

function Consumables:HasBuffBySpellIDs(spellIDs)
    local found = false
    self:ForEachAuraSafe("player", "HELPFUL", nil, function(aura)
        for _, id in ipairs(spellIDs) do
            if aura.spellId == id then
                found = true
                return true
            end
        end
    end)
    return found
end

function Consumables:HasFoodBuff()
    local found = false
    self:ForEachAuraSafe("player", "HELPFUL", nil, function(aura)
        if aura.name and aura.name:find("Well Fed") then
            found = true
            return true
        end
    end)
    return found
end

function Consumables:PlayerHasHealthstone(itemIDs)
    for _, id in ipairs(itemIDs) do
        if GetItemCount(id, true) > 0 then
            return true
        end
    end
    return false
end

function Consumables:GroupHasWarlock()
    local _, class = UnitClass("player")
    if class == "WARLOCK" then return true end
    
    local num = GetNumGroupMembers()
    if num == 0 then return false end
    
    local inRaid = IsInRaid()
    local prefix = inRaid and "raid" or "party"
    local maxIndex = inRaid and num or (num - 1)
    
    for i = 1, maxIndex do
        local unit = prefix .. i
        if UnitExists(unit) then
            local _, c = UnitClass(unit)
            if c == "WARLOCK" then return true end
        end
    end
    return false
end

-- ============================================================================
-- UPDATE DISPLAY
-- ============================================================================

function Consumables:UpdateBuffStatus()
    if not trackerFrame or InCombatLockdown() then
        if trackerFrame then
            trackerFrame:Hide()
        end
        self:StopJumpAnimation()
        return
    end
    
    local missingLabels = {}
    local anyMissing = false
    
    -- Check each buff group
    for i, iconGroup in ipairs(iconGroups) do
        local group = iconGroup.data
        local isMissing = group.checkFunc(group)
        
        if isMissing then
            iconGroup.frame:Show()
            table.insert(missingLabels, group.label)
            anyMissing = true
        else
            iconGroup.frame:Hide()
        end
    end
    
    -- Update global text
    if #missingLabels > 0 then
        globalTextLine:SetText(table.concat(missingLabels, ", "))
        self:PlayJumpAnimation()
    else
        globalTextLine:SetText("")
        self:StopJumpAnimation()
    end
    
    -- Update frame visibility
    if trackerFrame:IsShown() and not anyMissing then
        -- Keep visible during ready check even if nothing missing
        -- Will auto-hide when timer expires
    end
end

function Consumables:PlayJumpAnimation()
    if textJumpAnimation and not textJumpAnimation:IsPlaying() then
        textJumpAnimation:Play()
    end
end

function Consumables:StopJumpAnimation()
    if textJumpAnimation and textJumpAnimation:IsPlaying() then
        textJumpAnimation:Stop()
        if globalTextLine then
            globalTextLine:SetPoint("TOP", trackerFrame, "BOTTOM", 0, -10)
        end
    end
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

function Consumables:RegisterSlashCommands()
    SLASH_ABSCONSUMABLES1 = "/absconsumables"
    SLASH_ABSCONSUMABLES2 = "/abscon"
    SlashCmdList.ABSCONSUMABLES = function(msg)
        msg = string.lower(string.trim(msg))
        
        if msg == "show" then
            if trackerFrame then
                self:UpdateBuffStatus()
                trackerFrame:Show()
                self:Print("Consumables tracker shown")
            end
        elseif msg == "hide" then
            if trackerFrame then
                trackerFrame:Hide()
                self:Print("Consumables tracker hidden")
            end
        elseif msg == "toggle" then
            if trackerFrame then
                if trackerFrame:IsShown() then
                    trackerFrame:Hide()
                else
                    self:UpdateBuffStatus()
                    trackerFrame:Show()
                end
            end
        elseif msg == "reset" then
            self:ResetPosition()
            self:Print("Position reset to center")
        else
            self:Print("Consumables Commands:")
            self:Print("/abscon show - Show tracker")
            self:Print("/abscon hide - Hide tracker")
            self:Print("/abscon toggle - Toggle visibility")
            self:Print("/abscon reset - Reset position")
        end
    end
end

-- ============================================================================
-- POSITION MANAGEMENT
-- ============================================================================

function Consumables:SavePosition()
    if not trackerFrame then return end
    
    local point, _, relativePoint, x, y = trackerFrame:GetPoint()
    self.db.profile.position = {
        point = point,
        x = x,
        y = y,
    }
end

function Consumables:ResetPosition()
    if not trackerFrame then return end
    
    self.db.profile.position = {
        point = "CENTER",
        x = 0,
        y = 0,
    }
    
    trackerFrame:ClearAllPoints()
    trackerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end
