-- ScrollFrame.lua
-- Custom scrollbar implementation for MidnightUI
-- Replaces Blizzard's UIPanelScrollFrameTemplate with styled scrollbars

local _, MidnightUI = ...
local ScrollFrame = {}
MidnightUI.ScrollFrame = ScrollFrame
_G.MidnightUI_ScrollFrame = ScrollFrame

local ColorPalette = _G.MidnightUI_ColorPalette

-- Create a custom scrollbar frame
local function CreateScrollbar(parent, width)
    width = width or 18
    
    local scrollbar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    scrollbar:SetWidth(width)
    scrollbar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    scrollbar:SetBackdropColor(ColorPalette:GetColor('scrollbar-track'))
    scrollbar:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Up button
    local upButton = CreateFrame("Button", nil, scrollbar, "BackdropTemplate")
    upButton:SetSize(width - 2, width - 2)
    upButton:SetPoint("TOP", scrollbar, "TOP", 0, -1)
    upButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    upButton:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    upButton:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Up button arrow
    local upArrow = upButton:CreateTexture(nil, "ARTWORK")
    upArrow:SetSize(8, 8)
    upArrow:SetPoint("CENTER")
    upArrow:SetTexture("Interface\\Buttons\\WHITE8X8")
    upArrow:SetVertexColor(ColorPalette:GetColor('text-primary'))
    upArrow:SetRotation(math.rad(45))
    
    upButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ColorPalette:GetColor('button-hover'))
    end)
    upButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    end)
    
    -- Down button
    local downButton = CreateFrame("Button", nil, scrollbar, "BackdropTemplate")
    downButton:SetSize(width - 2, width - 2)
    downButton:SetPoint("BOTTOM", scrollbar, "BOTTOM", 0, 1)
    downButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    downButton:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    downButton:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Down button arrow
    local downArrow = downButton:CreateTexture(nil, "ARTWORK")
    downArrow:SetSize(8, 8)
    downArrow:SetPoint("CENTER")
    downArrow:SetTexture("Interface\\Buttons\\WHITE8X8")
    downArrow:SetVertexColor(ColorPalette:GetColor('text-primary'))
    downArrow:SetRotation(math.rad(-135))
    
    downButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ColorPalette:GetColor('button-hover'))
    end)
    downButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    end)
    
    -- Thumb (draggable slider)
    local thumb = CreateFrame("Button", nil, scrollbar, "BackdropTemplate")
    thumb:SetWidth(width - 4)
    thumb:SetHeight(30)
    thumb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    thumb:SetBackdropColor(ColorPalette:GetColor('scrollbar-thumb'))
    thumb:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    thumb:SetPoint("TOP", upButton, "BOTTOM", 0, -2)
    
    thumb:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ColorPalette:GetColor('button-hover'))
    end)
    thumb:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ColorPalette:GetColor('scrollbar-thumb'))
    end)
    
    scrollbar.upButton = upButton
    scrollbar.downButton = downButton
    scrollbar.thumb = thumb
    
    return scrollbar
end

-- Create a custom ScrollFrame
function ScrollFrame:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    
    -- Create the scroll area
    local scrollArea = CreateFrame("ScrollFrame", nil, frame)
    scrollArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    scrollArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 0)
    
    -- Create scroll child
    local scrollChild = CreateFrame("Frame", nil, scrollArea)
    scrollChild:SetWidth(1)
    scrollChild:SetHeight(1)
    scrollArea:SetScrollChild(scrollChild)
    
    -- Create scrollbar
    local scrollbar = CreateScrollbar(frame)
    scrollbar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    scrollbar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    
    -- Scrolling logic
    local function UpdateScroll()
        local maxScroll = math.max(0, scrollChild:GetHeight() - scrollArea:GetHeight())
        local currentScroll = scrollArea:GetVerticalScroll()
        
        if maxScroll == 0 then
            scrollbar:Hide()
            scrollArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        else
            scrollbar:Show()
            scrollArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 0)
            
            -- Update thumb position
            local scrollPercent = currentScroll / maxScroll
            local trackHeight = scrollbar:GetHeight() - scrollbar.upButton:GetHeight() - scrollbar.downButton:GetHeight() - scrollbar.thumb:GetHeight() - 4
            local thumbPos = -scrollbar.upButton:GetHeight() - 2 - (scrollPercent * trackHeight)
            scrollbar.thumb:SetPoint("TOP", scrollbar, "TOP", 0, thumbPos)
        end
    end
    
    -- Up button click
    scrollbar.upButton:SetScript("OnClick", function()
        local newScroll = math.max(0, scrollArea:GetVerticalScroll() - 20)
        scrollArea:SetVerticalScroll(newScroll)
        UpdateScroll()
    end)
    
    -- Down button click
    scrollbar.downButton:SetScript("OnClick", function()
        local maxScroll = math.max(0, scrollChild:GetHeight() - scrollArea:GetHeight())
        local newScroll = math.min(maxScroll, scrollArea:GetVerticalScroll() + 20)
        scrollArea:SetVerticalScroll(newScroll)
        UpdateScroll()
    end)
    
    -- Thumb dragging
    local isDragging = false
    local dragStartY = 0
    local dragStartScroll = 0
    
    scrollbar.thumb:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            isDragging = true
            dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
            dragStartScroll = scrollArea:GetVerticalScroll()
            self:SetBackdropColor(ColorPalette:GetColor('button-pressed'))
        end
    end)
    
    scrollbar.thumb:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            isDragging = false
            self:SetBackdropColor(ColorPalette:GetColor('scrollbar-thumb'))
        end
    end)
    
    scrollbar.thumb:SetScript("OnUpdate", function(self)
        if isDragging then
            local currentY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
            local deltaY = dragStartY - currentY
            
            local trackHeight = scrollbar:GetHeight() - scrollbar.upButton:GetHeight() - scrollbar.downButton:GetHeight() - scrollbar.thumb:GetHeight() - 4
            local maxScroll = math.max(0, scrollChild:GetHeight() - scrollArea:GetHeight())
            
            if trackHeight > 0 then
                local scrollDelta = (deltaY / trackHeight) * maxScroll
                local newScroll = math.max(0, math.min(maxScroll, dragStartScroll + scrollDelta))
                scrollArea:SetVerticalScroll(newScroll)
                UpdateScroll()
            end
        end
    end)
    
    -- Mouse wheel support
    scrollArea:EnableMouseWheel(true)
    scrollArea:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, scrollChild:GetHeight() - scrollArea:GetHeight())
        local newScroll = scrollArea:GetVerticalScroll() - (delta * 20)
        newScroll = math.max(0, math.min(maxScroll, newScroll))
        scrollArea:SetVerticalScroll(newScroll)
        UpdateScroll()
    end)
    
    -- Update on size change
    scrollArea:SetScript("OnSizeChanged", UpdateScroll)
    scrollChild:SetScript("OnSizeChanged", UpdateScroll)
    
    -- Public methods
    frame.SetScrollChild = function(self, child)
        scrollChild = child
        scrollArea:SetScrollChild(child)
        UpdateScroll()
    end
    
    frame.GetScrollChild = function(self)
        return scrollChild
    end
    
    frame.UpdateScroll = UpdateScroll
    
    frame.scrollArea = scrollArea
    frame.scrollChild = scrollChild
    frame.scrollbar = scrollbar
    
    -- Initial update
    C_Timer.After(0, UpdateScroll)
    
    return frame
end

return ScrollFrame
