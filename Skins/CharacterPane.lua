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
    
    -- Hide CharacterFrame's own Bg if it exists
    if CharacterFrame.Bg then
        CharacterFrame.Bg:SetAlpha(0)
        CharacterFrame.Bg:Hide()
    end
    
    -- Hide all unnamed child frames (decorative borders/bars)
    local children = {CharacterFrame:GetChildren()}
    for i, child in ipairs(children) do
        local childName = child:GetName()
        if not childName or childName == "" then
            child:Hide()
            child:SetAlpha(0)
            
            -- Also hide all regions within
            if child.GetNumRegions then
                for j = 1, child:GetNumRegions() do
                    local region = select(j, child:GetRegions())
                    if region then
                        region:SetAlpha(0)
                        region:Hide()
                    end
                end
            end
        end
    end
    
    -- Strip ALL texture regions directly from CharacterFrame
    for i = 1, CharacterFrame:GetNumRegions() do
        local region = select(i, CharacterFrame:GetRegions())
        if region and region:GetObjectType() == "Texture" then
            -- Don't hide the portrait texture (we'll handle that separately)
            if region ~= CharacterFramePortrait then
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end
    
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
        
        -- Weapon slot decorative elements
        "PaperDollItemsFrameItemFlyoutHighlight",
    }
    
    for _, name in ipairs(texturesToHide) do
        local tex = _G[name]
        if tex then
            tex:Hide()
            tex:SetAlpha(0)
        end
    end
    
    -- Weapon slot backgrounds/bars - hide frames and all contents
    local weaponFrames = {
        "CharacterHandsSlotFrame",
        "CharacterMainHandSlotFrame", 
        "CharacterSecondaryHandSlotFrame",
    }
    
    for _, name in ipairs(weaponFrames) do
        local frame = _G[name]
        if frame then
            frame:Hide()
            frame:SetAlpha(0)
            
            -- Hide all texture regions within the frame
            if frame.GetNumRegions then
                for i = 1, frame:GetNumRegions() do
                    local region = select(i, frame:GetRegions())
                    if region then
                        region:SetAlpha(0)
                        region:Hide()
                    end
                end
            end
            
            -- Hide all children
            if frame.GetChildren then
                local children = {frame:GetChildren()}
                for i, child in ipairs(children) do
                    child:Hide()
                    child:SetAlpha(0)
                    
                    -- Also hide child's regions
                    if child.GetNumRegions then
                        for j = 1, child:GetNumRegions() do
                            local region = select(j, child:GetRegions())
                            if region then
                                region:SetAlpha(0)
                                region:Hide()
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Hide PaperDollItemsFrame decorations
    if PaperDollItemsFrame then
        -- Hide all texture regions
        for i = 1, PaperDollItemsFrame:GetNumRegions() do
            local region = select(i, PaperDollItemsFrame:GetRegions())
            if region and region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
                region:Hide()
            end
        end
        
        -- Hide any child frames that aren't equipment slots
        local children = {PaperDollItemsFrame:GetChildren()}
        for _, child in ipairs(children) do
            local childName = child:GetName()
            -- Only hide if it's not an actual equipment slot button
            if childName and not childName:find("Slot$") then
                child:Hide()
                child:SetAlpha(0)
                
                -- Hide the child's regions too
                if child.GetNumRegions then
                    for i = 1, child:GetNumRegions() do
                        local region = select(i, child:GetRegions())
                        if region then
                            region:SetAlpha(0)
                            region:Hide()
                        end
                    end
                end
            end
        end
    end
    
    -- Strip ALL textures from CharacterFrame's NineSlice including Center
    if CharacterFrame.NineSlice then
        -- Hide the entire NineSlice
        CharacterFrame.NineSlice:SetAlpha(0)
        CharacterFrame.NineSlice:Hide()
        
        local nineSlicePieces = {
            "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
            "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
            "Center"
        }
        
        for _, piece in ipairs(nineSlicePieces) do
            if CharacterFrame.NineSlice[piece] then
                CharacterFrame.NineSlice[piece]:SetAlpha(0)
                CharacterFrame.NineSlice[piece]:Hide()
            end
        end
    end
    
    -- Strip portrait
    if CharacterFramePortrait then
        CharacterFramePortrait:SetAlpha(0)
        CharacterFramePortrait:Hide()
    end
    
    -- Hide PaperDollFrame background completely
    if PaperDollFrame then
        if PaperDollFrame.Bg then
            PaperDollFrame.Bg:SetAlpha(0)
            PaperDollFrame.Bg:Hide()
        end
        
        for i = 1, PaperDollFrame:GetNumRegions() do
            local region = select(i, PaperDollFrame:GetRegions())
            if region and region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end
    
    -- Strip textures from inset frames completely
    if CharacterFrame.Inset then
        CharacterFrame.Inset:SetAlpha(0)
        CharacterFrame.Inset:Hide()
        if CharacterFrame.Inset.Bg then
            CharacterFrame.Inset.Bg:SetAlpha(0)
            CharacterFrame.Inset.Bg:Hide()
        end
        if CharacterFrame.Inset.NineSlice then
            CharacterFrame.Inset.NineSlice:SetAlpha(0)
            CharacterFrame.Inset.NineSlice:Hide()
        end
    end
    
    if CharacterFrame.InsetRight then
        CharacterFrame.InsetRight:SetAlpha(0)
        CharacterFrame.InsetRight:Hide()
        if CharacterFrame.InsetRight.Bg then
            CharacterFrame.InsetRight.Bg:SetAlpha(0)
            CharacterFrame.InsetRight.Bg:Hide()
        end
        if CharacterFrame.InsetRight.NineSlice then
            CharacterFrame.InsetRight.NineSlice:SetAlpha(0)
            CharacterFrame.InsetRight.NineSlice:Hide()
        end
    end
    
    -- Make model scene completely transparent background - hide ALL textures
    if CharacterModelScene then
        CharacterModelScene:SetAlpha(1) -- Keep model visible
        
        -- Hide all texture regions
        for i = 1, CharacterModelScene:GetNumRegions() do
            local region = select(i, CharacterModelScene:GetRegions())
            if region and region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
                region:Hide()
            end
        end
        
        -- Hide backdrop if it exists
        if CharacterModelScene.backdrop then
            CharacterModelScene.backdrop:SetAlpha(0)
            CharacterModelScene.backdrop:Hide()
        end
    end
    
    -- Hide sidebar tab decorations
    if PaperDollSidebarTabs then
        if PaperDollSidebarTabs.DecorLeft then
            PaperDollSidebarTabs.DecorLeft:Hide()
            PaperDollSidebarTabs.DecorLeft:SetAlpha(0)
        end
        if PaperDollSidebarTabs.DecorRight then
            PaperDollSidebarTabs.DecorRight:Hide()
            PaperDollSidebarTabs.DecorRight:SetAlpha(0)
        end
    end
    
    -- Strip textures from stats pane completely
    if CharacterStatsPane then
        if CharacterStatsPane.ClassBackground then
            CharacterStatsPane.ClassBackground:SetAlpha(0)
            CharacterStatsPane.ClassBackground:Hide()
        end
        
        -- Hide all texture regions in stats pane
        for i = 1, CharacterStatsPane:GetNumRegions() do
            local region = select(i, CharacterStatsPane:GetRegions())
            if region and region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end

end

---------------------------------------------------------------------------
-- SKIN EQUIPMENT SLOT BUTTONS
---------------------------------------------------------------------------

local function SkinItemSlot(button)
    if not button or button._abstractSkinned then return end
    
    local pr, pg, pb, pa, bgr, bgg, bgb, bga = GetThemeColors()
    
    -- Hide Blizzard's background frame aggressively
    local frameName = button:GetName() .. "Frame"
    local frame = _G[frameName]
    if frame then
        frame:Hide()
        frame:SetAlpha(0)
        
        -- Also hide all its regions if it's a frame
        if frame.GetNumRegions then
            for i = 1, frame:GetNumRegions() do
                local region = select(i, frame:GetRegions())
                if region then
                    region:SetAlpha(0)
                    region:Hide()
                end
            end
        end
    end
    
    -- Store references to unnamed children and aggressively hide them
    local children = {button:GetChildren()}
    button._unnamedChildren = button._unnamedChildren or {}
    
    for i, child in ipairs(children) do
        local childName = child:GetName()
        -- Track unnamed children (these are the decorative bars)
        if not childName or childName == "" then
            table.insert(button._unnamedChildren, child)
            
            -- Nuclear hiding approach
            child:Hide()
            child:SetAlpha(0)
            child:SetScale(0.001)
            
            if child.SetShown then
                child:SetShown(false)
            end
            
            -- Hide all regions
            if child.GetNumRegions then
                for j = 1, child:GetNumRegions() do
                    local region = select(j, child:GetRegions())
                    if region then
                        region:SetAlpha(0)
                        region:Hide()
                        if region.SetVertexColor then
                            region:SetVertexColor(0, 0, 0, 0)
                        end
                    end
                end
            end
        end
    end
    
    -- Create OnUpdate hook to continuously force them hidden
    if not button._abstractUpdateFrame then
        local updateFrame = CreateFrame("Frame")
        updateFrame:SetScript("OnUpdate", function(self, elapsed)
            for _, child in ipairs(button._unnamedChildren or {}) do
                if child:IsShown() then
                    child:Hide()
                    child:SetAlpha(0)
                end
            end
        end)
        button._abstractUpdateFrame = updateFrame
    end
    
    -- Remove default textures
    button:SetNormalTexture("")
    button:SetPushedTexture("")
    
    -- Create backdrop frame (equipment slots don't have BackdropTemplate)
    if not button.backdrop then
        local backdrop = CreateFrame("Frame", nil, button, "BackdropTemplate")
        backdrop:SetAllPoints()
        backdrop:SetFrameLevel(button:GetFrameLevel() - 1)
        backdrop:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        backdrop:SetBackdropColor(bgr, bgg, bgb, 0.3)
        backdrop:SetBackdropBorderColor(pr * 0.2, pg * 0.2, pb * 0.2, 0.5)
        button.backdrop = backdrop
    end
    
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
            if button.backdrop and r and g and b and (r > 0.1 or g > 0.1 or b > 0.1) then
                button.backdrop:SetBackdropBorderColor(r, g, b, 0.8)
            elseif button.backdrop then
                button.backdrop:SetBackdropBorderColor(pr * 0.2, pg * 0.2, pb * 0.2, 0.5)
            end
        end)
    end
    
    -- Create highlight texture
    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetColorTexture(1, 1, 1, 0.1)
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
                    -- GetTexture can return a number (texture ID) or string (file path)
                    if tex and type(tex) == "string" and (tex:find("UI%-Panel%-Button") or tex:find("TabBar")) then
                        region:SetTexture("")
                    end
                end
            end
            
            -- Create backdrop frame
            if not tab.backdrop then
                local backdrop = CreateFrame("Frame", nil, tab, "BackdropTemplate")
                backdrop:SetAllPoints()
                backdrop:SetFrameLevel(tab:GetFrameLevel() - 1)
                backdrop:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                backdrop:SetBackdropColor(bgr, bgg, bgb, 0.5)
                backdrop:SetBackdropBorderColor(pr * 0.3, pg * 0.3, pb * 0.3, 0.5)
                tab.backdrop = backdrop
            end
            
            -- Style text
            local text = tab:GetFontString()
            if text then
                text:SetTextColor(0.9, 0.9, 0.9)
            end
            
            -- Highlight
            local highlight = tab:GetHighlightTexture()
            if highlight then
                highlight:SetColorTexture(pr, pg, pb, 0.15)
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
                            t.backdrop:SetBackdropColor(bgr * 2, bgg * 2, bgb * 2, 0.8)
                            t.backdrop:SetBackdropBorderColor(pr, pg, pb, 0.8)
                        else
                            t.backdrop:SetBackdropColor(bgr, bgg, bgb, 0.5)
                            t.backdrop:SetBackdropBorderColor(pr * 0.3, pg * 0.3, pb * 0.3, 0.5)
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
                
                -- Create backdrop frame
                if not tab.backdrop then
                    local backdrop = CreateFrame("Frame", nil, tab, "BackdropTemplate")
                    backdrop:SetAllPoints()
                    backdrop:SetFrameLevel(tab:GetFrameLevel() - 1)
                    backdrop:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                        edgeSize = 1,
                    })
                    backdrop:SetBackdropColor(bgr, bgg, bgb, 0.4)
                    backdrop:SetBackdropBorderColor(pr * 0.2, pg * 0.2, pb * 0.2, 0.5)
                    tab.backdrop = backdrop
                end
                
                -- Style icon
                if tab.Icon then
                    tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    tab.Icon:ClearAllPoints()
                    tab.Icon:SetPoint("TOPLEFT", 2, -2)
                    tab.Icon:SetPoint("BOTTOMRIGHT", -2, 2)
                end
                
                -- Highlight
                if tab.Highlight then
                    tab.Highlight:SetColorTexture(pr, pg, pb, 0.2)
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
    
    -- Create custom backdrop with class-colored border and background
    if not CharacterFrame.AbstractBackdrop then
        local backdrop = CreateFrame("Frame", nil, CharacterFrame, "BackdropTemplate")
        backdrop:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 0, 0)
        backdrop:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", 0, 0)
        backdrop:SetFrameLevel(CharacterFrame:GetFrameLevel() - 1)
        
        backdrop:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        
        -- Background with transparency
        backdrop:SetBackdropColor(bgr, bgg, bgb, 0.85)
        
        -- Class-colored border
        backdrop:SetBackdropBorderColor(pr, pg, pb, 1)
        
        CharacterFrame.AbstractBackdrop = backdrop
    end
    
    -- Make NineSlice completely transparent so game world shows through
    if CharacterFrame.NineSlice.Center then
        CharacterFrame.NineSlice.Center:SetAlpha(0)
        CharacterFrame.NineSlice.Center:Hide()
    end
    
    -- Hide the portrait completely
    if CharacterFramePortrait then
        CharacterFramePortrait:SetAlpha(0)
    end
    
    -- Hide Blizzard's close button and create our own
    if CharacterFrame.CloseButton then
        CharacterFrame.CloseButton:Hide()
        CharacterFrame.CloseButton:SetAlpha(0)
    end
    
    -- Create custom themed close button
    if not CharacterFrame.AbstractCloseButton then
        local closeBtn = CreateFrame("Button", nil, CharacterFrame, "BackdropTemplate")
        closeBtn:SetSize(20, 20)
        closeBtn:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -5, -5)
        
        -- Backdrop
        closeBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        closeBtn:SetBackdropColor(bgr, bgg, bgb, 0.5)
        closeBtn:SetBackdropBorderColor(pr * 0.5, pg * 0.5, pb * 0.5, 0.8)
        
        -- X text
        local xText = closeBtn:CreateFontString(nil, "OVERLAY")
        xText:SetPoint("CENTER", 0, 0)
        xText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        xText:SetText("X")
        xText:SetTextColor(pr, pg, pb, 1)
        
        -- Hover effect
        closeBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(pr * 0.8, pg * 0.8, pb * 0.8, 0.8)
            xText:SetTextColor(1, 1, 1, 1)
        end)
        
        closeBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(bgr, bgg, bgb, 0.5)
            xText:SetTextColor(pr, pg, pb, 1)
        end)
        
        -- Click to close
        closeBtn:SetScript("OnClick", function()
            HideUIPanel(CharacterFrame)
        end)
        
        CharacterFrame.AbstractCloseButton = closeBtn
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
    
    -- Completely hide class background
    if CharacterStatsPane.ClassBackground then
        CharacterStatsPane.ClassBackground:SetAlpha(0)
        CharacterStatsPane.ClassBackground:Hide()
    end
    
    -- Style item level display - remove background completely
    if CharacterStatsPane.ItemLevelFrame then
        local ilvlFrame = CharacterStatsPane.ItemLevelFrame
        
        if ilvlFrame.Background then
            ilvlFrame.Background:SetAlpha(0)
            ilvlFrame.Background:Hide()
        end
        
        if ilvlFrame.Value then
            ilvlFrame.Value:SetTextColor(pr, pg, pb, 1)
            ilvlFrame.Value:SetShadowOffset(1, -1)
            ilvlFrame.Value:SetShadowColor(0, 0, 0, 1)
        end
    end
    
    -- Completely remove backgrounds from stat category headers
    local categories = {
        "ItemLevelCategory",
        "AttributesCategory",
        "EnhancementsCategory",
    }
    
    for _, catName in ipairs(categories) do
        local category = CharacterStatsPane[catName]
        if category and category.Background then
            category.Background:SetAlpha(0)
            category.Background:Hide()
        end
        if category and category.Title then
            category.Title:SetTextColor(pr, pg, pb, 1)
        end
    end
    
    -- Remove backgrounds from individual stat frames
    if CharacterStatsPane.statsFramePool then
        hooksecurefunc(CharacterStatsPane.statsFramePool, "Acquire", function(pool)
            for frame in pool:EnumerateActive() do
                if frame.Background and not frame._abstractSkinned then
                    frame.Background:SetAlpha(0)
                    frame.Background:Hide()
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
