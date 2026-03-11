-- AbstractUI Frame Factory
-- Component creation system with theme support

local FrameFactory = {}

-- Cache framework systems
local Atlas, ColorPalette, FontKit, LayoutHelper
local AbstractUI

-- Initialize on addon load
function FrameFactory:Initialize(addon)
    AbstractUI = addon
    
    -- Get framework systems from global namespace
    Atlas = _G.AbstractUI_Atlas
    ColorPalette = _G.AbstractUI_ColorPalette
    FontKit = _G.AbstractUI_FontKit
    LayoutHelper = _G.AbstractUI_LayoutHelper
    
    -- Register all framework systems with the addon
    AbstractUI.Atlas = Atlas
    AbstractUI.ColorPalette = ColorPalette
    AbstractUI.FontKit = FontKit
    AbstractUI.LayoutHelper = LayoutHelper
    AbstractUI.FrameFactory = FrameFactory
end

-- Current theme
FrameFactory.activeTheme = "AbstractGlass"

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
    
    -- Use the same backdrop approach as AbstractOptionsPanel for consistency
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    panel:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
    panel:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
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
    
    -- Up button
    local upButton = CreateFrame("Button", nil, scrollbar, "BackdropTemplate")
    upButton:SetSize(14, 14)
    upButton:SetPoint("TOP", scrollbar, "TOP", 0, -1)
    upButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    upButton:SetBackdropColor(ColorPalette:GetColor("button-bg"))
    upButton:SetBackdropBorderColor(ColorPalette:GetColor("panel-border"))
    
    -- Up button diamond arrow
    local upArrow = upButton:CreateTexture(nil, "ARTWORK")
    upArrow:SetSize(8, 8)
    upArrow:SetPoint("CENTER")
    upArrow:SetTexture("Interface\\Buttons\\WHITE8X8")
    upArrow:SetVertexColor(ColorPalette:GetColor("text-primary"))
    upArrow:SetRotation(math.rad(45))
    
    upButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ColorPalette:GetColor("button-hover"))
    end)
    upButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ColorPalette:GetColor("button-bg"))
    end)
    upButton:SetScript("OnClick", function()
        local current = scrollbar:GetValue()
        local min = scrollbar:GetMinMaxValues()
        scrollbar:SetValue(math.max(min, current - 1))
    end)
    
    -- Down button
    local downButton = CreateFrame("Button", nil, scrollbar, "BackdropTemplate")
    downButton:SetSize(14, 14)
    downButton:SetPoint("BOTTOM", scrollbar, "BOTTOM", 0, 1)
    downButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    downButton:SetBackdropColor(ColorPalette:GetColor("button-bg"))
    downButton:SetBackdropBorderColor(ColorPalette:GetColor("panel-border"))
    
    -- Down button diamond arrow
    local downArrow = downButton:CreateTexture(nil, "ARTWORK")
    downArrow:SetSize(8, 8)
    downArrow:SetPoint("CENTER")
    downArrow:SetTexture("Interface\\Buttons\\WHITE8X8")
    downArrow:SetVertexColor(ColorPalette:GetColor("text-primary"))
    downArrow:SetRotation(math.rad(-135))
    
    downButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ColorPalette:GetColor("button-hover"))
    end)
    downButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ColorPalette:GetColor("button-bg"))
    end)
    downButton:SetScript("OnClick", function()
        local current = scrollbar:GetValue()
        local _, max = scrollbar:GetMinMaxValues()
        scrollbar:SetValue(math.min(max, current + 1))
    end)
    
    -- Thumb
    scrollbar.thumb = scrollbar:CreateTexture(nil, "OVERLAY")
    scrollbar.thumb:SetSize(14, 32)
    scrollbar.thumb:SetColorTexture(ColorPalette:GetColor("scrollbar-thumb"))
    scrollbar:SetThumbTexture(scrollbar.thumb)
    
    scrollbar.upButton = upButton
    scrollbar.downButton = downButton
    
    return scrollbar
end

-- ============================================================================
-- CHECKBOX FACTORY
-- ============================================================================

function FrameFactory:CreateCheckbox(parent, size)
    local checkbox = CreateFrame("Button", nil, parent, "BackdropTemplate")
    checkbox:SetSize(size or 16, size or 16)
    
    -- Box backdrop
    checkbox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    checkbox:SetBackdropColor(ColorPalette:GetColor("bg-secondary"))
    checkbox:SetBackdropBorderColor(ColorPalette:GetColor("primary"))
    
    -- Store colors
    checkbox.normalBgColor = {ColorPalette:GetColor("bg-secondary")}
    checkbox.hoverBgColor = {ColorPalette:GetColor("button-hover")}
    checkbox.borderColor = {ColorPalette:GetColor("primary")}
    checkbox.checkColor = {ColorPalette:GetColor("primary")}
    
    -- Checkmark texture
    checkbox.check = checkbox:CreateTexture(nil, "ARTWORK")
    checkbox.check:SetSize((size or 16) - 4, (size or 16) - 4)
    checkbox.check:SetPoint("CENTER")
    checkbox.check:SetTexture("Interface\\AddOns\\AbstractUI\\Media\\checkmark")
    checkbox.check:SetVertexColor(unpack(checkbox.checkColor))
    checkbox.check:Hide()
    
    checkbox.checked = false
    
    function checkbox:SetChecked(checked)
        self.checked = checked
        if checked then
            self.check:Show()
        else
            self.check:Hide()
        end
    end
    
    function checkbox:GetChecked()
        return self.checked
    end
    
    function checkbox:Toggle()
        self:SetChecked(not self.checked)
    end
    
    -- Hover effects
    checkbox:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(self.hoverBgColor))
    end)
    
    checkbox:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(self.normalBgColor))
    end)
    
    -- Click handler (override this after creation)
    checkbox:SetScript("OnClick", function(self)
        self:Toggle()
    end)
    
    return checkbox
end

-- ============================================================================
-- DROPDOWN FACTORY
-- ============================================================================

function FrameFactory:CreateDropdown(parent, width, height)
    local dropdown = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    dropdown:SetSize(width or 150, height or 24)
    
    -- Dropdown backdrop
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    dropdown:SetBackdropColor(ColorPalette:GetColor("bg-secondary"))
    dropdown:SetBackdropBorderColor(ColorPalette:GetColor("primary"))
    
    -- Button to open dropdown
    dropdown.button = CreateFrame("Button", nil, dropdown)
    dropdown.button:SetAllPoints()
    
    -- Selected text
    dropdown.text = FontKit:CreateFontString(dropdown, "body", "normal")
    dropdown.text:SetPoint("LEFT", 5, 0)
    dropdown.text:SetPoint("RIGHT", -20, 0)
    dropdown.text:SetJustifyH("LEFT")
    dropdown.text:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    -- Arrow indicator
    dropdown.arrow = dropdown:CreateTexture(nil, "ARTWORK")
    dropdown.arrow:SetSize(12, 12)
    dropdown.arrow:SetPoint("RIGHT", -5, 0)
    dropdown.arrow:SetTexture("Interface\\AddOns\\AbstractUI\\Media\\dropdown")
    dropdown.arrow:SetVertexColor(ColorPalette:GetColor("text-secondary"))
    
    -- Menu frame
    dropdown.menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    dropdown.menu:SetPoint("TOP", dropdown, "BOTTOM", 0, -2)
    dropdown.menu:SetSize(width or 150, 100)
    dropdown.menu:SetFrameStrata("DIALOG")
    dropdown.menu:SetFrameLevel(dropdown:GetFrameLevel() + 5)
    dropdown.menu:Hide()
    
    dropdown.menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    local r, g, b = ColorPalette:GetColor("panel-bg")
    if type(r) == "table" then
        g, b = r[2] or r.g or 0.05, r[3] or r.b or 0.1
        r = r[1] or r.r or 0.05
    end
    dropdown.menu:SetBackdropColor(r, g, b, 1.0)
    dropdown.menu:SetBackdropBorderColor(ColorPalette:GetColor("primary"))
    
    -- Menu items container
    dropdown.menu.items = {}
    dropdown.selectedValue = nil
    dropdown.selectedText = nil
    
    function dropdown:SetItems(items)
        -- Clear existing items
        for _, item in ipairs(self.menu.items) do
            item:Hide()
            item:SetParent(nil)
        end
        wipe(self.menu.items)
        
        -- Create new items
        local itemHeight = 20
        for i, itemData in ipairs(items) do
            local item = CreateFrame("Button", nil, self.menu, "BackdropTemplate")
            item:SetSize(self.menu:GetWidth() - 4, itemHeight)
            item:SetPoint("TOPLEFT", 2, -(i - 1) * itemHeight - 2)
            
            item:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                tile = false,
            })
            item:SetBackdropColor(0, 0, 0, 0)
            
            item.text = FontKit:CreateFontString(item, "body", "small")
            item.text:SetPoint("LEFT", 5, 0)
            item.text:SetText(itemData.text or itemData.value)
            item.text:SetTextColor(ColorPalette:GetColor("text-primary"))
            
            item.value = itemData.value
            item.text_display = itemData.text
            
            item:SetScript("OnEnter", function(self)
                self:SetBackdropColor(ColorPalette:GetColor("button-hover"))
            end)
            
            item:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0, 0, 0, 0)
            end)
            
            item:SetScript("OnClick", function(self)
                dropdown:SetValue(self.value, self.text_display)
                dropdown.menu:Hide()
                if dropdown.onChange then
                    dropdown.onChange(self.value)
                end
            end)
            
            table.insert(self.menu.items, item)
        end
        
        -- Adjust menu height
        self.menu:SetHeight(math.min(#items * itemHeight + 4, 200))
    end
    
    function dropdown:SetValue(value, text)
        self.selectedValue = value
        self.selectedText = text or value
        self.text:SetText(self.selectedText)
    end
    
    function dropdown:GetValue()
        return self.selectedValue
    end
    
    -- Toggle menu
    dropdown.button:SetScript("OnClick", function(self)
        local menu = dropdown.menu
        if menu:IsShown() then
            menu:Hide()
        else
            menu:Show()
        end
    end)
    
    -- Close menu when clicking outside
    dropdown.menu:SetScript("OnShow", function(self)
        if not self.closeHandler then
            self.closeHandler = CreateFrame("Frame")
            self.closeHandler:SetScript("OnUpdate", function(handler)
                if IsMouseButtonDown() then
                    if not MouseIsOver(dropdown) and not MouseIsOver(self) then
                        self:Hide()
                        handler:SetScript("OnUpdate", nil)
                    end
                end
            end)
        else
            self.closeHandler:SetScript("OnUpdate", function(handler)
                if IsMouseButtonDown() then
                    if not MouseIsOver(dropdown) and not MouseIsOver(self) then
                        self:Hide()
                        handler:SetScript("OnUpdate", nil)
                    end
                end
            end)
        end
    end)
    
    return dropdown
end

-- ============================================================================
-- TOOLTIP FACTORY
-- ============================================================================

function FrameFactory:CreateTooltip(name)
    local tooltip = CreateFrame("GameTooltip", name or "AbstractUITooltip", UIParent, "GameTooltipTemplate")
    
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
_G.AbstractUI_FrameFactory = FrameFactory

return FrameFactory
