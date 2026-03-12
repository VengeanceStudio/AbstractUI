-- ============================================================================
-- Group Manager Module
-- ============================================================================
-- Compact group management toolbar that reskins Blizzard's CompactRaidFrameManager
-- ============================================================================

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local GroupManager = AbstractUI:NewModule("GroupManager", "AceEvent-3.0")

-- Framework references
local ColorPalette, FontKit, FrameFactory

-- State
local managerFrame = nil
local isExpanded = false
local blizzardManager = nil

local defaults = {
    profile = {
        enabled = true,
        compactWidth = 30,
        compactHeight = 30,
        position = {
            point = "TOPLEFT",
            x = 10,
            y = -200,
        },
    }
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function GroupManager:OnInitialize()
    self.db = AbstractUI.db:RegisterNamespace("GroupManager", defaults)
    
    -- Get framework references
    ColorPalette = _G.AbstractUI_ColorPalette
    FontKit = _G.AbstractUI_FontKit
    FrameFactory = _G.AbstractUI_FrameFactory
end

function GroupManager:OnEnable()
    -- Check if module is enabled
    if not AbstractUI.db.profile.modules.groupManager then
        return
    end
    
    -- Ensure Blizzard_CompactRaidFrames is loaded
    if not IsAddOnLoaded("Blizzard_CompactRaidFrames") then
        LoadAddOn("Blizzard_CompactRaidFrames")
    end
    
    -- Register events
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Listen for move mode changes
    self:RegisterMessage("AbstractUI_MOVEMODE_CHANGED", "OnMoveModeChanged")
    
    -- Create toggle icon and reskin Blizzard's frame
    self:CreateToggleIcon()
    self:ReskinBlizzardManager()
    self:UpdateVisibility()
end

function GroupManager:OnDisable()
    if managerFrame then
        managerFrame:Hide()
    end
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

function GroupManager:CreateToggleIcon()
    if managerFrame then return end
    
    local Movable = AbstractUI:GetModule("Movable", true)
    
    -- Create container frame for positioning
    managerFrame = CreateFrame("Frame", "AbstractUI_GroupManagerIcon", UIParent)
    managerFrame:SetSize(self.db.profile.compactWidth, self.db.profile.compactHeight)
    managerFrame:SetPoint(
        self.db.profile.position.point,
        UIParent,
        self.db.profile.position.point,
        self.db.profile.position.x,
        self.db.profile.position.y
    )
    managerFrame:SetFrameStrata("MEDIUM")
    managerFrame:SetMovable(true)
    managerFrame:SetClampedToScreen(true)
    
    -- Toggle button
    local toggleBtn = FrameFactory:CreateButton(managerFrame, self.db.profile.compactWidth, self.db.profile.compactHeight, "")
    toggleBtn:SetPoint("CENTER", managerFrame, "CENTER", 0, 0)
    toggleBtn:EnableMouse(true)
    
    -- Icon for toggle button
    local icon = toggleBtn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
    icon:SetVertexColor(ColorPalette:GetColor('text-primary'))
    
    toggleBtn.text:Hide()
    
    managerFrame.toggleBtn = toggleBtn
    managerFrame.icon = icon
    
    toggleBtn:SetScript("OnClick", function()
        if not AbstractUI.moveMode then
            GroupManager:ToggleExpanded()
        end
    end)
    
    -- Tooltips
    local originalOnEnter = toggleBtn:GetScript("OnEnter")
    toggleBtn:SetScript("OnEnter", function(self)
        if originalOnEnter then originalOnEnter(self) end
        
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Group Manager", 1, 1, 1)
        GameTooltip:AddLine("Click to expand/collapse", 0.7, 0.7, 0.7)
        if AbstractUI.moveMode then
            GameTooltip:AddLine("Drag to move", 0.5, 1, 0.5)
        end
        GameTooltip:Show()
    end)
    
    local originalOnLeave = toggleBtn:GetScript("OnLeave")
    toggleBtn:SetScript("OnLeave", function(self)
        if originalOnLeave then originalOnLeave(self) end
        GameTooltip:Hide()
    end)
    
    -- Movable system integration
    if Movable then
        local highlight = CreateFrame("Frame", nil, managerFrame, "BackdropTemplate")
        highlight:SetAllPoints(managerFrame)
        highlight:SetFrameStrata("HIGH")
        highlight:SetFrameLevel(100)
        
        highlight:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        
        highlight:SetBackdropColor(0, 0.5, 0, 0.2)
        highlight:SetBackdropBorderColor(0, 1, 0, 1)
        
        highlight.text = highlight:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        highlight.text:SetPoint("CENTER", highlight, "CENTER", 0, 0)
        highlight.text:SetText("GM")
        highlight.text:SetTextColor(1, 1, 1, 1)
        highlight.text:SetShadowOffset(2, -2)
        highlight.text:SetShadowColor(0, 0, 0, 1)
        
        managerFrame.movableHighlight = highlight:CreateTexture(nil, "OVERLAY")
        managerFrame.movableHighlight:SetAllPoints(highlight)
        managerFrame.movableHighlight:SetColorTexture(0, 1, 0, 0.2)
        managerFrame.movableHighlight:Hide()
        
        managerFrame.movableHighlightLabel = highlight.text
        highlight:Hide()
        
        Movable:MakeFrameDraggable(
            highlight,
            function(point, x, y)
                GroupManager.db.profile.position.point = point or "TOPLEFT"
                GroupManager.db.profile.position.x = x or 0
                GroupManager.db.profile.position.y = y or 0
                
                managerFrame:ClearAllPoints()
                managerFrame:SetPoint(point, UIParent, point, x, y)
                
                if isExpanded then
                    GroupManager:UpdateBlizzardManagerPosition()
                end
                
                Movable:UpdateNudgeArrows(highlight)
            end,
            function() return true end
        )
        
        Movable:CreateNudgeArrows(highlight, self.db.profile.position, function()
            self.db.profile.position.point = "CENTER"
            self.db.profile.position.x = 0
            self.db.profile.position.y = 0
            managerFrame:ClearAllPoints()
            managerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end)
        
        managerFrame.moveHighlight = highlight
    end
    
    managerFrame:Hide()
end

-- ============================================================================
-- BLIZZARD FRAME RESKIN
-- ============================================================================

function GroupManager:ReskinBlizzardManager()
    if not CompactRaidFrameManager then return end
    
    blizzardManager = CompactRaidFrameManager
    local displayFrame = blizzardManager.displayFrame or CompactRaidFrameManagerDisplayFrame
    
    if not displayFrame then return end
    
    -- Store original settings
    if not blizzardManager.abstractUIOriginal then
        blizzardManager.abstractUIOriginal = {
            shown = blizzardManager:IsShown(),
            parent = blizzardManager:GetParent(),
            strata = blizzardManager:GetFrameStrata(),
        }
    end
    
    -- Apply AbstractUI styling to the main frame
    if blizzardManager.SetBackdrop then
        local bgColor = ColorPalette:GetColorTable('background-primary')
        local borderColor = ColorPalette:GetColorTable('border-primary')
        
        blizzardManager:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        blizzardManager:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.95)
        blizzardManager:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
    end
    
    -- Reskin all buttons in the display frame
    self:ReskinBlizzardButtons(displayFrame)
    
    -- Hide initially (will show when expanded)
    blizzardManager:Hide()
    blizzardManager:SetMovable(false)
    blizzardManager:EnableMouse(false)
    
end

function GroupManager:ReskinBlizzardButtons(frame)
    if not frame then return end
    
    local bgColor = ColorPalette:GetColorTable('background-tertiary')
    local borderColor = ColorPalette:GetColorTable('border-primary')
    local hoverColor = ColorPalette:GetColorTable('background-hover')
    
    -- Reskin all child buttons recursively
    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())
        
        if child:IsObjectType("Button") and child.SetBackdrop then
            -- Apply AbstractUI button styling
            child:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false,
                edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })
            child:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 1)
            child:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
            
            -- Add hover effect if it doesn't already have AbstractUI styling
            if not child.abstractUIStyled then
                child:HookScript("OnEnter", function(self)
                    if self:IsEnabled() then
                        self:SetBackdropColor(hoverColor.r, hoverColor.g, hoverColor.b, hoverColor.a or 1)
                    end
                end)
                
                child:HookScript("OnLeave", function(self)
                    self:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 1)
                end)
                
                child.abstractUIStyled = true
            end
            
            -- Hide default textures
            for _, region in ipairs({child:GetRegions()}) do
                if region:IsObjectType("Texture") and not region:GetName() then
                    local texture = region:GetTexture()
                    if texture and not string.match(tostring(texture), "RaidTargetingIcon") then
                        region:SetAlpha(0)
                    end
                end
            end
        end
        
        -- Recurse into children
        self:ReskinBlizzardButtons(child)
    end
end

function GroupManager:UpdateBlizzardManagerPosition()
    if not blizzardManager or not managerFrame then return end
    
    local gap = 5
    local iconX = managerFrame:GetLeft() or 0
    local iconY = managerFrame:GetTop() or 0
    local iconWidth = managerFrame:GetWidth()
    
    local screenWidth = GetScreenWidth()
    local managerWidth = blizzardManager:GetWidth()
    
    blizzardManager:ClearAllPoints()
    
    -- Try to position right of icon
    local spaceRight = screenWidth - (iconX + iconWidth)
    if spaceRight >= managerWidth + gap then
        blizzardManager:SetPoint("TOPLEFT", managerFrame, "TOPRIGHT", gap, 0)
    else
        -- Position left of icon
        blizzardManager:SetPoint("TOPRIGHT", managerFrame, "TOPLEFT", -gap, 0)
    end
end

function GroupManager:ToggleExpanded()
    if not blizzardManager then return end
    
    isExpanded = not isExpanded
    
    if isExpanded then
        self:UpdateBlizzardManagerPosition()
        blizzardManager:Show()
    else
        blizzardManager:Hide()
    end
end

-- ============================================================================
-- EVENTS
-- ============================================================================

function GroupManager:GROUP_ROSTER_UPDATE()
    self:UpdateVisibility()
end

function GroupManager:PLAYER_ENTERING_WORLD()
    self:UpdateVisibility()
end

function GroupManager:OnMoveModeChanged(event, moveMode)
    if not managerFrame or not managerFrame.moveHighlight then return end
    
    if moveMode then
        -- Show the green highlight frame in move mode
        managerFrame.moveHighlight:Show()
        -- Disable toggle button mouse interaction so highlight can be dragged
        if managerFrame.toggleBtn then
            managerFrame.toggleBtn:EnableMouse(false)
        end
    else
        -- Hide the highlight frame when not in move mode
        managerFrame.moveHighlight:Hide()
        -- Re-enable toggle button mouse interaction
        if managerFrame.toggleBtn then
            managerFrame.toggleBtn:EnableMouse(true)
        end
    end
end

function GroupManager:UpdateVisibility()
    if not managerFrame then return end
    
    -- Show manager if in a group
    if IsInGroup() or IsInRaid() then
        managerFrame:Show()
    else
        managerFrame:Hide()
    end
end

-- ============================================================================
-- OPTIONS
-- ============================================================================

function GroupManager:GetOptions()
    return {
        type = "group",
        name = "Group Manager",
        get = function(info) return self.db.profile[info[#info]] end,
        set = function(info, value) 
            self.db.profile[info[#info]] = value
            self:UpdateManagerFrame()
        end,
        args = {
            enabled = {
                name = "Enable Group Manager",
                desc = "Shows a compact toggle icon that opens Blizzard's CompactRaidFrameManager with AbstractUI styling.",
                type = "toggle",
                order = 1,
                set = function(info, value)
                    self.db.profile.enabled = value
                    AbstractUI.db.profile.modules.groupManager = value
                    if value then
                        self:OnEnable()
                    else
                        self:OnDisable()
                    end
                end,
            },
            header1 = {
                name = "Toggle Icon",
                type = "header",
                order = 2,
            },
            compactWidth = {
                name = "Icon Width",
                desc = "Width of the toggle icon",
                type = "range",
                min = 25,
                max = 60,
                step = 1,
                order = 3,
            },
            compactHeight = {
                name = "Icon Height",
                desc = "Height of the toggle icon",
                type = "range",
                min = 25,
                max = 60,
                step = 1,
                order = 4,
            },
        }
    }
end

function GroupManager:UpdateManagerFrame()
    if not managerFrame then return end
    
    -- Update toggle icon size
    managerFrame.toggleBtn:SetSize(self.db.profile.compactWidth, self.db.profile.compactHeight)
    managerFrame:SetSize(self.db.profile.compactWidth, self.db.profile.compactHeight)
end

return GroupManager
