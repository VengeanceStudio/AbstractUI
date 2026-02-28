-- MidnightUI Frame Factory
-- Component creation system with theme support

local FrameFactory = {}

-- Cache framework systems
local Atlas, ColorPalette, FontKit, LayoutHelper
local MidnightUI

-- Initialize on addon load
function FrameFactory:Initialize(addon)
    MidnightUI = addon
    
    -- Get framework systems from global namespace
    Atlas = _G.MidnightUI_Atlas
    ColorPalette = _G.MidnightUI_ColorPalette
    FontKit = _G.MidnightUI_FontKit
    LayoutHelper = _G.MidnightUI_LayoutHelper
    
    -- Register all framework systems with the addon
    MidnightUI.Atlas = Atlas
    MidnightUI.ColorPalette = ColorPalette
    MidnightUI.FontKit = FontKit
    MidnightUI.LayoutHelper = LayoutHelper
    MidnightUI.FrameFactory = FrameFactory
end

-- Current theme
FrameFactory.activeTheme = "MidnightGlass"

-- ============================================================================
-- THEME MANAGEMENT
-- ============================================================================

function FrameFactory:SetTheme(themeName)
    self.activeTheme = themeName
    if ColorPalette then ColorPalette:SetActiveTheme(themeName) end
    if FontKit then FontKit:SetActiveTheme(themeName) end
end

function FrameFactory:GetTheme()
    return self.activeTheme
end

-- ============================================================================
-- BUTTON FACTORY
-- ============================================================================

function FrameFactory:CreateButton(parent, width, height, text)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 120, height or 32)
    
    -- Use backdrop for visibility
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    button:SetBackdropColor(ColorPalette:GetColor("button-bg"))
    button:SetBackdropBorderColor(ColorPalette:GetColor("primary"))
    
    -- Text
    button.text = FontKit:CreateFontString(button, "button", "normal")
    button.text:SetPoint("CENTER")
    button.text:SetText(text or "Button")
    button.text:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    -- Store original colors
    button.normalBgColor = {ColorPalette:GetColor("button-bg")}
    button.hoverBgColor = {ColorPalette:GetColor("button-hover")}
    button.pressedBgColor = {ColorPalette:GetColor("button-pressed")}
    button.borderColor = {ColorPalette:GetColor("primary")}
    
    -- Interactivity
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(self.hoverBgColor))
    end)
    
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(self.normalBgColor))
    end)
    
    button:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(unpack(self.pressedBgColor))
    end)
    
    button:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            self:SetBackdropColor(unpack(self.hoverBgColor))
        else
            self:SetBackdropColor(unpack(self.normalBgColor))
        end
    end)
    
    -- Custom SetText function
    function button:SetButtonText(txt)
        self.text:SetText(txt)
    end
    
    return button
end

-- ============================================================================
-- PANEL FACTORY
-- ============================================================================

function FrameFactory:CreatePanel(parent, width, height)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(width or 400, height or 300)
    
    -- Background
    panel.bg = panel:CreateTexture(nil, "BACKGROUND")
    panel.bg:SetAllPoints()
    if not Atlas:SetTexture(panel.bg, self.activeTheme, "panel-bg") then
        panel.bg:SetColorTexture(ColorPalette:GetColor("panel-bg"))
    else
        panel.bg:SetVertexColor(ColorPalette:GetColor("panel-bg"))
    end
    
    -- Border
    panel.border = panel:CreateTexture(nil, "BORDER")
    panel.border:SetPoint("TOPLEFT", -2, 2)
    panel.border:SetPoint("BOTTOMRIGHT", 2, -2)
    if not Atlas:SetTexture(panel.border, self.activeTheme, "panel-border") then
        panel.border:SetColorTexture(ColorPalette:GetColor("panel-border"))
    else
        panel.border:SetVertexColor(ColorPalette:GetColor("panel-border"))
    end
    
    return panel
end

-- ============================================================================
-- TAB FACTORY
-- ============================================================================

function FrameFactory:CreateTab(parent, width, height, text)
    local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
    tab:SetSize(width or 120, height or 32)
    
    -- Use backdrop for visibility
    tab:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    tab:SetBackdropColor(ColorPalette:GetColor("tab-inactive"))
    tab:SetBackdropBorderColor(ColorPalette:GetColor("panel-border"))
    
    -- Text
    tab.text = FontKit:CreateFontString(tab, "tab", "normal")
    tab.text:SetPoint("CENTER")
    tab.text:SetText(text or "Tab")
    tab.text:SetTextColor(ColorPalette:GetColor("text-secondary"))
    
    tab.isActive = false
    tab.inactiveColor = {ColorPalette:GetColor("tab-inactive")}
    tab.activeColor = {ColorPalette:GetColor("tab-active")}
    
    function tab:SetActive(active)
        self.isActive = active
        if active then
            self:SetBackdropColor(unpack(self.activeColor))
            self.text:SetTextColor(ColorPalette:GetColor("text-primary"))
        else
            self:SetBackdropColor(unpack(self.inactiveColor))
            self.text:SetTextColor(ColorPalette:GetColor("text-secondary"))
        end
    end
    
    return tab
end

-- ============================================================================
-- SCROLLBAR FACTORY
-- ============================================================================

function FrameFactory:CreateScrollBar(parent, height)
    local scrollbar = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetSize(16, height or 400)
    scrollbar:SetMinMaxValues(0, 100)
    scrollbar:SetValue(0)
    scrollbar:SetValueStep(1)
    
    -- Track backdrop
    scrollbar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    scrollbar:SetBackdropColor(ColorPalette:GetColor("scrollbar-track"))
    scrollbar:SetBackdropBorderColor(ColorPalette:GetColor("panel-border"))
    
    -- Thumb
    scrollbar.thumb = scrollbar:CreateTexture(nil, "OVERLAY")
    scrollbar.thumb:SetSize(14, 32)
    scrollbar.thumb:SetColorTexture(ColorPalette:GetColor("scrollbar-thumb"))
    scrollbar:SetThumbTexture(scrollbar.thumb)
    
    return scrollbar
end

-- ============================================================================
-- TOOLTIP FACTORY
-- ============================================================================

function FrameFactory:CreateTooltip(name)
    local tooltip = CreateFrame("GameTooltip", name or "MidnightUITooltip", UIParent, "GameTooltipTemplate")
    
    -- Background
    if tooltip.NineSlice then
        tooltip.NineSlice:Hide()
    end
    
    tooltip.bg = tooltip:CreateTexture(nil, "BACKGROUND")
    tooltip.bg:SetAllPoints()
    if not Atlas:SetTexture(tooltip.bg, self.activeTheme, "tooltip-bg") then
        tooltip.bg:SetColorTexture(ColorPalette:GetColor("tooltip-bg"))
    else
        tooltip.bg:SetVertexColor(ColorPalette:GetColor("tooltip-bg"))
    end
    
    -- Apply font to tooltip lines
    for i = 1, 30 do
        local leftLine = _G[name .. "TextLeft" .. i]
        local rightLine = _G[name .. "TextRight" .. i]
        
        if leftLine then
            FontKit:SetFont(leftLine, "tooltip", "small")
        end
        if rightLine then
            FontKit:SetFont(rightLine, "tooltip", "small")
        end
    end
    
    return tooltip
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Apply theme to existing frame
function FrameFactory:ApplyTheme(frame, componentType)
    -- This would reapply theme textures and colors to an existing frame
    -- Implementation depends on frame type
end

-- Register in global namespace for Core.lua to find
_G.MidnightUI_FrameFactory = FrameFactory

return FrameFactory
