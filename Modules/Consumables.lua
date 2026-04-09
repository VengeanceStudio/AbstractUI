-- AbstractUI Consumables Module
-- Tracks missing buffs and consumables on the player
-- Based on ConsumableWatcher implementation

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local Consumables = AbstractUI:NewModule("Consumables", "AceEvent-3.0")

-- Cache framework systems
local FrameFactory, ColorPalette, FontKit

-- Module frames
local trackerFrame
local iconGroups = {}

-- State tracking
local readyCheckTimer = nil
local lastUpdate = 0
local THROTTLE = 0.2

-- Reference to ScrollFrame (will be initialized after DB is ready)
local ScrollFrame

-- Database defaults
local defaults = {
    profile = {
        enabled = true,
        textSize = 14,
        iconSize = 64,
        iconSpacing = 10,
        position = {
            point = "CENTER",
            x = 0,
            y = 0,
        },
        -- Individual buff tracking toggles
        trackBuffs = {
            weapon_imbues = true,  -- Tracks both main hand and offhand
            flask = true,
            food = true,
            mainhand_poison = true,
            offhand_poison = true,
            healthstone = true,
            augment_rune = true,
        },
        -- Custom icons and labels for each buff type
        customization = {
            weapon_imbue_mainhand = { icon = 7548987, label = "Main Hand" },
            weapon_imbue_offhand = { icon = 3622196, label = "Off Hand" },
            flask = { icon = 7548903, label = "Flask!" },
            food = { icon = 136000, label = "Food!" },
            mainhand_poison = { icon = 136066, label = "MH Poison" },
            offhand_poison = { icon = 136066, label = "OH Poison" },
            healthstone = { icon = 538745, label = "Healthstone" },
            augment_rune = { icon = 237556, label = "Augment Rune" },
        },
        -- Context-based display options
        showInContext = {
            world = false,          -- Open world
            delves = true,          -- Delves
            normalDungeon = false,  -- Normal dungeons
            heroicDungeon = false,  -- Heroic dungeons
            mythicDungeon = true,   -- Mythic/M+ dungeons
            normalRaid = false,     -- Normal raids
            heroicRaid = true,      -- Heroic raids
            mythicRaid = true,      -- Mythic raids
            lfr = false,            -- LFR
            pvp = false,            -- PvP (Arenas/BGs)
        },
        alwaysShowOnReadyCheck = true,  -- Override context and always show on ready check
    }
}

-- Buff/consumable groups to track
local BUFF_GROUPS = {
    {
        id = "weapon_imbue_mainhand",
        icon = 7548987,
        label = "Main Hand",
        checkFunc = function()
            local hasMain = GetWeaponEnchantInfo()
            return not hasMain
        end,
    },
    {
        id = "weapon_imbue_offhand",
        icon = 3622196,
        label = "Off Hand",
        checkFunc = function()
            -- Check if offhand weapon exists first
            local itemID = GetInventoryItemID("player", 17)
            if not itemID then return false end  -- No offhand item
            local classID = select(6, GetItemInfoInstant(itemID))
            local isWeapon = (classID == 2) -- 2 == Weapon
            if not isWeapon then return false end  -- Not a weapon (shield, etc.)
            
            -- Now check imbue status
            local _, _, _, _, hasOff = GetWeaponEnchantInfo()
            return not hasOff
        end,
    },
    {
        id = "flask",
        icon = 7548903,
        label = "Flask!",
        spells = { 46376, 1235110, 1235111, 1235057, 1235108 },
        checkFunc = function(self)
            return not Consumables:HasBuffBySpellIDs(self.spells)
        end,
    },
    {
        id = "food",
        icon = 136000,
        label = "Food!",
        checkFunc = function()
            return not Consumables:HasFoodBuff()
        end,
    },
    {
        id = "mainhand_poison",
        icon = 136066,
        label = "MH Poison",
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
        label = "OH Poison",
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
        label = "Healthstone",
        itemIDs = { 5512, 224464 },
        checkFunc = function(self)
            if not Consumables:GroupHasWarlock() then return false end
            return not Consumables:PlayerHasHealthstone(self.itemIDs)
        end,
    },
    {
        id = "augment_rune",
        icon = 237556,
        label = "Augment Rune",
        checkFunc = function()
            return not Consumables:HasRuneBuff()
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
    ScrollFrame = _G.AbstractUI_ScrollFrame
    
    -- Only initialize if module is enabled
    if AbstractUI.db.profile.modules.consumables then
        self:CreateTrackerFrame()
        self:RegisterEvents()
        self:RegisterSlashCommands()
        
        -- Start a periodic update timer (every 5 seconds)
        -- This ensures the display updates even if events are missed
        C_Timer.NewTicker(5, function()
            if not InCombatLockdown() then
                self:UpdateBuffStatus()
            end
        end)
    end
end

function Consumables:OnEnable()
    if trackerFrame then
        -- Delayed initial update to ensure everything is ready
        C_Timer.After(2, function()
            self:UpdateBuffStatus()
        end)
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
        
        -- Get custom icon and label from database, or use defaults
        local customization = self.db.profile.customization[group.id]
        local iconTexture = customization.icon or group.icon
        local labelText = customization.label or group.label
        
        -- Icon texture
        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(iconTexture)
        
        -- Border
        local border = iconFrame:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\WHITE8X8")
        border:SetAllPoints()
        border:SetVertexColor(1, 0, 0, 0.3)
        
        -- Individual text label under this icon
        local label = iconFrame:CreateFontString(nil, "OVERLAY")
        label:SetFont(STANDARD_TEXT_FONT, self.db.profile.textSize, "OUTLINE")
        label:SetPoint("TOP", iconFrame, "BOTTOM", 0, -2)
        label:SetTextColor(1, 0, 0, 1)
        label:SetText(labelText)
        
        iconGroups[i] = {
            frame = iconFrame,
            icon = icon,
            border = border,
            label = label,
            data = group,
        }
    end
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

function Consumables:RegisterEvents()
    self:RegisterEvent("READY_CHECK")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end

function Consumables:READY_CHECK()
    -- Always show on ready check if enabled, regardless of context
    if self.db.profile.alwaysShowOnReadyCheck then
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
    else
        -- Use normal context checking
        self:UpdateBuffStatus()
    end
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

function Consumables:PLAYER_ENTERING_WORLD()
    -- Update display when entering world/instances
    -- Use multiple delayed checks to ensure we catch the proper state
    C_Timer.After(1, function()
        self:UpdateBuffStatus()
    end)
    C_Timer.After(3, function()
        self:UpdateBuffStatus()
    end)
    C_Timer.After(5, function()
        self:UpdateBuffStatus()
    end)
end

function Consumables:ZONE_CHANGED_NEW_AREA()
    -- Update display when changing zones
    C_Timer.After(0.5, function()
        self:UpdateBuffStatus()
    end)
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

function Consumables:HasRuneBuff()
    local found = false
    self:ForEachAuraSafe("player", "HELPFUL", nil, function(aura)
        if aura.name and aura.name:find("Augment Rune") then
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
    -- Ensure frame exists
    if not trackerFrame then
        return
    end
    
    if InCombatLockdown() then
        trackerFrame:Hide()
        return
    end
    
    -- Check if we should show in current context
    if not self:ShouldShowInCurrentContext() then
        trackerFrame:Hide()
        return
    end
    
    local anyMissing = false
    
    -- Check each buff group
    for i, iconGroup in ipairs(iconGroups) do
        local group = iconGroup.data
        
        -- Weapon imbues use a single toggle for both slots
        local isEnabled
        if group.id == "weapon_imbue_mainhand" or group.id == "weapon_imbue_offhand" then
            isEnabled = self.db.profile.trackBuffs.weapon_imbues
        else
            isEnabled = self.db.profile.trackBuffs[group.id]
        end
        
        local isMissing = isEnabled and group.checkFunc(group)
        
        if isMissing then
            iconGroup.frame:Show()
            anyMissing = true
        else
            iconGroup.frame:Hide()
        end
    end
    
    -- Update frame visibility based on whether anything is missing
    trackerFrame:SetShown(anyMissing)
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

-- ============================================================================
-- CONTEXT CHECKING
-- ============================================================================

function Consumables:ShouldShowInCurrentContext()
    local inInstance, instanceType = IsInInstance()
    
    local settings = self.db.profile.showInContext
    
    -- Not in an instance - open world
    if not inInstance then
        return settings.world
    end
    
    -- Check instance type
    if instanceType == "party" then
        local _, _, difficulty = GetInstanceInfo()
        
        -- Delves are instanceType "party" with specific difficulty IDs
        if difficulty == 208 then  -- Delve difficulty
            return settings.delves
        end
        
        -- Regular dungeons
        if difficulty == 1 then  -- Normal
            return settings.normalDungeon
        elseif difficulty == 2 then  -- Heroic
            return settings.heroicDungeon
        elseif difficulty == 23 or difficulty == 8 then  -- Mythic/M+
            return settings.mythicDungeon
        end
    elseif instanceType == "raid" then
        local _, _, difficulty = GetInstanceInfo()
        
        if difficulty == 17 then  -- LFR
            return settings.lfr
        elseif difficulty == 14 then  -- Normal
            return settings.normalRaid
        elseif difficulty == 15 then  -- Heroic
            return settings.heroicRaid
        elseif difficulty == 16 then  -- Mythic
            return settings.mythicRaid
        end
    elseif instanceType == "pvp" or instanceType == "arena" then
        return settings.pvp
    end
    
    -- Default to false for unknown contexts
    return false
end

-- ============================================================================
-- MODULE OPTIONS
-- ============================================================================

function Consumables:GetOptions()
    if not self.db then return {} end
    
    return {
        type = "group",
        name = "Consumables Tracker",
        args = {
            header = {
                type = "header",
                name = "Consumables Tracker Settings",
                order = 1,
            },
            description = {
                type = "description",
                name = "Track missing buffs and consumables. Shows icons for missing enchants, flasks, food, and more.",
                order = 2,
            },
            
            -- Display Settings
            displayHeader = {
                type = "header",
                name = "Display Settings",
                order = 10,
            },
            iconSize = {
                type = "range",
                name = "Icon Size",
                desc = "Size of the consumable icons",
                min = 32,
                max = 128,
                step = 1,
                order = 11,
                width = "normal",
                get = function() return self.db.profile.iconSize end,
                set = function(_, v)
                    self.db.profile.iconSize = v
                    self:RecreateFrame()
                end,
            },
            iconSpacing = {
                type = "range",
                name = "Icon Spacing",
                desc = "Space between icons",
                min = 0,
                max = 30,
                step = 1,
                order = 12,
                width = "normal",
                get = function() return self.db.profile.iconSpacing end,
                set = function(_, v)
                    self.db.profile.iconSpacing = v
                    self:RecreateFrame()
                end,
            },
            textSize = {
                type = "range",
                name = "Text Size",
                desc = "Size of warning text below icons",
                min = 8,
                max = 32,
                step = 1,
                order = 13,
                width = "normal",
                get = function() return self.db.profile.textSize end,
                set = function(_, v)
                    self.db.profile.textSize = v
                    -- Update all icon labels
                    for _, iconGroup in ipairs(iconGroups) do
                        if iconGroup.label then
                            iconGroup.label:SetFont(STANDARD_TEXT_FONT, v, "OUTLINE")
                        end
                    end
                end,
            },
            resetPosition = {
                type = "execute",
                name = "Reset Position",
                desc = "Reset tracker position to center of screen",
                order = 14,
                func = function() self:ResetPosition() end,
            },
            
            -- What to Track
            trackingHeader = {
                type = "header",
                name = "What to Track",
                order = 20,
            },
            trackWeaponImbues = {
                type = "toggle",
                name = "Weapon Imbues",
                desc = "Track missing temporary weapon enhancements (Shaman imbues, weapon oils, sharpening stones, etc.)",
                order = 21,
                width = "full",
                get = function() return self.db.profile.trackBuffs.weapon_imbues end,
                set = function(_, v)
                    self.db.profile.trackBuffs.weapon_imbues = v
                    self:UpdateBuffStatus()
                end,
            },
            trackFlask = {
                type = "toggle",
                name = "Flask",
                desc = "Track missing flask buff",
                order = 23,
                width = "full",
                get = function() return self.db.profile.trackBuffs.flask end,
                set = function(_, v)
                    self.db.profile.trackBuffs.flask = v
                    self:UpdateBuffStatus()
                end,
            },
            trackFood = {
                type = "toggle",
                name = "Food Buff",
                desc = "Track missing Well Fed buff",
                order = 24,
                width = "full",
                get = function() return self.db.profile.trackBuffs.food end,
                set = function(_, v)
                    self.db.profile.trackBuffs.food = v
                    self:UpdateBuffStatus()
                end,
            },
            trackMainhandPoison = {
                type = "toggle",
                name = "Main Hand Poison (Rogue)",
                desc = "Track missing main hand poison (Rogue only)",
                order = 25,
                width = "full",
                get = function() return self.db.profile.trackBuffs.mainhand_poison end,
                set = function(_, v)
                    self.db.profile.trackBuffs.mainhand_poison = v
                    self:UpdateBuffStatus()
                end,
            },
            trackOffhandPoison = {
                type = "toggle",
                name = "Off Hand Poison (Rogue)",
                desc = "Track missing off hand poison (Rogue only)",
                order = 26,
                width = "full",
                get = function() return self.db.profile.trackBuffs.offhand_poison end,
                set = function(_, v)
                    self.db.profile.trackBuffs.offhand_poison = v
                    self:UpdateBuffStatus()
                end,
            },
            trackHealthstone = {
                type = "toggle",
                name = "Healthstone",
                desc = "Track missing healthstone (when Warlock is in group)",
                order = 27,
                width = "full",
                get = function() return self.db.profile.trackBuffs.healthstone end,
                set = function(_, v)
                    self.db.profile.trackBuffs.healthstone = v
                    self:UpdateBuffStatus()
                end,
            },
            trackAugmentRune = {
                type = "toggle",
                name = "Augment Rune",
                desc = "Track missing Augment Rune buff",
                order = 28,
                width = "full",
                get = function() return self.db.profile.trackBuffs.augment_rune end,
                set = function(_, v)
                    self.db.profile.trackBuffs.augment_rune = v
                    self:UpdateBuffStatus()
                end,
            },
            
            -- When to Show
            contextHeader = {
                type = "header",
                name = "When to Show",
                order = 30,
            },
            contextDescription = {
                type = "description",
                name = "Choose which contexts will automatically show the tracker when buffs are missing.",
                order = 31,
            },
            alwaysShowOnReadyCheck = {
                type = "toggle",
                name = "Always Show on Ready Check",
                desc = "Show tracker on ready checks regardless of other settings",
                order = 32,
                width = "full",
                get = function() return self.db.profile.alwaysShowOnReadyCheck end,
                set = function(_, v)
                    self.db.profile.alwaysShowOnReadyCheck = v
                    self:UpdateBuffStatus()
                end,
            },
            showInWorld = {
                type = "toggle",
                name = "Open World",
                desc = "Show tracker in open world when buffs are missing",
                order = 33,
                width = "full",
                get = function() return self.db.profile.showInContext.world end,
                set = function(_, v)
                    self.db.profile.showInContext.world = v
                    self:UpdateBuffStatus()
                end,
            },
            showInDelves = {
                type = "toggle",
                name = "Delves",
                desc = "Show tracker in Delves when buffs are missing",
                order = 34,
                width = "full",
                get = function() return self.db.profile.showInContext.delves end,
                set = function(_, v)
                    self.db.profile.showInContext.delves = v
                    self:UpdateBuffStatus()
                end,
            },
            dungeonSubHeader = {
                type = "description",
                name = "|cff888888Dungeons:|r",
                order = 35,
            },
            showInNormalDungeon = {
                type = "toggle",
                name = "  Normal Dungeons",
                desc = "Show tracker in Normal dungeons",
                order = 36,
                width = "full",
                get = function() return self.db.profile.showInContext.normalDungeon end,
                set = function(_, v)
                    self.db.profile.showInContext.normalDungeon = v
                    self:UpdateBuffStatus()
                end,
            },
            showInHeroicDungeon = {
                type = "toggle",
                name = "  Heroic Dungeons",
                desc = "Show tracker in Heroic dungeons",
                order = 37,
                width = "full",
                get = function() return self.db.profile.showInContext.heroicDungeon end,
                set = function(_, v)
                    self.db.profile.showInContext.heroicDungeon = v
                    self:UpdateBuffStatus()
                end,
            },
            showInMythicDungeon = {
                type = "toggle",
                name = "  Mythic/M+ Dungeons",
                desc = "Show tracker in Mythic and Mythic+ dungeons",
                order = 38,
                width = "full",
                get = function() return self.db.profile.showInContext.mythicDungeon end,
                set = function(_, v)
                    self.db.profile.showInContext.mythicDungeon = v
                    self:UpdateBuffStatus()
                end,
            },
            raidSubHeader = {
                type = "description",
                name = "|cff888888Raids:|r",
                order = 39,
            },
            showInLFR = {
                type = "toggle",
                name = "  LFR",
                desc = "Show tracker in LFR raids",
                order = 40,
                width = "full",
                get = function() return self.db.profile.showInContext.lfr end,
                set = function(_, v)
                    self.db.profile.showInContext.lfr = v
                    self:UpdateBuffStatus()
                end,
            },
            showInNormalRaid = {
                type = "toggle",
                name = "  Normal Raids",
                desc = "Show tracker in Normal raids",
                order = 41,
                width = "full",
                get = function() return self.db.profile.showInContext.normalRaid end,
                set = function(_, v)
                    self.db.profile.showInContext.normalRaid = v
                    self:UpdateBuffStatus()
                end,
            },
            showInHeroicRaid = {
                type = "toggle",
                name = "  Heroic Raids",
                desc = "Show tracker in Heroic raids",
                order = 42,
                width = "full",
                get = function() return self.db.profile.showInContext.heroicRaid end,
                set = function(_, v)
                    self.db.profile.showInContext.heroicRaid = v
                    self:UpdateBuffStatus()
                end,
            },
            showInMythicRaid = {
                type = "toggle",
                name = "  Mythic Raids",
                desc = "Show tracker in Mythic raids",
                order = 43,
                width = "full",
                get = function() return self.db.profile.showInContext.mythicRaid end,
                set = function(_, v)
                    self.db.profile.showInContext.mythicRaid = v
                    self:UpdateBuffStatus()
                end,
            },
            showInPvP = {
                type = "toggle",
                name = "PvP (Arenas/Battlegrounds)",
                desc = "Show tracker in PvP content",
                order = 44,
                width = "full",
                get = function() return self.db.profile.showInContext.pvp end,
                set = function(_, v)
                    self.db.profile.showInContext.pvp = v
                    self:UpdateBuffStatus()
                end,
            },
            
            -- Customize Icons & Labels
            customizeHeader = {
                type = "header",
                name = "Customize Icons & Labels",
                order = 50,
            },
            customizeDescription = {
                type = "description",
                name = "Click Edit to customize the icon and label for each buff type.",
                order = 51,
            },
            customizeMainHandImbue = {
                type = "execute",
                name = function()
                    local custom = self.db.profile.customization.weapon_imbue_mainhand
                    local icon = custom.icon or 7548987
                    return string.format("|T%d:20:20:0:0:64:64:4:60:4:60|t  %s", icon, custom.label or "Main Hand")
                end,
                desc = "Customize Main Hand weapon imbue icon and label",
                order = 52,
                width = "half",
                func = function() self:ShowBuffCustomizationEditor("weapon_imbue_mainhand", "Main Hand Weapon Imbue") end,
            },
            customizeOffHandImbue = {
                type = "execute",
                name = function()
                    local custom = self.db.profile.customization.weapon_imbue_offhand
                    local icon = custom.icon or 3622196
                    return string.format("|T%d:20:20:0:0:64:64:4:60:4:60|t  %s", icon, custom.label or "Off Hand")
                end,
                desc = "Customize Off Hand weapon imbue icon and label",
                order = 53,
                width = "half",
                func = function() self:ShowBuffCustomizationEditor("weapon_imbue_offhand", "Off Hand Weapon Imbue") end,
            },
            customizeFlask = {
                type = "execute",
                name = function()
                    local custom = self.db.profile.customization.flask
                    local icon = custom.icon or 7548903
                    return string.format("|T%d:20:20:0:0:64:64:4:60:4:60|t  %s", icon, custom.label or "Flask!")
                end,
                desc = "Customize Flask icon and label",
                order = 54,
                width = "half",
                func = function() self:ShowBuffCustomizationEditor("flask", "Flask Buff") end,
            },
            customizeFood = {
                type = "execute",
                name = function()
                    local custom = self.db.profile.customization.food
                    local icon = custom.icon or 136000
                    return string.format("|T%d:20:20:0:0:64:64:4:60:4:60|t  %s", icon, custom.label or "Food!")
                end,
                desc = "Customize Food buff icon and label",
                order = 55,
                width = "half",
                func = function() self:ShowBuffCustomizationEditor("food", "Food Buff") end,
            },
            customizeMainHandPoison = {
                type = "execute",
                name = function()
                    local custom = self.db.profile.customization.mainhand_poison
                    local icon = custom.icon or 136066
                    return string.format("|T%d:20:20:0:0:64:64:4:60:4:60|t  %s", icon, custom.label or "MH Poison")
                end,
                desc = "Customize Main Hand Poison icon and label",
                order = 56,
                width = "half",
                func = function() self:ShowBuffCustomizationEditor("mainhand_poison", "Main Hand Poison") end,
            },
            customizeOffHandPoison = {
                type = "execute",
                name = function()
                    local custom = self.db.profile.customization.offhand_poison
                    local icon = custom.icon or 136066
                    return string.format("|T%d:20:20:0:0:64:64:4:60:4:60|t  %s", icon, custom.label or "OH Poison")
                end,
                desc = "Customize Off Hand Poison icon and label",
                order = 57,
                width = "half",
                func = function() self:ShowBuffCustomizationEditor("offhand_poison", "Off Hand Poison") end,
            },
            customizeHealthstone = {
                type = "execute",
                name = function()
                    local custom = self.db.profile.customization.healthstone
                    local icon = custom.icon or 538745
                    return string.format("|T%d:20:20:0:0:64:64:4:60:4:60|t  %s", icon, custom.label or "Healthstone")
                end,
                desc = "Customize Healthstone icon and label",
                order = 58,
                width = "half",
                func = function() self:ShowBuffCustomizationEditor("healthstone", "Healthstone") end,
            },
            customizeAugmentRune = {
                type = "execute",
                name = function()
                    local custom = self.db.profile.customization.augment_rune
                    local icon = custom.icon or 237556
                    return string.format("|T%d:20:20:0:0:64:64:4:60:4:60|t  %s", icon, custom.label or "Augment Rune")
                end,
                desc = "Customize Augment Rune icon and label",
                order = 59,
                width = "half",
                func = function() self:ShowBuffCustomizationEditor("augment_rune", "Augment Rune") end,
            },
        },
    }
end

-- Show buff customization editor dialog
function Consumables:ShowBuffCustomizationEditor(buffId, title)
    if not ColorPalette or not ScrollFrame then
        print("Consumables: Required frameworks not loaded yet")
        return
    end
    
    -- Get current values from database
    local currentCustom = self.db.profile.customization[buffId]
    if not currentCustom then
        print("Consumables: Invalid buff ID: " .. tostring(buffId))
        return
    end
    
    -- Create custom editor dialog
    local editor = CreateFrame("Frame", "AbstractUI_ConsumablesCustomizationEditor", UIParent, "BackdropTemplate")
    editor:SetSize(400, 450)
    editor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    editor:SetFrameStrata("FULLSCREEN_DIALOG")
    editor:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    editor:SetBackdropColor(0.1, 0.1, 0.1, 1.0)
    editor:SetBackdropBorderColor(ColorPalette:GetColor("accent-primary"))
    editor:EnableMouse(true)
    editor:SetMovable(true)
    editor:RegisterForDrag("LeftButton")
    editor:SetScript("OnDragStart", function(self) self:StartMoving() end)
    editor:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Title
    local titleText = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", editor, "TOP", 0, -10)
    titleText:SetText("Customize: " .. title)
    titleText:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    -- Store selected icon
    editor.selectedIcon = currentCustom.icon
    editor.buffId = buffId
    
    -- Label text label
    local labelLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 15, -40)
    labelLabel:SetText("Label Text:")
    labelLabel:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    -- Label edit box
    local labelBox = CreateFrame("EditBox", nil, editor, "BackdropTemplate")
    labelBox:SetSize(370, 22)
    labelBox:SetPoint("TOPLEFT", labelLabel, "BOTTOMLEFT", 0, -5)
    labelBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    labelBox:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    labelBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    labelBox:SetFontObject("ChatFontNormal")
    labelBox:SetTextColor(1, 1, 1)
    labelBox:SetAutoFocus(false)
    labelBox:SetMaxLetters(50)
    labelBox:SetText(currentCustom.label or "")
    labelBox:SetCursorPosition(0)
    editor.labelBox = labelBox
    
    -- Icon selection label
    local iconLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconLabel:SetPoint("TOPLEFT", labelBox, "BOTTOMLEFT", 0, -10)
    iconLabel:SetText("Select Icon:")
    iconLabel:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    -- Search box for icons
    local searchBox = CreateFrame("EditBox", nil, editor, "BackdropTemplate")
    searchBox:SetSize(370, 22)
    searchBox:SetPoint("TOPLEFT", iconLabel, "BOTTOMLEFT", 0, -5)
    searchBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    searchBox:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    searchBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    searchBox:SetFontObject("ChatFontNormal")
    searchBox:SetTextColor(0.7, 0.7, 0.7)
    searchBox:SetAutoFocus(false)
    searchBox:SetText("Search icons...")
    
    -- Icon grid container with AbstractUI ScrollFrame
    local iconScrollContainer = CreateFrame("Frame", nil, editor)
    iconScrollContainer:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -5)
    iconScrollContainer:SetSize(370, 260)
    
    local iconScrollFrame = ScrollFrame:Create(iconScrollContainer)
    iconScrollFrame:SetPoint("TOPLEFT", iconScrollContainer, "TOPLEFT", 0, 0)
    iconScrollFrame:SetPoint("BOTTOMRIGHT", iconScrollContainer, "BOTTOMRIGHT", 0, 0)
    
    local iconScrollChild = iconScrollFrame:GetScrollChild()
    iconScrollChild:SetSize(350, 1)  -- Slightly narrower to account for scrollbar
    
    -- Get all equipment/armor icons
    local allIcons = {}
    GetMacroItemIcons(allIcons)
    local macroIcons = GetMacroIcons()
    for i = 1, #macroIcons do
        table.insert(allIcons, macroIcons[i])
    end
    
    editor.allIcons = allIcons
    editor.iconButtons = {}
    
    -- Function to rebuild icon grid
    local function RebuildIconGrid(searchText)
        -- Clear existing buttons
        for _, btn in ipairs(editor.iconButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
        editor.iconButtons = {}
        
        -- Filter icons
        local displayIcons = {}
        local searchLower = searchText and string.lower(searchText) or ""
        local usingSearch = searchLower ~= "" and searchLower ~= "search icons..."
        
        if usingSearch and _G.ICON_FILE_NAMES then
            -- Search by icon name
            for _, iconID in ipairs(allIcons) do
                local iconName = _G.ICON_FILE_NAMES[iconID]
                if iconName and string.find(string.lower(iconName), searchLower, 1, true) then
                    table.insert(displayIcons, iconID)
                    if #displayIcons >= 200 then break end
                end
            end
        else
            -- Show first 100 icons by default
            for i = 1, math.min(100, #allIcons) do
                table.insert(displayIcons, allIcons[i])
            end
        end
        
        -- Create icon buttons in grid
        local iconsPerRow = 9  -- Adjusted for scrollbar width
        local iconSize = 32
        local iconSpacing = 4
        
        for i, iconID in ipairs(displayIcons) do
            local row = math.floor((i - 1) / iconsPerRow)
            local col = (i - 1) % iconsPerRow
            
            local btn = CreateFrame("Button", nil, iconScrollChild, "BackdropTemplate")
            btn:SetSize(iconSize, iconSize)
            btn:SetPoint("TOPLEFT", iconScrollChild, "TOPLEFT", col * (iconSize + iconSpacing), -row * (iconSize + iconSpacing))
            
            -- Selection border (larger background texture)
            local borderBg = btn:CreateTexture(nil, "BACKGROUND")
            borderBg:SetTexture("Interface\\Buttons\\WHITE8X8")
            borderBg:SetVertexColor(1, 0.82, 0, 1)  -- Gold
            borderBg:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
            borderBg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
            borderBg:Hide()
            btn.borderBg = borderBg
            
            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexture(iconID)
            btn.texture = tex
            btn.iconID = iconID
            
            local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(1, 1, 1, 0.3)
            
            btn:SetScript("OnClick", function(self)
                editor.selectedIcon = iconID
                -- Update all borders
                for _, b in ipairs(editor.iconButtons) do
                    if b.borderBg then
                        b.borderBg:Hide()
                    end
                end
                if self.borderBg then
                    self.borderBg:Show()
                end
            end)
            
            -- Tooltip with icon name
            if _G.ICON_FILE_NAMES and _G.ICON_FILE_NAMES[iconID] then
                btn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(_G.ICON_FILE_NAMES[iconID])
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)
            end
            
            -- Show border if this is the current icon
            if iconID == editor.selectedIcon then
                borderBg:Show()
            end
            
            table.insert(editor.iconButtons, btn)
        end
        
        -- Set scroll child height
        local numRows = math.ceil(#displayIcons / iconsPerRow)
        iconScrollChild:SetHeight(math.max(1, numRows * (iconSize + iconSpacing)))
        
        -- Update scrollbar
        if iconScrollFrame.UpdateScroll then
            iconScrollFrame:UpdateScroll()
        end
    end
    
    -- Search box handlers
    searchBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == "Search icons..." then
            self:SetText("")
            self:SetTextColor(1, 1, 1)
        end
    end)
    
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self:SetText("Search icons...")
            self:SetTextColor(0.7, 0.7, 0.7)
            RebuildIconGrid("")
        end
    end)
    
    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text ~= "Search icons..." then
            RebuildIconGrid(text)
        end
    end)
    
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    -- Build initial icon grid
    RebuildIconGrid("")
    
    -- Save button
    local saveBtn = CreateFrame("Button", nil, editor, "BackdropTemplate")
    saveBtn:SetSize(80, 24)
    saveBtn:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 15, 15)
    saveBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    saveBtn:SetBackdropColor(ColorPalette:GetColor("button-bg"))
    saveBtn:SetBackdropBorderColor(ColorPalette:GetColor("accent-primary"))
    local saveText = saveBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    saveText:SetPoint("CENTER")
    saveText:SetText("Save")
    saveText:SetTextColor(ColorPalette:GetColor("text-primary"))
    saveBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ColorPalette:GetColor("button-hover"))
    end)
    saveBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ColorPalette:GetColor("button-bg"))
    end)
    saveBtn:SetScript("OnClick", function()
        local newLabel = labelBox:GetText()
        if newLabel and newLabel ~= "" then
            self.db.profile.customization[buffId].label = newLabel
            self.db.profile.customization[buffId].icon = editor.selectedIcon
            self:RecreateFrame()
            -- Notify AceConfig to refresh the options display
            LibStub("AceConfigRegistry-3.0"):NotifyChange("AbstractUI")
        end
        editor:Hide()
    end)
    
    -- Cancel button
    local cancelBtn = CreateFrame("Button", nil, editor, "BackdropTemplate")
    cancelBtn:SetSize(80, 24)
    cancelBtn:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -15, 15)
    cancelBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    cancelBtn:SetBackdropColor(ColorPalette:GetColor("button-bg"))
    cancelBtn:SetBackdropBorderColor(ColorPalette:GetColor("accent-primary"))
    local cancelText = cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cancelText:SetPoint("CENTER")
    cancelText:SetText("Cancel")
    cancelText:SetTextColor(ColorPalette:GetColor("text-primary"))
    cancelBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ColorPalette:GetColor("button-hover"))
    end)
    cancelBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ColorPalette:GetColor("button-bg"))
    end)
    cancelBtn:SetScript("OnClick", function()
        editor:Hide()
    end)
    
    -- Reset to Default button
    local resetBtn = CreateFrame("Button", nil, editor, "BackdropTemplate")
    resetBtn:SetSize(100, 24)
    resetBtn:SetPoint("BOTTOM", editor, "BOTTOM", 0, 15)
    resetBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    resetBtn:SetBackdropColor(ColorPalette:GetColor("button-bg"))
    resetBtn:SetBackdropBorderColor(ColorPalette:GetColor("accent-primary"))
    local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resetText:SetPoint("CENTER")
    resetText:SetText("Reset Default")
    resetText:SetTextColor(ColorPalette:GetColor("text-primary"))
    resetBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ColorPalette:GetColor("button-hover"))
    end)
    resetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ColorPalette:GetColor("button-bg"))
    end)
    resetBtn:SetScript("OnClick", function()
        -- Find default icon and label from BUFF_GROUPS
        for _, group in ipairs(BUFF_GROUPS) do
            if group.id == buffId then
                editor.selectedIcon = group.icon
                labelBox:SetText(group.label)
                RebuildIconGrid(searchBox:GetText())
                -- Save the defaults back to the database
                self.db.profile.customization[buffId].label = group.label
                self.db.profile.customization[buffId].icon = group.icon
                self:RecreateFrame()
                -- Notify AceConfig to refresh the options display
                LibStub("AceConfigRegistry-3.0"):NotifyChange("AbstractUI")
                break
            end
        end
    end)
    
    -- ESC to close
    labelBox:SetScript("OnEscapePressed", function(self)
        editor:Hide()
    end)
    
    -- Enter to save
    labelBox:SetScript("OnEnterPressed", function(self)
        saveBtn:Click()
    end)
    
    editor:Show()
    labelBox:SetFocus()
end

-- Recreate frame with new settings
function Consumables:RecreateFrame()
    if trackerFrame then
        trackerFrame:Hide()
        trackerFrame:SetParent(nil)
        trackerFrame = nil
        iconGroups = {}
    end
    
    self:CreateTrackerFrame()
    self:UpdateBuffStatus()
end
