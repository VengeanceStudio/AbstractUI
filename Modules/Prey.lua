local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local Prey = AbstractUI:NewModule("Prey", "AceEvent-3.0")

-- ============================================================================
-- PREY ICON MANAGER
-- Manages the draggable Prey icon (UIWidgetPowerBarContainerFrame)
-- Widget ID 7663 for the Prey tracking icon
-- ============================================================================

-- Progress text reference
local percentText = nil
local preyCount = 0
local preyMax = 0

-- Database defaults
local defaults = {
    profile = {
        enabled = true,
        position = nil, -- Stores {point, relativePoint, x, y}
        showPercent = true,
        percentFontSize = 14,
    }
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function Prey:OnInitialize()
    -- Initialize database
    self.db = AbstractUI.db:RegisterNamespace("Prey", defaults)
    
    -- Register slash command for testing
    SLASH_PREYDEBUG1 = "/preydebug"
    SlashCmdList["PREYDEBUG"] = function(msg)
        if msg == "show" then
            if percentText then
                percentText:Show()
                print("Prey percent shown")
            else
                print("Prey percent not created yet")
            end
        elseif msg == "hide" then
            if percentText then
                percentText:Hide()
                print("Prey percent hidden")
            else
                print("Prey percent not created yet")
            end
        elseif msg == "update" then
            self:UpdatePreyPercent()
            print("Prey percent updated: " .. preyCount .. "/" .. preyMax)
        else
            print("Prey Debug Commands:")
            print("  /preydebug show - Show percent")
            print("  /preydebug hide - Hide percent")
            print("  /preydebug update - Update prey percent")
        end
    end
end

function Prey:OnEnable()
    if not self.db.profile.enabled then return end
    
    -- Hide old tracker frame if it exists
    local oldTracker = _G["AbstractUI_PreyTracker"]
    if oldTracker then
        oldTracker:Hide()
    end
    
    -- Register events for tracking prey count
    self:RegisterEvent("UPDATE_UI_WIDGET")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- UIWidget frames are created dynamically, so we need multiple attempts
    -- Try every 2 seconds for the first 20 seconds
    for i = 1, 10 do
        C_Timer.After(i * 2, function()
            self:MakePreyIconDraggable()
            self:AttachPercentText()
            self:UpdatePreyPercent()
        end)
    end
end

function Prey:PLAYER_ENTERING_WORLD()
    -- Try to make the Prey icon draggable when entering a new zone
    C_Timer.After(2, function()
        self:MakePreyIconDraggable()
        self:AttachPercentText()
        self:UpdatePreyPercent()
    end)
    C_Timer.After(5, function()
        self:MakePreyIconDraggable()
        self:AttachPercentText()
        self:UpdatePreyPercent()
    end)
end

function Prey:UPDATE_UI_WIDGET(event, widgetInfo)
    -- Update prey percent when widgets change
    self:UpdatePreyPercent()
end

-- ============================================================================
-- PERCENT TEXT ATTACHED TO BLIZZARD ICON
-- ============================================================================

function Prey:AttachPercentText()
    local frame = _G["UIWidgetPowerBarContainerFrame"]
    if not frame then return end
    if not self.db.profile.showPercent then return end
    
    -- Create percent text if it doesn't exist
    if not percentText then
        percentText = frame:CreateFontString(nil, "OVERLAY")
        percentText:SetFont("Fonts\\FRIZQT__.TTF", self.db.profile.percentFontSize, "OUTLINE")
        percentText:SetPoint("TOP", frame, "BOTTOM", 0, -2)
        percentText:SetTextColor(1, 1, 1, 1)
        percentText:SetJustifyH("CENTER")
    end
    
    -- Update immediately
    self:UpdatePreyPercent()
end

function Prey:UpdatePreyPercent()
    if not self.db.profile.showPercent or not percentText then return end
    
    local frame = _G["UIWidgetPowerBarContainerFrame"]
    if not frame or not frame:IsShown() then
        if percentText then
            percentText:Hide()
        end
        return
    end
    
    local foundWidget = false
    
    -- Try to get prey count from UIWidget
    if C_UIWidgetManager and C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo then
        local widgetInfo = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(7663)
        
        if widgetInfo and widgetInfo.barValue and widgetInfo.barMax then
            preyCount = widgetInfo.barValue or 0
            preyMax = widgetInfo.barMax or 0
            foundWidget = true
            
            -- Calculate percentage
            local percent = (preyMax > 0) and math.floor((preyCount / preyMax) * 100) or 0
            
            -- Update display
            percentText:SetText(percent .. "%")
            
            -- Color based on progress
            if percent >= 100 then
                percentText:SetTextColor(0, 1, 0, 1) -- Green when complete
            elseif percent >= 50 then
                percentText:SetTextColor(1, 0.82, 0, 1) -- Gold when halfway
            else
                percentText:SetTextColor(1, 1, 1, 1) -- White
            end
            
            percentText:Show()
        end
    end
    
    if not foundWidget and percentText then
        percentText:Hide()
    end
end

function Prey:UpdatePercentFontSize()
    if percentText then
        percentText:SetFont("Fonts\\FRIZQT__.TTF", self.db.profile.percentFontSize, "OUTLINE")
    end
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
        -- Also update percent text when frame shows
        C_Timer.After(0.1, function()
            Prey:AttachPercentText()
            Prey:UpdatePreyPercent()
        end)
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
            showPercent = {
                name = "Show Percentage",
                desc = "Display completion percentage below the Prey icon",
                type = "toggle",
                order = 2,
                get = function() return self.db.profile.showPercent end,
                set = function(_, value)
                    self.db.profile.showPercent = value
                    if value then
                        self:AttachPercentText()
                    elseif percentText then
                        percentText:Hide()
                    end
                end,
            },
            percentFontSize = {
                name = "Percentage Font Size",
                desc = "Adjust the size of the percentage text",
                type = "range",
                order = 3,
                min = 8,
                max = 24,
                step = 1,
                get = function() return self.db.profile.percentFontSize end,
                set = function(_, value)
                    self.db.profile.percentFontSize = value
                    self:UpdatePercentFontSize()
                end,
                disabled = function() return not self.db.profile.showPercent end,
            },
            reset = {
                name = "Reset Icon Position",
                desc = "Reset the Prey icon to its default position",
                type = "execute",
                order = 4,
                func = function()
                    self:ResetPosition()
                end,
            },
            spacer1 = {
                name = "",
                type = "description",
                order = 10,
            },
            description = {
                name = "The Prey tracking icon appears during active Prey events. This module allows you to drag it and displays a percentage (1-100%) below the icon showing your hunt progress.",
                type = "description",
                order = 11,
            },
        }
    }
end
