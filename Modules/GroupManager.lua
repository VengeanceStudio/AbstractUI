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
    
    -- Create main panel using FrameFactory
    managerFrame = FrameFactory:CreatePanel(UIParent, self.db.profile.compactWidth, self.db.profile.compactHeight)
    managerFrame:SetPoint(
        self.db.profile.position.point,
        UIParent,
        self.db.profile.position.point,
        self.db.profile.position.x,
        self.db.profile.position.y
    )
    managerFrame:SetFrameStrata("MEDIUM")
    managerFrame:SetMovable(true)
    managerFrame:EnableMouse(true)
    managerFrame:RegisterForDrag("LeftButton")
    
    managerFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    managerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        GroupManager.db.profile.position.point = point
        GroupManager.db.profile.position.x = x
        GroupManager.db.profile.position.y = y
    end)
    
    -- Toggle button (using framework) - stays in top left corner
    local toggleBtn = FrameFactory:CreateButton(managerFrame, 26, 26, "")
    toggleBtn:SetPoint("TOPLEFT", managerFrame, "TOPLEFT", 2, -2)
    toggleBtn:SetFrameLevel(managerFrame:GetFrameLevel() + 10)  -- Keep on top when expanded
    
    -- Icon for collapsed state
    local icon = toggleBtn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
    icon:SetVertexColor(ColorPalette:GetColor('text-primary'))
    
    managerFrame.toggleBtn = toggleBtn
    managerFrame.icon = icon
    
    toggleBtn:SetScript("OnClick", function()
        GroupManager:ToggleExpanded()
    end)
    
    -- Custom hover behavior for icon button
    local originalOnEnter = toggleBtn:GetScript("OnEnter")
    toggleBtn:SetScript("OnEnter", function(self)
        if originalOnEnter then originalOnEnter(self) end
        
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Group Manager", 1, 1, 1)
        GameTooltip:AddLine("Click to expand/collapse", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    local originalOnLeave = toggleBtn:GetScript("OnLeave")
    toggleBtn:SetScript("OnLeave", function(self)
        if originalOnLeave then originalOnLeave(self) end
        GameTooltip:Hide()
    end)
    
    -- Create expanded content (hidden by default)
    self:CreateExpandedContent()
    
    managerFrame:Hide()
end

function GroupManager:CreateExpandedContent()
    if not managerFrame then return end
    
    local content = CreateFrame("Frame", nil, managerFrame)
    content:SetPoint("TOPLEFT", managerFrame, "TOPLEFT", 4, -32)  -- Start below toggle button
    content:SetPoint("BOTTOMRIGHT", managerFrame, "BOTTOMRIGHT", -4, 4)
    content:Hide()
    
    managerFrame.content = content
    
    -- Title
    local title = FontKit:CreateFontString(content, 'header', 'large')
    title:SetPoint("TOPLEFT", content, "TOPLEFT", 3, -3)
    title:SetText("Group Controls")
    title:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    -- Raid Markers Section
    local markersLabel = FontKit:CreateFontString(content, 'body', 'normal')
    markersLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    markersLabel:SetText("Raid Markers:")
    markersLabel:SetTextColor(ColorPalette:GetColor('text-secondary'))
    
    -- Create marker buttons in 2 rows of 4
    local markerButtons = {}
    for i, marker in ipairs(RAID_MARKERS) do
        local btn = FrameFactory:CreateButton(content, 30, 30, "")
        
        local col = ((i - 1) % 4)
        local row = math.floor((i - 1) / 4)
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
    local worldLabel = FontKit:CreateFontString(content, 'body', 'normal')
    worldLabel:SetPoint("TOPLEFT", markerButtons[5], "BOTTOMLEFT", 0, -15)
    worldLabel:SetText("World Markers:")
    worldLabel:SetTextColor(ColorPalette:GetColor('text-secondary'))
    
    -- World marker buttons (in 2 rows of 4)
    for i = 1, 8 do
        local btn = FrameFactory:CreateButton(content, 30, 30, "")
        
        local col = ((i - 1) % 4)
        local row = math.floor((i - 1) / 4)
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
    local actionsLabel = FontKit:CreateFontString(content, 'body', 'normal')
    actionsLabel:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 3, 120)
    actionsLabel:SetText("Actions:")
    actionsLabel:SetTextColor(ColorPalette:GetColor('text-secondary'))
    
    -- Leave Party button (using FrameFactory)
    local leaveBtn = FrameFactory:CreateButton(content, 180, 22, "Leave Party")
    leaveBtn:SetPoint("TOPLEFT", actionsLabel, "BOTTOMLEFT", 0, -5)
    
    leaveBtn:SetScript("OnClick", function()
        if IsInRaid() then
            LeaveParty()
        elseif IsInGroup() then
            LeaveParty()
        end
    end)
    
    -- Ready Check button (using FrameFactory)
    local readyBtn = FrameFactory:CreateButton(content, 180, 22, "Ready Check")
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
    local convertBtn = FrameFactory:CreateButton(content, 180, 22, "Convert to Raid")
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
    local difficultyLabel = FontKit:CreateFontString(content, 'body', 'normal')
    difficultyLabel:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 3, 5)
    difficultyLabel:SetText("Difficulty:")
    difficultyLabel:SetTextColor(ColorPalette:GetColor('text-secondary'))
    
    -- Dungeon Difficulty Button (using FrameFactory)
    local dungeonBtn = FrameFactory:CreateButton(content, 87, 20, "Normal")
    dungeonBtn:SetPoint("LEFT", difficultyLabel, "RIGHT", 5, 0)
    
    local function UpdateDungeonText()
        local difficultyID = GetDungeonDifficultyID()
        local difficultyName = GetDifficultyInfo(difficultyID)
        dungeonBtn:SetButtonText(difficultyName or "Normal")
    end
    
    UpdateDungeonText()
    
    dungeonBtn:SetScript("OnClick", function(self)
        local currentDiff = GetDungeonDifficultyID()
        local newDiff
        
        -- Cycle through: 1=Normal, 2=Heroic, 23=Mythic
        if currentDiff == 1 then
            newDiff = 2  -- Heroic
        elseif currentDiff == 2 then
            newDiff = 23 -- Mythic
        else
            newDiff = 1  -- Normal
        end
        
        SetDungeonDifficultyID(newDiff)
        UpdateDungeonText()
    end)
    
    -- Custom tooltip for dungeon button
    local originalDungeonEnter = dungeonBtn:GetScript("OnEnter")
    dungeonBtn:SetScript("OnEnter", function(self)
        if originalDungeonEnter then originalDungeonEnter(self) end
        
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Dungeon Difficulty", 1, 1, 1)
        GameTooltip:AddLine("Click to cycle difficulty", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    -- Raid Difficulty Button (using FrameFactory)
    local raidBtn = FrameFactory:CreateButton(content, 87, 20, "Normal")
    raidBtn:SetPoint("LEFT", dungeonBtn, "RIGHT", 3, 0)
    
    local function UpdateRaidText()
        local difficultyID = GetRaidDifficultyID()
        local difficultyName = GetDifficultyInfo(difficultyID)
        raidBtn:SetButtonText(difficultyName or "Normal")
    end
    
    UpdateRaidText()
    
    raidBtn:SetScript("OnClick", function(self)
        local currentDiff = GetRaidDifficultyID()
        local newDiff
        
        -- Cycle through: 14=Normal, 15=Heroic, 16=Mythic
        if currentDiff == 14 then
            newDiff = 15  -- Heroic
        elseif currentDiff == 15 then
            newDiff = 16 -- Mythic
        else
            newDiff = 14  -- Normal
        end
        
        SetRaidDifficultyID(newDiff)
        UpdateRaidText()
    end)
    
    -- Custom tooltip for raid button
    local originalRaidEnter = raidBtn:GetScript("OnEnter")
    raidBtn:SetScript("OnEnter", function(self)
        if originalRaidEnter then originalRaidEnter(self) end
        
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Raid Difficulty", 1, 1, 1)
        GameTooltip:AddLine("Click to cycle difficulty", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    -- Store references for updates
    managerFrame.dungeonBtn = dungeonBtn
    managerFrame.raidBtn = raidBtn
    managerFrame.updateDungeonText = UpdateDungeonText
    managerFrame.updateRaidText = UpdateRaidText
end

function GroupManager:ToggleExpanded()
    isExpanded = not isExpanded
    
    if isExpanded then
        managerFrame:SetSize(self.db.profile.expandedWidth, self.db.profile.expandedHeight)
        managerFrame.content:Show()
        managerFrame.icon:Hide()
    else
        managerFrame:SetSize(self.db.profile.compactWidth, self.db.profile.compactHeight)
        managerFrame.content:Hide()
        managerFrame.icon:Show()
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
    
    -- Update difficulty buttons if frame exists
    if managerFrame and managerFrame.updateDungeonText then
        managerFrame.updateDungeonText()
        managerFrame.updateRaidText()
    end
end

function GroupManager:PLAYER_DIFFICULTY_CHANGED()
    -- Update difficulty buttons when difficulty changes
    if managerFrame and managerFrame.updateDungeonText then
        managerFrame.updateDungeonText()
        managerFrame.updateRaidText()
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
    
    if isExpanded then
        managerFrame:SetSize(self.db.profile.expandedWidth, self.db.profile.expandedHeight)
    else
        managerFrame:SetSize(self.db.profile.compactWidth, self.db.profile.compactHeight)
    end
end

return GroupManager
