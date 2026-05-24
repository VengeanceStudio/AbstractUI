local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local GroupManager = AbstractUI:NewModule("GroupManager", "AceEvent-3.0")

---------------------------------------------------------------------------
-- GROUP MANAGER SKIN
-- Skins Blizzard's CompactRaidFrameManager with AbstractUI styling
-- and provides a compact toggle icon for easy access
---------------------------------------------------------------------------

local SkinFramework = nil
local ColorPalette = nil
local FontKit = nil
local FrameFactory = nil
local skinned = false

-- State
local managerFrame = nil
local isExpanded = false
local blizzardManager = nil

-- WoW API compatibility
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
local LoadAddOn = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn

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

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

function GroupManager:OnInitialize()
    self:RegisterMessage("AbstractUI_DB_READY", "OnDBReady")
end

function GroupManager:OnDBReady()
    -- Get framework references
    SkinFramework = AbstractUI.SkinFramework
    if SkinFramework then
        ColorPalette = SkinFramework:GetColorPalette()
        FontKit = SkinFramework:GetFontKit()
    end
    
    -- Fallback to global references if SkinFramework not available
    if not ColorPalette then
        ColorPalette = _G.AbstractUI_ColorPalette
    end
    if not FontKit then
        FontKit = _G.AbstractUI_FontKit
    end
    if not FrameFactory then
        FrameFactory = _G.AbstractUI_FrameFactory
    end
    
    self.db = AbstractUI.db:RegisterNamespace("GroupManager", defaults)
    
    -- Check if enabled in module settings
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
    self:RegisterEvent("ADDON_LOADED")
    
    -- Listen for move mode changes
    self:RegisterMessage("AbstractUI_MOVEMODE_CHANGED", "OnMoveModeChanged")
    
    -- Create toggle icon and reskin Blizzard's frame
    C_Timer.After(0.5, function()
        self:CreateToggleIcon()
        self:ApplySkin()
        self:UpdateVisibility()
    end)
    
    -- Also hook CompactRaidFrameManager if it already exists
    if CompactRaidFrameManager then
        self:HookFrameForSkinning()
        -- If frame is already shown, apply skin immediately
        if CompactRaidFrameManager:IsShown() then
            C_Timer.After(0.6, function()
                self:ApplySkin()
            end)
        end
    end
end

---------------------------------------------------------------------------
-- ADDON LOADED EVENT
---------------------------------------------------------------------------

function GroupManager:ADDON_LOADED(event, addon)
    if addon == "Blizzard_CompactRaidFrames" then
        C_Timer.After(0.2, function()
            self:HookFrameForSkinning()
            self:ApplySkin()
        end)
    end
end

function GroupManager:HookFrameForSkinning()
    if not CompactRaidFrameManager then return end
    if CompactRaidFrameManager.abstractUIHookedForSkin then return end
    
    -- Hook OnShow to ensure skin is applied when frame appears
    CompactRaidFrameManager:HookScript("OnShow", function()
        if not skinned and IsEnabled() then
            GroupManager:ApplySkin()
        end
    end)
    
    CompactRaidFrameManager.abstractUIHookedForSkin = true
end

---------------------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------------------

local function IsEnabled()
    -- If the Group Manager module is enabled, always apply skinning
    if AbstractUI.db and AbstractUI.db.profile and AbstractUI.db.profile.modules then
        if AbstractUI.db.profile.modules.groupManager == true then
            return true
        end
    end
    
    -- Also check the separate skin toggle (for users who may want to skin without the toggle icon)
    if SkinFramework then
        return SkinFramework:IsFrameEnabled("CompactRaidFrameManager")
    end
    
    return false
end

local function GetThemeColors()
    if ColorPalette then
        -- Get color tables and convert to arrays for unpack()
        local primary = ColorPalette:GetColorTable('background-primary')
        local secondary = ColorPalette:GetColorTable('background-secondary')
        local tertiary = ColorPalette:GetColorTable('background-tertiary')
        local border = ColorPalette:GetColorTable('border-primary')
        local hover = ColorPalette:GetColorTable('background-hover')
        
        -- Helper function to safely convert color table to array
        local function toColorArray(t, fallback)
            if not t then return fallback end
            return {
                t.r or t[1] or fallback[1],
                t.g or t[2] or fallback[2],
                t.b or t[3] or fallback[3],
                t.a or t[4] or fallback[4]
            }
        end
        
        return {
            primary = toColorArray(primary, {0.1, 0.1, 0.1, 0.75}),
            secondary = toColorArray(secondary, {0.15, 0.15, 0.15, 0.75}),
            tertiary = toColorArray(tertiary, {0.2, 0.2, 0.2, 0.75}),
            border = toColorArray(border, {0.3, 0.3, 0.3, 1}),
            hover = toColorArray(hover, {0.25, 0.25, 0.35, 0.9}),
            textPrimary = {ColorPalette:GetColor('text-primary')},
            textSecondary = {ColorPalette:GetColor('text-secondary')},
        }
    end
    
    -- Fallback colors
    return {
        primary = {0.1, 0.1, 0.1, 0.75},
        secondary = {0.15, 0.15, 0.15, 0.75},
        tertiary = {0.2, 0.2, 0.2, 0.75},
        border = {0.3, 0.3, 0.3, 1},
        hover = {0.25, 0.25, 0.35, 0.9},
        textPrimary = {1, 1, 1, 1},
        textSecondary = {0.7, 0.7, 0.7, 1},
    }
end

---------------------------------------------------------------------------
-- TOGGLE ICON CREATION
---------------------------------------------------------------------------

function GroupManager:CreateToggleIcon()
    if managerFrame then return end
    
    local Movable = AbstractUI:GetModule("Movable", true)
    local colors = GetThemeColors()
    
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
    local toggleBtn
    if FrameFactory then
        toggleBtn = FrameFactory:CreateButton(managerFrame, self.db.profile.compactWidth, self.db.profile.compactHeight, "")
    else
        -- Fallback button creation
        toggleBtn = CreateFrame("Button", nil, managerFrame, "BackdropTemplate")
        toggleBtn:SetSize(self.db.profile.compactWidth, self.db.profile.compactHeight)
        toggleBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        toggleBtn:SetBackdropColor(unpack(colors.primary))
        toggleBtn:SetBackdropBorderColor(unpack(colors.border))
    end
    
    toggleBtn:SetPoint("CENTER", managerFrame, "CENTER", 0, 0)
    toggleBtn:EnableMouse(true)
    
    -- Icon for toggle button
    local icon = toggleBtn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
    if ColorPalette then
        icon:SetVertexColor(ColorPalette:GetColor('text-primary'))
    else
        icon:SetVertexColor(1, 1, 1)
    end
    
    if toggleBtn.text then
        toggleBtn.text:Hide()
    end
    
    managerFrame.toggleBtn = toggleBtn
    managerFrame.icon = icon
    
    toggleBtn:SetScript("OnClick", function()
        if not AbstractUI.moveMode then
            GroupManager:ToggleExpanded()
        end
    end)
    
    -- Tooltips
    toggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Group Manager", 1, 1, 1)
        GameTooltip:AddLine("Click to expand/collapse", 0.7, 0.7, 0.7)
        if AbstractUI.moveMode then
            GameTooltip:AddLine("Drag to move", 0.5, 1, 0.5)
        end
        GameTooltip:Show()
    end)
    
    toggleBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Movable system integration
    if Movable then
        local highlight = CreateFrame("Frame", "AbstractUI_GroupManagerHighlight", UIParent, "BackdropTemplate")
        highlight:SetSize(managerFrame:GetSize())
        highlight:SetPoint(managerFrame:GetPoint())
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
        
        highlight.movableHighlight = highlight:CreateTexture(nil, "OVERLAY")
        highlight.movableHighlight:SetAllPoints(highlight)
        highlight.movableHighlight:SetColorTexture(0, 1, 0, 0.2)
        highlight.movableHighlight:Hide()
        
        highlight.movableHighlightLabel = highlight.text
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

---------------------------------------------------------------------------
-- BLIZZARD FRAME SKINNING
---------------------------------------------------------------------------

function GroupManager:ApplySkin(force)
    if not IsEnabled() then 
        print("|cffff0000AbstractUI GroupManager:|r Skinning not enabled")
        return 
    end
    
    if skinned and not force then 
        return 
    end
    
    if not CompactRaidFrameManager then 
        print("|cffff0000AbstractUI GroupManager:|r CompactRaidFrameManager not found")
        return 
    end
    
    print("|cff00ff00AbstractUI GroupManager:|r Applying skin to CompactRaidFrameManager")
    
    blizzardManager = CompactRaidFrameManager
    local displayFrame = blizzardManager.displayFrame or CompactRaidFrameManagerDisplayFrame
    
    if not displayFrame then 
        print("|cffff0000AbstractUI GroupManager:|r Display frame not found")
        return 
    end
    
    local colors = GetThemeColors()
    
    -- Store original settings
    if not blizzardManager.abstractUIOriginal then
        blizzardManager.abstractUIOriginal = {
            shown = blizzardManager:IsShown(),
            parent = blizzardManager:GetParent(),
            strata = blizzardManager:GetFrameStrata(),
        }
    end
    
    -- Ensure BackdropTemplate is available
    if not blizzardManager.SetBackdrop and BackdropTemplateMixin then
        Mixin(blizzardManager, BackdropTemplateMixin)
        if blizzardManager.OnBackdropLoaded then
            blizzardManager:OnBackdropLoaded()
        end
    end
    
    -- Apply AbstractUI styling to the main frame
    if blizzardManager.SetBackdrop then
        blizzardManager:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        blizzardManager:SetBackdropColor(unpack(colors.primary))
        blizzardManager:SetBackdropBorderColor(unpack(colors.border))
    end
    
    -- Hide all Blizzard art textures on the main frame
    for _, region in ipairs({blizzardManager:GetRegions()}) do
        if region:IsObjectType("Texture") then
            local texPath = region:GetTexture()
            if texPath then
                local texStr = tostring(texPath)
                if not texStr:match("WHITE8X8") then
                    region:SetAlpha(0)
                end
            end
        elseif region:IsObjectType("FontString") then
            region:SetTextColor(unpack(colors.textPrimary))
        end
    end
    
    -- Also hide textures on the display frame
    if displayFrame then
        for _, region in ipairs({displayFrame:GetRegions()}) do
            if region:IsObjectType("Texture") then
                local texPath = region:GetTexture()
                if texPath then
                    local texStr = tostring(texPath)
                    if not texStr:match("WHITE8X8") then
                        region:SetAlpha(0)
                    end
                end
            end
        end
        
        -- Ensure BackdropTemplate is available for display frame
        if not displayFrame.SetBackdrop and BackdropTemplateMixin then
            Mixin(displayFrame, BackdropTemplateMixin)
            if displayFrame.OnBackdropLoaded then
                displayFrame:OnBackdropLoaded()
            end
        end
        
        -- Apply backdrop to display frame
        if displayFrame.SetBackdrop then
            displayFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false,
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            displayFrame:SetBackdropColor(unpack(colors.tertiary))
            displayFrame:SetBackdropBorderColor(unpack(colors.border))
        end
    end
    
    -- Reskin all buttons and UI elements
    self:ReskinBlizzardButtons(displayFrame, colors)
    
    -- Hide initially (will show when expanded)
    blizzardManager:Hide()
    blizzardManager:SetMovable(false)
    blizzardManager:EnableMouse(false)
    
    -- Prevent Blizzard from showing it automatically
    if not blizzardManager.abstractUIHooked then
        blizzardManager:UnregisterAllEvents()
        blizzardManager.abstractUIHooked = true
    end
    
    skinned = true
end

function GroupManager:ReskinBlizzardButtons(frame, colors)
    if not frame then return end
    
    -- Reskin all children recursively
    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())
        local childName = child:GetName() or ""
        
        -- Hide default Blizzard art textures
        for _, region in ipairs({child:GetRegions()}) do
            if region:IsObjectType("Texture") then
                local texPath = region:GetTexture()
                if texPath then
                    local texStr = tostring(texPath)
                    if not (texStr:match("RaidTargetingIcon") or texStr:match("RaidIcon") or texStr:match("WHITE8X8")) then
                        local regionName = region:GetName() or ""
                        if regionName:match("Background") or regionName:match("Border") or regionName:match("Texture") or 
                           regionName:match("Left") or regionName:match("Right") or regionName:match("Middle") or
                           texStr:match("Interface\\FriendsFrame") or texStr:match("Interface\\ChatFrame") then
                            region:SetAlpha(0)
                        end
                    end
                end
            elseif region:IsObjectType("FontString") then
                if not region.abstractUIStyled then
                    local _, fontSize = region:GetFont()
                    if fontSize and fontSize >= 14 then
                        region:SetTextColor(unpack(colors.textPrimary))
                    else
                        region:SetTextColor(unpack(colors.textSecondary))
                    end
                    region.abstractUIStyled = true
                end
            end
        end
        
        -- Style CheckButtons
        if child:IsObjectType("CheckButton") then
            if child.SetBackdrop then
                child:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false,
                    edgeSize = 1,
                    insets = { left = 0, right = 0, top = 0, bottom = 0 }
                })
                child:SetBackdropColor(unpack(colors.secondary))
                child:SetBackdropBorderColor(unpack(colors.border))
            end
            
            local checkTexture = child:GetCheckedTexture()
            if checkTexture then
                checkTexture:SetColorTexture(0.2, 0.8, 0.2, 1)
                checkTexture:SetAllPoints()
            end
            
            local normalTexture = child:GetNormalTexture()
            if normalTexture then normalTexture:SetAlpha(0) end
            local pushedTexture = child:GetPushedTexture()
            if pushedTexture then pushedTexture:SetAlpha(0) end
        end
        
        -- Style Buttons
        if child:IsObjectType("Button") and child.SetBackdrop then
            child:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false,
                edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })
            child:SetBackdropColor(unpack(colors.secondary))
            child:SetBackdropBorderColor(unpack(colors.border))
            
            if not child.abstractUIStyled then
                child:HookScript("OnEnter", function(self)
                    if self:IsEnabled() then
                        self:SetBackdropColor(unpack(colors.hover))
                    end
                end)
                
                child:HookScript("OnLeave", function(self)
                    self:SetBackdropColor(unpack(colors.secondary))
                end)
                
                child.abstractUIStyled = true
            end
            
            -- Hide default textures
            for _, region in ipairs({child:GetRegions()}) do
                if region:IsObjectType("Texture") and not region:GetName() then
                    local texture = region:GetTexture()
                    if texture then
                        local texStr = tostring(texture)
                        if not (texStr:match("RaidTargetingIcon") or texStr:match("RaidIcon") or texStr:match("WHITE8X8")) then
                            region:SetAlpha(0)
                        end
                    end
                end
            end
            
            local buttonText = child:GetFontString()
            if buttonText and not buttonText.abstractUIStyled then
                buttonText:SetTextColor(unpack(colors.textPrimary))
                buttonText.abstractUIStyled = true
            end
        end
        
        -- Style container Frames
        if child:IsObjectType("Frame") and child.SetBackdrop then
            local backdrop = child:GetBackdrop()
            if backdrop then
                child:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false,
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                child:SetBackdropColor(unpack(colors.primary))
                child:SetBackdropBorderColor(unpack(colors.border))
            end
        end
        
        -- Recurse into children
        self:ReskinBlizzardButtons(child, colors)
    end
end

---------------------------------------------------------------------------
-- MANAGER POSITIONING & TOGGLE
---------------------------------------------------------------------------

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

---------------------------------------------------------------------------
-- EVENTS
---------------------------------------------------------------------------

function GroupManager:GROUP_ROSTER_UPDATE()
    self:UpdateVisibility()
end

function GroupManager:PLAYER_ENTERING_WORLD()
    self:UpdateVisibility()
end

function GroupManager:OnMoveModeChanged(event, moveMode)
    if not managerFrame or not managerFrame.moveHighlight then return end
    
    if moveMode then
        managerFrame.moveHighlight:Show()
        if managerFrame.toggleBtn then
            managerFrame.toggleBtn:EnableMouse(false)
        end
    else
        managerFrame.moveHighlight:Hide()
        if managerFrame.toggleBtn then
            managerFrame.toggleBtn:EnableMouse(true)
        end
    end
end

function GroupManager:UpdateVisibility()
    if not managerFrame then return end
    
    if IsInGroup() or IsInRaid() then
        managerFrame:Show()
    else
        managerFrame:Hide()
    end
end

---------------------------------------------------------------------------
-- OPTIONS
---------------------------------------------------------------------------

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
                        self:OnDBReady()
                    else
                        if managerFrame then
                            managerFrame:Hide()
                        end
                        if blizzardManager then
                            blizzardManager:Hide()
                        end
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
    
    managerFrame.toggleBtn:SetSize(self.db.profile.compactWidth, self.db.profile.compactHeight)
    managerFrame:SetSize(self.db.profile.compactWidth, self.db.profile.compactHeight)
end

---------------------------------------------------------------------------
-- SLASH COMMANDS
---------------------------------------------------------------------------

SLASH_GROUPMANAGER1 = "/gmskin"
SLASH_GROUPMANAGER2 = "/groupmanagerskin"
SlashCmdList["GROUPMANAGER"] = function(msg)
    if msg == "reskin" or msg == "" then
        print("|cff00ff00AbstractUI:|r Force re-skinning Group Manager frame...")
        if GroupManager then
            skinned = false
            GroupManager:ApplySkin(true)
        end
    elseif msg == "debug" then
        print("|cff00ff00AbstractUI GroupManager Debug:|r")
        print("  Module Enabled:", AbstractUI.db.profile.modules.groupManager)
        print("  IsEnabled():", IsEnabled())
        print("  Skinned:", skinned)
        print("  CompactRaidFrameManager exists:", CompactRaidFrameManager ~= nil)
        if CompactRaidFrameManager then
            print("  Frame is shown:", CompactRaidFrameManager:IsShown())
        end
        print("  ColorPalette exists:", ColorPalette ~= nil)
        
        -- Test color generation
        local colors = GetThemeColors()
        print("  Colors generated:")
        print("    Primary:", unpack(colors.primary))
        print("    Border:", unpack(colors.border))
    else
        print("|cff00ff00AbstractUI Group Manager Commands:|r")
        print("  /gmskin reskin - Force re-apply skin")
        print("  /gmskin debug - Show debug information")
    end
end

return GroupManager
