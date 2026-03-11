-- ============================================================================
-- Group Manager Module
-- ============================================================================
-- Compact group management toolbar with markers and controls
-- ============================================================================

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local GroupManager = AbstractUI:NewModule("GroupManager", "AceEvent-3.0")

-- Framework references
local ColorPalette, FontKit, FrameFactory

-- State
local managerFrame = nil
local isExpanded = false

local defaults = {
    profile = {
        enabled = true,
        compactWidth = 30,
        compactHeight = 30,
        expandedWidth = 200,
        expandedHeight = 340,
        position = {
            point = "TOPLEFT",
            x = 10,
            y = -200,
        },
    }
}

-- Raid marker icons in order
local RAID_MARKERS = {
    {icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", index = 1, name = "Star"},
    {icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2", index = 2, name = "Circle"},
    {icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", index = 3, name = "Diamond"},
    {icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", index = 4, name = "Triangle"},
    {icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5", index = 5, name = "Moon"},
    {icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6", index = 6, name = "Square"},
    {icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", index = 7, name = "Cross"},
    {icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", index = 8, name = "Skull"},
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
    
    -- Register events
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    
    -- Listen for move mode changes
    self:RegisterMessage("AbstractUI_MOVEMODE_CHANGED", "OnMoveModeChanged")
    
    -- Create frames
    self:CreateManagerFrame()
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

function GroupManager:CreateManagerFrame()
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
    
    -- Toggle button (standalone with its own background)
    local toggleBtn = FrameFactory:CreateButton(managerFrame, self.db.profile.compactWidth, self.db.profile.compactHeight, "")
    toggleBtn:SetPoint("CENTER", managerFrame, "CENTER", 0, 0)
    toggleBtn:EnableMouse(true)
    
    -- Icon for toggle button
    local icon = toggleBtn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
    icon:SetVertexColor(ColorPalette:GetColor('text-primary'))
    
    -- Hide the text since we only want the icon
    toggleBtn.text:Hide()
    
    managerFrame.toggleBtn = toggleBtn
    managerFrame.icon = icon
    
    toggleBtn:SetScript("OnClick", function()
        -- Don't expand/collapse in move mode
        if not AbstractUI.moveMode then
            GroupManager:ToggleExpanded()
        end
    end)
    
    -- Custom hover behavior for icon button
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
        -- Create highlight overlay for move mode (simple backdrop like Tooltips anchor)
        local highlight = CreateFrame("Frame", nil, managerFrame, "BackdropTemplate")
        highlight:SetAllPoints(managerFrame)
        highlight:SetFrameStrata("HIGH")
        highlight:SetFrameLevel(100)
        
        -- Backdrop (match Tooltips anchor style)
        highlight:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        
        highlight:SetBackdropColor(0, 0.5, 0, 0.2)  -- Semi-transparent green
        highlight:SetBackdropBorderColor(0, 1, 0, 1) -- Bright green border
        
        -- Label
        highlight.text = highlight:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        highlight.text:SetPoint("CENTER", highlight, "CENTER", 0, 0)
        highlight.text:SetText("GM")
        highlight.text:SetTextColor(1, 1, 1, 1)
        highlight.text:SetShadowOffset(2, -2)
        highlight.text:SetShadowColor(0, 0, 0, 1)
        
        -- Store as movableHighlight for the Movable system
        managerFrame.movableHighlight = highlight:CreateTexture(nil, "OVERLAY")
        managerFrame.movableHighlight:SetAllPoints(highlight)
        managerFrame.movableHighlight:SetColorTexture(0, 1, 0, 0.2)
        managerFrame.movableHighlight:Hide()
        
        managerFrame.movableHighlightLabel = highlight.text
        
        -- Hide the backdrop highlight by default (only show in move mode)
        highlight:Hide()
        
        -- Use Movable:MakeFrameDraggable for proper drag functionality
        Movable:MakeFrameDraggable(
            highlight,
            function(point, x, y)
                GroupManager.db.profile.position.point = point or "TOPLEFT"
                GroupManager.db.profile.position.x = x or 0
                GroupManager.db.profile.position.y = y or 0
                
                -- Move the parent frame
                managerFrame:ClearAllPoints()
                managerFrame:SetPoint(point, UIParent, point, x, y)
                
                -- Update content panel position if open
                if isExpanded then
                    GroupManager:UpdateContentPanelPosition()
                end
                
                -- Update nudge arrows
                Movable:UpdateNudgeArrows(highlight)
            end,
            function() return true end -- Always movable when visible
        )
        
        -- Add nudge arrows
        Movable:CreateNudgeArrows(highlight, self.db.profile.position, function()
            -- Reset callback: center the icon
            self.db.profile.position.point = "CENTER"
            self.db.profile.position.x = 0
            self.db.profile.position.y = 0
            managerFrame:ClearAllPoints()
            managerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end)
        
        -- Store reference to the highlight frame
        managerFrame.moveHighlight = highlight
    end
    
    -- Create expanded content panel (separate from toggle button)
    self:CreateExpandedContent()
    
    managerFrame:Hide()
end

function GroupManager:CreateExpandedContent()
    if not managerFrame then return end
    
    -- Create separate content panel using FrameFactory (positioned relative to toggle button)
    local contentPanel = FrameFactory:CreatePanel(UIParent, self.db.profile.expandedWidth, self.db.profile.expandedHeight)
    contentPanel:SetFrameStrata("MEDIUM")
    contentPanel:SetFrameLevel(managerFrame:GetFrameLevel() - 1)
    contentPanel:SetClampedToScreen(true)
    contentPanel:Hide()
    
    managerFrame.contentPanel = contentPanel
    
    -- Title
    local title = FontKit:CreateFontString(contentPanel, 'header', 'large')
    title:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 8, -8)
    title:SetText("Group Controls")
    title:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    -- Raid Markers Section
    local markersLabel = FontKit:CreateFontString(contentPanel, 'body', 'normal')
    markersLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    markersLabel:SetText("Raid Markers:")
    markersLabel:SetTextColor(ColorPalette:GetColor('text-secondary'))
    
    -- Create marker buttons in 2 rows of 4 (reversed order: Skull to Star)
    local markerButtons = {}
    for i = #RAID_MARKERS, 1, -1 do
        local marker = RAID_MARKERS[i]
        local btn = FrameFactory:CreateButton(contentPanel, 30, 30, "")
        
        local displayIndex = #RAID_MARKERS - i + 1
        local col = ((displayIndex - 1) % 4)
        local row = math.floor((displayIndex - 1) / 4)
        btn:SetPoint("TOPLEFT", markersLabel, "BOTTOMLEFT", col * 35, -5 - (row * 35))
        
        -- Hide the button text since we'll show an icon instead
        btn.text:Hide()
        
        -- Marker icon (Blizzard asset - only thing that should be Blizzard)
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("CENTER")
        icon:SetTexture(marker.icon)
        
        -- Preserve the framework's original OnEnter/OnLeave
        local originalOnEnter = btn:GetScript("OnEnter")
        local originalOnLeave = btn:GetScript("OnLeave")
        
        btn:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                -- Mark target
                if UnitExists("target") then
                    SetRaidTarget("target", marker.index)
                end
            elseif button == "RightButton" then
                -- Clear marker
                for j = 1, 40 do
                    local unit = "raid" .. j
                    if UnitExists(unit) and GetRaidTargetIndex(unit) == marker.index then
                        SetRaidTarget(unit, 0)
                        break
                    end
                end
                for j = 1, 4 do
                    local unit = "party" .. j
                    if UnitExists(unit) and GetRaidTargetIndex(unit) == marker.index then
                        SetRaidTarget(unit, 0)
                        break
                    end
                end
                if GetRaidTargetIndex("player") == marker.index then
                    SetRaidTarget("player", 0)
                end
            end
        end)
        
        btn:SetScript("OnEnter", function(self)
            if originalOnEnter then originalOnEnter(self) end
            
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(marker.name, 1, 1, 1)
            GameTooltip:AddLine("Left-click: Mark target", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Right-click: Clear marker", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        
        btn:SetScript("OnLeave", function(self)
            if originalOnLeave then originalOnLeave(self) end
            GameTooltip:Hide()
        end)
        
        btn:RegisterForClicks("LeftButtonDown", "RightButtonDown")
        
        markerButtons[i] = btn
    end
    
    -- World Markers Section
    local worldLabel = FontKit:CreateFontString(contentPanel, 'body', 'normal')
    worldLabel:SetPoint("TOPLEFT", markerButtons[4], "BOTTOMLEFT", 0, -15)
    worldLabel:SetText("World Markers:")
    worldLabel:SetTextColor(ColorPalette:GetColor('text-secondary'))
    
    -- World marker buttons (in 2 rows of 4, reversed order: Skull to Star)
    for i = 8, 1, -1 do
        local btn = FrameFactory:CreateButton(contentPanel, 30, 30, "")
        
        local displayIndex = 9 - i
        local col = ((displayIndex - 1) % 4)
        local row = math.floor((displayIndex - 1) / 4)
        btn:SetPoint("TOPLEFT", worldLabel, "BOTTOMLEFT", col * 35, -5 - (row * 35))
        
        -- Hide the button text since we'll show an icon instead
        btn.text:Hide()
        
        -- World marker icon (Blizzard asset)
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("CENTER")
        icon:SetTexture(RAID_MARKERS[i].icon)
        icon:SetDesaturated(true)  -- Gray out for world markers
        
        -- Preserve the framework's original OnEnter/OnLeave
        local originalOnEnter = btn:GetScript("OnEnter")
        local originalOnLeave = btn:GetScript("OnLeave")
        
        btn:SetScript("OnClick", function(self)
            PlaceRaidMarker(i)
        end)
        
        btn:SetScript("OnEnter", function(self)
            if originalOnEnter then originalOnEnter(self) end
            
            icon:SetDesaturated(false)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Place " .. RAID_MARKERS[i].name, 1, 1, 1)
            GameTooltip:AddLine("Click to place on ground", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        
        btn:SetScript("OnLeave", function(self)
            if originalOnLeave then originalOnLeave(self) end
            
            icon:SetDesaturated(true)
            GameTooltip:Hide()
        end)
    end
    
    -- Actions Section
    local actionsLabel = FontKit:CreateFontString(contentPanel, 'body', 'normal')
    actionsLabel:SetPoint("BOTTOMLEFT", contentPanel, "BOTTOMLEFT", 8, 90)
    actionsLabel:SetText("Actions:")
    actionsLabel:SetTextColor(ColorPalette:GetColor('text-secondary'))
    
    -- Leave Party button (using FrameFactory)
    local leaveBtn = FrameFactory:CreateButton(contentPanel, 180, 22, "Leave Party")
    leaveBtn:SetPoint("TOPLEFT", actionsLabel, "BOTTOMLEFT", 0, -5)
    
    leaveBtn:SetScript("OnClick", function()
        if IsInRaid() then
            LeaveParty()
        elseif IsInGroup() then
            LeaveParty()
        end
    end)
    
    -- Ready Check button (using FrameFactory)
    local readyBtn = FrameFactory:CreateButton(contentPanel, 180, 22, "Ready Check")
    readyBtn:SetPoint("TOPLEFT", leaveBtn, "BOTTOMLEFT", 0, -3)
    
    readyBtn:SetScript("OnClick", function()
        DoReadyCheck()
    end)
    
    -- Custom tooltip for ready check
    local originalReadyEnter = readyBtn:GetScript("OnEnter")
    readyBtn:SetScript("OnEnter", function(self)
        if originalReadyEnter then originalReadyEnter(self) end
        
        if not (IsInRaid() or IsInGroup()) or not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Requires Leader/Assistant", 1, 0.3, 0.3)
            GameTooltip:Show()
        end
    end)
    
    -- Convert to Raid button (using FrameFactory)
    local convertBtn = FrameFactory:CreateButton(contentPanel, 180, 22, "Convert to Raid")
    convertBtn:SetPoint("TOPLEFT", readyBtn, "BOTTOMLEFT", 0, -3)
    
    convertBtn:SetScript("OnClick", function()
        if IsInGroup() and not IsInRaid() and UnitIsGroupLeader("player") then
            ConvertToRaid()
        end
    end)
    
    -- Custom tooltip for convert button
    local originalConvertEnter = convertBtn:GetScript("OnEnter")
    convertBtn:SetScript("OnEnter", function(self)
        if originalConvertEnter then originalConvertEnter(self) end
        
        if not IsInGroup() then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Not in a group", 1, 0.3, 0.3)
            GameTooltip:Show()
        elseif IsInRaid() then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Already in a raid", 1, 0.3, 0.3)
            GameTooltip:Show()
        elseif not UnitIsGroupLeader("player") then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Requires Group Leader", 1, 0.3, 0.3)
            GameTooltip:Show()
        end
    end)
    
    -- Difficulty Settings Section
    -- Dungeon Difficulty Label
    local dungeonLabel = FontKit:CreateFontString(contentPanel, 'body', 'normal')
    dungeonLabel:SetPoint("BOTTOMLEFT", contentPanel, "BOTTOMLEFT", 8, 30)
    dungeonLabel:SetText("Dungeon Difficulty:")
    dungeonLabel:SetTextColor(ColorPalette:GetColor('text-secondary'))
    
    -- Dungeon Difficulty Dropdown
    local dungeonDropdown = FrameFactory:CreateDropdown(contentPanel, 180, 22)
    dungeonDropdown:SetPoint("TOPLEFT", dungeonLabel, "BOTTOMLEFT", 0, -3)
    
    dungeonDropdown:SetItems({
        {value = 1, text = "Normal"},
        {value = 2, text = "Heroic"},
        {value = 23, text = "Mythic"}
    })
    
    dungeonDropdown.onChange = function(value)
        SetDungeonDifficultyID(value)
    end
    
    local function UpdateDungeonDropdown()
        local difficultyID = GetDungeonDifficultyID()
        local difficultyName = GetDifficultyInfo(difficultyID)
        dungeonDropdown:SetValue(difficultyID, difficultyName or "Normal")
        
        -- Show only in dungeons
        local _, instanceType = IsInInstance()
        if instanceType == "party" then
            dungeonLabel:Show()
            dungeonDropdown:Show()
        else
            dungeonLabel:Hide()
            dungeonDropdown:Hide()
        end
    end
    
    UpdateDungeonDropdown()
    
    -- Raid Difficulty Label (same position as dungeon, since they never show together)
    local raidLabel = FontKit:CreateFontString(contentPanel, 'body', 'normal')
    raidLabel:SetPoint("BOTTOMLEFT", contentPanel, "BOTTOMLEFT", 8, 30)
    raidLabel:SetText("Raid Difficulty:")
    raidLabel:SetTextColor(ColorPalette:GetColor('text-secondary'))
    
    -- Raid Difficulty Dropdown (same position as dungeon, since they never show together)
    local raidDropdown = FrameFactory:CreateDropdown(contentPanel, 180, 22)
    raidDropdown:SetPoint("TOPLEFT", raidLabel, "BOTTOMLEFT", 0, -3)
    
    raidDropdown:SetItems({
        {value = 14, text = "Normal"},
        {value = 15, text = "Heroic"},
        {value = 16, text = "Mythic"}
    })
    
    raidDropdown.onChange = function(value)
        SetRaidDifficultyID(value)
    end
    
    local function UpdateRaidDropdown()
        local difficultyID = GetRaidDifficultyID()
        local difficultyName = GetDifficultyInfo(difficultyID)
        raidDropdown:SetValue(difficultyID, difficultyName or "Normal")
        
        -- Show only in raids
        local _, instanceType = IsInInstance()
        if instanceType == "raid" then
            raidLabel:Show()
            raidDropdown:Show()
        else
            raidLabel:Hide()
            raidDropdown:Hide()
        end
    end
    
    UpdateRaidDropdown()
    
    -- Store references for updates
    managerFrame.dungeonDropdown = dungeonDropdown
    managerFrame.raidDropdown = raidDropdown
    managerFrame.updateDungeonDropdown = UpdateDungeonDropdown
    managerFrame.updateRaidDropdown = UpdateRaidDropdown
end

function GroupManager:UpdateContentPanelPosition()
    if not managerFrame or not managerFrame.contentPanel then return end
    
    local contentPanel = managerFrame.contentPanel
    local panelWidth = self.db.profile.expandedWidth
    local panelHeight = self.db.profile.expandedHeight
    local gap = 3
    
    -- Get toggle button position
    local iconX = managerFrame:GetLeft() or 0
    local iconY = managerFrame:GetTop() or 0
    local iconWidth = managerFrame:GetWidth()
    local iconHeight = managerFrame:GetHeight()
    
    -- Get screen dimensions
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    
    -- Determine best direction based on available space
    local spaceRight = screenWidth - (iconX + iconWidth)
    local spaceLeft = iconX
    local spaceDown = iconY
    local spaceUp = screenHeight - (iconY - iconHeight)
    
    contentPanel:ClearAllPoints()
    
    -- Try right first (preferred)
    if spaceRight >= panelWidth + gap then
        contentPanel:SetPoint("TOPLEFT", managerFrame, "TOPRIGHT", gap, 0)
    -- Try left
    elseif spaceLeft >= panelWidth + gap then
        contentPanel:SetPoint("TOPRIGHT", managerFrame, "TOPLEFT", -gap, 0)
    -- Try down
    elseif spaceDown >= panelHeight + gap then
        contentPanel:SetPoint("TOPLEFT", managerFrame, "BOTTOMLEFT", 0, -gap)
    -- Try up
    elseif spaceUp >= panelHeight + gap then
        contentPanel:SetPoint("BOTTOMLEFT", managerFrame, "TOPLEFT", 0, gap)
    else
        -- Not enough space anywhere, default to right and let it go offscreen
        contentPanel:SetPoint("TOPLEFT", managerFrame, "TOPRIGHT", gap, 0)
    end
end

function GroupManager:ToggleExpanded()
    isExpanded = not isExpanded
    
    if isExpanded then
        -- Update position based on current icon location
        self:UpdateContentPanelPosition()
        -- Show the content panel
        managerFrame.contentPanel:Show()
    else
        -- Hide the content panel, just showing the toggle button
        managerFrame.contentPanel:Hide()
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
    
    -- Update difficulty dropdowns if frame exists
    if managerFrame and managerFrame.updateDungeonDropdown then
        managerFrame.updateDungeonDropdown()
        managerFrame.updateRaidDropdown()
    end
end

function GroupManager:PLAYER_DIFFICULTY_CHANGED()
    -- Update difficulty dropdowns when difficulty changes
    if managerFrame and managerFrame.updateDungeonDropdown then
        managerFrame.updateDungeonDropdown()
        managerFrame.updateRaidDropdown()
    end
end

function GroupManager:ZONE_CHANGED_NEW_AREA()
    -- Update difficulty dropdown visibility based on instance type
    if managerFrame and managerFrame.updateDungeonDropdown then
        managerFrame.updateDungeonDropdown()
        managerFrame.updateRaidDropdown()
    end
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
                desc = "Show compact group management toolbar with raid markers and controls. Enable 'Hide Compact Party/Raid Manager' in Tweaks to hide Blizzard's default.",
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
                name = "Compact Mode",
                type = "header",
                order = 2,
            },
            compactWidth = {
                name = "Compact Width",
                desc = "Width of toolbar when collapsed",
                type = "range",
                min = 25,
                max = 60,
                step = 1,
                order = 3,
            },
            compactHeight = {
                name = "Compact Height",
                desc = "Height of toolbar when collapsed",
                type = "range",
                min = 25,
                max = 60,
                step = 1,
                order = 4,
            },
            header2 = {
                name = "Expanded Mode",
                type = "header",
                order = 5,
            },
            expandedWidth = {
                name = "Expanded Width",
                desc = "Width of toolbar when expanded",
                type = "range",
                min = 150,
                max = 300,
                step = 1,
                order = 6,
            },
            expandedHeight = {
                name = "Expanded Height",
                desc = "Height of toolbar when expanded",
                type = "range",
                min = 150,
                max = 400,
                step = 1,
                order = 7,
            },
        }
    }
end

function GroupManager:UpdateManagerFrame()
    if not managerFrame then return end
    
    -- Update toggle button size
    managerFrame.toggleBtn:SetSize(self.db.profile.compactWidth, self.db.profile.compactHeight)
    managerFrame:SetSize(self.db.profile.compactWidth, self.db.profile.compactHeight)
    
    -- Update content panel size
    if managerFrame.contentPanel then
        managerFrame.contentPanel:SetSize(self.db.profile.expandedWidth, self.db.profile.expandedHeight)
        
        -- Update position if expanded
        if isExpanded then
            self:UpdateContentPanelPosition()
        end
    end
end

return GroupManager
