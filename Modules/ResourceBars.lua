local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local ResourceBars = MidnightUI:NewModule("ResourceBars", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- Get ColorPalette and FontKit from Framework
local ColorPalette = MidnightUI.ColorPalette
local FontKit = MidnightUI.FontKit

-- -----------------------------------------------------------------------------
-- DATABASE DEFAULTS
-- -----------------------------------------------------------------------------
local defaults = {
    profile = {
        enabled = true,
        
        -- Primary Resource Bar (Mana, Energy, Rage, etc.)
        primary = {
            enabled = true,
            locked = false,
            point = "CENTER",
            x = 0,
            y = -250,
            width = 250,
            height = 20,
            
            -- Attachment
            attachToEssentialCooldowns = false,
            attachPosition = "BELOW", -- "ABOVE" or "BELOW"
            attachSpacing = 2, -- Spacing from Essential Cooldowns
            
            -- Appearance
            texture = "Blizzard",
            showBorder = true,
            showBackground = true,
            alpha = 1.0,
            
            -- Colors (nil = use class/power type color)
            customColor = nil,
            backgroundColor = {0, 0, 0, 0.5},
            borderColor = {0, 0, 0, 1},
            
            -- Text
            showText = true,
            showPercentage = false, -- Show percentage instead of current/max values
            textFormat = "[curpp] / [maxpp]",
            font = "Friz Quadrata TT",
            fontSize = 12,
            fontOutline = "OUTLINE",
        },
        
        -- Secondary Resource Bar (Holy Power, Chi, Runes, etc.)
        secondary = {
            enabled = true,
            locked = false,
            point = "CENTER",
            x = 0,
            y = -280,
            width = 250,
            height = 12,
            
            -- Attachment
            attachToPrimary = false,
            attachPosition = "BELOW", -- "ABOVE" or "BELOW"
            attachSpacing = 2, -- Spacing between bars when attached
            
            -- Appearance
            showBorder = true,
            showBackground = true,
            alpha = 1.0,
            
            -- Segment Display (for combo points, runes, etc.)
            segmentSpacing = 2,
            
            -- Colors
            customColor = nil,
            backgroundColor = {0, 0, 0, 0.5},
            borderColor = {0, 0, 0, 1},
        }
    }
}

-- -----------------------------------------------------------------------------
-- HELPER FUNCTIONS
-- -----------------------------------------------------------------------------
function ResourceBars:GetEssentialCooldownsWidth()
    local viewer = _G["EssentialCooldownViewer"]
    if not viewer or not viewer:IsShown() then return nil end
    
    -- Simply return the actual width of Blizzard's viewer frame
    local width = viewer:GetWidth()
    
    -- Ensure we have a valid width
    if width and width > 0 then
        return width
    end
    
    return nil
end

-- -----------------------------------------------------------------------------
-- INITIALIZATION
-- -----------------------------------------------------------------------------
function ResourceBars:OnInitialize()
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "OnDBReady")
end

function ResourceBars:OnDBReady()
    if not MidnightUI.db or not MidnightUI.db.profile or not MidnightUI.db.profile.modules.resourceBars then
        self:Disable()
        return
    end
    
    self.db = MidnightUI.db:RegisterNamespace("ResourceBars", defaults)
    
    -- Register events
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_POWER_UPDATE")
    self:RegisterEvent("UNIT_MAXPOWER")
    self:RegisterEvent("UNIT_DISPLAYPOWER")
    self:RegisterEvent("UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    
    -- For secondary resources (combo points, runes, chi, etc.)
    self:RegisterEvent("UNIT_POWER_POINT_CHARGE")
    self:RegisterEvent("RUNE_POWER_UPDATE")
    
    -- Register for Move Mode changes
    self:RegisterMessage("MIDNIGHTUI_MOVEMODE_CHANGED", "OnMoveModeChanged")
    
    -- If player is already in world, set up immediately
    if IsPlayerInWorld and IsPlayerInWorld() then
        C_Timer.After(0.5, function()
            self:SetupPrimaryResourceBar()
            self:SetupSecondaryResourceBar()
        end)
    end
end

function ResourceBars:PLAYER_ENTERING_WORLD()
    C_Timer.After(0.5, function()
        if self.db and self.db.profile then
            self:SetupPrimaryResourceBar()
            self:SetupSecondaryResourceBar()
            
            -- Trigger cooldowns attachment update after bars are created
            C_Timer.After(0.5, function()
                local CooldownManager = MidnightUI:GetModule("CooldownManager", true)
                if CooldownManager then
                    CooldownManager:UpdateCooldownManager()
                end
            end)
        end
    end)
end

function ResourceBars:PLAYER_SPECIALIZATION_CHANGED()
    -- Recreate secondary bar when spec changes (different specs may use different resources)
    if self.secondaryBar then
        self.secondaryBar:Hide()
        self.secondaryBar = nil
    end
    
    C_Timer.After(0.2, function()
        if self.db and self.db.profile then
            self:SetupSecondaryResourceBar()
        end
    end)
end

-- -----------------------------------------------------------------------------
-- PRIMARY RESOURCE BAR (Mana, Energy, Rage, Focus, etc.)
-- -----------------------------------------------------------------------------
function ResourceBars:SetupPrimaryResourceBar()
    if not self.db.profile.primary.enabled then 
        return 
    end
    
    -- Always recreate the bar to ensure proper sizing
    if self.primaryBar then
        self.primaryBar:Hide()
        self.primaryBar = nil
    end
    
    local db = self.db.profile.primary
    
    -- Calculate width based on attachment
    local barWidth = db.width
    if db.attachToEssentialCooldowns then
        local cooldownWidth = self:GetEssentialCooldownsWidth()
        if cooldownWidth then
            barWidth = cooldownWidth
        end
    end
    
    -- Create main frame
    local frame = CreateFrame("Frame", "MidnightUI_PrimaryResourceBar", UIParent, "BackdropTemplate")
    frame:SetSize(barWidth, db.height)
    
    -- Set position based on attachment
    if db.attachToEssentialCooldowns then
        local viewer = _G["EssentialCooldownViewer"]
        if viewer then
            frame:ClearAllPoints()
            if db.attachPosition == "ABOVE" then
                frame:SetPoint("BOTTOM", viewer, "TOP", 0, db.attachSpacing)
            else -- "BELOW"
                frame:SetPoint("TOP", viewer, "BOTTOM", 0, -db.attachSpacing)
            end
        else
            frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
        end
    else
        frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    end
    frame:SetMovable(true)
    frame:EnableMouse(false)
    frame:SetClampedToScreen(true)
    
    -- Backdrop
    frame:SetBackdrop({
        bgFile = db.showBackground and "Interface\\Buttons\\WHITE8X8" or nil,
        edgeFile = db.showBorder and "Interface\\Buttons\\WHITE8X8" or nil,
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    frame:SetBackdropColor(unpack(db.backgroundColor))
    frame:SetBackdropBorderColor(unpack(db.borderColor))
    
    -- Status bar
    local statusBar = CreateFrame("StatusBar", nil, frame)
    statusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    statusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    statusBar:SetStatusBarTexture(LSM:Fetch("statusbar", db.texture))
    statusBar:SetMinMaxValues(0, 100)
    statusBar:SetValue(100)
    statusBar:SetAlpha(db.alpha)
    
    -- Text
    if db.showText then
        local text = statusBar:CreateFontString(nil, "OVERLAY")
        text:SetPoint("CENTER")
        local font = LSM:Fetch("font", db.font)
        text:SetFont(font, db.fontSize, db.fontOutline)
        text:SetTextColor(1, 1, 1, 1)
        text:SetShadowOffset(1, -1)
        text:SetShadowColor(0, 0, 0, 1)
        statusBar.text = text
    end
    
    frame.statusBar = statusBar
    self.primaryBar = frame
    
    -- Create green highlight overlay for move mode (parented to UIParent to avoid alpha inheritance)
    frame.movableHighlightFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame.movableHighlightFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame.movableHighlightFrame:SetFrameLevel(10000)
    frame.movableHighlightFrame:SetAllPoints(frame)
    frame.movableHighlightFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame.movableHighlightFrame:SetBackdropColor(0, 0.5, 0, 0.2)
    frame.movableHighlightFrame:SetBackdropBorderColor(0, 1, 0, 1)
    frame.movableHighlightFrame:Hide()
    
    -- Create label text on overlay frame
    frame.movableLabel = frame.movableHighlightFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.movableLabel:SetPoint("CENTER")
    frame.movableLabel:SetText("Primary Resource Bar")
    frame.movableLabel:SetTextColor(1, 1, 1, 1)
    frame.movableLabel:SetShadowOffset(2, -2)
    frame.movableLabel:SetShadowColor(0, 0, 0, 1)
    
    frame:Show()
    
    -- Setup dragging
    self:SetupDragging(frame, "primary")
    
    -- Add nudge arrows
    local Movable = MidnightUI:GetModule("Movable")
    if Movable and Movable.CreateNudgeArrows then
        Movable:CreateNudgeArrows(frame, db, function()
            -- Reset callback: center the frame
            db.point = "CENTER"
            db.x = 0
            db.y = 0
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end)
    end
    
    -- Set initial color based on power type
    local powerType = UnitPowerType("player")
    if db.customColor then
        statusBar:SetStatusBarColor(unpack(db.customColor))
    else
        local info = PowerBarColor[powerType]
        if info then
            statusBar:SetStatusBarColor(info.r, info.g, info.b)
        end
    end
    
    -- Call update after a short delay to populate values safely
    C_Timer.After(0.1, function()
        self:UpdatePrimaryResourceBar()
    end)
end

function ResourceBars:UpdatePrimaryResourceBar()
    if not self.primaryBar or not self.primaryBar:IsShown() then return end
    
    local db = self.db.profile.primary
    local statusBar = self.primaryBar.statusBar
    
    -- Update width if attached to Essential Cooldowns
    if db.attachToEssentialCooldowns then
        local cooldownWidth = self:GetEssentialCooldownsWidth()
        if cooldownWidth and cooldownWidth ~= self.primaryBar:GetWidth() then
            self.primaryBar:SetWidth(cooldownWidth)
            -- Update secondary bar width if it's attached to primary
            if self.secondaryBar and self.db.profile.secondary.attachToPrimary then
                self.secondaryBar:SetWidth(cooldownWidth)
                if self.secondaryBar.resourceType then
                    self:CreateSecondarySegments()
                end
            end
        end
    end
    
    -- Get power type and values
    local powerType = UnitPowerType("player")
    local current = UnitPower("player", powerType)
    local maximum = UnitPowerMax("player", powerType)
    
    -- Safety check - if values aren't ready yet, skip update
    if not current or not maximum then return end
    
    -- Update bar (safe to use secrets with SetValue/SetMinMaxValues)
    statusBar:SetMinMaxValues(0, maximum)
    statusBar:SetValue(current)
    
    -- Set color
    if db.customColor then
        statusBar:SetStatusBarColor(unpack(db.customColor))
    else
        -- Use power type color
        local info = PowerBarColor[powerType]
        if info then
            statusBar:SetStatusBarColor(info.r, info.g, info.b)
        end
    end
    
    -- Update text - pass secret values directly without converting
    if db.showText and statusBar.text then
        if db.showPercentage then
            -- Use UnitPowerPercent but format to remove decimals
            local percentage
            if UnitPowerPercent and CurveConstants and CurveConstants.ScaleTo100 then
                percentage = UnitPowerPercent("player", powerType, false, CurveConstants.ScaleTo100)
            end
            
            -- Display percentage with format string that rounds to integer
            if percentage then
                statusBar.text:SetFormattedText("%.0f%%", percentage)
            else
                statusBar.text:SetText("0%")
            end
        else
            -- Show current / max values
            statusBar.text:SetText(current .. " / " .. maximum)
        end
    end
end

-- -----------------------------------------------------------------------------
-- SECONDARY RESOURCE BAR (Holy Power, Chi, Runes, Combo Points, etc.)
-- -----------------------------------------------------------------------------
function ResourceBars:SetupSecondaryResourceBar()
    if not self.db.profile.secondary.enabled then 
        return 
    end
    
    -- Complete resource table for all classes and specs
    local Resources = {
        DEATHKNIGHT = {
            Blood      = { primary = "RUNIC_POWER", secondary = "RUNES" },
            Frost      = { primary = "RUNIC_POWER", secondary = "RUNES" },
            Unholy     = { primary = "RUNIC_POWER", secondary = "RUNES" },
        },
        DEMONHUNTER = {
            Havoc      = { primary = "FURY",        secondary = nil },
            Vengeance  = { primary = "PAIN",        secondary = nil },
            Devourer   = { primary = "FURY",        secondary = nil },
        },
        DRUID = {
            Balance    = { primary = "MANA",        secondary = "LUNAR_POWER" },
            Feral      = { primary = "ENERGY",      secondary = "COMBO_POINTS" },
            Guardian   = { primary = "RAGE",        secondary = nil },
            Restoration= { primary = "MANA",        secondary = nil },
        },
        EVOKER = {
            Devastation  = { primary = "MANA",      secondary = "ESSENCE" },
            Preservation = { primary = "MANA",      secondary = "ESSENCE" },
            Augmentation = { primary = "MANA",      secondary = "ESSENCE" },
        },
        HUNTER = {
            BeastMastery = { primary = "FOCUS",     secondary = nil },
            Marksmanship = { primary = "FOCUS",     secondary = nil },
            Survival     = { primary = "FOCUS",     secondary = nil },
        },
        MAGE = {
            Arcane     = { primary = "MANA",        secondary = "ARCANE_CHARGES" },
            Fire       = { primary = "MANA",        secondary = nil },
            Frost      = { primary = "MANA",        secondary = nil },
        },
        MONK = {
            Brewmaster = { primary = "ENERGY",      secondary = "STAGGER" },
            Mistweaver = { primary = "MANA",        secondary = nil },
            Windwalker = { primary = "ENERGY",      secondary = "CHI" },
        },
        PALADIN = {
            Holy       = { primary = "MANA",        secondary = "HOLY_POWER" },
            Protection = { primary = "MANA",        secondary = "HOLY_POWER" },
            Retribution= { primary = "MANA",        secondary = "HOLY_POWER" },
        },
        PRIEST = {
            Discipline = { primary = "MANA",        secondary = nil },
            Holy       = { primary = "MANA",        secondary = nil },
            Shadow     = { primary = "INSANITY",    secondary = nil },
        },
        ROGUE = {
            Assassination = { primary = "ENERGY",   secondary = "COMBO_POINTS" },
            Outlaw        = { primary = "ENERGY",   secondary = "COMBO_POINTS" },
            Subtlety      = { primary = "ENERGY",   secondary = "COMBO_POINTS" },
        },
        SHAMAN = {
            Elemental   = { primary = "MANA",       secondary = "MAELSTROM" },
            Enhancement = { primary = "MANA",       secondary = "MAELSTROM" },
            Restoration = { primary = "MANA",       secondary = nil },
        },
        WARLOCK = {
            Affliction  = { primary = "MANA",       secondary = "SOUL_SHARDS" },
            Demonology  = { primary = "MANA",       secondary = "SOUL_SHARDS" },
            Destruction = { primary = "MANA",       secondary = "SOUL_SHARDS" },
        },
        WARRIOR = {
            Arms       = { primary = "RAGE",        secondary = nil },
            Fury       = { primary = "RAGE",        secondary = nil },
            Protection = { primary = "RAGE",        secondary = nil },
        },
    }
    
    -- Map resource string names to Enum.PowerType values
    local powerTypeMap = {
        ARCANE_CHARGES = Enum.PowerType.ArcaneCharges,
        CHI = Enum.PowerType.Chi,
        COMBO_POINTS = Enum.PowerType.ComboPoints,
        ESSENCE = Enum.PowerType.Essence,
        HOLY_POWER = Enum.PowerType.HolyPower,
        LUNAR_POWER = Enum.PowerType.LunarPower,
        MAELSTROM = Enum.PowerType.Maelstrom,
        RUNES = Enum.PowerType.Runes,
        SOUL_SHARDS = Enum.PowerType.SoulShards,
        STAGGER = 20, -- Stagger is a special case, may need different handling
    }
    
    -- Get current class and spec
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization()
    if not specIndex then
        if self.secondaryBar then
            self.secondaryBar:Hide()
        end
        return
    end
    
    -- Get spec name
    local specID, specName = GetSpecializationInfo(specIndex)
    if not specName then
        if self.secondaryBar then
            self.secondaryBar:Hide()
        end
        return
    end
    
    -- Remove spaces from spec name to match table keys
    specName = specName:gsub("%s+", "")
    
    -- Look up the secondary resource for this class/spec
    local resourceType = nil
    if Resources[class] and Resources[class][specName] then
        local secondaryName = Resources[class][specName].secondary
        if secondaryName and powerTypeMap[secondaryName] then
            resourceType = powerTypeMap[secondaryName]
        end
    end
    
    -- If no secondary resource for this spec, hide the bar if it exists and exit
    if not resourceType then
        if self.secondaryBar then
            self.secondaryBar:Hide()
        end
        return
    end
    
    if self.secondaryBar then
        -- Check if resource type changed - if so, recreate the bar
        if self.secondaryBar.resourceType ~= resourceType then
            self.secondaryBar:Hide()
            self.secondaryBar = nil
            -- Continue to create new bar below
        else
            -- Update position if attachment settings changed
            local db = self.db.profile.secondary
            self.secondaryBar:ClearAllPoints()
            if db.attachToPrimary and self.primaryBar then
                if db.attachPosition == "ABOVE" then
                    self.secondaryBar:SetPoint("BOTTOM", self.primaryBar, "TOP", 0, db.attachSpacing)
                else -- "BELOW"
                    self.secondaryBar:SetPoint("TOP", self.primaryBar, "BOTTOM", 0, -db.attachSpacing)
                end
            else
                self.secondaryBar:SetPoint(db.point, UIParent, db.point, db.x, db.y)
            end
            self:UpdateSecondaryResourceBar()
            return
        end
    end
    
    local db = self.db.profile.secondary
    
    -- Create main frame
    local frame = CreateFrame("Frame", "MidnightUI_SecondaryResourceBar", UIParent, "BackdropTemplate")
    frame:SetSize(db.width, db.height)
    
    -- Set position and width based on attachment setting
    if db.attachToPrimary and self.primaryBar then
        frame:ClearAllPoints()
        if db.attachPosition == "ABOVE" then
            frame:SetPoint("BOTTOM", self.primaryBar, "TOP", 0, db.attachSpacing)
        else -- "BELOW"
            frame:SetPoint("TOP", self.primaryBar, "BOTTOM", 0, -db.attachSpacing)
        end
        -- Match primary bar width
        frame:SetSize(self.primaryBar:GetWidth(), db.height)
    else
        frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    end
    
    frame:SetMovable(true)
    frame:EnableMouse(false)
    frame:SetClampedToScreen(true)
    
    -- Backdrop
    if db.showBackground then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = db.showBorder and "Interface\\Buttons\\WHITE8X8" or nil,
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        frame:SetBackdropColor(unpack(db.backgroundColor))
        frame:SetBackdropBorderColor(unpack(db.borderColor))
    end
    
    frame.resourceType = resourceType
    frame.segments = {}
    self.secondaryBar = frame
    
    -- Create green highlight overlay for move mode (parented to UIParent to avoid alpha inheritance)
    frame.movableHighlightFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame.movableHighlightFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame.movableHighlightFrame:SetFrameLevel(10000)
    frame.movableHighlightFrame:SetAllPoints(frame)
    frame.movableHighlightFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame.movableHighlightFrame:SetBackdropColor(0, 0.5, 0, 0.2)
    frame.movableHighlightFrame:SetBackdropBorderColor(0, 1, 0, 1)
    frame.movableHighlightFrame:Hide()
    
    -- Create label text on overlay frame
    frame.movableLabel = frame.movableHighlightFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.movableLabel:SetPoint("CENTER")
    frame.movableLabel:SetText("Secondary Resource Bar")
    frame.movableLabel:SetTextColor(1, 1, 1, 1)
    frame.movableLabel:SetShadowOffset(2, -2)
    frame.movableLabel:SetShadowColor(0, 0, 0, 1)
    
    -- Create segments
    self:CreateSecondarySegments()
    
    -- Setup dragging
    self:SetupDragging(frame, "secondary")
    
    -- Add nudge arrows
    local Movable = MidnightUI:GetModule("Movable")
    if Movable and Movable.CreateNudgeArrows then
        Movable:CreateNudgeArrows(frame, db, function()
            -- Reset callback: center the frame
            db.point = "CENTER"
            db.x = 0
            db.y = 0
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end)
    end
    
    -- Don't call update here - let the events handle it once player data is loaded
end

function ResourceBars:CreateSecondarySegments()
    if not self.secondaryBar then return end
    
    local frame = self.secondaryBar
    local db = self.db.profile.secondary
    local maxPower = UnitPowerMax("player", frame.resourceType)
    
    if maxPower == 0 then maxPower = 6 end -- Default fallback
    
    -- Clear existing segments
    if frame.segments then
        for _, segment in ipairs(frame.segments) do
            segment:Hide()
            segment:SetParent(nil)
        end
    end
    frame.segments = {}
    
    -- Use actual frame width, not db.width (important for attached bars)
    local frameWidth = frame:GetWidth()
    local segmentWidth = (frameWidth - (db.segmentSpacing * (maxPower - 1)) - 2) / maxPower
    
    for i = 1, maxPower do
        local segment = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        segment:SetSize(segmentWidth, db.height - 2)
        segment:SetPoint("LEFT", frame, "LEFT", ((i - 1) * (segmentWidth + db.segmentSpacing)) + 1, 0)
        
        segment:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        
        -- Get color from power bar color or use class color
        local r, g, b = 0.5, 0.5, 0.5
        if db.customColor then
            r, g, b = unpack(db.customColor)
        else
            local info = PowerBarColor[frame.resourceType]
            if info then
                r, g, b = info.r, info.g, info.b
            end
        end
        
        segment:SetBackdropColor(r * 0.3, g * 0.3, b * 0.3, 0.5)
        segment:SetBackdropBorderColor(0, 0, 0, 1)
        
        segment.activeColor = {r, g, b}
        segment.inactiveColor = {r * 0.3, g * 0.3, b * 0.3}
        
        table.insert(frame.segments, segment)
    end
end

function ResourceBars:UpdateSecondaryResourceBar()
    if not self.secondaryBar or not self.secondaryBar:IsShown() then return end
    
    local frame = self.secondaryBar
    local current = UnitPower("player", frame.resourceType)
    
    for i, segment in ipairs(frame.segments) do
        if i <= current then
            segment:SetBackdropColor(segment.activeColor[1], segment.activeColor[2], segment.activeColor[3], 1)
        else
            segment:SetBackdropColor(segment.inactiveColor[1], segment.inactiveColor[2], segment.inactiveColor[3], 0.5)
        end
    end
end

-- -----------------------------------------------------------------------------
-- EVENT HANDLERS
-- -----------------------------------------------------------------------------
function ResourceBars:UNIT_POWER_UPDATE(event, unit, powerType)
    if unit ~= "player" then return end
    self:UpdatePrimaryResourceBar()
    self:UpdateSecondaryResourceBar()
end

function ResourceBars:UNIT_MAXPOWER(event, unit, powerType)
    if unit ~= "player" then return end
    self:UpdatePrimaryResourceBar()
end

function ResourceBars:UNIT_DISPLAYPOWER(event, unit)
    if unit ~= "player" then return end
    self:UpdatePrimaryResourceBar()
end

function ResourceBars:UNIT_POWER_POINT_CHARGE(event, unit)
    if unit ~= "player" then return end
    self:UpdateSecondaryResourceBar()
end

function ResourceBars:RUNE_POWER_UPDATE()
    self:UpdateSecondaryResourceBar()
end

-- -----------------------------------------------------------------------------
-- DRAGGING SUPPORT
-- -----------------------------------------------------------------------------
function ResourceBars:SetupDragging(frame, barType)
    if not frame then return end
    
    local Movable = MidnightUI:GetModule("Movable")
    
    Movable:MakeFrameDraggable(
        frame,
        function(point, x, y)
            ResourceBars.db.profile[barType].point = point
            ResourceBars.db.profile[barType].x = x
            ResourceBars.db.profile[barType].y = y
        end,
        nil
    )
end

function ResourceBars:OnMoveModeChanged(event, enabled)
    local Movable = MidnightUI:GetModule("Movable")
    
    if self.primaryBar then
        self.primaryBar:EnableMouse(enabled)
        if enabled then
            self.primaryBar:SetAlpha(0.3)
            self.primaryBar.movableHighlightFrame:Show()
            if Movable and Movable.UpdateNudgeArrows then
                Movable:UpdateNudgeArrows(self.primaryBar)
            end
        else
            self.primaryBar:SetAlpha(1.0)
            self.primaryBar.movableHighlightFrame:Hide()
            if Movable and Movable.HideNudgeArrows then
                Movable:HideNudgeArrows(self.primaryBar)
            end
        end
    end
    if self.secondaryBar then
        self.secondaryBar:EnableMouse(enabled)
        if enabled then
            self.secondaryBar:SetAlpha(0.3)
            self.secondaryBar.movableHighlightFrame:Show()
            if Movable and Movable.UpdateNudgeArrows then
                Movable:UpdateNudgeArrows(self.secondaryBar)
            end
        else
            self.secondaryBar:SetAlpha(1.0)
            self.secondaryBar.movableHighlightFrame:Hide()
            if Movable and Movable.HideNudgeArrows then
                Movable:HideNudgeArrows(self.secondaryBar)
            end
        end
    end
end

-- -----------------------------------------------------------------------------
-- OPTIONS
-- -----------------------------------------------------------------------------
function ResourceBars:GetOptions()
    return {
        type = "group",
        name = "Resource Bars",
        order = 11,
        args = {
            header = {
                type = "header",
                name = "Resource Bars",
                order = 1
            },
            desc = {
                type = "description",
                name = "Display primary and secondary resource bars for your class.\n\nHold CTRL+ALT to drag, or use /muimove to enable Move Mode.",
                order = 2
            },
            
            -- Primary Resource Bar
            primaryHeader = { type = "header", name = "Primary Resource Bar", order = 10},
            primaryEnabled = {
                name = "Enable Primary Resource Bar",
                type = "toggle",
                order = 11,
                get = function() return self.db.profile.primary.enabled end,
                set = function(_, v)
                    self.db.profile.primary.enabled = v
                    if v then
                        self:SetupPrimaryResourceBar()
                    elseif self.primaryBar then
                        self.primaryBar:Hide()
                        self.primaryBar = nil
                    end
                end
            },
            primaryWidth = {
                name = "Width",
                type = "range",
                order = 12,
                min = 100,
                max = 500,
                step = 1,
                disabled = function() return not self.db.profile.primary.enabled end,
                get = function() return self.db.profile.primary.width end,
                set = function(_, v)
                    self.db.profile.primary.width = v
                    if self.primaryBar then
                        self.primaryBar:SetWidth(v)
                    end
                end
            },
            primaryHeight = {
                name = "Height",
                type = "range",
                order = 13,
                min = 10,
                max = 50,
                step = 1,
                disabled = function() return not self.db.profile.primary.enabled end,
                get = function() return self.db.profile.primary.height end,
                set = function(_, v)
                    self.db.profile.primary.height = v
                    if self.primaryBar then
                        self.primaryBar:SetHeight(v)
                    end
                end
            },
            primaryShowText = {
                name = "Show Text",
                type = "toggle",
                order = 14,
                disabled = function() return not self.db.profile.primary.enabled end,
                get = function() return self.db.profile.primary.showText end,
                set = function(_, v)
                    self.db.profile.primary.showText = v
                    if self.primaryBar and self.primaryBar.statusBar.text then
                        if v then
                            self.primaryBar.statusBar.text:Show()
                            self:UpdatePrimaryResourceBar()
                        else
                            self.primaryBar.statusBar.text:Hide()
                        end
                    end
                end
            },
            primaryShowPercentage = {
                name = "Show Percentage",
                desc = "Display resource as percentage instead of current/max values.",
                type = "toggle",
                order = 15,
                disabled = function() return not self.db.profile.primary.enabled or not self.db.profile.primary.showText end,
                get = function() return self.db.profile.primary.showPercentage end,
                set = function(_, v)
                    self.db.profile.primary.showPercentage = v
                    if self.primaryBar then
                        self:UpdatePrimaryResourceBar()
                    end
                end
            },
            primaryAttachToEssentialCooldowns = {
                name = "Attach to Essential Cooldowns",
                desc = "Automatically position and size the primary bar to match Essential Cooldowns width.",
                type = "toggle",
                order = 16,
                disabled = function() return not self.db.profile.primary.enabled end,
                get = function() return self.db.profile.primary.attachToEssentialCooldowns end,
                set = function(_, v)
                    self.db.profile.primary.attachToEssentialCooldowns = v
                    if self.primaryBar then
                        self.primaryBar:Hide()
                        self.primaryBar = nil
                        self:SetupPrimaryResourceBar()
                        if self.secondaryBar then
                            self.secondaryBar:Hide()
                            self.secondaryBar = nil
                            self:SetupSecondaryResourceBar()
                        end
                    end
                end
            },
            primaryAttachPosition = {
                name = "Attach Position",
                desc = "Position the primary bar above or below Essential Cooldowns.",
                type = "select",
                order = 17,
                disabled = function() return not self.db.profile.primary.enabled or not self.db.profile.primary.attachToEssentialCooldowns end,
                values = {
                    ["ABOVE"] = "Above",
                    ["BELOW"] = "Below"
                },
                get = function() return self.db.profile.primary.attachPosition end,
                set = function(_, v)
                    self.db.profile.primary.attachPosition = v
                    if self.primaryBar then
                        self.primaryBar:Hide()
                        self.primaryBar = nil
                        self:SetupPrimaryResourceBar()
                        if self.secondaryBar then
                            self.secondaryBar:Hide()
                            self.secondaryBar = nil
                            self:SetupSecondaryResourceBar()
                        end
                    end
                end
            },
            primaryAttachSpacing = {
                name = "Attach Spacing",
                desc = "Spacing between primary bar and Essential Cooldowns when attached.",
                type = "range",
                order = 18,
                min = 0,
                max = 20,
                step = 1,
                disabled = function() return not self.db.profile.primary.enabled or not self.db.profile.primary.attachToEssentialCooldowns end,
                get = function() return self.db.profile.primary.attachSpacing end,
                set = function(_, v)
                    self.db.profile.primary.attachSpacing = v
                    if self.primaryBar then
                        self.primaryBar:Hide()
                        self.primaryBar = nil
                        self:SetupPrimaryResourceBar()
                        if self.secondaryBar then
                            self.secondaryBar:Hide()
                            self.secondaryBar = nil
                            self:SetupSecondaryResourceBar()
                        end
                    end
                end
            },
            
            -- Secondary Resource Bar
            secondaryHeader = { type = "header", name = "Secondary Resource Bar", order = 20},
            secondaryEnabled = {
                name = "Enable Secondary Resource Bar",
                type = "toggle",
                order = 21,
                get = function() return self.db.profile.secondary.enabled end,
                set = function(_, v)
                    self.db.profile.secondary.enabled = v
                    if v then
                        self:SetupSecondaryResourceBar()
                    elseif self.secondaryBar then
                        self.secondaryBar:Hide()
                        self.secondaryBar = nil
                    end
                end
            },
            secondaryWidth = {
                name = "Width",
                type = "range",
                order = 22,
                min = 100,
                max = 500,
                step = 1,
                disabled = function() return not self.db.profile.secondary.enabled end,
                get = function() return self.db.profile.secondary.width end,
                set = function(_, v)
                    self.db.profile.secondary.width = v
                    if self.secondaryBar then
                        self.secondaryBar:SetWidth(v)
                        self:CreateSecondarySegments()
                    end
                end
            },
            secondaryHeight = {
                name = "Height",
                type = "range",
                order = 23,
                min = 8,
                max = 30,
                step = 1,
                disabled = function() return not self.db.profile.secondary.enabled end,
                get = function() return self.db.profile.secondary.height end,
                set = function(_, v)
                    self.db.profile.secondary.height = v
                    if self.secondaryBar then
                        self.secondaryBar:SetHeight(v)
                        self:CreateSecondarySegments()
                    end
                end
            },
            secondaryAttach = {
                name = "Attach to Primary Bar",
                desc = "Automatically position the secondary bar relative to the primary bar.",
                type = "toggle",
                order = 24,
                disabled = function() return not self.db.profile.secondary.enabled end,
                get = function() return self.db.profile.secondary.attachToPrimary end,
                set = function(_, v)
                    self.db.profile.secondary.attachToPrimary = v
                    if self.secondaryBar then
                        self:SetupSecondaryResourceBar()
                    end
                end
            },
            secondaryAttachPosition = {
                name = "Attach Position",
                desc = "Position the secondary bar above or below the primary bar.",
                type = "select",
                order = 25,
                disabled = function() return not self.db.profile.secondary.enabled or not self.db.profile.secondary.attachToPrimary end,
                values = {
                    ["ABOVE"] = "Above",
                    ["BELOW"] = "Below"
                },
                get = function() return self.db.profile.secondary.attachPosition end,
                set = function(_, v)
                    self.db.profile.secondary.attachPosition = v
                    if self.secondaryBar then
                        self:SetupSecondaryResourceBar()
                    end
                end
            },
            secondaryAttachSpacing = {
                name = "Attach Spacing",
                desc = "Spacing between primary and secondary bars when attached.",
                type = "range",
                order = 26,
                min = 0,
                max = 20,
                step = 1,
                disabled = function() return not self.db.profile.secondary.enabled or not self.db.profile.secondary.attachToPrimary end,
                get = function() return self.db.profile.secondary.attachSpacing end,
                set = function(_, v)
                    self.db.profile.secondary.attachSpacing = v
                    if self.secondaryBar then
                        self:SetupSecondaryResourceBar()
                    end
                end
            },
        }
    }
end
