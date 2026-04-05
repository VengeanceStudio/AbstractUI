local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local CharacterPane = AbstractUI:NewModule("CharacterPane", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

---------------------------------------------------------------------------
-- CHARACTER FRAME SKINNING
-- Skins CharacterFrame including Character, Reputation, and Currency tabs
---------------------------------------------------------------------------

-- Configuration constants
local CONFIG = {
    PANEL_WIDTH_EXTENSION = 55,   -- Extra width for stats panel
    PANEL_HEIGHT_EXTENSION = 50,  -- Extra height for stats panel
}

-- Module state
local customBg = nil
local ColorPalette = nil
local FontKit = nil

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function CharacterPane:OnInitialize()
    self:RegisterMessage("AbstractUI_DB_READY", "OnDBReady")
end

function CharacterPane:OnDBReady()
    -- Get framework references
    ColorPalette = _G.AbstractUI_ColorPalette
    FontKit = _G.AbstractUI_FontKit
    
    if not ColorPalette or not FontKit then
        AbstractUI:Print("CharacterPane: ColorPalette or FontKit not available")
        return
    end
    
    self.db = AbstractUI.db:RegisterNamespace("CharacterPane", {
        profile = {
            enabled = true,
        }
    })
    
    -- Wait for Blizzard_CharacterFrame to load
    if IsAddOnLoaded("Blizzard_CharacterFrame") then
        self:SetupCharacterFrameSkinning()
    else
        self:RegisterEvent("ADDON_LOADED")
    end
end

function CharacterPane:ADDON_LOADED(event, addon)
    if addon == "Blizzard_CharacterFrame" then
        C_Timer.After(0.1, function()
            self:SetupCharacterFrameSkinning()
        end)
        self:UnregisterEvent("ADDON_LOADED")
    end
end

---------------------------------------------------------------------------
-- Helper: Get theme colors
---------------------------------------------------------------------------
local function GetThemeColors()
    if not ColorPalette then
        return 0.2, 1.0, 0.6, 1, 0.05, 0.05, 0.05, 0.95  -- Fallback
    end
    
    local sr, sg, sb, sa = ColorPalette:GetColor('primary')
    local bgr, bgg, bgb, bga = ColorPalette:GetColor('background')
    
    return sr, sg, sb, sa, bgr, bgg, bgb, bga
end

---------------------------------------------------------------------------
-- Helper: Get font path from settings
---------------------------------------------------------------------------
local function GetFontPath()
    if FontKit then
        return FontKit:GetFont('body')
    end
    local db = AbstractUI.db and AbstractUI.db.profile
    return (db and LSM:Fetch("font", db.theme.font)) or STANDARD_TEXT_FONT
end

---------------------------------------------------------------------------
-- Helper: Check if skinning is enabled
---------------------------------------------------------------------------
local function IsSkinningEnabled()
    if not CharacterPane.db then return false end
    return CharacterPane.db.profile.enabled
end

---------------------------------------------------------------------------
-- Create/update the custom background frame
---------------------------------------------------------------------------
local function CreateOrUpdateBackground()
    if not CharacterFrame then return end

    local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetThemeColors()

    if not customBg then
        customBg = CreateFrame("Frame", "AbstractUI_CharacterFrameBg", CharacterFrame, "BackdropTemplate")
        customBg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        customBg:SetFrameStrata("BACKGROUND")
        customBg:SetFrameLevel(0)
        customBg:EnableMouse(false)
    end

    customBg:SetBackdropColor(bgr, bgg, bgb, bga)
    customBg:SetBackdropBorderColor(sr, sg, sb, sa)

    return customBg
end

---------------------------------------------------------------------------
-- Hide Blizzard decorative elements on CharacterFrame
---------------------------------------------------------------------------
local function HideBlizzardDecorations()
    if CharacterFramePortrait then CharacterFramePortrait:Hide() end
    if CharacterFrame.Background then CharacterFrame.Background:Hide() end
    if CharacterFrame.NineSlice then CharacterFrame.NineSlice:Hide() end
    if CharacterFrameBg then CharacterFrameBg:Hide() end
    if CharacterStatsPane then CharacterStatsPane:Hide() end
end

---------------------------------------------------------------------------
-- Set background to normal or extended mode
---------------------------------------------------------------------------
local function SetCharacterFrameBgExtended(extended)
    if not customBg then
        CreateOrUpdateBackground()
    end
    if not customBg then return end

    customBg:ClearAllPoints()

    if extended then
        customBg:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 0, 0)
        customBg:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT",
            CONFIG.PANEL_WIDTH_EXTENSION, -CONFIG.PANEL_HEIGHT_EXTENSION)
    else
        customBg:SetAllPoints(CharacterFrame)
    end

    customBg:Show()
    HideBlizzardDecorations()
end

---------------------------------------------------------------------------
-- Skin individual reputation entry/header
---------------------------------------------------------------------------
local function SkinReputationEntry(child)
    if child.abstractSkinned then return end

    local sr, sg, sb, sa = GetThemeColors()
    local fontPath = GetFontPath()

    -- Skin top-level headers (expansion names)
    if child.Right then
        if child.Name then
            child.Name:SetFont(fontPath, 13, "")
            child.Name:SetTextColor(sr, sg, sb, 1)
        end

        -- Replace collapse icons
        local function UpdateCollapseIcon(texture, atlas)
            if not atlas or atlas == "Options_ListExpand_Right" or atlas == "Options_ListExpand_Right_Expanded" then
                if child.IsCollapsed and child:IsCollapsed() then
                    texture:SetAtlas("Soulbinds_Collection_CategoryHeader_Expand", true)
                else
                    texture:SetAtlas("Soulbinds_Collection_CategoryHeader_Collapse", true)
                end
            end
        end

        UpdateCollapseIcon(child.Right)
        UpdateCollapseIcon(child.HighlightRight)
        hooksecurefunc(child.Right, "SetAtlas", UpdateCollapseIcon)
        hooksecurefunc(child.HighlightRight, "SetAtlas", UpdateCollapseIcon)
    end

    -- Skin reputation bar
    local ReputationBar = child.Content and child.Content.ReputationBar
    if ReputationBar then
        ReputationBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")

        if ReputationBar.BarText then
            ReputationBar.BarText:SetFont(fontPath, 10, "")
            ReputationBar.BarText:SetTextColor(0.9, 0.9, 0.9, 1)
        end

        -- Create backdrop for rep bar
        if not ReputationBar.abstractBackdrop then
            local backdrop = CreateFrame("Frame", nil, ReputationBar:GetParent(), "BackdropTemplate")
            backdrop:SetFrameLevel(ReputationBar:GetFrameLevel())
            backdrop:SetPoint("TOPLEFT", ReputationBar, "TOPLEFT", -2, 2)
            backdrop:SetPoint("BOTTOMRIGHT", ReputationBar, "BOTTOMRIGHT", 2, -2)
            backdrop:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 2,
            })
            backdrop:SetBackdropColor(0, 0, 0, 0.9)
            backdrop:SetBackdropBorderColor(sr, sg, sb, 1)
            backdrop:Show()
            ReputationBar.abstractBackdrop = backdrop
        end

        if child.Content.Name then
            child.Content.Name:SetFont(fontPath, 11, "")
        end
    end

    -- Skin collapse button
    local ToggleCollapseButton = child.ToggleCollapseButton
    if ToggleCollapseButton and ToggleCollapseButton.RefreshIcon then
        local function UpdateToggleButton(button)
            local header = button.GetHeader and button:GetHeader()
            if not header then return end
            if header:IsCollapsed() then
                button:GetNormalTexture():SetAtlas("Gamepad_Expand", true)
                button:GetPushedTexture():SetAtlas("Gamepad_Expand", true)
            else
                button:GetNormalTexture():SetAtlas("Gamepad_Collapse", true)
                button:GetPushedTexture():SetAtlas("Gamepad_Collapse", true)
            end
        end
        hooksecurefunc(ToggleCollapseButton, "RefreshIcon", UpdateToggleButton)
        UpdateToggleButton(ToggleCollapseButton)
    end

    child.abstractSkinned = true
end

---------------------------------------------------------------------------
-- Skin individual currency entry/header
---------------------------------------------------------------------------
local function SkinCurrencyEntry(child)
    if child.abstractSkinned then return end

    local sr, sg, sb, sa = GetThemeColors()
    local fontPath = GetFontPath()

    -- Skin top-level headers
    if child.Right then
        if child.Name then
            child.Name:SetFont(fontPath, 13, "")
            child.Name:SetTextColor(sr, sg, sb, 1)
        end

        -- Replace collapse icons
        local function UpdateCollapseIcon(texture, atlas)
            if not atlas or atlas == "Options_ListExpand_Right" or atlas == "Options_ListExpand_Right_Expanded" then
                if child.IsCollapsed and child:IsCollapsed() then
                    texture:SetAtlas("Soulbinds_Collection_CategoryHeader_Expand", true)
                else
                    texture:SetAtlas("Soulbinds_Collection_CategoryHeader_Collapse", true)
                end
            end
        end

        UpdateCollapseIcon(child.Right)
        UpdateCollapseIcon(child.HighlightRight)
        hooksecurefunc(child.Right, "SetAtlas", UpdateCollapseIcon)
        hooksecurefunc(child.HighlightRight, "SetAtlas", UpdateCollapseIcon)
    end

    -- Style currency icon
    local CurrencyIcon = child.Content and child.Content.CurrencyIcon
    if CurrencyIcon then
        CurrencyIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        if not CurrencyIcon.abstractBorder then
            local border = CreateFrame("Frame", nil, CurrencyIcon:GetParent(), "BackdropTemplate")
            local drawLayer = CurrencyIcon.GetDrawLayer and CurrencyIcon:GetDrawLayer()
            border:SetFrameLevel((drawLayer == "OVERLAY") and child:GetFrameLevel() + 2 or child:GetFrameLevel() + 1)
            border:SetPoint("TOPLEFT", CurrencyIcon, "TOPLEFT", -1, 1)
            border:SetPoint("BOTTOMRIGHT", CurrencyIcon, "BOTTOMRIGHT", 1, -1)
            border:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            border:SetBackdropBorderColor(sr, sg, sb, 1)
            CurrencyIcon.abstractBorder = border
        end
    end

    -- Style name and count
    if child.Content then
        if child.Content.Name then
            child.Content.Name:SetFont(fontPath, 11, "")
        end
        if child.Content.Count then
            child.Content.Count:SetFont(fontPath, 11, "")
        end
    end

    -- Skin collapse button
    local ToggleCollapseButton = child.ToggleCollapseButton
    if ToggleCollapseButton and ToggleCollapseButton.RefreshIcon then
        local function UpdateToggleButton(button)
            local header = button.GetHeader and button:GetHeader()
            if not header then return end
            if header:IsCollapsed() then
                button:GetNormalTexture():SetAtlas("Gamepad_Expand", true)
                button:GetPushedTexture():SetAtlas("Gamepad_Expand", true)
            else
                button:GetNormalTexture():SetAtlas("Gamepad_Collapse", true)
                button:GetPushedTexture():SetAtlas("Gamepad_Collapse", true)
            end
        end
        hooksecurefunc(ToggleCollapseButton, "RefreshIcon", UpdateToggleButton)
        UpdateToggleButton(ToggleCollapseButton)
    end

    child.abstractSkinned = true
end

---------------------------------------------------------------------------
-- Skin individual title entry button
---------------------------------------------------------------------------
local function SkinTitleEntry(button)
    if button.abstractSkinned then return end

    local sr, sg, sb, sa = GetThemeColors()
    local fontPath = GetFontPath()

    -- Style title text
    if button.text then
        button.text:SetFont(fontPath, 12, "")
        button.text:SetTextColor(0.9, 0.9, 0.9, 1)
    end

    -- Style check mark with theme color
    if button.Check then
        button.Check:SetVertexColor(sr, sg, sb, 1)
    end

    -- Style selection bar with theme color
    if button.SelectedBar then
        button.SelectedBar:SetColorTexture(sr, sg, sb, 0.3)
    end

    -- Hide Blizzard background textures
    if button.BgTop then button.BgTop:Hide() end
    if button.BgMiddle then button.BgMiddle:Hide() end
    if button.BgBottom then button.BgBottom:Hide() end

    -- Add subtle hover highlight
    if button.Highlight then
        button.Highlight:SetColorTexture(sr, sg, sb, 0.15)
    elseif not button.abstractHighlight then
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(sr, sg, sb, 0.15)
        button.abstractHighlight = highlight
    end

    button.abstractSkinned = true
end

---------------------------------------------------------------------------
-- Main skinning setup
---------------------------------------------------------------------------
function CharacterPane:SetupCharacterFrameSkinning()
    if not IsSkinningEnabled() then return end
    if not CharacterFrame then return end

    -- Create initial background
    CreateOrUpdateBackground()

    -- Hook ScrollBox updates for reputation
    if ReputationFrame and ReputationFrame.ScrollBox then
        hooksecurefunc(ReputationFrame.ScrollBox, "Update", function(frame)
            if IsSkinningEnabled() then
                frame:ForEachFrame(SkinReputationEntry)
            end
        end)
    end

    -- Hook ScrollBox updates for currency
    if TokenFrame and TokenFrame.ScrollBox then
        hooksecurefunc(TokenFrame.ScrollBox, "Update", function(frame)
            if IsSkinningEnabled() then
                frame:ForEachFrame(SkinCurrencyEntry)
            end
        end)
    end

    -- Hook title pane if it exists
    if PaperDollFrame and PaperDollFrame.TitleManagerPane then
        local titlePane = PaperDollFrame.TitleManagerPane
        
        -- Hide pane background
        if titlePane.Bg then titlePane.Bg:Hide() end
        
        -- Hook ScrollBox for titles
        if titlePane.ScrollBox then
            hooksecurefunc(titlePane.ScrollBox, "Update", function(scrollBox)
                if IsSkinningEnabled() then
                    scrollBox:ForEachFrame(SkinTitleEntry)
                end
            end)
        end
        
        -- Show on title pane open
        titlePane:HookScript("OnShow", function()
            if IsSkinningEnabled() and titlePane.ScrollBox then
                titlePane.ScrollBox:ForEachFrame(SkinTitleEntry)
            end
        end)
    end

    -- Handle tab switching - show background and hide decorations
    if ReputationFrame then
        ReputationFrame:HookScript("OnShow", function()
            if IsSkinningEnabled() then
                SetCharacterFrameBgExtended(false)
            end
        end)
        if ReputationFrame:IsShown() then
            SetCharacterFrameBgExtended(false)
        end
    end

    if TokenFrame then
        TokenFrame:HookScript("OnShow", function()
            if IsSkinningEnabled() then
                SetCharacterFrameBgExtended(false)
            end
        end)
        if TokenFrame:IsShown() then
            SetCharacterFrameBgExtended(false)
        end
    end

    -- Handle Character tab (PaperDollFrame)
    if PaperDollFrame then
        PaperDollFrame:HookScript("OnShow", function()
            if IsSkinningEnabled() then
                SetCharacterFrameBgExtended(false)
            end
        end)
        if PaperDollFrame:IsShown() then
            SetCharacterFrameBgExtended(false)
        end
    end

    -- Handle CharacterFrame open when PaperDoll not shown
    CharacterFrame:HookScript("OnShow", function()
        C_Timer.After(0.01, function()
            if IsSkinningEnabled() and not (PaperDollFrame and PaperDollFrame:IsShown()) then
                SetCharacterFrameBgExtended(false)
            end
        end)
    end)
    
    -- Listen for theme changes
    self:RegisterMessage("AbstractUI_THEME_CHANGED", "OnThemeChanged")
end

---------------------------------------------------------------------------
-- Refresh colors on theme change
---------------------------------------------------------------------------
function CharacterPane:OnThemeChanged()
    if not IsSkinningEnabled() then return end

    local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetThemeColors()

    -- Update main background
    if customBg then
        customBg:SetBackdropColor(bgr, bgg, bgb, bga)
        customBg:SetBackdropBorderColor(sr, sg, sb, sa)
    end

    -- Update reputation entries
    if ReputationFrame and ReputationFrame.ScrollBox then
        ReputationFrame.ScrollBox:ForEachFrame(function(child)
            if not child.abstractSkinned then return end
            if child.Right and child.Name then
                child.Name:SetTextColor(sr, sg, sb, 1)
            end
            local ReputationBar = child.Content and child.Content.ReputationBar
            if ReputationBar and ReputationBar.abstractBackdrop then
                ReputationBar.abstractBackdrop:SetBackdropBorderColor(sr, sg, sb, 1)
            end
        end)
    end

    -- Update currency entries
    if TokenFrame and TokenFrame.ScrollBox then
        TokenFrame.ScrollBox:ForEachFrame(function(child)
            if not child.abstractSkinned then return end
            if child.Right and child.Name then
                child.Name:SetTextColor(sr, sg, sb, 1)
            end
            local CurrencyIcon = child.Content and child.Content.CurrencyIcon
            if CurrencyIcon and CurrencyIcon.abstractBorder then
                CurrencyIcon.abstractBorder:SetBackdropBorderColor(sr, sg, sb, 1)
            end
        end)
    end

    -- Update title entries
    if PaperDollFrame and PaperDollFrame.TitleManagerPane and PaperDollFrame.TitleManagerPane.ScrollBox then
        PaperDollFrame.TitleManagerPane.ScrollBox:ForEachFrame(function(button)
            if not button.abstractSkinned then return end
            if button.Check then
                button.Check:SetVertexColor(sr, sg, sb, 1)
            end
            if button.SelectedBar then
                button.SelectedBar:SetColorTexture(sr, sg, sb, 0.3)
            end
            if button.abstractHighlight then
                button.abstractHighlight:SetColorTexture(sr, sg, sb, 0.15)
            end
        end)
    end
end
