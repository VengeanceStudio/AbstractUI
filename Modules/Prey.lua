local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local Prey = AbstractUI:NewModule("Prey", "AceEvent-3.0")

-- ============================================================================
-- PREY ICON MANAGER
-- Manages the draggable Prey icon (UIWidgetPowerBarContainerFrame)
-- Widget ID 7663 for the Prey tracking icon
-- ============================================================================

-- Database defaults
local defaults = {
    profile = {
        enabled = true,
        position = nil, -- Stores {point, relativePoint, x, y}
    }
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function Prey:OnInitialize()
    -- Initialize database
    self.db = AbstractUI.db:RegisterNamespace("Prey", defaults)
end

function Prey:OnEnable()
    if not self.db.profile.enabled then return end
    
    -- UIWidget frames are created dynamically, so we need multiple attempts
    -- Try every 2 seconds for the first 20 seconds
    for i = 1, 10 do
        C_Timer.After(i * 2, function()
            self:MakePreyIconDraggable()
        end)
    end
    
    -- Also hook PLAYER_ENTERING_WORLD for zone changes
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function Prey:PLAYER_ENTERING_WORLD()
    -- Try to make the Prey icon draggable when entering a new zone
    C_Timer.After(2, function()
        self:MakePreyIconDraggable()
    end)
    C_Timer.After(5, function()
        self:MakePreyIconDraggable()
    end)
end

-- ============================================================================
-- DRAGGABLE PREY ICON
-- ============================================================================

function Prey:MakePreyIconDraggable()
    local frame = _G["UIWidgetPowerBarContainerFrame"]
    if not frame then return end
    
    -- Skip if already made draggable
    if frame.AbstractUI_PreyDraggable then return end
    
    -- Make frame movable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    
    -- Register for dragging on left mouse button
    frame:RegisterForDrag("LeftButton")
    
    -- Set up drag scripts
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, x, y = self:GetPoint()
        if not Prey.db then return end
        Prey.db.profile.position = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end)
    
    -- Mark as draggable
    frame.AbstractUI_PreyDraggable = true
    
    -- Restore saved position if it exists
    if self.db.profile.position then
        local pos = self.db.profile.position
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
    
    -- Hook OnShow to restore position (UIWidgets get repositioned by Blizzard)
    frame:HookScript("OnShow", function(self)
        if Prey.db and Prey.db.profile.position then
            C_Timer.After(0, function()
                if not self then return end
                local pos = Prey.db.profile.position
                self:ClearAllPoints()
                self:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
            end)
        end
    end)
end

-- ============================================================================
-- RESET POSITION
-- ============================================================================

function Prey:ResetPosition()
    self.db.profile.position = nil
    
    local frame = _G["UIWidgetPowerBarContainerFrame"]
    if frame then
        -- Clear all points and let Blizzard reposition it
        frame:ClearAllPoints()
        -- Force a UI reload or re-show
        if frame:IsShown() then
            frame:Hide()
            C_Timer.After(0.1, function()
                frame:Show()
            end)
        end
    end
end

-- ============================================================================
-- OPTIONS
-- ============================================================================

function Prey:GetOptions()
    return {
        type = "group",
        name = "Prey Icon",
        args = {
            enabled = {
                name = "Enable Prey Icon Manager",
                desc = "Enable dragging and managing the Prey tracking icon",
                type = "toggle",
                order = 1,
                get = function() return self.db.profile.enabled end,
                set = function(_, value)
                    self.db.profile.enabled = value
                    if value then
                        self:OnEnable()
                    end
                end,
            },
            reset = {
                name = "Reset Position",
                desc = "Reset the Prey icon to its default position",
                type = "execute",
                order = 2,
                func = function()
                    self:ResetPosition()
                end,
            },
            description = {
                name = "The Prey tracking icon appears in certain zones during events. This module allows you to drag it to a custom position that will be remembered.",
                type = "description",
                order = 3,
            },
        }
    }
end
