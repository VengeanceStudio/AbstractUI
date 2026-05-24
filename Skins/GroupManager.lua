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

---------------------------------------------------------------------------
-- HELPER FUNCTIONS (defined before use)
---------------------------------------------------------------------------

local function IsEnabled()
    -- Check the skin toggle in Skinning settings
    if SkinFramework then
        return SkinFramework:IsFrameEnabled("CompactRaidFrameManager")
    end
    
    -- Fallback check if SkinFramework not available
    if not AbstractUI.db or not AbstractUI.db.profile then
        return false
    end
    
    local SkinModule = AbstractUI:GetModule("Skin", true)
    if SkinModule and SkinModule.db and SkinModule.db.profile and SkinModule.db.profile.frames then
        return SkinModule.db.profile.frames.CompactRaidFrameManager == true
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
    
    -- Check if enabled via skin toggle
    if not IsEnabled() then
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
        -- If frame is already shown, apply skin immediately but then hide it
        if CompactRaidFrameManager:IsShown() then
            C_Timer.After(0.6, function()
                self:ApplySkin()
                -- Force hide even if it was already shown - user must click our toggle
                CompactRaidFrameManager:Hide()
                isExpanded = false
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
            -- Ensure frame is hidden - user must click our toggle to open it
            if CompactRaidFrameManager then
                CompactRaidFrameManager:Hide()
                isExpanded = false
            end
        end)
    end
end

function GroupManager:HookFrameForSkinning()
    if not CompactRaidFrameManager then return end
    if CompactRaidFrameManager.abstractUIHookedForSkin then return end
    
    -- Hook OnShow to ensure skin is applied when frame appears (but only if WE show it)
    CompactRaidFrameManager:HookScript("OnShow", function()
        if not skinned and IsEnabled() then
            GroupManager:ApplySkin()
        end
    end)
    
    -- Store original Show function
    if not CompactRaidFrameManager.abstractUIOriginalShow then
        CompactRaidFrameManager.abstractUIOriginalShow = CompactRaidFrameManager.Show
    end
    
    -- Override Show to prevent Blizzard from showing it automatically
    CompactRaidFrameManager.Show = function(self)
        -- Only allow showing if we explicitly request it via our toggle
        if GroupManager.allowShow then
            CompactRaidFrameManager.abstractUIOriginalShow(self)
        end
    end
    
    -- Also override SetShown to prevent Blizzard from showing it
    if not CompactRaidFrameManager.abstractUIOriginalSetShown then
        CompactRaidFrameManager.abstractUIOriginalSetShown = CompactRaidFrameManager.SetShown
    end
    
    CompactRaidFrameManager.SetShown = function(self, show)
        -- Only allow showing if we explicitly request it
        if show and not GroupManager.allowShow then
            -- Blizzard wants to show it, but we don't allow it
            return
        else
            CompactRaidFrameManager.abstractUIOriginalSetShown(self, show)
        end
    end
    
    CompactRaidFrameManager.abstractUIHookedForSkin = true
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
    
    -- Apply AbstractUI styling to the main frame with TRANSPARENT background
    if blizzardManager.SetBackdrop then
        blizzardManager:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        -- Set fully transparent background with visible border
        blizzardManager:SetBackdropColor(0, 0, 0, 0.15)
        blizzardManager:SetBackdropBorderColor(unpack(colors.border))
    end
    
    -- Aggressively hide ALL Blizzard art textures on the main frame
    for _, region in ipairs({blizzardManager:GetRegions()}) do
        if region:IsObjectType("Texture") then
            local texPath = region:GetTexture()
            if texPath then
                local texStr = tostring(texPath)
                -- Hide everything except our white8x8 backdrop
                if not texStr:match("WHITE8X8") then
                    region:SetTexture(nil)
                    region:SetAlpha(0)
                    region:Hide()
                end
            end
        elseif region:IsObjectType("FontString") then
            region:SetTextColor(unpack(colors.textPrimary))
        end
    end
    
    -- Strip textures from all unnamed child frames (decorative elements)
    for i = 1, blizzardManager:GetNumChildren() do
        local child = select(i, blizzardManager:GetChildren())
        local childName = child:GetName()
        if not childName or childName == "" then
            -- Hide decorative child frames
            local numRegions = child.GetNumRegions and child:GetNumRegions() or 0
            for j = 1, numRegions do
                local region = select(j, child:GetRegions())
                if region and region:IsObjectType("Texture") then
                    region:SetTexture(nil)
                    region:SetAlpha(0)
                    region:Hide()
                end
            end
        end
    end
    
    -- AGGRESSIVE: Strip all white backdrops from immediate children
    for i = 1, blizzardManager:GetNumChildren() do
        local child = select(i, blizzardManager:GetChildren())
        if child.GetBackdropColor then
            local r, g, b, a = child:GetBackdropColor()
            if r and g and b and r > 0.85 and g > 0.85 and b > 0.85 then
                -- White backdrop found - clear it
                if child.SetBackdrop then
                    child:SetBackdrop(nil)
                end
            end
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
                        region:SetTexture(nil)
                        region:SetAlpha(0)
                        region:Hide()
                    end
                end
            end
        end
        
        -- AGGRESSIVE: Strip all white backdrops from display frame children
        for i = 1, displayFrame:GetNumChildren() do
            local child = select(i, displayFrame:GetChildren())
            if child.GetBackdropColor then
                local r, g, b, a = child:GetBackdropColor()
                if r and g and b and r > 0.85 and g > 0.85 and b > 0.85 then
                    -- White backdrop found - clear it
                    if child.SetBackdrop then
                        child:SetBackdrop(nil)
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
        
        -- Apply transparent backdrop to display frame
        if displayFrame.SetBackdrop then
            displayFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false,
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            displayFrame:SetBackdropColor(0, 0, 0, 0.1)
            displayFrame:SetBackdropBorderColor(unpack(colors.border))
        end
    end
    
    -- Reskin all buttons and UI elements
    self:ReskinBlizzardButtons(displayFrame, colors)
    
    -- Hook dropdown menus to skin them when they appear
    if not self.dropdownHooked then
        hooksecurefunc("ToggleDropDownMenu", function()
            C_Timer.After(0.05, function()
                GroupManager:SkinDropDownLists(colors)
            end)
        end)
        self.dropdownHooked = true
    end
    
    -- Skin specific known elements
    self:SkinSpecificElements(blizzardManager, displayFrame, colors)
    
    -- Hide initially (will show when expanded)
    self.allowShow = false
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
        
        -- Aggressively hide default Blizzard art textures
        for _, region in ipairs({child:GetRegions()}) do
            if region:IsObjectType("Texture") then
                local texPath = region:GetTexture()
                if texPath then
                    local texStr = tostring(texPath)
                    -- Hide all Blizzard UI textures except icons and our backdrops
                    if not (texStr:match("RaidTargetingIcon") or 
                           texStr:match("RaidIcon") or 
                           texStr:match("WHITE8X8") or
                           texStr:match("_ICON_") or
                           texStr:match("Icon")) then
                        local regionName = region:GetName() or ""
                        -- Hide background, border, and decorative textures
                        if regionName:match("Background") or 
                           regionName:match("Border") or 
                           regionName:match("Texture") or 
                           regionName:match("Left") or 
                           regionName:match("Right") or 
                           regionName:match("Middle") or
                           regionName:match("Top") or
                           regionName:match("Bottom") or
                           regionName == "" or
                           texStr:match("Interface\\FriendsFrame") or 
                           texStr:match("Interface\\ChatFrame") or
                           texStr:match("Interface\\Buttons\\UI-") or
                           texStr:match("Interface\\Common\\") then
                            region:SetTexture(nil)
                            region:SetAlpha(0)
                            region:Hide()
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
        
        -- Add BackdropTemplate if not present
        if not child.SetBackdrop and BackdropTemplateMixin then
            Mixin(child, BackdropTemplateMixin)
            if child.OnBackdropLoaded then
                child:OnBackdropLoaded()
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
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                child:SetBackdropColor(unpack(colors.secondary))
                child:SetBackdropBorderColor(unpack(colors.border))
            end
            
            -- Hide default textures
            local normalTexture = child:GetNormalTexture()
            if normalTexture then 
                normalTexture:SetTexture(nil)
                normalTexture:SetAlpha(0) 
            end
            local pushedTexture = child:GetPushedTexture()
            if pushedTexture then 
                pushedTexture:SetTexture(nil)
                pushedTexture:SetAlpha(0) 
            end
            local disabledCheckedTexture = child:GetDisabledCheckedTexture()
            if disabledCheckedTexture then
                disabledCheckedTexture:SetTexture(nil)
                disabledCheckedTexture:SetAlpha(0)
            end
            
            -- Create custom check texture
            local checkTexture = child:GetCheckedTexture()
            if checkTexture then
                checkTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
                checkTexture:SetColorTexture(0.2, 0.8, 0.2, 1)
                checkTexture:ClearAllPoints()
                checkTexture:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -2)
                checkTexture:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", -2, 2)
            end
        end
        
        -- Style Buttons (including icon buttons)
        if child:IsObjectType("Button") then
            -- First, clear any existing white backdrop
            if child.GetBackdropColor then
                local r, g, b, a = child:GetBackdropColor()
                if r and g and b and r > 0.9 and g > 0.9 and b > 0.9 then
                    -- White backdrop detected - will be replaced below
                end
            end
            
            -- Hide all default button textures
            local normalTexture = child:GetNormalTexture()
            if normalTexture then
                local texPath = normalTexture:GetTexture()
                if texPath and not tostring(texPath):match("_ICON_") and not tostring(texPath):match("RaidIcon") then
                    normalTexture:SetTexture(nil)
                    normalTexture:SetAlpha(0)
                end
            end
            
            local pushedTexture = child:GetPushedTexture()
            if pushedTexture then 
                pushedTexture:SetTexture(nil)
                pushedTexture:SetAlpha(0) 
            end
            
            local highlightTexture = child:GetHighlightTexture()
            if highlightTexture then 
                highlightTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
                highlightTexture:SetVertexColor(1, 1, 1, 0.2)
            end
            
            local disabledTexture = child:GetDisabledTexture()
            if disabledTexture then 
                disabledTexture:SetTexture(nil)
                disabledTexture:SetAlpha(0) 
            end
            
            -- FORCE AbstractUI backdrop on ALL buttons
            if child.SetBackdrop then
                child:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false,
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                child:SetBackdropColor(unpack(colors.secondary))
                child:SetBackdropBorderColor(unpack(colors.border))
                
                -- Add hover effects
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
            end
            
            -- Style button text
            local buttonText = child:GetFontString()
            if buttonText and not buttonText.abstractUIStyled then
                buttonText:SetTextColor(unpack(colors.textPrimary))
                buttonText.abstractUIStyled = true
            end
            
            -- Also check for Text property
            if child.Text and not child.Text.abstractUIStyled then
                child.Text:SetTextColor(unpack(colors.textPrimary))
                child.Text.abstractUIStyled = true
            end
        end
        
        -- Style DropDown menus
        if childName and (childName:match("DropDown") or childName:match("Dropdown")) then
            -- Ensure backdrop template
            if not child.SetBackdrop and BackdropTemplateMixin then
                Mixin(child, BackdropTemplateMixin)
                if child.OnBackdropLoaded then
                    child:OnBackdropLoaded()
                end
            end
            
            -- Style the main dropdown frame
            if child.SetBackdrop then
                child:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false,
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                child:SetBackdropColor(unpack(colors.secondary))
                child:SetBackdropBorderColor(unpack(colors.border))
            end
            
            -- Style the dropdown button
            if child.Button then
                local btn = child.Button
                if not btn.SetBackdrop and BackdropTemplateMixin then
                    Mixin(btn, BackdropTemplateMixin)
                    if btn.OnBackdropLoaded then
                        btn:OnBackdropLoaded()
                    end
                end
                
                if btn.SetBackdrop then
                    btn:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8",
                        tile = false,
                        edgeSize = 1,
                        insets = { left = 1, right = 1, top = 1, bottom = 1 }
                    })
                    btn:SetBackdropColor(unpack(colors.secondary))
                    btn:SetBackdropBorderColor(unpack(colors.border))
                end
                
                -- Hide default dropdown textures
                if btn.NormalTexture then
                    btn.NormalTexture:SetTexture(nil)
                    btn.NormalTexture:SetAlpha(0)
                end
            end
            
            -- Style the dropdown text
            if child.Text then
                child.Text:SetTextColor(unpack(colors.textPrimary))
            end
            
            -- Hide dropdown frame backgrounds
            for _, region in ipairs({child:GetRegions()}) do
                if region:IsObjectType("Texture") then
                    local texPath = region:GetTexture()
                    if texPath and not tostring(texPath):match("WHITE8X8") then
                        region:SetTexture(nil)
                        region:SetAlpha(0)
                    end
                end
            end
        end
        
        -- Style EditBox (text input fields)
        if child:IsObjectType("EditBox") then
            if not child.SetBackdrop and BackdropTemplateMixin then
                Mixin(child, BackdropTemplateMixin)
                if child.OnBackdropLoaded then
                    child:OnBackdropLoaded()
                end
            end
            
            if child.SetBackdrop then
                child:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false,
                    edgeSize = 1,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 }
                })
                child:SetBackdropColor(unpack(colors.secondary))
                child:SetBackdropBorderColor(unpack(colors.border))
            end
            
            -- Style text color
            child:SetTextColor(unpack(colors.textPrimary))
        end
        
        -- Style container Frames - handle ALL frames, not just those with backdrops
        if child:IsObjectType("Frame") and not child:IsObjectType("Button") and not child:IsObjectType("CheckButton") then
            -- Check if frame already has a backdrop
            local backdrop = child.SetBackdrop and child:GetBackdrop()
            
            if backdrop then
                -- Frame has a backdrop - check if it's white/opaque and needs replacing
                local r, g, b, a = child:GetBackdropColor()
                
                -- If backdrop is white or highly opaque, replace it
                if (r and g and b and ((r > 0.9 and g > 0.9 and b > 0.9) or a > 0.5)) or backdrop.bgFile then
                    child:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8",
                        tile = false,
                        edgeSize = 1,
                        insets = { left = 1, right = 1, top = 1, bottom = 1 }
                    })
                    -- Very transparent background for container frames
                    child:SetBackdropColor(0, 0, 0, 0.1)
                    child:SetBackdropBorderColor(unpack(colors.border))
                end
            else
                -- Frame doesn't have a backdrop - check if it's displaying white
                -- by checking for white texture regions
                local hasWhiteBackground = false
                for _, region in ipairs({child:GetRegions()}) do
                    if region:IsObjectType("Texture") then
                        local r, g, b = region:GetVertexColor()
                        local texPath = region:GetTexture()
                        if texPath and ((r and g and b and r > 0.9 and g > 0.9 and b > 0.9) or tostring(texPath):match("WHITE")) then
                            hasWhiteBackground = true
                            -- Hide this white texture
                            region:SetTexture(nil)
                            region:SetAlpha(0)
                            region:Hide()
                        end
                    end
                end
                
                -- If we found white backgrounds, add a transparent AbstractUI backdrop
                if hasWhiteBackground and child.SetBackdrop then
                    child:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8",
                        tile = false,
                        edgeSize = 1,
                        insets = { left = 1, right = 1, top = 1, bottom = 1 }
                    })
                    child:SetBackdropColor(0, 0, 0, 0.1)
                    child:SetBackdropBorderColor(unpack(colors.border))
                end
            end
        end
        
        -- Final aggressive cleanup: if this child still looks white/default, force styling
        if child.SetBackdrop and child.GetBackdropColor then
            local r, g, b, a = child:GetBackdropColor()
            -- Check for white or very opaque backgrounds that slipped through
            if r and g and b and a and r > 0.85 and g > 0.85 and b > 0.85 and a > 0.3 then
                -- This is showing as white - force our styling
                if not child:IsObjectType("Button") then
                    -- For non-buttons, make it very transparent
                    child:SetBackdropColor(0, 0, 0, 0.1)
                    child:SetBackdropBorderColor(unpack(colors.border))
                else
                    -- For buttons, use secondary color
                    child:SetBackdropColor(unpack(colors.secondary))
                    child:SetBackdropBorderColor(unpack(colors.border))
                end
            end
        end
        
        -- Recurse into children
        self:ReskinBlizzardButtons(child, colors)
    end
    
    -- Also skin DropDownList frames when they appear
    self:SkinDropDownLists(colors)
end

function GroupManager:SkinDropDownLists(colors)
    -- Skin dropdown menu frames
    for i = 1, UIDROPDOWNMENU_MAXLEVELS do
        local listFrame = _G["DropDownList"..i.."MenuBackdrop"]
        if listFrame then
            if listFrame.SetBackdrop then
                listFrame:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false,
                    edgeSize = 2,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 }
                })
                listFrame:SetBackdropColor(unpack(colors.primary))
                listFrame:SetBackdropBorderColor(unpack(colors.border))
            end
        end
        
        local listFrameMain = _G["DropDownList"..i]
        if listFrameMain then
            -- Hide default backdrop
            for _, region in ipairs({listFrameMain:GetRegions()}) do
                if region:IsObjectType("Texture") then
                    local texPath = region:GetTexture()
                    if texPath and not tostring(texPath):match("WHITE8X8") then
                        region:SetTexture(nil)
                        region:SetAlpha(0)
                    end
                end
            end
            
            -- Style buttons in dropdown
            for j = 1, UIDROPDOWNMENU_MAXBUTTONS do
                local button = _G["DropDownList"..i.."Button"..j]
                if button then
                    -- Style button background
                    if button.SetBackdrop then
                        button:SetBackdrop({
                            bgFile = "Interface\\Buttons\\WHITE8X8",
                            tile = false,
                        })
                        button:SetBackdropColor(0, 0, 0, 0)
                    end
                    
                    -- Hide default highlight
                    local highlight = button:GetHighlightTexture()
                    if highlight then
                        highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
                        highlight:SetVertexColor(unpack(colors.hover))
                    end
                    
                    -- Hide default textures
                    if button.NormalTexture then
                        button.NormalTexture:SetAlpha(0)
                    end
                    
                    -- Style button text
                    local btnText = _G["DropDownList"..i.."Button"..j.."NormalText"]
                    if btnText then
                        btnText:SetTextColor(unpack(colors.textPrimary))
                    end
                end
            end
        end
    end
end

function GroupManager:SkinSpecificElements(manager, displayFrame, colors)
    if not manager or not displayFrame then return end
    
    -- Common elements to skin by pattern
    local elementsToSkin = {
        "RoleButton",
        "GroupButton",
        "FilterButton", 
        "EveryoneIsAssist",
        "Dropdown",
        "DropDown",
        "ToggleButton",
        "LeaderOptions",
        "RaidMarker"
    }
    
    -- Recursively find and skin elements by name pattern
    local function SkinByPattern(parent)
        if not parent then return end
        
        for i = 1, parent:GetNumChildren() do
            local child = select(i, parent:GetChildren())
            local childName = child:GetName()
            
            if childName then
                for _, pattern in ipairs(elementsToSkin) do
                    if childName:match(pattern) then
                        -- Ensure it has backdrop capability
                        if not child.SetBackdrop and BackdropTemplateMixin then
                            Mixin(child, BackdropTemplateMixin)
                            if child.OnBackdropLoaded then
                                child:OnBackdropLoaded()
                            end
                        end
                        
                        -- Apply AbstractUI styling
                        if child:IsObjectType("Button") and child.SetBackdrop then
                            child:SetBackdrop({
                                bgFile = "Interface\\Buttons\\WHITE8X8",
                                edgeFile = "Interface\\Buttons\\WHITE8X8",
                                tile = false,
                                edgeSize = 1,
                                insets = { left = 1, right = 1, top = 1, bottom = 1 }
                            })
                            child:SetBackdropColor(unpack(colors.secondary))
                            child:SetBackdropBorderColor(unpack(colors.border))
                            
                            -- Hide button textures
                            if child.GetNormalTexture and child:GetNormalTexture() then
                                local normalTex = child:GetNormalTexture()
                                local texPath = normalTex:GetTexture()
                                -- Only hide if not an icon
                                if texPath and not tostring(texPath):match("_ICON_") and not tostring(texPath):match("RaidIcon") then
                                    normalTex:SetAlpha(0)
                                end
                            end
                            if child.GetPushedTexture and child:GetPushedTexture() then
                                child:GetPushedTexture():SetAlpha(0)
                            end
                            
                            -- Add hover effect
                            if not child.abstractUIHover then
                                child:HookScript("OnEnter", function(self)
                                    if self:IsEnabled() then
                                        self:SetBackdropColor(unpack(colors.hover))
                                    end
                                end)
                                child:HookScript("OnLeave", function(self)
                                    self:SetBackdropColor(unpack(colors.secondary))
                                end)
                                child.abstractUIHover = true
                            end
                        end
                        
                        break
                    end
                end
            end
            
            -- Recurse
            SkinByPattern(child)
        end
    end
    
    SkinByPattern(manager)
    SkinByPattern(displayFrame)
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
        -- Set flag to allow showing the frame
        self.allowShow = true
        blizzardManager:Show()
        self.allowShow = false
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
        desc = "Enable/disable this skin in Blizzard Frames > Skinning > Group Manager / Raid Frames",
        get = function(info) return self.db.profile[info[#info]] end,
        set = function(info, value) 
            self.db.profile[info[#info]] = value
            self:UpdateManagerFrame()
        end,
        args = {
            description = {
                name = "Group Manager provides a compact toggle icon for Blizzard's CompactRaidFrameManager with AbstractUI styling.\n\n|cffFFD700To enable:|r Go to Blizzard Frames > Skinning and enable 'Group Manager / Raid Frames'",
                type = "description",
                order = 1,
                fontSize = "medium",
            },
            header1 = {
                name = "Toggle Icon Size",
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
        print("  IsEnabled():", IsEnabled())
        print("  Skinned:", skinned)
        print("  CompactRaidFrameManager exists:", CompactRaidFrameManager ~= nil)
        if CompactRaidFrameManager then
            print("  Frame is shown:", CompactRaidFrameManager:IsShown())
        end
        print("  ColorPalette exists:", ColorPalette ~= nil)
        print("  SkinFramework exists:", SkinFramework ~= nil)
        
        -- Check skin module setting
        local SkinModule = AbstractUI:GetModule("Skin", true)
        if SkinModule and SkinModule.db and SkinModule.db.profile and SkinModule.db.profile.frames then
            print("  Skin Toggle Setting:", SkinModule.db.profile.frames.CompactRaidFrameManager)
        end
        
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
