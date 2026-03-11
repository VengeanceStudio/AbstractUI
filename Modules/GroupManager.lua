-- ============================================================================
-- Group Manager Module
-- ============================================================================
-- Compact group management toolbar with markers and controls
-- ============================================================================

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local GroupManager = AbstractUI:NewModule("GroupManager", "AceEvent-3.0")
local ColorPalette = _G.AbstractUI_ColorPalette
local FontKit = _G.AbstractUI_FontKit

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
    
    managerFrame = CreateFrame("Frame", "AbstractUI_GroupManager", UIParent, "BackdropTemplate")
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
    managerFrame:EnableMouse(true)
    managerFrame:RegisterForDrag("LeftButton")
    
    managerFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    
    if ColorPalette then
        local bgr, bgg, bgb, bga = ColorPalette:GetColor('panel-bg')
        local bordr, bordg, bordb, borda = ColorPalette:GetColor('panel-border')
        managerFrame:SetBackdropColor(bgr, bgg, bgb, bga or 0.9)
        managerFrame:SetBackdropBorderColor(bordr, bordg, bordb, borda or 1)
    else
        managerFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        managerFrame:SetBackdropBorderColor(0, 0, 0, 1)
    end
    
    managerFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    managerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        GroupManager.db.profile.position.point = point
        GroupManager.db.profile.position.x = x
        GroupManager.db.profile.position.y = y
    end)
    
    -- Toggle button
    local toggleBtn = CreateFrame("Button", nil, managerFrame, "BackdropTemplate")
    toggleBtn:SetSize(self.db.profile.compactWidth - 2, self.db.profile.compactHeight - 2)
    toggleBtn:SetPoint("CENTER", managerFrame, "CENTER", 0, 0)
    toggleBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    
    if ColorPalette then
        local bgr, bgg, bgb, bga = ColorPalette:GetColor('button-bg')
        local bordr, bordg, bordb, borda = ColorPalette:GetColor('panel-border')
        toggleBtn:SetBackdropColor(bgr, bgg, bgb, bga or 0.8)
        toggleBtn:SetBackdropBorderColor(bordr, bordg, bordb, borda or 1)
    else
        toggleBtn:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
        toggleBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
    
    -- Icon for collapsed state (group icon)
    local icon = toggleBtn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
    icon:SetVertexColor(0.8, 0.8, 0.8, 1)
    
    managerFrame.toggleBtn = toggleBtn
    managerFrame.icon = icon
    
    toggleBtn:SetScript("OnClick", function()
        GroupManager:ToggleExpanded()
    end)
    
    toggleBtn:SetScript("OnEnter", function(self)
        if ColorPalette then
            local r, g, b, a = ColorPalette:GetColor('button-hover')
            self:SetBackdropColor(r, g, b, a or 0.9)
        else
            self:SetBackdropColor(0.25, 0.25, 0.25, 0.9)
        end
        
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Group Manager", 1, 1, 1)
        GameTooltip:AddLine("Click to expand/collapse", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    toggleBtn:SetScript("OnLeave", function(self)
        if ColorPalette then
            local r, g, b, a = ColorPalette:GetColor('button-bg')
            self:SetBackdropColor(r, g, b, a or 0.8)
        else
            self:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
        end
        GameTooltip:Hide()
    end)
    
    -- Create expanded content (hidden by default)
    self:CreateExpandedContent()
    
    managerFrame:Hide()
end

function GroupManager:CreateExpandedContent()
    if not managerFrame then return end
    
    local content = CreateFrame("Frame", nil, managerFrame)
    content:SetPoint("TOPLEFT", managerFrame, "TOPLEFT", 2, -2)
    content:SetPoint("BOTTOMRIGHT", managerFrame, "BOTTOMRIGHT", -2, 2)
    content:Hide()
    
    managerFrame.content = content
    
    -- Title
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
    title:SetText("Group Controls")
    if FontKit then
        FontKit:SetFont(title, 'header', 'large')
    end
    
    -- Raid Markers Section
    local markersLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    markersLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    markersLabel:SetText("Raid Markers:")
    if FontKit then
        FontKit:SetFont(markersLabel, 'body', 'normal')
    end
    
    -- Create marker buttons in 2 rows of 4
    local markerButtons = {}
    for i, marker in ipairs(RAID_MARKERS) do
        local btn = CreateFrame("Button", nil, content)
        btn:SetSize(30, 30)
        
        local col = ((i - 1) % 4)
        local row = math.floor((i - 1) / 4)
        btn:SetPoint("TOPLEFT", markersLabel, "BOTTOMLEFT", col * 35, -5 - (row * 35))
        
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(btn)
        icon:SetTexture(marker.icon)
        
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
            icon:SetVertexColor(1, 1, 0.5)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(marker.name, 1, 1, 1)
            GameTooltip:AddLine("Left-click: Mark target", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Right-click: Clear marker", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        
        btn:SetScript("OnLeave", function(self)
            icon:SetVertexColor(1, 1, 1)
            GameTooltip:Hide()
        end)
        
        btn:RegisterForClicks("LeftButtonDown", "RightButtonDown")
        
        markerButtons[i] = btn
    end
    
    -- World Markers Section
    local worldLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    worldLabel:SetPoint("TOPLEFT", markerButtons[5], "BOTTOMLEFT", 0, -15)
    worldLabel:SetText("World Markers:")
    if FontKit then
        FontKit:SetFont(worldLabel, 'body', 'normal')
    end
    
    -- World marker buttons (in 2 rows of 4)
    for i = 1, 8 do
        local btn = CreateFrame("Button", nil, content)
        btn:SetSize(30, 30)
        
        local col = ((i - 1) % 4)
        local row = math.floor((i - 1) / 4)
        btn:SetPoint("TOPLEFT", worldLabel, "BOTTOMLEFT", col * 35, -5 - (row * 35))
        
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(btn)
        icon:SetTexture(RAID_MARKERS[i].icon)
        icon:SetVertexColor(0.7, 0.7, 0.7)
        
        btn:SetScript("OnClick", function(self)
            PlaceRaidMarker(i)
        end)
        
        btn:SetScript("OnEnter", function(self)
            icon:SetVertexColor(1, 1, 0.5)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Place " .. RAID_MARKERS[i].name, 1, 1, 1)
            GameTooltip:AddLine("Click to place on ground", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        
        btn:SetScript("OnLeave", function(self)
            icon:SetVertexColor(0.7, 0.7, 0.7)
            GameTooltip:Hide()
        end)
    end
    
    -- Actions Section
    local actionsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionsLabel:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 5, 120)
    actionsLabel:SetText("Actions:")
    if FontKit then
        FontKit:SetFont(actionsLabel, 'body', 'normal')
    end
    
    -- Leave Party button
    local leaveBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    leaveBtn:SetSize(180, 20)
    leaveBtn:SetPoint("TOPLEFT", actionsLabel, "BOTTOMLEFT", 0, -5)
    leaveBtn:SetText("Leave Party")
    
    leaveBtn:SetScript("OnClick", function()
        if IsInRaid() then
            LeaveParty()
        elseif IsInGroup() then
            LeaveParty()
        end
    end)
    
    -- Ready Check button
    local readyBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    readyBtn:SetSize(180, 20)
    readyBtn:SetPoint("TOPLEFT", leaveBtn, "BOTTOMLEFT", 0, -5)
    readyBtn:SetText("Ready Check")
    
    readyBtn:SetScript("OnClick", function()
        DoReadyCheck()
    end)
    
    readyBtn:SetScript("OnEnter", function(self)
        if not (IsInRaid() or IsInGroup()) or not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Requires Leader/Assistant", 1, 0.3, 0.3)
            GameTooltip:Show()
        end
    end)
    
    readyBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Convert to Raid button
    local convertBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    convertBtn:SetSize(180, 20)
    convertBtn:SetPoint("TOPLEFT", readyBtn, "BOTTOMLEFT", 0, -5)
    convertBtn:SetText("Convert to Raid")
    
    convertBtn:SetScript("OnClick", function()
        if IsInGroup() and not IsInRaid() and UnitIsGroupLeader("player") then
            ConvertToRaid()
        end
    end)
    
    convertBtn:SetScript("OnEnter", function(self)
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
    
    convertBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Difficulty Settings Section
    local difficultyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    difficultyLabel:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 5, 5)
    difficultyLabel:SetText("Difficulty:")
    if FontKit then
        FontKit:SetFont(difficultyLabel, 'body', 'normal')
    end
    
    -- Dungeon Difficulty Dropdown
    local dungeonBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    dungeonBtn:SetSize(87, 20)
    dungeonBtn:SetPoint("LEFT", difficultyLabel, "RIGHT", 5, 0)
    
    local function UpdateDungeonText()
        local difficultyID = GetDungeonDifficultyID()
        local difficultyName = GetDifficultyInfo(difficultyID)
        dungeonBtn:SetText(difficultyName or "Dungeon")
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
    
    dungeonBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Dungeon Difficulty", 1, 1, 1)
        GameTooltip:AddLine("Click to cycle difficulty", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    dungeonBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Raid Difficulty Dropdown
    local raidBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    raidBtn:SetSize(87, 20)
    raidBtn:SetPoint("LEFT", dungeonBtn, "RIGHT", 3, 0)
    
    local function UpdateRaidText()
        local difficultyID = GetRaidDifficultyID()
        local difficultyName = GetDifficultyInfo(difficultyID)
        raidBtn:SetText(difficultyName or "Raid")
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
    
    raidBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Raid Difficulty", 1, 1, 1)
        GameTooltip:AddLine("Click to cycle difficulty", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    raidBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
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
        managerFrame.toggleBtn:SetSize(self.db.profile.compactWidth - 2, self.db.profile.compactHeight - 2)
    end
end

return GroupManager
