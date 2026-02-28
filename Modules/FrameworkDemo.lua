-- MidnightUI Framework Demo
-- Showcases the framework components and theme system

local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local Demo = MidnightUI:NewModule("FrameworkDemo", "AceEvent-3.0")

-- Cache framework systems
local FrameFactory, ColorPalette, FontKit, LayoutHelper, Atlas

-- Demo frame
local demoFrame

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function Demo:OnInitialize()
    -- Register slash command
    SLASH_MIDNIGHTDEMO1 = "/midemo"
    SLASH_MIDNIGHTDEMO2 = "/midnightdemo"
    SlashCmdList["MIDNIGHTDEMO"] = function()
        Demo:Toggle()
    end
end

function Demo:OnEnable()
    -- Framework Demo loaded
end

-- ============================================================================
-- DEMO FRAME CREATION
-- ============================================================================

function Demo:CreateDemoFrame()
    if demoFrame then return demoFrame end
    
    -- Get framework systems (they're registered by now)
    FrameFactory = MidnightUI.FrameFactory
    ColorPalette = _G.MidnightUI_ColorPalette
    FontKit = MidnightUI.FontKit
    LayoutHelper = MidnightUI.LayoutHelper
    Atlas = MidnightUI.Atlas
    
    if not FrameFactory or not ColorPalette or not FontKit then
        MidnightUI:Print("Framework not initialized yet. Please try again.")
        return
    end
    
    -- Main container
    demoFrame = CreateFrame("Frame", "MidnightUIDemoFrame", UIParent, "BackdropTemplate")
    demoFrame:SetSize(800, 600)
    demoFrame:SetPoint("CENTER")
    demoFrame:SetFrameStrata("DIALOG")
    demoFrame:EnableMouse(true)
    demoFrame:SetMovable(true)
    demoFrame:RegisterForDrag("LeftButton")
    demoFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    demoFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    demoFrame:Hide()
    
    -- Main background (ensure visibility)
    demoFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    demoFrame:SetBackdropColor(ColorPalette:GetColor("panel-bg"))
    demoFrame:SetBackdropBorderColor(ColorPalette:GetColor("panel-border"))
    
    -- Title bar
    local titleBg = demoFrame:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT", 0, 0)
    titleBg:SetPoint("TOPRIGHT", 0, 0)
    titleBg:SetHeight(40)
    titleBg:SetColorTexture(ColorPalette:GetColor("bg-secondary"))
    
    local title = FontKit:CreateFontString(demoFrame, "title", "large")
    title:SetPoint("TOP", 0, -10)
    title:SetText("MidnightUI Framework Demo")
    title:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    -- Close button (top right)
    local closeBtn = FrameFactory:CreateButton(demoFrame, 24, 24, "X")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function()
        Demo:Hide()
    end)
    
    -- Theme info display
    local themeLabel = FontKit:CreateFontString(demoFrame, "body", "small")
    themeLabel:SetPoint("TOPLEFT", 20, -50)
    themeLabel:SetText("Active Theme:")
    themeLabel:SetTextColor(ColorPalette:GetColor("text-secondary"))
    
    local themeValue = FontKit:CreateFontString(demoFrame, "heading", "normal")
    themeValue:SetPoint("LEFT", themeLabel, "RIGHT", 10, 0)
    themeValue:SetText(ColorPalette:GetActiveTheme())
    themeValue:SetTextColor(ColorPalette:GetColor("primary"))
    demoFrame.themeValue = themeValue
    
    -- Theme switching buttons
    local glassBtnLabel = "Switch to Midnight Glass"
    if ColorPalette:GetActiveTheme() == "MidnightGlass" then
        glassBtnLabel = "Midnight Glass (Active)"
    end
    
    local glassBtn = FrameFactory:CreateButton(demoFrame, 200, 32, glassBtnLabel)
    glassBtn:SetPoint("TOPLEFT", 20, -80)
    glassBtn:SetScript("OnClick", function()
        Demo:SwitchTheme("MidnightGlass")
    end)
    demoFrame.glassBtn = glassBtn
    
    local neonBtnLabel = "Switch to Neon Sci-Fi"
    if ColorPalette:GetActiveTheme() == "NeonSciFi" then
        neonBtnLabel = "Neon Sci-Fi (Active)"
    end
    
    local neonBtn = FrameFactory:CreateButton(demoFrame, 200, 32, neonBtnLabel)
    neonBtn:SetPoint("LEFT", glassBtn, "RIGHT", 10, 0)
    neonBtn:SetScript("OnClick", function()
        Demo:SwitchTheme("NeonSciFi")
    end)
    demoFrame.neonBtn = neonBtn
    
    -- Divider
    local divider1 = demoFrame:CreateTexture(nil, "ARTWORK")
    divider1:SetPoint("TOPLEFT", 20, -125)
    divider1:SetPoint("TOPRIGHT", -20, -125)
    divider1:SetHeight(2)
    divider1:SetColorTexture(ColorPalette:GetColor("panel-border"))
    
    -- BUTTONS SECTION
    local buttonLabel = FontKit:CreateFontString(demoFrame, "heading", "medium")
    buttonLabel:SetPoint("TOPLEFT", 20, -140)
    buttonLabel:SetText("Buttons")
    buttonLabel:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    local btn1 = FrameFactory:CreateButton(demoFrame, 140, 36, "Normal Button")
    btn1:SetPoint("TOPLEFT", 20, -170)
    btn1:SetScript("OnClick", function()
        MidnightUI:Print("Button 1 clicked!")
    end)
    
    local btn2 = FrameFactory:CreateButton(demoFrame, 140, 36, "Another Button")
    btn2:SetPoint("LEFT", btn1, "RIGHT", 10, 0)
    btn2:SetScript("OnClick", function()
        MidnightUI:Print("Button 2 clicked!")
    end)
    
    local btn3 = FrameFactory:CreateButton(demoFrame, 140, 36, "Third Button")
    btn3:SetPoint("LEFT", btn2, "RIGHT", 10, 0)
    btn3:SetScript("OnClick", function()
        MidnightUI:Print("Button 3 clicked!")
    end)
    
    -- TABS SECTION
    local tabLabel = FontKit:CreateFontString(demoFrame, "heading", "medium")
    tabLabel:SetPoint("TOPLEFT", 20, -230)
    tabLabel:SetText("Tabs")
    tabLabel:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    local tab1 = FrameFactory:CreateTab(demoFrame, 120, 32, "Tab One")
    tab1:SetPoint("TOPLEFT", 20, -260)
    tab1:SetActive(true)
    
    local tab2 = FrameFactory:CreateTab(demoFrame, 120, 32, "Tab Two")
    tab2:SetPoint("LEFT", tab1, "RIGHT", 5, 0)
    
    local tab3 = FrameFactory:CreateTab(demoFrame, 120, 32, "Tab Three")
    tab3:SetPoint("LEFT", tab2, "RIGHT", 5, 0)
    
    -- Tab switching logic
    local tabs = {tab1, tab2, tab3}
    for i, tab in ipairs(tabs) do
        tab:SetScript("OnClick", function()
            for _, t in ipairs(tabs) do
                t:SetActive(false)
            end
            tab:SetActive(true)
            MidnightUI:Print("Switched to " .. tab.text:GetText())
        end)
    end
    
    -- PANEL SECTION
    local panelLabel = FontKit:CreateFontString(demoFrame, "heading", "medium")
    panelLabel:SetPoint("TOPLEFT", 20, -310)
    panelLabel:SetText("Panels")
    panelLabel:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    local innerPanel = FrameFactory:CreatePanel(demoFrame, 360, 120)
    innerPanel:SetPoint("TOPLEFT", 20, -340)
    
    local panelText = FontKit:CreateFontString(innerPanel, "body", "normal")
    panelText:SetPoint("CENTER")
    panelText:SetText("This is a themed panel\nwith background and border")
    panelText:SetTextColor(ColorPalette:GetColor("text-secondary"))
    
    -- SCROLLBAR SECTION
    local scrollLabel = FontKit:CreateFontString(demoFrame, "heading", "medium")
    scrollLabel:SetPoint("TOPLEFT", 400, -310)
    scrollLabel:SetText("Scrollbar")
    scrollLabel:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    local scrollbar = FrameFactory:CreateScrollBar(demoFrame, 120)
    scrollbar:SetPoint("TOPLEFT", 400, -340)
    
    local scrollValue = FontKit:CreateFontString(demoFrame, "body", "normal")
    scrollValue:SetPoint("LEFT", scrollbar, "RIGHT", 10, 0)
    scrollValue:SetText("Value: 0")
    scrollValue:SetTextColor(ColorPalette:GetColor("text-secondary"))
    
    scrollbar:SetScript("OnValueChanged", function(self, value)
        scrollValue:SetText(string.format("Value: %d", math.floor(value)))
    end)
    
    -- COLOR PALETTE SECTION
    local colorLabel = FontKit:CreateFontString(demoFrame, "heading", "medium")
    colorLabel:SetPoint("TOPLEFT", 20, -480)
    colorLabel:SetText("Color Palette")
    colorLabel:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    -- Color swatches
    local colors = {
        {name = "Primary", key = "primary"},
        {name = "Secondary", key = "secondary"},
        {name = "Accent", key = "accent"},
        {name = "Success", key = "success"},
        {name = "Warning", key = "warning"},
        {name = "Error", key = "error"},
    }
    
    local xOffset = 0
    for i, colorData in ipairs(colors) do
        local swatch = demoFrame:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(50, 30)
        swatch:SetPoint("TOPLEFT", 20 + xOffset, -510)
        swatch:SetColorTexture(ColorPalette:GetColor(colorData.key))
        
        local swatchLabel = FontKit:CreateFontString(demoFrame, "body", "tiny")
        swatchLabel:SetPoint("TOP", swatch, "BOTTOM", 0, -2)
        swatchLabel:SetText(colorData.name)
        swatchLabel:SetTextColor(ColorPalette:GetColor("text-secondary"))
        
        xOffset = xOffset + 60
    end
    
    -- Instructions
    local instructions = FontKit:CreateFontString(demoFrame, "body", "small")
    instructions:SetPoint("BOTTOM", 0, 10)
    instructions:SetText("Hover and click buttons to see state changes • Switch themes to see visual updates")
    instructions:SetTextColor(ColorPalette:GetColor("text-muted"))
    
    return demoFrame
end

-- ============================================================================
-- THEME SWITCHING
-- ============================================================================

function Demo:SwitchTheme(themeName)
    if not FrameFactory or not ColorPalette then return end
    
    FrameFactory:SetTheme(themeName)
    MidnightUI:Print("Switched to " .. themeName .. " theme")
    
    -- Recreate the demo frame to apply new theme
    if demoFrame then
        demoFrame:Hide()
        demoFrame = nil
    end
    
    self:CreateDemoFrame()
    demoFrame:Show()
end

-- ============================================================================
-- SHOW/HIDE/TOGGLE
-- ============================================================================

function Demo:Show()
    if not demoFrame then
        demoFrame = self:CreateDemoFrame()
    end
    if demoFrame then
        demoFrame:Show()
    end
end

function Demo:Hide()
    if demoFrame then
        demoFrame:Hide()
    end
end

function Demo:Toggle()
    if not demoFrame then
        self:Show()
    elseif demoFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

return Demo
