-- ============================================================================
-- MidnightUI Options Panel Framework
-- Custom options UI framework - zero dependency on AceGUI
-- ============================================================================

local MidnightOptionsPanel = {}
_G.MidnightUI_OptionsPanel = MidnightOptionsPanel

local ScrollFrame = _G.MidnightUI_ScrollFrame

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Evaluate a value that can be either a literal or a function
local function EvaluateValue(value, ...)
    if type(value) == "function" then
        return value(...)
    end
    return value
end

-- ============================================================================
-- TREE PARSER - Convert options table to tree structure
-- ============================================================================

-- Parse options table into tree structure for navigation
function MidnightOptionsPanel:ParseOptionsToTree(optionsTable)
    local tree = {}
    
    if not optionsTable or not optionsTable.args then
        return tree
    end
    
    -- Build tree nodes from options table
    for key, option in pairs(optionsTable.args) do
        if option.type == "group" then
            local node = {
                key = key,
                name = EvaluateValue(option.name) or key,
                desc = EvaluateValue(option.desc),
                order = option.order or 100,
                children = {},
                options = option.args or {},
                childGroups = option.childGroups  -- Store childGroups setting
            }
            
            -- Recursively parse child groups ONLY if childGroups != "tab"
            if option.args and option.childGroups ~= "tab" then
                for childKey, childOption in pairs(option.args) do
                    if childOption.type == "group" then
                        local childNode = {
                            key = childKey,
                            name = EvaluateValue(childOption.name) or childKey,
                            desc = EvaluateValue(childOption.desc),
                            order = childOption.order or 100,
                            parent = node,
                            options = childOption.args or {}
                        }
                        table.insert(node.children, childNode)
                    end
                end
                
                -- Sort children by order
                table.sort(node.children, function(a, b)
                    return (a.order or 100) < (b.order or 100)
                end)
            end
            
            table.insert(tree, node)
        end
    end
    
    -- Sort top-level nodes by order
    table.sort(tree, function(a, b)
        return (a.order or 100) < (b.order or 100)
    end)
    
    return tree
end

-- ============================================================================
-- MAIN FRAME CREATION
-- ============================================================================

function MidnightOptionsPanel:CreateFrame(addonRef)
    if self.frame then
        return self.frame
    end
    
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    
    -- Create main frame
    local frame = CreateFrame("Frame", "MidnightUIOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(1100, 800)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    
    -- Apply backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    frame:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
    frame:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Add logo
    frame.logo = frame:CreateTexture(nil, "ARTWORK")
    frame.logo:SetTexture("Interface\\AddOns\\MidnightUI\\Media\\midnightUI_icon.tga")
    frame.logo:SetSize(80, 80)
    frame.logo:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -18)
    
    -- Add title
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
    frame.title:SetText("Midnight UI")
    frame.title:SetTextColor(ColorPalette:GetColor('text-primary'))
    frame.title:SetPoint("LEFT", frame.logo, "RIGHT", 15, 0)
    
    -- Create drag area (top 100px excluding close button)
    frame.dragArea = CreateFrame("Frame", nil, frame)
    frame.dragArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.dragArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -50, 0)
    frame.dragArea:SetHeight(100)
    frame.dragArea:EnableMouse(true)
    frame.dragArea:RegisterForDrag("LeftButton")
    frame.dragArea:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame.dragArea:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    
    -- Create close button
    frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    frame.closeButton:SetSize(32, 32)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)
    
    -- Create tree navigation panel (left side)
    frame.treePanel = self:CreateTreePanel(frame)
    
    -- Create content panel (right side)
    frame.contentPanel = self:CreateContentPanel(frame)
    
    -- Store references
    self.frame = frame
    self.addonRef = addonRef
    
    return frame
end

-- ============================================================================
-- TREE NAVIGATION PANEL
-- ============================================================================

function MidnightOptionsPanel:CreateTreePanel(parent)
    local ColorPalette = _G.MidnightUI_ColorPalette
    
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -106)
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 6, 6)
    panel:SetWidth(250)
    
    -- Apply backdrop
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    panel:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
    panel:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Create custom scrollframe for tree buttons
    panel.scrollFrame = ScrollFrame:Create(panel)
    panel.scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    panel.scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    
    -- Get scroll child
    panel.scrollChild = panel.scrollFrame:GetScrollChild()
    panel.scrollChild:SetWidth(panel.scrollFrame.scrollArea:GetWidth())
    
    -- Store tree buttons
    panel.buttons = {}
    
    return panel
end

-- Build tree buttons from parsed tree structure
function MidnightOptionsPanel:BuildTree(tree)
    local panel = self.frame.treePanel
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    
    -- Clear existing buttons
    for _, btn in ipairs(panel.buttons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    panel.buttons = {}
    
    local yOffset = 0
    local buttonHeight = 24
    local indent = 0
    
    -- Recursive function to create buttons
    local function CreateTreeButton(node, depth)
        local btn = CreateFrame("Button", nil, panel.scrollChild, "BackdropTemplate")
        btn:SetSize(panel.scrollChild:GetWidth() - (depth * 16), buttonHeight)
        btn:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", depth * 16, -yOffset)
        
        -- Create text
        btn.text = btn:CreateFontString(nil, "OVERLAY")
        if FontKit then
            FontKit:SetFont(btn.text, 'body', 'normal')
        end
        btn.text:SetPoint("LEFT", btn, "LEFT", 8, 0)
        btn.text:SetText(node.name)
        btn.text:SetTextColor(ColorPalette:GetColor('text-primary'))
        
        -- Store node reference
        btn.node = node
        
        -- Click handler
        btn:SetScript("OnClick", function(self)
            MidnightOptionsPanel:SelectNode(self.node)
        end)
        
        -- Hover effect
        btn:SetScript("OnEnter", function(self)
            self:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = nil,
                tile = false
            })
            local r, g, b = ColorPalette:GetColor('accent-primary')
            self:SetBackdropColor(r, g, b, 0.15)
        end)
        
        btn:SetScript("OnLeave", function(self)
            if MidnightOptionsPanel.selectedNode ~= self.node then
                self:SetBackdrop(nil)
            end
        end)
        
        table.insert(panel.buttons, btn)
        yOffset = yOffset + buttonHeight
        
        -- Create child buttons if expanded (for now, always expanded in MVP)
        if node.children then
            for _, child in ipairs(node.children) do
                CreateTreeButton(child, depth + 1)
            end
        end
    end
    
    -- Create buttons for all top-level nodes
    for _, node in ipairs(tree) do
        CreateTreeButton(node, 0)
    end
    
    -- Update scroll child height
    panel.scrollChild:SetHeight(math.max(yOffset, panel.scrollFrame:GetHeight()))
    panel.scrollFrame:UpdateScroll()
end

-- Handle node selection
function MidnightOptionsPanel:SelectNode(node)
    local ColorPalette = _G.MidnightUI_ColorPalette
    
    -- Clear previous selection
    if self.selectedNode then
        for _, btn in ipairs(self.frame.treePanel.buttons) do
            if btn.node == self.selectedNode then
                btn:SetBackdrop(nil)
            end
        end
    end
    
    -- Set new selection
    self.selectedNode = node
    
    -- Highlight selected button
    for _, btn in ipairs(self.frame.treePanel.buttons) do
        if btn.node == node then
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = nil,
                tile = false
            })
            local r, g, b = ColorPalette:GetColor('accent-primary')
            btn:SetBackdropColor(r, g, b, 0.3)
        end
    end
    
    -- Render content for selected node
    self:RenderContent(node)
end

-- ============================================================================
-- CONTENT PANEL
-- ============================================================================

function MidnightOptionsPanel:CreateContentPanel(parent)
    local ColorPalette = _G.MidnightUI_ColorPalette
    
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", parent.treePanel, "TOPRIGHT", 6, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -6, 6)
    
    -- Apply backdrop
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    panel:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
    panel:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Create custom scrollframe for content
    panel.scrollFrame = ScrollFrame:Create(panel)
    panel.scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    panel.scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
    
    -- Get scroll child
    panel.scrollChild = panel.scrollFrame:GetScrollChild()
    panel.scrollChild:SetWidth(panel.scrollFrame.scrollArea:GetWidth())
    
    -- Store for widgets
    panel.widgets = {}
    
    return panel
end

-- Render content for selected node
function MidnightOptionsPanel:RenderContent(node)
    local panel = self.frame.contentPanel
    
    -- Clear existing widgets
    for _, widget in ipairs(panel.widgets) do
        widget:Hide()
        widget:SetParent(nil)
    end
    panel.widgets = {}
    
    -- Clear existing tabs
    if panel.tabs then
        for _, tab in ipairs(panel.tabs) do
            tab:Hide()
            tab:SetParent(nil)
        end
        panel.tabs = nil
        panel.activeTab = nil
    end
    
    if not node or not node.options then
        return
    end
    
    -- Check if this node uses tabs for child groups
    if node.childGroups == "tab" then
        self:RenderTabGroup(node)
        return
    end
    
    -- Sort options by order
    local sortedOptions = {}
    for key, option in pairs(node.options) do
        option.key = key
        table.insert(sortedOptions, option)
    end
    table.sort(sortedOptions, function(a, b)
        return (a.order or 100) < (b.order or 100)
    end)
    
    -- Render widgets with inline layout support
    local xOffset = 0
    local yOffset = 0
    local rowHeight = 0
    local maxWidth = panel.scrollChild:GetWidth() - 20
    
    for _, option in ipairs(sortedOptions) do
        -- Skip group types (they're in the tree)
        if option.type ~= "group" then
            local isFullWidth = (option.width == "full" or not option.width)
            
            -- Check if we need to wrap to next row
            if isFullWidth and xOffset > 0 then
                -- Move to next row
                yOffset = yOffset + rowHeight + 10
                xOffset = 0
                rowHeight = 0
            end
            
            local widget, height, width = self:CreateWidgetForOption(panel.scrollChild, option, xOffset, yOffset)
            if widget then
                table.insert(panel.widgets, widget)
                rowHeight = math.max(rowHeight, height)
                
                if isFullWidth then
                    -- Full width widget - move to next row
                    yOffset = yOffset + height + 10
                    xOffset = 0
                    rowHeight = 0
                else
                    -- Inline widget - advance horizontally
                    xOffset = xOffset + width + 20
                    
                    -- If we exceed max width, wrap to next row
                    if xOffset >= maxWidth then
                        yOffset = yOffset + rowHeight + 10
                        xOffset = 0
                        rowHeight = 0
                    end
                end
            end
        end
    end
    
    -- Add final row height
    if rowHeight > 0 then
        yOffset = yOffset + rowHeight
    end
    
    -- Update scroll child height
    panel.scrollChild:SetHeight(math.max(yOffset + 20, panel.scrollFrame:GetHeight()))
    panel.scrollFrame:UpdateScroll()
end

-- Render a group with tabs for child groups
function MidnightOptionsPanel:RenderTabGroup(node)
    local panel = self.frame.contentPanel
    local ColorPalette = _G.MidnightUI_ColorPalette
    
    -- Build sorted list of child groups
    local childGroups = {}
    for key, option in pairs(node.options) do
        if option.type == "group" then
            option.key = key
            table.insert(childGroups, option)
        end
    end
    table.sort(childGroups, function(a, b)
        return (a.order or 100) < (b.order or 100)
    end)
    
    if #childGroups == 0 then
        return -- No child groups to render as tabs
    end
    
    -- Create tab buttons
    panel.tabs = {}
    panel.activeTab = nil
    local xOffset = 10
    
    for i, childGroup in ipairs(childGroups) do
        local tabButton = CreateFrame("Button", nil, panel, "BackdropTemplate")
        
        -- Create tab text first to measure width
        local tabText = tabButton:CreateFontString(nil, "OVERLAY")
        tabText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
        tabText:SetText(EvaluateValue(childGroup.name) or childGroup.key)
        tabText:SetPoint("CENTER")
        
        -- Calculate tab width based on text width + padding
        local textWidth = tabText:GetStringWidth()
        local tabWidth = math.max(textWidth + 30, 80) -- Min 80px, 15px padding each side
        
        tabButton:SetSize(tabWidth, 32)
        tabButton:SetPoint("TOPLEFT", panel, "TOPLEFT", xOffset, -10)
        tabButton:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        
        tabButton.childGroup = childGroup
        tabButton.text = tabText
        tabButton.index = i
        
        tabButton:SetScript("OnClick", function(self)
            MidnightOptionsPanel:SelectTab(self.index)
        end)
        
        table.insert(panel.tabs, tabButton)
        xOffset = xOffset + tabWidth + 5
    end
    
    -- Select first tab by default
    self:SelectTab(1)
end

-- Select and render a specific tab
function MidnightOptionsPanel:SelectTab(tabIndex)
    local panel = self.frame.contentPanel
    local ColorPalette = _G.MidnightUI_ColorPalette
    
    if not panel.tabs or not panel.tabs[tabIndex] then
        return
    end
    
    -- Update tab appearance
    for i, tab in ipairs(panel.tabs) do
        if i == tabIndex then
            tab:SetBackdropColor(ColorPalette:GetColor('tab-active'))
            tab:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
            tab.text:SetTextColor(ColorPalette:GetColor('text-primary'))
        else
            tab:SetBackdropColor(ColorPalette:GetColor('button-bg'))
            tab:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
            tab.text:SetTextColor(ColorPalette:GetColor('text-secondary'))
        end
    end
    
    panel.activeTab = tabIndex
    
    -- Clear existing widgets
    for _, widget in ipairs(panel.widgets) do
        widget:Hide()
        widget:SetParent(nil)
    end
    panel.widgets = {}
    
    -- Render the selected tab's content
    local selectedTab = panel.tabs[tabIndex]
    local childGroup = selectedTab.childGroup
    
    -- Sort child group's options
    local sortedOptions = {}
    for key, option in pairs(childGroup.args or {}) do
        option.key = key
        table.insert(sortedOptions, option)
    end
    table.sort(sortedOptions, function(a, b)
        return (a.order or 100) < (b.order or 100)
    end)
    
    -- Render widgets (starting below tabs) with inline layout support
    local xOffset = 0
    local yOffset = 50 -- Space for tabs
    local rowHeight = 0
    local maxWidth = panel.scrollChild:GetWidth() - 20
    
    for _, option in ipairs(sortedOptions) do
        -- Skip group types
        if option.type ~= "group" then
            local isFullWidth = (option.width == "full" or not option.width)
            
            -- Check if we need to wrap to next row
            if isFullWidth and xOffset > 0 then
                -- Move to next row
                yOffset = yOffset + rowHeight + 10
                xOffset = 0
                rowHeight = 0
            end
            
            local widget, height, width = self:CreateWidgetForOption(panel.scrollChild, option, xOffset, yOffset)
            if widget then
                table.insert(panel.widgets, widget)
                rowHeight = math.max(rowHeight, height)
                
                if isFullWidth then
                    -- Full width widget - move to next row
                    yOffset = yOffset + height + 10
                    xOffset = 0
                    rowHeight = 0
                else
                    -- Inline widget - advance horizontally
                    xOffset = xOffset + width + 20
                    
                    -- If we exceed max width, wrap to next row
                    if xOffset >= maxWidth then
                        yOffset = yOffset + rowHeight + 10
                        xOffset = 0
                        rowHeight = 0
                    end
                end
            end
        end
    end
    
    -- Add final row height
    if rowHeight > 0 then
        yOffset = yOffset + rowHeight
    end
    
    -- Update scroll child height
    panel.scrollChild:SetHeight(math.max(yOffset + 20, panel.scrollFrame:GetHeight()))
    panel.scrollFrame:UpdateScroll()
end

-- ============================================================================
-- WIDGET CREATION
-- ============================================================================

function MidnightOptionsPanel:CreateWidgetForOption(parent, option, xOffset, yOffset)
    -- Dispatch to specific widget creator based on type
    if option.type == "header" then
        return self:CreateHeader(parent, option, xOffset, yOffset)
    elseif option.type == "description" then
        return self:CreateDescription(parent, option, xOffset, yOffset)
    elseif option.type == "toggle" then
        return self:CreateToggle(parent, option, xOffset, yOffset)
    elseif option.type == "range" then
        return self:CreateRange(parent, option, xOffset, yOffset)
    elseif option.type == "select" then
        return self:CreateSelect(parent, option, xOffset, yOffset)
    elseif option.type == "input" then
        return self:CreateInput(parent, option, xOffset, yOffset)
    elseif option.type == "color" then
        return self:CreateColor(parent, option, xOffset, yOffset)
    elseif option.type == "execute" then
        return self:CreateExecute(parent, option, xOffset, yOffset)
    end
    
    return nil, 0, 0
end

-- Create header widget
function MidnightOptionsPanel:CreateHeader(parent, option, xOffset, yOffset)
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    
    -- Create container frame for header with lines
    local headerFrame = CreateFrame("Frame", nil, parent)
    headerFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -yOffset)
    headerFrame:SetSize(parent:GetWidth() - xOffset, 28)
    
    -- Header text
    local header = headerFrame:CreateFontString(nil, "OVERLAY")
    header:SetPoint("LEFT", headerFrame, "LEFT", 0, 0)
    if FontKit then
        FontKit:SetFont(header, 'heading', 'large')
    else
        header:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    end
    header:SetText(EvaluateValue(option.name) or "")
    header:SetTextColor(ColorPalette:GetColor('accent-primary'))
    
    -- Horizontal line to the right of text
    local line = headerFrame:CreateTexture(nil, "BACKGROUND")
    line:SetHeight(2)
    line:SetPoint("LEFT", header, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", headerFrame, "RIGHT", -3, 0)
    local r, g, b = ColorPalette:GetColor('accent-primary')
    line:SetColorTexture(r, g, b, 0.5)
    
    return headerFrame, 32, parent:GetWidth()
end

-- Create description widget
function MidnightOptionsPanel:CreateDescription(parent, option, xOffset, yOffset)
    local ColorPalette = _G.MidnightUI_ColorPalette
    
    local desc = parent:CreateFontString(nil, "OVERLAY")
    desc:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -yOffset)
    desc:SetPoint("RIGHT", parent, "RIGHT", -20, 0)
    desc:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    desc:SetText(EvaluateValue(option.name) or "")
    desc:SetTextColor(ColorPalette:GetColor('text-primary'))
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    
    -- Calculate actual height of wrapped text
    local stringHeight = desc:GetStringHeight()
    local height = math.max(stringHeight + 10, 20)  -- Add some padding, minimum 20
    
    return desc, height
end

-- ============================================================================
-- TOGGLE (CHECKBOX) WIDGET
-- ============================================================================

function MidnightOptionsPanel:CreateToggle(parent, option, xOffset, yOffset)
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    
    local frameWidth = (option.width == "full" or not option.width) and parent:GetWidth() or 220
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -yOffset)
    frame:SetSize(frameWidth, 30)
    
    -- Create toggle slider background
    local toggleBg = frame:CreateTexture(nil, "BACKGROUND")
    toggleBg:SetSize(40, 20)
    toggleBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    toggleBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    
    -- Create border
    local toggleBorder = frame:CreateTexture(nil, "BORDER")
    toggleBorder:SetSize(42, 22)
    toggleBorder:SetPoint("CENTER", toggleBg, "CENTER")
    toggleBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    toggleBorder:SetVertexColor(ColorPalette:GetColor('panel-border'))
    
    -- Create slider knob
    local toggleKnob = frame:CreateTexture(nil, "OVERLAY")
    toggleKnob:SetSize(16, 16)
    toggleKnob:SetTexture("Interface\\Buttons\\WHITE8X8")
    toggleKnob:SetVertexColor(ColorPalette:GetColor('text-primary'))
    
    -- Create label
    local label = frame:CreateFontString(nil, "OVERLAY")
    if FontKit then
        FontKit:SetFont(label, 'body', 'normal')
    end
    label:SetPoint("LEFT", frame, "LEFT", 50, 0)
    label:SetText(EvaluateValue(option.name) or "")
    label:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    -- Make clickable
    local button = CreateFrame("Button", nil, frame)
    button:SetAllPoints(frame)
    
    -- Get/Set value function
    local function GetValue()
        if option.get then
            return option.get(self.addonRef.db.profile)
        end
        return false
    end
    
    local function SetValue(value)
        if option.set then
            option.set(self.addonRef.db.profile, value)
        end
        
        -- Update visual
        UpdateVisual(value)
    end
    
    local function UpdateVisual(value)
        if value then
            -- ON state: accent color with knob on right
            toggleKnob:SetPoint("CENTER", toggleBg, "RIGHT", -10, 0)
            toggleBg:SetVertexColor(ColorPalette:GetColor('accent-primary'))
            toggleBorder:SetVertexColor(ColorPalette:GetColor('panel-border'))
        else
            -- OFF state: dark background from theme with knob on left
            toggleKnob:SetPoint("CENTER", toggleBg, "LEFT", 10, 0)
            toggleBg:SetVertexColor(ColorPalette:GetColor('toggle-off-bg'))
            toggleBorder:SetVertexColor(ColorPalette:GetColor('toggle-off-border'))
        end
    end
    
    -- Click handler
    button:SetScript("OnClick", function()
        local currentValue = GetValue()
        SetValue(not currentValue)
    end)
    
    -- Set initial state (visual only, don't call set function)
    UpdateVisual(GetValue())
    
    return frame, 30, frameWidth
end

-- ============================================================================
-- RANGE (SLIDER) WIDGET
-- ============================================================================

function MidnightOptionsPanel:CreateRange(parent, option, xOffset, yOffset)
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    
    local frameWidth = (option.width == "full" or not option.width) and parent:GetWidth() or 220
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -yOffset)
    frame:SetSize(frameWidth, 70)
    
    -- Create label
    local label = frame:CreateFontString(nil, "OVERLAY")
    if FontKit then
        FontKit:SetFont(label, 'body', 'normal')
    end
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    label:SetText(EvaluateValue(option.name) or "")
    label:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    -- Create slider
    local slider = CreateFrame("Slider", nil, frame, "BackdropTemplate")
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -10)
    slider:SetSize(150, 4)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(option.min or 0, option.max or 100)
    slider:SetValueStep(option.step or 1)
    slider:SetObeyStepOnDrag(true)
    
    -- Style slider track
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    local r, g, b = ColorPalette:GetColor('accent-primary')
    slider:SetBackdropColor(r, g, b, 0.5)
    slider:SetBackdropBorderColor(r, g, b, 1)
    
    -- Style thumb
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = slider:GetThumbTexture()
    thumb:SetVertexColor(ColorPalette:GetColor('text-primary'))
    thumb:SetSize(6, 10)
    
    -- Create value display
    local valueText = frame:CreateFontString(nil, "OVERLAY")
    if FontKit then
        FontKit:SetFont(valueText, 'body', 'normal')
    end
    valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    valueText:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    -- Get/Set value functions
    local function GetValue()
        if option.get then
            return option.get(self.addonRef.db.profile)
        end
        return option.min or 0
    end
    
    local function UpdateVisual(value)
        slider:SetValue(value)
        valueText:SetText(tostring(value))
    end
    
    local function SetValue(value)
        if option.set then
            option.set(self.addonRef.db.profile, value)
        end
        UpdateVisual(value)
    end
    
    -- Slider change handler
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5) -- Round to nearest
        SetValue(value)
    end)
    
    -- Set initial value (visual only)
    UpdateVisual(GetValue())
    
    return frame, 70, frameWidth
end

-- ============================================================================
-- SELECT (DROPDOWN) WIDGET
-- ============================================================================

function MidnightOptionsPanel:CreateSelect(parent, option, xOffset, yOffset)
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    
    local frameWidth = (option.width == "full" or not option.width) and parent:GetWidth() or 220
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -yOffset)
    frame:SetSize(frameWidth, 50)
    
    -- Create label
    local label = frame:CreateFontString(nil, "OVERLAY")
    if FontKit then
        FontKit:SetFont(label, 'body', 'normal')
    end
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    label:SetText(EvaluateValue(option.name) or "")
    label:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    -- Create dropdown button
    local dropdown = CreateFrame("Button", nil, frame, "BackdropTemplate")
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    dropdown:SetSize(200, 24)
    
    -- Style dropdown
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    dropdown:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    dropdown:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Dropdown text
    dropdown.text = dropdown:CreateFontString(nil, "OVERLAY")
    if FontKit then
        FontKit:SetFont(dropdown.text, 'body', 'normal')
    end
    dropdown.text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    dropdown.text:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    -- Dropdown arrow
    dropdown.arrow = dropdown:CreateTexture(nil, "OVERLAY")
    dropdown.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    dropdown.arrow:SetTexCoord(0, 1, 0, 0.5)
    dropdown.arrow:SetSize(12, 12)
    dropdown.arrow:SetPoint("RIGHT", dropdown, "RIGHT", -6, 0)
    local r, g, b = ColorPalette:GetColor('accent-primary')
    dropdown.arrow:SetVertexColor(r, g, b, 1)
    
    -- Get/Set value functions
    local function GetValue()
        if option.get then
            return option.get(self.addonRef.db.profile)
        end
        return nil
    end
    
    local function UpdateVisual(value)
        -- Update display text
        local values = EvaluateValue(option.values)
        if values then
            dropdown.text:SetText(values[value] or tostring(value))
        else
            dropdown.text:SetText(tostring(value))
        end
    end
    
    local function SetValue(value)
        if option.set then
            option.set(self.addonRef.db.profile, value)
        end
        UpdateVisual(value)
    end
    
    -- Create simple dropdown menu on click
    dropdown:SetScript("OnClick", function(self)
        local values = EvaluateValue(option.values)
        if not values then return end
        
        -- Create menu
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetFrameStrata("DIALOG")
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        -- Force solid background for dropdown menu readability
        local r, g, b, a = ColorPalette:GetColor('panel-bg')
        menu:SetBackdropColor(r, g, b, 1.0)  -- Always use alpha=1.0
        menu:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
        
        -- Calculate menu size
        local itemHeight = 20
        local numItems = 0
        for _ in pairs(values) do numItems = numItems + 1 end
        menu:SetSize(200, numItems * itemHeight + 4)
        
        -- Create menu items
        local y = -2
        for key, text in pairs(values) do
            local item = CreateFrame("Button", nil, menu, BackdropTemplateMixin and "BackdropTemplate")
            item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, y)
            item:SetSize(196, itemHeight)
            
            item.text = item:CreateFontString(nil, "OVERLAY")
            if FontKit then
                FontKit:SetFont(item.text, 'body', 'normal')
            end
            item.text:SetPoint("LEFT", item, "LEFT", 6, 0)
            item.text:SetText(text)
            item.text:SetTextColor(ColorPalette:GetColor('text-primary'))
            
            -- Highlight on hover
            item:SetScript("OnEnter", function()
                item:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
                local r, g, b = ColorPalette:GetColor('accent-primary')
                item:SetBackdropColor(r, g, b, 0.15)
            end)
            item:SetScript("OnLeave", function()
                item:SetBackdrop(nil)
            end)
            
            -- Click handler
            item:SetScript("OnClick", function()
                SetValue(key)
                menu:Hide()
            end)
            
            y = y - itemHeight
        end
        
        -- Close menu when clicking outside
        menu:SetScript("OnHide", function() menu:SetParent(nil) end)
        C_Timer.After(0.1, function()
            menu:SetScript("OnUpdate", function(self)
                if not MouseIsOver(self) and not MouseIsOver(dropdown) then
                    self:Hide()
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end)
    end)
    
    -- Set initial value (visual only)
    UpdateVisual(GetValue())
    
    return frame, 50, frameWidth
end

-- ============================================================================
-- INPUT (TEXT BOX) WIDGET
-- ============================================================================

function MidnightOptionsPanel:CreateInput(parent, option, xOffset, yOffset)
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    
    local frameWidth = (option.width == "full" or not option.width) and parent:GetWidth() or 220
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -yOffset)
    
    local isMultiline = option.multiline
    local frameHeight = isMultiline and 100 or 50
    frame:SetSize(frameWidth, frameHeight)
    
    -- Create label
    local label = frame:CreateFontString(nil, "OVERLAY")
    if FontKit then
        FontKit:SetFont(label, 'body', 'normal')
    end
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    label:SetText(EvaluateValue(option.name) or "")
    label:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    -- Create edit box
    local editBox
    if isMultiline then
        local scroll = ScrollFrame:Create(frame)
        scroll:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
        scroll:SetSize(frameWidth - 20, 60)
        
        editBox = CreateFrame("EditBox", nil, scroll.scrollArea)
        editBox:SetMultiLine(true)
        editBox:SetSize(scroll.scrollArea:GetWidth(), 200)
        editBox:SetAutoFocus(false)
        scroll:SetScrollChild(editBox)
    else
        editBox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
        editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
        editBox:SetSize(frameWidth - 20, 24)
        editBox:SetAutoFocus(false)
        
        -- Style edit box
        editBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 4, right = 4, top = 2, bottom = 2 }
        })
        editBox:SetBackdropColor(ColorPalette:GetColor('button-bg'))
        editBox:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    end
    
    -- Set font
    if FontKit then
        FontKit:SetFont(editBox, 'body', 'normal')
    else
        editBox:SetFont("Fonts\\FRIZQT__.TTF", 12)
    end
    editBox:SetTextColor(ColorPalette:GetColor('text-primary'))
    editBox:SetTextInsets(6, 6, 2, 2)
    
    -- Get/Set value functions
    local function GetValue()
        if option.get then
            return option.get(self.addonRef.db.profile)
        end
        return ""
    end
    
    local function UpdateVisual(value)
        editBox:SetText(value or "")
    end
    
    local function SetValue(value)
        if option.set then
            option.set(self.addonRef.db.profile, value)
        end
        UpdateVisual(value)
    end
    
    -- Save on focus lost
    editBox:SetScript("OnEditFocusLost", function()
        SetValue(editBox:GetText())
    end)
    
    editBox:SetScript("OnEnterPressed", function()
        editBox:ClearFocus()
    end)
    
    editBox:SetScript("OnEscapePressed", function()
        editBox:ClearFocus()
        UpdateVisual(GetValue()) -- Revert visual only
    end)
    
    -- Set initial value (visual only)
    UpdateVisual(GetValue())
    
    return frame, frameHeight, frameWidth
end

-- ============================================================================
-- COLOR PICKER WIDGET
-- ============================================================================

function MidnightOptionsPanel:CreateColor(parent, option, xOffset, yOffset)
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    
    local frameWidth = (option.width == "full" or not option.width) and parent:GetWidth() or 220
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -yOffset)
    frame:SetSize(frameWidth, 40)
    
    -- Create label
    local label = frame:CreateFontString(nil, "OVERLAY")
    if FontKit then
        FontKit:SetFont(label, 'body', 'normal')
    end
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    label:SetText(EvaluateValue(option.name) or "")
    label:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    -- Create color swatch button
    local swatch = CreateFrame("Button", nil, frame, "BackdropTemplate")
    swatch:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    swatch:SetSize(32, 32)
    
    -- Swatch border
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    swatch:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Swatch color texture
    swatch.texture = swatch:CreateTexture(nil, "BACKGROUND")
    swatch.texture:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
    swatch.texture:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)
    swatch.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    
    -- Get/Set value functions
    local function GetValue()
        if option.get then
            local color = option.get(self.addonRef.db.profile)
            if type(color) == "table" then
                return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
            end
        end
        return 1, 1, 1, 1
    end
    
    local function UpdateVisual(r, g, b, a)
        swatch.texture:SetVertexColor(r, g, b, a or 1)
    end
    
    local function SetValue(r, g, b, a)
        if option.set then
            option.set(self.addonRef.db.profile, {r, g, b, a or 1})
        end
        UpdateVisual(r, g, b, a)
    end
    
    -- Open color picker on click
    swatch:SetScript("OnClick", function()
        local r, g, b, a = GetValue()
        
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            opacity = a,
            hasOpacity = option.hasAlpha,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                SetValue(r, g, b, a)
            end,
            opacityFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                SetValue(r, g, b, a)
            end,
            cancelFunc = function()
                UpdateVisual(r, g, b, a)
            end,
        })
    end)
    
    -- Set initial color (visual only)
    UpdateVisual(GetValue())
    
    return frame, 40, frameWidth
end

-- ============================================================================
-- EXECUTE (BUTTON) WIDGET
-- ============================================================================

function MidnightOptionsPanel:CreateExecute(parent, option, xOffset, yOffset)
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    
    local frameWidth = (option.width == "full" or not option.width) and parent:GetWidth() or 220
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -yOffset)
    frame:SetSize(frameWidth, 40)
    
    -- Create button
    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    button:SetSize(150, 28)
    
    -- Style button
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    button:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    button:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
    
    -- Button text
    button.text = button:CreateFontString(nil, "OVERLAY")
    if FontKit then
        FontKit:SetFont(button.text, 'button', 'normal')
    end
    button.text:SetPoint("CENTER")
    button.text:SetText(EvaluateValue(option.name) or "")
    button.text:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    -- Hover effect
    button:SetScript("OnEnter", function(self)
        local r, g, b = ColorPalette:GetColor('button-bg')
        self:SetBackdropColor(r * 1.3, g * 1.3, b * 1.3, 1)
    end)
    
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    end)
    
    -- Click handler
    button:SetScript("OnClick", function()
        if option.func then
            -- Check for confirmation dialog
            local confirmText = EvaluateValue(option.confirm)
            if confirmText then
                StaticPopupDialogs["MIDNIGHTUI_OPTIONS_CONFIRM"] = {
                    text = confirmText,
                    button1 = "Yes",
                    button2 = "No",
                    OnAccept = function()
                        option.func()
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                }
                StaticPopup_Show("MIDNIGHTUI_OPTIONS_CONFIRM")
            else
                option.func()
            end
        end
    end)
    
    return frame, 40, frameWidth
end

-- ============================================================================
-- OPEN/CLOSE FUNCTIONS
-- ============================================================================

function MidnightOptionsPanel:Open(addonRef)
    -- Store addon reference
    self.addonRef = addonRef
    
    -- Create frame if needed
    if not self.frame then
        self:CreateFrame(addonRef)
    end
    
    -- Get and parse options table
    local success, optionsTable = pcall(function() return addonRef:GetOptions() end)
    if not success then
        print("|cffff0000[MidnightUI]|r Error getting options:", optionsTable)
        return
    end
    
    if not optionsTable or not optionsTable.args then
        print("|cffff0000[MidnightUI]|r No options available")
        return
    end
    
    local tree = self:ParseOptionsToTree(optionsTable)
    
    if not tree or #tree == 0 then
        print("|cffff0000[MidnightUI]|r No options tree generated")
        return
    end
    
    -- Build tree navigation
    self:BuildTree(tree)
    
    -- Select first node by default
    if tree[1] then
        self:SelectNode(tree[1])
    end
    
    self.frame:Show()
end

function MidnightOptionsPanel:Close()
    if self.frame then
        self.frame:Hide()
    end
end

function MidnightOptionsPanel:Toggle(addonRef)
    if self.frame and self.frame:IsShown() then
        self:Close()
    else
        self:Open(addonRef)
    end
end

return MidnightOptionsPanel
