local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local CharacterPane = AbstractUI:NewModule("CharacterPane", "AceEvent-3.0", "AceHook-3.0")

---------------------------------------------------------------------------
-- CHARACTER PANEL SKIN
-- Modern, transparent skin for Blizzard's character panel
-- Inspired by Aurora - works WITH Blizzard's frames, not against them
---------------------------------------------------------------------------

local ColorPalette = nil
local FontKit = nil
local skinned = false

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

function CharacterPane:OnInitialize()
    self:RegisterMessage("AbstractUI_DB_READY", "OnDBReady")
end

function CharacterPane:OnDBReady()
    ColorPalette = _G.AbstractUI_ColorPalette
    FontKit = _G.AbstractUI_FontKit
    
    if not ColorPalette then return end
    
    self.db = AbstractUI.db:RegisterNamespace("CharacterPane", {
        profile = {
            enabled = true,
        }
    })
    
   self:RegisterEvent("ADDON_LOADED")
    
    if CharacterFrame then
        self:ApplySkin()
    end
end

function CharacterPane:ADDON_LOADED(event, addon)
    if addon == "Blizzard_CharacterFrame" or (addon == "AbstractUI" and CharacterFrame) then
        C_Timer.After(0.1, function()
            if CharacterFrame and not skinned then
                self:ApplySkin()
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

---------------------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------------------

local function GetThemeColors()
    if not ColorPalette then
        return 0.55, 0.60, 0.70, 0.85, 0.05, 0.05, 0.05, 0.65
    end
    local pr, pg, pb, pa = ColorPalette:GetColor('primary')
    local bgr, bgg, bgb, bga = ColorPalette:GetColor('panel-bg')
    return pr, pg, pb, pa or 0.85, bgr, bgg, bgb, bga or 0.65
end

local function IsEnabled()
    return CharacterPane.db and CharacterPane.db.profile.enabled
end

---------------------------------------------------------------------------
-- STRIP BLIZZARD TEXTURES (AURORA-STYLE)
---------------------------------------------------------------------------

local function StripBlizzardTextures()
    if not CharacterFrame then return end
    
    -- Hide all the background/border textures from CharacterFrame
    local texturesToHide = {
        -- Character model background corners
        "CharacterModelFrameBackgroundTopLeft",
        "CharacterModelFrameBackgroundTopRight",
        "CharacterModelFrameBackgroundBotLeft",
        "CharacterModelFrameBackgroundBotRight",
        "CharacterModelFrameBackgroundOverlay",
        
        -- Inner borders around equipment area
        "PaperDollInnerBorderTopLeft",
        "PaperDollInnerBorderTopRight",
        "PaperDollInnerBorderBottomLeft",
        "PaperDollInnerBorderBottomRight",
        "PaperDollInnerBorderLeft",
        "PaperDollInnerBorderRight",
        "PaperDollInnerBorderTop",
        "PaperDollInnerBorderBottom",
        "PaperDollInnerBorderBottom2",
    }
    
    for _, name in ipairs(texturesToHide) do
        local tex = _G[name]
        if tex then
            tex:Hide()
            tex:SetAlpha(0)
        end
    end
    
    -- Strip textures from inset frames
    if CharacterFrame.Inset then
        CharacterFrame.Inset:SetAlpha(0)
        if CharacterFrame.Inset.Bg then
            CharacterFrame.Inset.Bg:SetAlpha(0)
        end
    end
    
    if CharacterFrame.InsetRight then
        CharacterFrame.InsetRight:SetAlpha(0)
        if CharacterFrame.InsetRight.Bg then
            CharacterFrame.InsetRight.Bg:SetAlpha(0)
        end
    end
    
    -- Make model scene transparent
    if CharacterModelScene then
        CharacterModelScene:SetAlpha(1)
    end
    
    -- Hide sidebar tab decorations
    if PaperDollSidebarTabs then
        if PaperDollSidebarTabs.DecorLeft then
            PaperDollSidebarTabs.DecorLeft:Hide()
        end
        if PaperDollSidebarTabs.DecorRight then
            PaperDollSidebarTabs.DecorRight:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- SKIN EQUIPMENT SLOT BUTTONS
---------------------------------------------------------------------------

local function SkinItemSlot(button)
    if not button or button._abstractSkinned then return end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    
    -- Hide Blizzard's background frame
    local frameName = button:GetName() .. "Frame"
    local frame = _G[frameName]
    if frame then
        frame:Hide()
        frame:SetAlpha(0)
    end
    
    -- Remove default textures
    button:SetNormalTexture("")
    button:SetPushedTexture("")
    
    -- Create clean backdrop
    if not button.backdrop then
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
    end
    
    button:SetBackdropColor(bgr, bgg, bgb, 0.6)
    button:SetBackdropBorderColor(pr * 0.3, pg * 0.3, pb * 0.3, 0.8)
    
    -- Style icon
    if button.icon then
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icon:ClearAllPoints()
        button.icon:SetPoint("TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    end
    
    -- Style IconBorder (quality border)
    if button.IconBorder then
        button.IconBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
        button.IconBorder:ClearAllPoints()
        button.IconBorder:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.IconBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button.IconBorder:SetDrawLayer("OVERLAY", 0)
        
        -- Hook to update border color based on quality
        hooksecurefunc(button.IconBorder, "SetVertexColor", function(self, r, g, b)
            if r and g and b and (r > 0.1 or g > 0.1 or b > 0.1) then
                button:SetBackdropBorderColor(r, g, b, 1)
            else
                button:SetBackdropBorderColor(pr * 0.3, pg * 0.3, pb * 0.3, 0.8)
            end
        end)
    end
    
    -- Create highlight texture
    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetColorTexture(1, 1, 1, 0.15)
        highlight:ClearAllPoints()
        highlight:SetPoint("TOPLEFT", 1, -1)
        highlight:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    
    button._abstractSkinned = true
end

local function SkinAllEquipmentSlots()
    -- Equipment slots (sides)
    local slots = {
        "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot",
        "CharacterChestSlot", "CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot",
        "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
        "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot",
    }
    
    for _, slotName in ipairs(slots) do
        local slot = _G[slotName]
        if slot then
            SkinItemSlot(slot)
        end
    end
    
    -- Weapon slots (bottom)
    local weaponSlots = {
        "CharacterMainHandSlot",
        "CharacterSecondaryHandSlot",
    }
    
    for _, slotName in ipairs(weaponSlots) do
        local slot = _G[slotName]
        if slot then
            SkinItemSlot(slot)
        end
    end
end

---------------------------------------------------------------------------
-- SKIN TABS
---------------------------------------------------------------------------

local function SkinCharacterTabs()
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    
    -- Bottom tabs (Character, Reputation, Currency)
    for i = 1, 3 do
        local tab = _G["CharacterFrameTab" .. i]
        if tab and not tab._abstractSkinned then
            -- Remove default textures
            tab:SetNormalTexture("")
            tab:SetPushedTexture("")
            tab:SetDisabledTexture("")
            
            -- Remove highlight
            local regions = {tab:GetRegions()}
            for _, region in ipairs(regions) do
                if region:GetObjectType() == "Texture" then
                    local tex = region:GetTexture()
                    if tex and (tex:find("UI%-Panel%-Button") or tex:find("TabBar")) then
                        region:SetTexture("")
                    end
                end
            end
            
            -- Create backdrop
            if not tab.backdrop then
                tab:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
            end
            
            tab:SetBackdropColor(bgr, bgg, bgb, 0.7)
            tab:SetBackdropBorderColor(pr * 0.5, pg * 0.5, pb * 0.5, 0.8)
            
            -- Style text
            local text = tab:GetFontString()
            if text then
                text:SetTextColor(0.9, 0.9, 0.9)
            end
            
            -- Highlight
            local highlight = tab:GetHighlightTexture()
            if highlight then
                highlight:SetColorTexture(pr, pg, pb, 0.2)
                highlight:ClearAllPoints()
                highlight:SetPoint("TOPLEFT", 1, -1)
                highlight:SetPoint("BOTTOMRIGHT", -1, 1)
            end
            
            -- Selected state
            tab:HookScript("OnClick", function(self)
                for j = 1, 3 do
                    local t = _G["CharacterFrameTab" .. j]
                    if t and t.backdrop then
                        if j == i then
                            t:SetBackdropColor(bgr * 1.5, bgg * 1.5, bgb * 1.5, 0.9)
                            t:SetBackdropBorderColor(pr, pg, pb, 1)
                        else
                            t:SetBackdropColor(bgr, bgg, bgb, 0.7)
                            t:SetBackdropBorderColor(pr * 0.5, pg * 0.5, pb * 0.5, 0.8)
                        end
                    end
                end
            end)
            
            tab._abstractSkinned = true
        end
    end
    
    -- Sidebar tabs (right side)
    if PaperDollSidebarTabs then
        for i = 1, #PAPERDOLL_SIDEBARS do
            local tab = _G["PaperDollSidebarTab" .. i]
            if tab and not tab._abstractSkinned then
                -- Hide default textures
                if tab.TabBg then
                    tab.TabBg:SetAlpha(0)
                end
                if tab.Hider then
                    tab.Hider:SetTexture("")
                end
                
                -- Create backdrop
                if not tab.backdrop then
                    tab:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                        edgeSize = 1,
                    })
                end
                
                tab:SetBackdropColor(bgr, bgg, bgb, 0.6)
                tab:SetBackdropBorderColor(pr * 0.3, pg * 0.3, pb * 0.3, 0.8)
                
                -- Style icon
                if tab.Icon then
                    tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    tab.Icon:ClearAllPoints()
                    tab.Icon:SetPoint("TOPLEFT", 2, -2)
                    tab.Icon:SetPoint("BOTTOMRIGHT", -2, 2)
                end
                
                -- Highlight
                if tab.Highlight then
                    tab.Highlight:SetColorTexture(pr, pg, pb, 0.3)
                    tab.Highlight:ClearAllPoints()
                    tab.Highlight:SetPoint("TOPLEFT", 1, -1)
                    tab.Highlight:SetPoint("BOTTOMRIGHT", -1, 1)
                end
                
                tab._abstractSkinned = true
            end
        end
    end
end

---------------------------------------------------------------------------
-- SKIN CHARACTER FRAME BACKDROP
---------------------------------------------------------------------------

local function SkinCharacterFrameBackdrop()
    if not CharacterFrame or not CharacterFrame.NineSlice then return end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    
    -- Make NineSlice transparent with our theme colors
    if CharacterFrame.NineSlice.Center then
        CharacterFrame.NineSlice.Center:SetColorTexture(bgr, bgg, bgb, bga * 0.95)
    end
    
    -- Tint borders with primary color
    local borderPieces = {
        "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
        "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner"
    }
    
    for _, piece in ipairs(borderPieces) do
        if CharacterFrame.NineSlice[piece] then
            CharacterFrame.NineSlice[piece]:SetVertexColor(pr * 0.7, pg * 0.7, pb * 0.7, 0.9)
        end
    end
    
    -- Style close button
    if CharacterFrame.CloseButton then
        local closeBtn = CharacterFrame.CloseButton
        if not closeBtn._abstractSkinned then
            closeBtn:SetSize(20, 20)
            
            -- Remove default textures
            closeBtn:SetNormalTexture("")
            closeBtn:SetPushedTexture("")
            closeBtn:SetHighlightTexture("")
            
            -- Create X text
            if not closeBtn.text then
                closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY")
                closeBtn.text:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
                closeBtn.text:SetPoint("CENTER", 1, 0)
                closeBtn.text:SetText("×")
            end
            closeBtn.text:SetTextColor(0.9, 0.9, 0.9)
            
            -- Hover effect
            closeBtn:HookScript("OnEnter", function(self)
                self.text:SetTextColor(1, 0.3, 0.3)
            end)
            closeBtn:HookScript("OnLeave", function(self)
                self.text:SetTextColor(0.9, 0.9, 0.9)
            end)
            
            closeBtn._abstractSkinned = true
        end
    end
    
    -- Style title text
    if CharacterFrame.TitleContainer and CharacterFrame.TitleContainer.TitleText then
        local title = CharacterFrame.TitleContainer.TitleText
        title:SetTextColor(pr, pg, pb, 1)
        title:SetShadowOffset(1, -1)
        title:SetShadowColor(0, 0, 0, 1)
    end
end

---------------------------------------------------------------------------
-- SKIN STATS PANE
---------------------------------------------------------------------------

local function SkinStatsPane()
    if not CharacterStatsPane then return end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    
    -- Make stats pane background transparent
    if CharacterStatsPane.ClassBackground then
        CharacterStatsPane.ClassBackground:SetAlpha(0.15)
        CharacterStatsPane.ClassBackground:SetDesaturated(true)
    end
    
    -- Style item level display
    if CharacterStatsPane.ItemLevelFrame then
        local ilvlFrame = CharacterStatsPane.ItemLevelFrame
        
        if ilvlFrame.Background then
            ilvlFrame.Background:SetAlpha(0)
        end
        
        if ilvlFrame.Value then
            ilvlFrame.Value:SetTextColor(1, 1, 1)
            ilvlFrame.Value:SetShadowOffset(1, -1)
            ilvlFrame.Value:SetShadowColor(0, 0, 0, 0.8)
        end
    end
    
    -- Style stat category headers
    local categories = {
        "ItemLevelCategory",
        "AttributesCategory",
        "EnhancementsCategory",
    }
    
    for _, catName in ipairs(categories) do
        local category = CharacterStatsPane[catName]
        if category and category.Background then
            category.Background:SetAlpha(0.3)
            category.Background:SetVertexColor(pr * 0.5, pg * 0.5, pb * 0.5)
        end
    end
    
    -- Style individual stat frames (from the pool)
    if CharacterStatsPane.statsFramePool then
        hooksecurefunc(CharacterStatsPane.statsFramePool, "Acquire", function(pool)
            for frame in pool:EnumerateActive() do
                if frame.Background and not frame._abstractSkinned then
                    frame.Background:SetColorTexture(1, 1, 1, 0.1)
                    frame._abstractSkinned = true
                end
            end
        end)
    end
end

---------------------------------------------------------------------------
-- MAIN SKIN APPLICATION
---------------------------------------------------------------------------

function CharacterPane:ApplySkin()
    if not IsEnabled() or skinned then return end
    if not CharacterFrame then return end
    
    -- Apply all skins
    StripBlizzardTextures()
    SkinCharacterFrameBackdrop()
    SkinAllEquipmentSlots()
    SkinCharacterTabs()
    SkinStatsPane()
    
    skinned = true
    
    -- Listen for theme changes
    self:RegisterMessage("AbstractUI_THEME_CHANGED", "OnThemeChanged")
end

function CharacterPane:OnThemeChanged()
    if not IsEnabled() then return end
    
    -- Reapply skins with new theme colors
    skinned = false
    self:ApplySkin()
end
