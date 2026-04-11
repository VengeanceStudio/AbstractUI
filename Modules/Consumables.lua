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

-- Buff state cache (persists when live data unavailable due to secret values)
local buffCache = {
    flask = { active = false, expiresAt = 0 },
    food = { active = false, expiresAt = 0 },
    rune = { active = false, expiresAt = 0 },
    weaponMH = { active = false, expiresAt = 0 },
    weaponOH = { active = false, expiresAt = 0 },
    rogueMHPoison = { active = false, expiresAt = 0 },
    rogueOHPoison = { active = false, expiresAt = 0 },
    classBuff = { active = false, expiresAt = 0 },
}

-- Buffs that persist through death
-- Note: Modern "Hearty" food variants persist through death, so food is marked as persistent
local PERSISTS_THROUGH_DEATH = {
    flask = true,
    rune = true,
    weaponMH = true,
    weaponOH = true,
    rogueMHPoison = true,
    rogueOHPoison = true,
    food = true,  -- Hearty food buffs persist through death (TWW+)
    classBuff = false,  -- Class buffs (Mark of the Wild, etc.) are lost on death
}

-- Reference to ScrollFrame (will be initialized after DB is ready)
local ScrollFrame

-- ============================================================================
-- COMPREHENSIVE CONSUMABLE DETECTION DATA
-- Based on ReadyCheckConsumables for accurate multi-expansion support
-- ============================================================================

-- Flask Buff Spell IDs (detects active flask auras)
local FLASK_BUFF_IDS = {
    -- 12.0.0 - Midnight
    [1235057] = true, -- Flask of Thalassian Resistance (Vers)
    [1235108] = true, -- Flask of the Magisters (Mastery)
    [1235110] = true, -- Flask of the Blood Knights (Haste)
    [1235111] = true, -- Flask of the Shattered Sun (Crit)
    
    -- 11.0.0 - The War Within
    [432021] = true, -- Flask of Alchemical Chaos
    [432473] = true, -- Flask of Saving Graces
    [431971] = true, -- Flask of Tempered Aggression
    [431972] = true, -- Flask of Tempered Swiftness
    [431974] = true, -- Flask of Tempered Mastery
    [431973] = true, -- Flask of Tempered Versatility
    
    -- 10.0.0 - Dragonflight
    [371339] = true, -- Phial of Elemental Chaos
    [374000] = true, -- Iced Phial of Corrupting Rage
    [371354] = true, -- Phial of the Eye in the Storm
    [371204] = true, -- Phial of Still Air
    [370662] = true, -- Phial of Icy Preservation
    [373257] = true, -- Phial of Glacial Fury
    [371386] = true, -- Phial of Charged Isolation
    [370652] = true, -- Phial of Static Empowerment
    [371172] = true, -- Phial of Tepid Versatility
    [371186] = true, -- Charged Phial of Alacrity
    
    -- 9.0.1 - Shadowlands
    [307187] = true, -- Spectral Stamina Flask
    [307185] = true, -- Spectral Flask of Power
    [307166] = true, -- Eternal Flask
    
    -- 8.0.1 - Battle for Azeroth
    [251838] = true, [251837] = true, [251836] = true, [251839] = true,
    [298839] = true, [298837] = true, [298836] = true, [298841] = true,
}

-- Food Buff Spell IDs (detects active food buffs)
local FOOD_BUFF_IDS = {
    -- 8.0.1 - Battle for Azeroth
    [257413] = true, [257415] = true, [297034] = true, [257418] = true,
    [257420] = true, [297035] = true, [257408] = true, [257410] = true,
    [297039] = true, [185736] = true, [257422] = true, [257424] = true,
    [297037] = true, [259449] = true, [259455] = true, [290468] = true,
    [297117] = true, [259452] = true, [259456] = true, [290469] = true,
    [297118] = true, [259448] = true, [259454] = true, [290467] = true,
    [297116] = true, [259453] = true, [259457] = true, [288074] = true,
    [288075] = true, [297119] = true, [297040] = true, [285719] = true,
    [285720] = true, [285721] = true, [286171] = true,
    
    -- 10.0.0 - Dragonflight
    [308488] = true, [308506] = true, [308434] = true, [308514] = true,
    [327708] = true, [327706] = true, [327709] = true, [308525] = true,
    [327707] = true, [308637] = true, [308474] = true, [308504] = true,
    [308430] = true, [308509] = true, [327704] = true, [327701] = true,
    [327705] = true, [327702] = true, [382145] = true, [382150] = true,
    [382146] = true, [382149] = true, [396092] = true, [382246] = true,
    [382247] = true, [382152] = true, [382153] = true, [382157] = true,
    [382230] = true, [382231] = true,
    
    -- 11.0.0 - The War Within
    [456960] = true, [456961] = true, [456962] = true, [456963] = true,
    [456964] = true, [456965] = true, [456966] = true, [456967] = true,
    [456999] = true, [457001] = true, [457003] = true, [457005] = true,
    [457006] = true, [457120] = true, [457139] = true, [457244] = true,
    [457297] = true, [462206] = true, [462207] = true, [462211] = true,
    [462212] = true, [462213] = true, [462214] = true, [462215] = true,
    
    -- 12.0.0 - Midnight
    [1237881] = true, [1237884] = true, [1237883] = true, [1237885] = true,
    [1237890] = true, [1237891] = true, [1237895] = true, [1237896] = true,
    [1237902] = true, [1237903] = true, [1237908] = true, [1237910] = true,
    [1237914] = true, [1237915] = true, [1237918] = true, [1237919] = true,
}

-- Food Icon IDs (fallback detection when spell ID is unknown)
local FOOD_ICON_IDS = {
    [136000] = true, -- Well Fed icon (canonical)
    [132805] = true, -- Drinking
    [133950] = true, -- Eating
}

-- Augment Rune Buff Spell IDs (detects active rune buffs)
local RUNE_BUFF_IDS = {
    [1264426] = true, -- 12.0.0: Void-Touched Augment Rune
    [1242347] = true, -- 11.2.0: Soulgorged Augmentation
    [1234969] = true, -- 11.2.0: Ethereal Augmentation
    [453250]  = true, -- 11.0.0: Crystallization
    [393438]  = true, -- 10.0.0: Draconic Augmentation
    [367405]  = true, -- 9.2.0:  Eternal Augmentation
    [347901]  = true, -- 9.0.2:  Veiled Augmentation
    [317065]  = true, -- 8.3.0:  Battle-Scarred Augmentation
    [270058]  = true, -- 8.1.0:  Battle-Scarred Augmentation
    [224001]  = true, -- 7.0.3:  Defiled Augmentation
}

-- Healthstone Item IDs
local HEALTHSTONE_ITEM_IDS = {
    [5512]   = true, -- Healthstone
    [224464] = true, -- Demonic Healthstone
}

-- Rogue Poison Spell IDs
local ROGUE_DEADLY_POISON_IDS = { 2823, 315584 }  -- Deadly Poison (MH)
local ROGUE_WOUND_POISON_IDS = { 8679 }  -- Wound Poison (MH)
local ROGUE_CRIPPLING_POISON_IDS = { 3408 }  -- Crippling Poison (OH)
local ROGUE_ATROPHIC_POISON_IDS = { 381637 }  -- Atrophic Poison (OH)
local ROGUE_NUMBING_POISON_IDS = { 5761 }  -- Numbing Poison (OH)

-- Class/Raid Buff Spell IDs (lost on death, need reapplication)
-- Only checked if player is the specified class
local CLASS_BUFF_IDS = {
    -- Druid: Mark of the Wild
    [1126] = "DRUID",
    
    -- Priest: Power Word: Fortitude
    [21562] = "PRIEST",
    
    -- Mage: Arcane Intellect
    [1459] = "MAGE",
    
    -- Warrior: Battle Shout
    [6673] = "WARRIOR",
}

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
            class_buff = true,  -- Track class/raid buffs (Mark of the Wild, etc.)
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
            class_buff = { icon = 136116, label = "Buff!" },  -- Spell_nature_regeneration icon
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
        previewMode = false,  -- Show all icons regardless of buff status (for customization preview)
    }
}

-- Buff/consumable groups to track
local BUFF_GROUPS = {
    {
        id = "weapon_imbue_mainhand",
        icon = 7548987,
        label = "Main Hand",
        checkFunc = function()
            return not Consumables:HasWeaponMHEnchant()
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
            return not Consumables:HasWeaponOHEnchant()
        end,
    },
    {
        id = "flask",
        icon = 7548903,
        label = "Flask!",
        checkFunc = function()
            return not Consumables:HasFlaskBuff()
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
        requireClass = "ROGUE",
        checkFunc = function()
            local _, playerClass = UnitClass("player")
            if playerClass ~= "ROGUE" then return false end
            return not Consumables:HasRogueMHPoisonBuff()
        end,
    },
    {
        id = "offhand_poison",
        icon = 136066,
        label = "OH Poison",
        requireClass = "ROGUE",
        checkFunc = function()
            local _, playerClass = UnitClass("player")
            if playerClass ~= "ROGUE" then return false end
            local itemID = GetInventoryItemID("player", 17)
            if not itemID then return false end
            local classID = select(6, GetItemInfoInstant(itemID))
            local isWeapon = (classID == 2)
            return isWeapon and not Consumables:HasRogueOHPoisonBuff()
        end,
    },
    {
        id = "healthstone",
        icon = 538745,
        label = "Healthstone",
        checkFunc = function()
            if not Consumables:GroupHasWarlock() then return false end
            return not Consumables:PlayerHasHealthstone()
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
    {
        id = "class_buff",
        icon = 136116,
        label = "Buff!",
        checkFunc = function()
            -- Only check if player class has a personal buff
            local _, playerClass = UnitClass("player")
            local hasClassBuff = (playerClass == "DRUID" or 
                                  playerClass == "PRIEST" or 
                                  playerClass == "MAGE" or 
                                  playerClass == "WARRIOR")
            
            if not hasClassBuff then
                return false  -- Class doesn't have a personal buff, don't show
            end
            
            return not Consumables:HasClassBuff()
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
        
        -- Border (no color overlay)
        local border = iconFrame:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\WHITE8X8")
        border:SetAllPoints()
        border:SetVertexColor(1, 1, 1, 0)  -- Transparent, no red overlay
        
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
    self:RegisterEvent("PLAYER_DEAD")
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

function Consumables:PLAYER_DEAD()
    -- Clear buffs that don't persist through death
    local now = GetTime()
    for buffType, persists in pairs(PERSISTS_THROUGH_DEATH) do
        if not persists and buffCache[buffType] then
            buffCache[buffType].active = false
            buffCache[buffType].expiresAt = now
        end
    end
    
    -- Update display after death
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
-- Using C_UnitAuras for comprehensive detection across all expansions
-- Caches buff states to handle secret values during instance transitions
-- ============================================================================

-- Scans player auras using direct C_UnitAuras API for maximum compatibility
function Consumables:ScanPlayerAuras()
    local now = GetTime()
    local buffs = {
        hasFlask = false,
        hasFood = false,
        hasRune = false,
        hasRogueMHPoison = false,
        hasRogueOHPoison = false,
        hasClassBuff = false,
    }
    
    local foundAnyValidAura = false
    local hadSecretValues = false
    
    -- Scan up to 60 buff slots
    for i = 1, 60 do
        local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        
        if not auraData then
            break
        end
        
        local spellId = auraData.spellId
        local icon = auraData.icon
        local expirationTime = auraData.expirationTime or 0
        
        -- Skip secret values (occurs during M+ countdown and instance transitions)
        if issecretvalue and issecretvalue(spellId) then
            hadSecretValues = true
        else
            foundAnyValidAura = true
            
            -- Check flask buffs by spell ID
            if FLASK_BUFF_IDS[spellId] then
                buffs.hasFlask = true
                buffCache.flask.active = true
                buffCache.flask.expiresAt = expirationTime
            end
            
            -- Check food buffs by spell ID
            if FOOD_BUFF_IDS[spellId] then
                buffs.hasFood = true
                buffCache.food.active = true
                buffCache.food.expiresAt = expirationTime
            end
            
            -- Check food buffs by icon ID (fallback)
            if FOOD_ICON_IDS[icon] then
                buffs.hasFood = true
                buffCache.food.active = true
                buffCache.food.expiresAt = expirationTime
            end
            
            -- Check rune buffs by spell ID
            if RUNE_BUFF_IDS[spellId] then
                buffs.hasRune = true
                buffCache.rune.active = true
                buffCache.rune.expiresAt = expirationTime
            end
            
            -- Check class/raid buff by spell ID (only if player is that class)
            local buffClass = CLASS_BUFF_IDS[spellId]
            if buffClass then
                local _, playerClass = UnitClass("player")
                if playerClass == buffClass then
                    buffs.hasClassBuff = true
                    buffCache.classBuff.active = true
                    buffCache.classBuff.expiresAt = expirationTime
                end
            end
            
            -- Check rogue poison buffs
            for _, poisonId in ipairs(ROGUE_DEADLY_POISON_IDS) do
                if spellId == poisonId then
                    buffs.hasRogueMHPoison = true
                    buffCache.rogueMHPoison.active = true
                    buffCache.rogueMHPoison.expiresAt = expirationTime
                end
            end
            for _, poisonId in ipairs(ROGUE_WOUND_POISON_IDS) do
                if spellId == poisonId then
                    buffs.hasRogueMHPoison = true
                    buffCache.rogueMHPoison.active = true
                    buffCache.rogueMHPoison.expiresAt = expirationTime
                end
            end
            for _, poisonId in ipairs(ROGUE_CRIPPLING_POISON_IDS) do
                if spellId == poisonId then
                    buffs.hasRogueOHPoison = true
                    buffCache.rogueOHPoison.active = true
                    buffCache.rogueOHPoison.expiresAt = expirationTime
                end
            end
            for _, poisonId in ipairs(ROGUE_ATROPHIC_POISON_IDS) do
                if spellId == poisonId then
                    buffs.hasRogueOHPoison = true
                    buffCache.rogueOHPoison.active = true
                    buffCache.rogueOHPoison.expiresAt = expirationTime
                end
            end
            for _, poisonId in ipairs(ROGUE_NUMBING_POISON_IDS) do
                if spellId == poisonId then
                    buffs.hasRogueOHPoison = true
                    buffCache.rogueOHPoison.active = true
                    buffCache.rogueOHPoison.expiresAt = expirationTime
                end
            end
        end
    end
    
    -- Scan weapon enchants (separate system from auras)
    local hasMainHandEnchant, mainHandExpiration, _, _,
          hasOffHandEnchant, offHandExpiration = GetWeaponEnchantInfo()
    
    if hasMainHandEnchant then
        buffCache.weaponMH.active = true
        -- Weapon enchant expiration is in milliseconds from now
        buffCache.weaponMH.expiresAt = now + ((mainHandExpiration or 0) / 1000)
    end
    
    if hasOffHandEnchant then
        buffCache.weaponOH.active = true
        buffCache.weaponOH.expiresAt = now + ((offHandExpiration or 0) / 1000)
    end
    
    -- If we had secret values or no valid auras, use cached data
    if hadSecretValues or not foundAnyValidAura then
        -- Use cached data if it hasn't expired
        if buffCache.flask.active and buffCache.flask.expiresAt > now then
            buffs.hasFlask = true
        else
            buffCache.flask.active = false
        end
        
        if buffCache.food.active and buffCache.food.expiresAt > now then
            buffs.hasFood = true
        else
            buffCache.food.active = false
        end
        
        if buffCache.rune.active and buffCache.rune.expiresAt > now then
            buffs.hasRune = true
        else
            buffCache.rune.active = false
        end
        
        if buffCache.rogueMHPoison.active and buffCache.rogueMHPoison.expiresAt > now then
            buffs.hasRogueMHPoison = true
        else
            buffCache.rogueMHPoison.active = false
        end
        
        if buffCache.rogueOHPoison.active and buffCache.rogueOHPoison.expiresAt > now then
            buffs.hasRogueOHPoison = true
        else
            buffCache.rogueOHPoison.active = false
        end
        
        if buffCache.classBuff.active and buffCache.classBuff.expiresAt > now then
            buffs.hasClassBuff = true
        else
            buffCache.classBuff.active = false
        end
    else
        -- Clear cache entries for buffs we didn't find (they expired or were removed)
        if not buffs.hasFlask then
            buffCache.flask.active = false
            buffCache.flask.expiresAt = now
        end
        if not buffs.hasFood then
            buffCache.food.active = false
            buffCache.food.expiresAt = now
        end
        if not buffs.hasRune then
            buffCache.rune.active = false
            buffCache.rune.expiresAt = now
        end
        if not buffs.hasRogueMHPoison then
            buffCache.rogueMHPoison.active = false
            buffCache.rogueMHPoison.expiresAt = now
        end
        if not buffs.hasRogueOHPoison then
            buffCache.rogueOHPoison.active = false
            buffCache.rogueOHPoison.expiresAt = now
        end
        if not buffs.hasClassBuff then
            buffCache.classBuff.active = false
            buffCache.classBuff.expiresAt = now
        end
    end
    
    -- Always use cached weapon enchant data (checked separately above)
    if buffCache.weaponMH.active and buffCache.weaponMH.expiresAt > now then
        buffs.hasWeaponMH = true
    else
        buffCache.weaponMH.active = false
        buffs.hasWeaponMH = false
    end
    
    if buffCache.weaponOH.active and buffCache.weaponOH.expiresAt > now then
        buffs.hasWeaponOH = true
    else
        buffCache.weaponOH.active = false
        buffs.hasWeaponOH = false
    end
    
    return buffs
end

function Consumables:HasFlaskBuff()
    local buffs = self:ScanPlayerAuras()
    return buffs.hasFlask
end

function Consumables:HasFoodBuff()
    local buffs = self:ScanPlayerAuras()
    return buffs.hasFood
end

function Consumables:HasRuneBuff()
    local buffs = self:ScanPlayerAuras()
    return buffs.hasRune
end

function Consumables:HasRogueMHPoisonBuff()
    local buffs = self:ScanPlayerAuras()
    return buffs.hasRogueMHPoison
end

function Consumables:HasRogueOHPoisonBuff()
    local buffs = self:ScanPlayerAuras()
    return buffs.hasRogueOHPoison
end

function Consumables:HasWeaponMHEnchant()
    local buffs = self:ScanPlayerAuras()
    return buffs.hasWeaponMH
end

function Consumables:HasWeaponOHEnchant()
    local buffs = self:ScanPlayerAuras()
    return buffs.hasWeaponOH
end

function Consumables:HasClassBuff()
    local buffs = self:ScanPlayerAuras()
    return buffs.hasClassBuff
end

function Consumables:PlayerHasHealthstone()
    for itemID in pairs(HEALTHSTONE_ITEM_IDS) do
        if GetItemCount(itemID, true) > 0 then
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
    
    -- Preview mode shows all icons regardless of context
    local inPreviewMode = self.db.profile.previewMode
    
    -- Check if we should show in current context (skip check in preview mode)
    if not inPreviewMode and not self:ShouldShowInCurrentContext() then
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
        
        -- In preview mode, show all enabled buffs. Otherwise check if missing
        local shouldShow
        if inPreviewMode then
            shouldShow = isEnabled
        else
            local isMissing = isEnabled and group.checkFunc(group)
            shouldShow = isMissing
        end
        
        if shouldShow then
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
        elseif msg == "debug" or msg == "cache" then
            -- Debug command to show cache state
            local now = GetTime()
            self:Print("=== Buff Cache Status ===")
            for buffType, data in pairs(buffCache) do
                local status = data.active and "ACTIVE" or "INACTIVE"
                local timeLeft = data.expiresAt > now and string.format("%.1fm", (data.expiresAt - now) / 60) or "EXPIRED"
                self:Print(string.format("%s: %s (%s)", buffType, status, timeLeft))
            end
        elseif msg == "preview" then
            -- Toggle preview mode
            self.db.profile.previewMode = not self.db.profile.previewMode
            if self.db.profile.previewMode then
                self:Print("Preview mode enabled - showing all icons")
            else
                self:Print("Preview mode disabled")
            end
            self:UpdateBuffStatus()
        else
            self:Print("Consumables Commands:")
            self:Print("/abscon show - Show tracker")
            self:Print("/abscon hide - Hide tracker")
            self:Print("/abscon toggle - Toggle visibility")
            self:Print("/abscon reset - Reset position")
            self:Print("/abscon preview - Toggle preview mode (show all icons)")
            self:Print("/abscon debug - Show buff cache status")
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
            previewMode = {
                type = "toggle",
                name = "Preview Mode",
                desc = "Show all icons regardless of buff status. Useful for previewing and customizing icons.",
                order = 15,
                width = "full",
                get = function() return self.db.profile.previewMode end,
                set = function(_, v)
                    self.db.profile.previewMode = v
                    self:UpdateBuffStatus()
                end,
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
            trackClassBuff = {
                type = "toggle",
                name = "Class/Raid Buffs",
                desc = "Track missing personal class buffs (Druid: Mark of the Wild | Priest: Power Word: Fortitude | Mage: Arcane Intellect | Warrior: Battle Shout). Only applies to these classes.",
                order = 29,
                width = "full",
                get = function() return self.db.profile.trackBuffs.class_buff end,
                set = function(_, v)
                    self.db.profile.trackBuffs.class_buff = v
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
            customizeClassBuff = {
                type = "execute",
                name = function()
                    local custom = self.db.profile.customization.class_buff
                    local icon = custom.icon or 136116
                    return string.format("|T%d:20:20:0:0:64:64:4:60:4:60|t  %s", icon, custom.label or "Buff!")
                end,
                desc = "Customize personal class buff icon and label (Druid/Priest/Mage/Warrior/Monk only)",
                order = 60,
                width = "half",
                func = function() self:ShowBuffCustomizationEditor("class_buff", "Class/Raid Buff") end,
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
