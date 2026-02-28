-- CooldownManager.lua
-- Skins and positions Blizzard's cooldown manager frames with MidnightUI styling

local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local LSM = LibStub("LibSharedMedia-3.0")

-- Create the module
local CooldownManager = MidnightUI:NewModule("CooldownManager", "AceEvent-3.0", "AceHook-3.0")

-- Module reference for global access
_G.CooldownManager = CooldownManager

--------------------------------------------------------------------------------
-- Defaults
--------------------------------------------------------------------------------

local defaults = {
    profile = {
        enabled = true,
        
        -- Essential Cooldowns
        essential = {
            enabled = true,
            position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = -200 },
            iconWidth = 44,
            iconHeight = 44,
            iconSpacing = 4,
            maxPerRow = 12,
            borderThickness = 2,
            borderColor = { 0, 0, 0, 1 },
            backgroundColor = { 0, 0, 0, 0.8 },
            font = "Friz Quadrata TT",
            fontSize = 14,
            fontFlag = "OUTLINE",
        },
        
        -- Utility Cooldowns
        utility = {
            enabled = true,
            position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = -250 },
            iconWidth = 36,
            iconHeight = 36,
            iconSpacing = 4,
            maxPerRow = 16,
            borderThickness = 2,
            borderColor = { 0, 0, 0, 1 },
            backgroundColor = { 0, 0, 0, 0.8 },
            font = "Friz Quadrata TT",
            fontSize = 12,
            fontFlag = "OUTLINE",
        },
        
        -- Font settings
        font = "Friz Quadrata TT",
        fontSize = 14,
        fontFlag = "OUTLINE",
    }
}

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function CooldownManager:OnInitialize()
    -- Setup database
    self.db = MidnightUI.db:RegisterNamespace("CooldownManager", defaults)
end

function CooldownManager:OnEnable()
    if not self.db.profile.enabled then return end
    
    -- Enable Blizzard's cooldown manager
    C_CVar.SetCVar("cooldownViewerEnabled", "1")
    
    -- Hook Blizzard's cooldown manager updates
    self:HookBlizzardCooldownManager()
    
    -- Initial styling and layout
    self:UpdateCooldownManager()
    
    -- Register events
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateCooldownManager")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "UpdateCooldownManager")
    self:RegisterEvent("SPELLS_CHANGED", "UpdateCooldownManager")
end

function CooldownManager:OnDisable()
    self:UnhookAll()
    self:UnregisterAllEvents()
end

--------------------------------------------------------------------------------
-- Blizzard Frame Hooking
--------------------------------------------------------------------------------

function CooldownManager:HookBlizzardCooldownManager()
    -- Hook when Blizzard's cooldown manager updates
    if CooldownViewerSettings then
        self:SecureHook(CooldownViewerSettings, "RefreshLayout", function()
            C_Timer.After(0.1, function()
                self:UpdateCooldownManager()
            end)
        end)
    end
    
    -- Hook Edit Mode changes
    if EditModeManagerFrame then
        self:SecureHook(EditModeManagerFrame, "EnterEditMode", "OnEditModeEnter")
        self:SecureHook(EditModeManagerFrame, "ExitEditMode", "OnEditModeExit")
    end
end

function CooldownManager:OnEditModeEnter()
    -- User is in Blizzard's Edit Mode - don't interfere
end

function CooldownManager:OnEditModeExit()
    -- Re-apply our styling after Edit Mode changes
    self:UpdateCooldownManager()
end

--------------------------------------------------------------------------------
-- Main Update Function
--------------------------------------------------------------------------------

function CooldownManager:UpdateCooldownManager()
    if not self.db.profile.enabled then return end
    if InCombatLockdown() then
        -- Queue update for after combat
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UpdateCooldownManager()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        end)
        return
    end
    
    -- Update Essential Cooldowns
    if self.db.profile.essential.enabled then
        self:UpdateViewerDisplay("EssentialCooldownViewer", "essential")
    end
    
    -- Update Utility Cooldowns
    if self.db.profile.utility.enabled then
        self:UpdateViewerDisplay("UtilityCooldownViewer", "utility")
    end
    
    -- Update Resource Bars if they're attached to Essential Cooldowns
    C_Timer.After(0.1, function()
        local ResourceBars = MidnightUI:GetModule("ResourceBars", true)
        if ResourceBars and ResourceBars.db and ResourceBars.db.profile.primary.attachToEssentialCooldowns then
            ResourceBars:UpdatePrimaryResourceBar()
        end
    end)
end

function CooldownManager:UpdateViewerDisplay(viewerName, displayType)
    local viewer = _G[viewerName]
    if not viewer then return end
    
    -- Get all child frames from Blizzard's viewer
    local children = { viewer:GetChildren() }
    
    -- Skin each visible frame
    for _, childFrame in ipairs(children) do
        if childFrame and childFrame.layoutIndex and childFrame:IsShown() then
            self:SkinBlizzardFrame(childFrame, displayType)
        end
    end
end

--------------------------------------------------------------------------------
-- Frame Styling
--------------------------------------------------------------------------------

function CooldownManager:SkinBlizzardFrame(childFrame, displayType)
    local db = self.db.profile[displayType]
    
    -- Resize the frame
    childFrame:SetSize(db.iconWidth, db.iconHeight)
    
    -- Style the icon
    if childFrame.Icon then
        childFrame.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        childFrame.Icon:ClearAllPoints()
        childFrame.Icon:SetPoint("TOPLEFT", childFrame, "TOPLEFT", db.borderThickness, -db.borderThickness)
        childFrame.Icon:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", -db.borderThickness, db.borderThickness)
    end
    
    -- Style the cooldown swipe - use dark swipe like Blizzard default
    if childFrame.Cooldown then
        childFrame.Cooldown:SetSwipeColor(0, 0, 0, 0.8)  -- Dark swipe overlay
        childFrame.Cooldown:SetDrawEdge(true)
        childFrame.Cooldown:SetDrawSwipe(true)
        childFrame.Cooldown:SetHideCountdownNumbers(false)
    end
    
    -- Add custom border if it doesn't exist
    if not childFrame.customBorder then
        childFrame.customBorder = childFrame:CreateTexture(nil, "BORDER")
        childFrame.customBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
        childFrame.customBorder:SetAllPoints(childFrame)
        childFrame.customBorder:SetVertexColor(db.borderColor[1], db.borderColor[2], db.borderColor[3], db.borderColor[4])
    end
    
    -- Add custom background
    if not childFrame.customBackground then
        childFrame.customBackground = childFrame:CreateTexture(nil, "BACKGROUND")
        childFrame.customBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
        childFrame.customBackground:SetPoint("TOPLEFT", childFrame, "TOPLEFT", db.borderThickness, -db.borderThickness)
        childFrame.customBackground:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", -db.borderThickness, db.borderThickness)
        childFrame.customBackground:SetVertexColor(db.backgroundColor[1], db.backgroundColor[2], db.backgroundColor[3], db.backgroundColor[4])
    end
    
    -- Style charge count text
    if childFrame.ChargeCount and childFrame.ChargeCount.Current then
        local fontPath = LSM:Fetch("font", db.font)
        childFrame.ChargeCount.Current:SetFont(fontPath, db.fontSize, db.fontFlag)
        childFrame.ChargeCount.Current:SetTextColor(1, 1, 1, 1)
    end
    
    -- Style application count text
    if childFrame.Applications and childFrame.Applications.Applications then
        local fontPath = LSM:Fetch("font", db.font)
        childFrame.Applications.Applications:SetFont(fontPath, db.fontSize, db.fontFlag)
        childFrame.Applications.Applications:SetTextColor(1, 1, 1, 1)
    end
    
    -- Hide elements we don't want
    if childFrame.CooldownFlash then
        childFrame.CooldownFlash:SetAlpha(0)
    end
    if childFrame.DebuffBorder then
        childFrame.DebuffBorder:SetAlpha(0)
    end
    
    -- Make sure the frame is visible
    childFrame:Show()
end

--------------------------------------------------------------------------------
-- Configuration Options
--------------------------------------------------------------------------------

function CooldownManager:GetOptions()
    return {
        type = "group",
        name = "Cooldown Manager",
        args = {
            enabled = {
                type = "toggle",
                name = "Enable Cooldown Manager",
                desc = "Enable the cooldown manager module",
                order = 1,
                get = function() return self.db.profile.enabled end,
                set = function(_, value)
                    self.db.profile.enabled = value
                    if value then
                        self:Enable()
                    else
                        self:Disable()
                    end
                end,
            },
            essentialHeader = {
                type = "header",
                name = "Essential Cooldowns",
                order = 10
            },
            essentialEnabled = {
                type = "toggle",
                name = "Enable Essential Cooldowns",
                order = 11,
                get = function() return self.db.profile.essential.enabled end,
                set = function(_, value)
                    self.db.profile.essential.enabled = value
                    self:UpdateCooldownManager()
                end,
            },
            essentialIconSize = {
                type = "range",
                name = "Essential Icon Size",
                order = 12,
                min = 24,
                max = 64,
                step = 2,
                get = function() return self.db.profile.essential.iconWidth end,
                set = function(_, value)
                    self.db.profile.essential.iconWidth = value
                    self.db.profile.essential.iconHeight = value
                    self:UpdateCooldownManager()
                end,
            },
            essentialSpacing = {
                type = "range",
                name = "Essential Icon Spacing",
                order = 13,
                min = 0,
                max = 20,
                step = 1,
                get = function() return self.db.profile.essential.iconSpacing end,
                set = function(_, value)
                    self.db.profile.essential.iconSpacing = value
                    self:UpdateCooldownManager()
                end,
            },
            essentialMaxPerRow = {
                type = "range",
                name = "Essential Icons Per Row",
                order = 14,
                min = 1,
                max = 20,
                step = 1,
                get = function() return self.db.profile.essential.maxPerRow end,
                set = function(_, value)
                    self.db.profile.essential.maxPerRow = value
                    self:UpdateCooldownManager()
                end,
            },
            utilityHeader = {
                type = "header",
                name = "Utility Cooldowns",
                order = 20
            },
            utilityEnabled = {
                type = "toggle",
                name = "Enable Utility Cooldowns",
                order = 21,
                get = function() return self.db.profile.utility.enabled end,
                set = function(_, value)
                    self.db.profile.utility.enabled = value
                    self:UpdateCooldownManager()
                end,
            },
            utilityIconSize = {
                type = "range",
                name = "Utility Icon Size",
                order = 22,
                min = 24,
                max = 64,
                step = 2,
                get = function() return self.db.profile.utility.iconWidth end,
                set = function(_, value)
                    self.db.profile.utility.iconWidth = value
                    self.db.profile.utility.iconHeight = value
                    self:UpdateCooldownManager()
                end,
            },
            utilitySpacing = {
                type = "range",
                name = "Utility Icon Spacing",
                order = 23,
                min = 0,
                max = 20,
                step = 1,
                get = function() return self.db.profile.utility.iconSpacing end,
                set = function(_, value)
                    self.db.profile.utility.iconSpacing = value
                    self:UpdateCooldownManager()
                end,
            },
            utilityMaxPerRow = {
                type = "range",
                name = "Utility Icons Per Row",
                order = 24,
                min = 1,
                max = 20,
                step = 1,
                get = function() return self.db.profile.utility.maxPerRow end,
                set = function(_, value)
                    self.db.profile.utility.maxPerRow = value
                    self:UpdateCooldownManager()
                end,
            },
        },
    }
end

return CooldownManager
