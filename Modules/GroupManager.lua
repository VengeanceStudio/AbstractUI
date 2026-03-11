-- ============================================================================
-- Group Manager Module
-- ============================================================================
-- Compact party/raid frames that expand on click for more details
-- ============================================================================

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local GroupManager = AbstractUI:NewModule("GroupManager", "AceEvent-3.0")
local ColorPalette = _G.AbstractUI_ColorPalette
local FontKit = _G.AbstractUI_FontKit
local FrameFactory = _G.AbstractUI_FrameFactory

-- State
local groupFrames = {}
local containerFrame = nil
local isExpanded = false
local MAX_PARTY_MEMBERS = 4

local defaults = {
    profile = {
        enabled = true,
        compactMode = true, -- Start in compact mode
        showPets = false,
        compactWidth = 80,
        compactHeight = 8,
        expandedWidth = 180,
        expandedHeight = 40,
        spacing = 2,
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
end

function GroupManager:OnEnable()
    -- Check if module is enabled
    if not AbstractUI.db.profile.modules.groupManager then
        return
    end
    
    -- Register events
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("UNIT_HEALTH")
    self:RegisterEvent("UNIT_MAXHEALTH")
    self:RegisterEvent("UNIT_POWER_UPDATE")
    self:RegisterEvent("UNIT_MAXPOWER")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_CONNECTION")
    
    -- Create frames
    self:CreateContainer()
    self:UpdateGroupFrames()
end

function GroupManager:OnDisable()
    if containerFrame then
        containerFrame:Hide()
    end
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

function GroupManager:CreateContainer()
    if containerFrame then return end
    
    containerFrame = CreateFrame("Frame", "AbstractUI_GroupContainer", UIParent, "BackdropTemplate")
    containerFrame:SetSize(200, 200)
    containerFrame:SetPoint(
        self.db.profile.position.point,
        UIParent,
        self.db.profile.position.point,
        self.db.profile.position.x,
        self.db.profile.position.y
    )
    containerFrame:SetFrameStrata("LOW")
    containerFrame:SetMovable(true)
    containerFrame:EnableMouse(true)
    containerFrame:RegisterForDrag("LeftButton")
    containerFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    containerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        GroupManager.db.profile.position.point = point
        GroupManager.db.profile.position.x = x
        GroupManager.db.profile.position.y = y
    end)
    
    -- Toggle button (always visible)
    local toggleBtn = CreateFrame("Button", nil, containerFrame, "BackdropTemplate")
    toggleBtn:SetSize(20, 20)
    toggleBtn:SetPoint("TOPRIGHT", containerFrame, "TOPRIGHT", 0, 0)
    toggleBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    
    if ColorPalette then
        local bgr, bgg, bgb, bga = ColorPalette:GetColor('panel-bg')
        local bordr, bordg, bordb, borda = ColorPalette:GetColor('panel-border')
        toggleBtn:SetBackdropColor(bgr, bgg, bgb, bga or 0.9)
        toggleBtn:SetBackdropBorderColor(bordr, bordg, bordb, borda or 1)
    else
        toggleBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        toggleBtn:SetBackdropBorderColor(0, 0, 0, 1)
    end
    
    local toggleText = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toggleText:SetPoint("CENTER")
    toggleText:SetText("+")
    if FontKit then
        FontKit:SetFont(toggleText, 'body', 'normal')
    end
    
    toggleBtn:SetScript("OnClick", function()
        GroupManager:ToggleExpanded()
    end)
    
    toggleBtn:SetScript("OnEnter", function(self)
        if ColorPalette then
            local r, g, b, a = ColorPalette:GetColor('button-hover')
            self:SetBackdropColor(r, g, b, a or 0.9)
        else
            self:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
        end
    end)
    
    toggleBtn:SetScript("OnLeave", function(self)
        if ColorPalette then
            local r, g, b, a = ColorPalette:GetColor('panel-bg')
            self:SetBackdropColor(r, g, b, a or 0.9)
        else
            self:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        end
    end)
    
    containerFrame.toggleBtn = toggleBtn
    containerFrame.toggleText = toggleText
    
    -- Start hidden
    containerFrame:Hide()
end

function GroupManager:CreateGroupFrame(index)
    if groupFrames[index] then
        return groupFrames[index]
    end
    
    local frame = CreateFrame("Button", "AbstractUI_GroupFrame" .. index, containerFrame, "BackdropTemplate")
    frame:SetSize(self.db.profile.compactWidth, self.db.profile.compactHeight)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    
    -- Health bar background
    frame.healthBg = frame:CreateTexture(nil, "BACKGROUND")
    frame.healthBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.healthBg:SetPoint("TOPLEFT", 1, -1)
    frame.healthBg:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.healthBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    
    -- Health bar
    frame.health = frame:CreateTexture(nil, "ARTWORK")
    frame.health:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.health:SetPoint("TOPLEFT", 1, -1)
    frame.health:SetPoint("BOTTOMLEFT", 1, 1)
    frame.health:SetWidth(self.db.profile.compactWidth - 2)
    
    -- Name text (hidden in compact mode)
    frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.name:SetPoint("LEFT", frame, "LEFT", 4, 0)
    frame.name:SetJustifyH("LEFT")
    if FontKit then
        FontKit:SetFont(frame.name, 'body', 'small')
    end
    frame.name:Hide()
    
    -- Health text (hidden in compact mode)
    frame.healthText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.healthText:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    frame.healthText:SetJustifyH("RIGHT")
    if FontKit then
        FontKit:SetFont(frame.healthText, 'body', 'small')
    end
    frame.healthText:Hide()
    
    -- Offline/dead indicator
    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.status:SetPoint("CENTER")
    if FontKit then
        FontKit:SetFont(frame.status, 'body', 'small')
    end
    frame.status:Hide()
    
    frame.unit = "party" .. index
    frame.index = index
    frame:Hide()
    
    groupFrames[index] = frame
    return frame
end

-- ============================================================================
-- UPDATE FUNCTIONS
-- ============================================================================

function GroupManager:UpdateGroupFrames()
    if not containerFrame then return end
    
    local numMembers = GetNumSubgroupMembers()
    
    if numMembers == 0 then
        containerFrame:Hide()
        return
    end
    
    containerFrame:Show()
    
    -- Update size based on number of members and mode
    local width = isExpanded and self.db.profile.expandedWidth or self.db.profile.compactWidth
    local height = isExpanded and self.db.profile.expandedHeight or self.db.profile.compactHeight
    local totalHeight = (height + self.db.profile.spacing) * numMembers + 20 -- +20 for toggle button
    
    containerFrame:SetSize(width + 25, totalHeight) -- +25 for toggle button
    
    -- Update each group member frame
    for i = 1, MAX_PARTY_MEMBERS do
        if i <= numMembers and UnitExists("party" .. i) then
            local frame = self:CreateGroupFrame(i)
            frame:ClearAllPoints()
            
            if i == 1 then
                frame:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", 0, -20)
            else
                frame:SetPoint("TOPLEFT", groupFrames[i-1], "BOTTOMLEFT", 0, -self.db.profile.spacing)
            end
            
            frame:SetSize(width, height)
            frame:Show()
            
            self:UpdateUnitFrame(frame)
        elseif groupFrames[i] then
            groupFrames[i]:Hide()
        end
    end
    
    -- Update toggle button text
    if containerFrame.toggleText then
        containerFrame.toggleText:SetText(isExpanded and "-" or "+")
    end
end

function GroupManager:UpdateUnitFrame(frame)
    if not frame or not UnitExists(frame.unit) then return end
    
    local unit = frame.unit
    
    -- Update health
    local health = UnitHealth(unit)
    local maxHealth = UnitHealthMax(unit)
    local healthPct = maxHealth > 0 and (health / maxHealth) or 0
    
    -- Get class color
    local _, class = UnitClass(unit)
    local color
    if UnitIsConnected(unit) then
        if class then
            color = RAID_CLASS_COLORS[class]
        else
            color = { r = 0.5, g = 0.5, b = 0.5 }
        end
    else
        color = { r = 0.5, g = 0.5, b = 0.5 }
    end
    
    -- Update health bar
    if frame.health then
        local width = isExpanded and self.db.profile.expandedWidth or self.db.profile.compactWidth
        frame.health:SetWidth((width - 2) * healthPct)
        
        -- Color based on health percentage
        if not UnitIsConnected(unit) then
            frame.health:SetVertexColor(0.5, 0.5, 0.5, 0.8)
        elseif UnitIsDeadOrGhost(unit) then
            frame.health:SetVertexColor(0.3, 0.3, 0.3, 0.8)
        elseif healthPct <= 0.25 then
            frame.health:SetVertexColor(1, 0, 0, 0.8)
        elseif healthPct <= 0.5 then
            frame.health:SetVertexColor(1, 0.5, 0, 0.8)
        else
            frame.health:SetVertexColor(color.r, color.g, color.b, 0.8)
        end
    end
    
    -- Update border color with class color
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
    end
    
    -- Update texts (only in expanded mode)
    if isExpanded then
        if frame.name then
            frame.name:SetText(UnitName(unit))
            frame.name:Show()
        end
        
        if frame.healthText then
            if UnitIsConnected(unit) then
                if UnitIsDeadOrGhost(unit) then
                    frame.healthText:SetText("DEAD")
                else
                    frame.healthText:SetText(string.format("%d%%", healthPct * 100))
                end
            else
                frame.healthText:SetText("OFF")
            end
            frame.healthText:Show()
        end
        
        -- Hide status indicator in expanded mode
        if frame.status then
            frame.status:Hide()
        end
    else
        -- Compact mode - hide texts
        if frame.name then
            frame.name:Hide()
        end
        if frame.healthText then
            frame.healthText:Hide()
        end
        
        -- Show status indicator for offline/dead
        if frame.status then
            if not UnitIsConnected(unit) then
                frame.status:SetText("D/C")
                frame.status:SetTextColor(0.5, 0.5, 0.5, 1)
                frame.status:Show()
            elseif UnitIsDeadOrGhost(unit) then
                frame.status:SetText("X")
                frame.status:SetTextColor(1, 0, 0, 1)
                frame.status:Show()
            else
                frame.status:Hide()
            end
        end
    end
end

function GroupManager:ToggleExpanded()
    isExpanded = not isExpanded
    self:UpdateGroupFrames()
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

function GroupManager:GROUP_ROSTER_UPDATE()
    self:UpdateGroupFrames()
end

function GroupManager:PLAYER_ENTERING_WORLD()
    self:UpdateGroupFrames()
end

function GroupManager:UNIT_HEALTH(event, unit)
    if not unit or not unit:match("^party%d$") then return end
    
    local index = tonumber(unit:match("%d+"))
    if groupFrames[index] and groupFrames[index]:IsShown() then
        self:UpdateUnitFrame(groupFrames[index])
    end
end

function GroupManager:UNIT_MAXHEALTH(event, unit)
    self:UNIT_HEALTH(event, unit)
end

function GroupManager:UNIT_POWER_UPDATE(event, unit)
    -- Could add power bar functionality here if desired
end

function GroupManager:UNIT_MAXPOWER(event, unit)
    -- Could add power bar functionality here if desired
end

function GroupManager:UNIT_CONNECTION(event, unit)
    if not unit or not unit:match("^party%d$") then return end
    
    local index = tonumber(unit:match("%d+"))
    if groupFrames[index] and groupFrames[index]:IsShown() then
        self:UpdateUnitFrame(groupFrames[index])
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
            self:UpdateGroupFrames()
        end,
        args = {
            enabled = {
                name = "Enable Custom Group Manager",
                desc = "Show compact group frames that expand on click. Make sure to enable 'Hide Compact Party/Raid Manager' in Tweaks to hide Blizzard's default.",
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
                desc = "Width of group frames in compact mode",
                type = "range",
                min = 40,
                max = 200,
                step = 1,
                order = 3,
            },
            compactHeight = {
                name = "Compact Height",
                desc = "Height of group frames in compact mode",
                type = "range",
                min = 4,
                max = 20,
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
                desc = "Width of group frames in expanded mode",
                type = "range",
                min = 100,
                max = 300,
                step = 1,
                order = 6,
            },
            expandedHeight = {
                name = "Expanded Height",
                desc = "Height of group frames in expanded mode",
                type = "range",
                min = 20,
                max = 80,
                step = 1,
                order = 7,
            },
            spacing = {
                name = "Frame Spacing",
                desc = "Vertical spacing between group frames",
                type = "range",
                min = 0,
                max = 10,
                step = 1,
                order = 8,
            },
        }
    }
end

return GroupManager
