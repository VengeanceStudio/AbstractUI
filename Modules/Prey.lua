local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local Prey = AbstractUI:NewModule("Prey", "AceEvent-3.0")

-- ============================================================================
-- PREY ICON MANAGER
-- Manages the draggable Prey icon (UIWidgetPowerBarContainerFrame)
-- Widget ID 7663 for the Prey tracking icon
-- ============================================================================

-- Tracker frame reference
local trackerFrame = nil
local preyCount = 0
local preyMax = 0

-- Database defaults
local defaults = {
    profile = {
        enabled = true,
        position = nil, -- Stores {point, relativePoint, x, y}
        tracker = {
            enabled = true,
            position = nil, -- Separate position for tracker
            scale = 1.0,
            showWhenInactive = true, -- Show tracker even when not in prey event
        }
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
            if trackerFrame then
                trackerFrame:Show()
                print("Prey tracker shown")
            else
                print("Prey tracker not created yet")
            end
        elseif msg == "hide" then
            if trackerFrame then
                trackerFrame:Hide()
                print("Prey tracker hidden")
            else
                print("Prey tracker not created yet")
            end
        elseif msg == "update" then
            self:UpdatePreyCount()
            print("Prey count updated: " .. preyCount .. "/" .. preyMax)
        else
            print("Prey Debug Commands:")
            print("  /preydebug show - Show tracker")
            print("  /preydebug hide - Hide tracker")
            print("  /preydebug update - Update prey count")
        end
    end
end

function Prey:OnEnable()
    if not self.db.profile.enabled then return end
    
    -- Create prey tracker frame
    if self.db.profile.tracker.enabled then
        self:CreateTrackerFrame()
    end
    
    -- Register events for tracking prey count
    self:RegisterEvent("UPDATE_UI_WIDGET")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- UIWidget frames are created dynamically, so we need multiple attempts
    -- Try every 2 seconds for the first 20 seconds
    for i = 1, 10 do
        C_Timer.After(i * 2, function()
            self:MakePreyIconDraggable()
            self:UpdatePreyCount()
        end)
    end
end

function Prey:PLAYER_ENTERING_WORLD()
    -- Try to make the Prey icon draggable when entering a new zone
    C_Timer.After(2, function()
        self:MakePreyIconDraggable()
        self:UpdatePreyCount()
    end)
    C_Timer.After(5, function()
        self:MakePreyIconDraggable()
        self:UpdatePreyCount()
    end)
end

function Prey:UPDATE_UI_WIDGET(event, widgetInfo)
    -- Update prey count when widgets change
    self:UpdatePreyCount()
end

-- ============================================================================
-- PREY TRACKER FRAME
-- ============================================================================

function Prey:CreateTrackerFrame()
    if trackerFrame then return end
    
    -- Create main frame
    trackerFrame = CreateFrame("Frame", "AbstractUI_PreyTracker", UIParent)
    trackerFrame:SetSize(64, 64)
    trackerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    trackerFrame:SetFrameStrata("MEDIUM")
    trackerFrame:SetFrameLevel(100)
    trackerFrame:SetClampedToScreen(true)
    
    -- Make it draggable
    trackerFrame:SetMovable(true)
    trackerFrame:EnableMouse(true)
    trackerFrame:RegisterForDrag("LeftButton")
    
    trackerFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    
    trackerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        if Prey.db then
            Prey.db.profile.tracker.position = {
                point = point,
                relativePoint = relativePoint,
                x = x,
                y = y,
            }
        end
    end)
    
    -- Create background
    trackerFrame.bg = trackerFrame:CreateTexture(nil, "BACKGROUND")
    trackerFrame.bg:SetAllPoints()
    trackerFrame.bg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Create icon (using the prey icon)
    trackerFrame.icon = trackerFrame:CreateTexture(nil, "ARTWORK")
    trackerFrame.icon:SetPoint("CENTER", 0, 4)
    trackerFrame.icon:SetSize(40, 40)
    trackerFrame.icon:SetTexture(87493985) -- ui_prey icon from MacroIconData
    trackerFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Create count text
    trackerFrame.count = trackerFrame:CreateFontString(nil, "OVERLAY")
    trackerFrame.count:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    trackerFrame.count:SetPoint("BOTTOM", trackerFrame, "BOTTOM", 0, 4)
    trackerFrame.count:SetTextColor(1, 1, 1, 1)
    trackerFrame.count:SetText("0/0")
    
    -- Add border
    trackerFrame.border = trackerFrame:CreateTexture(nil, "OVERLAY")
    trackerFrame.border:SetAllPoints()
    trackerFrame.border:SetTexture("Interface\\Buttons\\WHITE8X8")
    trackerFrame.border:SetVertexColor(0.3, 0.3, 0.3, 1)
    trackerFrame.border:SetDrawLayer("OVERLAY", 1)
    
    -- Create a thin border effect by layering
    trackerFrame.innerBorder = trackerFrame:CreateTexture(nil, "OVERLAY")
    trackerFrame.innerBorder:SetPoint("TOPLEFT", 1, -1)
    trackerFrame.innerBorder:SetPoint("BOTTOMRIGHT", -1, 1)
    trackerFrame.innerBorder:SetColorTexture(0, 0, 0, 0.5)
    trackerFrame.innerBorder:SetDrawLayer("OVERLAY", 0)
    
    -- Tooltip
    trackerFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Prey Hunt Progress", 1, 1, 1)
        if preyCount > 0 or preyMax > 0 then
            GameTooltip:AddLine(string.format("%d of %d prey defeated", preyCount, preyMax), 1, 0.82, 0)
        else
            GameTooltip:AddLine("No active prey hunt", 0.5, 0.5, 0.5)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click and drag to move", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    trackerFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Apply scale
    trackerFrame:SetScale(self.db.profile.tracker.scale)
    
    -- Restore saved position
    if self.db.profile.tracker.position then
        local pos = self.db.profile.tracker.position
        trackerFrame:ClearAllPoints()
        trackerFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
    
    -- Initially show the frame
    trackerFrame:Show()
    
    -- Initial update
    self:UpdatePreyCount()
    
    -- Debug message
    print("|cff00ff00AbstractUI Prey:|r Tracker created at center of screen")
end

function Prey:UpdatePreyCount()
    if not trackerFrame then return end
    
    local foundWidget = false
    
    -- Try to get prey count from UIWidget
    -- Widget ID 7663 is mentioned for prey tracking
    if C_UIWidgetManager and C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo then
        local widgetInfo = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(7663)
        
        if widgetInfo and widgetInfo.barValue and widgetInfo.barMax then
            preyCount = widgetInfo.barValue or 0
            preyMax = widgetInfo.barMax or 0
            foundWidget = true
            
            -- Update display
            trackerFrame.count:SetText(string.format("%d/%d", preyCount, preyMax))
            
            -- Color the count based on progress
            local ratio = preyMax > 0 and (preyCount / preyMax) or 0
            if ratio >= 1 then
                trackerFrame.count:SetTextColor(0, 1, 0, 1) -- Green when complete
            elseif ratio >= 0.5 then
                trackerFrame.count:SetTextColor(1, 0.82, 0, 1) -- Gold when halfway
            else
                trackerFrame.count:SetTextColor(1, 1, 1, 1) -- White
            end
        end
    end
    
    if not foundWidget then
        -- No active prey hunt
        preyCount = 0
        preyMax = 0
        trackerFrame.count:SetText("0/0")
        trackerFrame.count:SetTextColor(0.5, 0.5, 0.5, 1)
    end
    
    -- Show/hide based on settings
    if foundWidget or self.db.profile.tracker.showWhenInactive then
        trackerFrame:Show()
    else
        trackerFrame:Hide()
    end
end

function Prey:ToggleTracker(show)
    if not trackerFrame then
        if show and self.db.profile.tracker.enabled then
            self:CreateTrackerFrame()
        end
        return
    end
    
    if show then
        trackerFrame:Show()
    else
        trackerFrame:Hide()
    end
end

function Prey:UpdateTrackerScale()
    if trackerFrame then
        trackerFrame:SetScale(self.db.profile.tracker.scale)
    end
end

function Prey:ResetTrackerPosition()
    self.db.profile.tracker.position = nil
    if trackerFrame then
        trackerFrame:ClearAllPoints()
        trackerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
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
                name = "Reset Blizzard Icon Position",
                desc = "Reset the Prey icon to its default position",
                type = "execute",
                order = 2,
                func = function()
                    self:ResetPosition()
                end,
            },
            spacer1 = {
                name = "",
                type = "description",
                order = 3,
            },
            trackerHeader = {
                name = "Prey Hunt Tracker",
                type = "header",
                order = 10,
            },
            trackerEnabled = {
                name = "Enable Tracker",
                desc = "Show a custom tracker with prey hunt progress count",
                type = "toggle",
                order = 11,
                get = function() return self.db.profile.tracker.enabled end,
                set = function(_, value)
                    self.db.profile.tracker.enabled = value
                    if value then
                        self:CreateTrackerFrame()
                    else
                        self:ToggleTracker(false)
                    end
                end,
            },
            trackerShowInactive = {
                name = "Show When Inactive",
                desc = "Show tracker even when no prey hunt is active",
                type = "toggle",
                order = 12,
                get = function() return self.db.profile.tracker.showWhenInactive end,
                set = function(_, value)
                    self.db.profile.tracker.showWhenInactive = value
                    self:UpdatePreyCount()
                end,
                disabled = function() return not self.db.profile.tracker.enabled end,
            },
            trackerScale = {
                name = "Tracker Scale",
                desc = "Adjust the size of the prey tracker",
                type = "range",
                order = 13,
                min = 0.5,
                max = 2.0,
                step = 0.05,
                get = function() return self.db.profile.tracker.scale end,
                set = function(_, value)
                    self.db.profile.tracker.scale = value
                    self:UpdateTrackerScale()
                end,
                disabled = function() return not self.db.profile.tracker.enabled end,
            },
            trackerReset = {
                name = "Reset Tracker Position",
                desc = "Reset the tracker to its default position",
                type = "execute",
                order = 14,
                func = function()
                    self:ResetTrackerPosition()
                end,
                disabled = function() return not self.db.profile.tracker.enabled end,
            },
            spacer2 = {
                name = "",
                type = "description",
                order = 20,
            },
            description = {
                name = "The Prey tracking icon appears in certain zones during events. This module allows you to drag it to a custom position and displays a custom tracker showing your hunt progress.",
                type = "description",
                order = 21,
            },
        }
    }
end
