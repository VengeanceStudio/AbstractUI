local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local Movable = MidnightUI:NewModule("Movable", "AceEvent-3.0")

-- ============================================================================
-- MOVABLE FRAME SYSTEM
-- Centralized drag and nudge functionality for all MidnightUI modules
-- ============================================================================

-- Store registered movable frames with their highlight overlays
Movable.registeredFrames = {}
Movable.registeredNudgeFrames = {}

-- Store Blizzard frames that have been made movable
Movable.blizzardFrames = {}

-- Grid settings
local GRID_SIZE = 16
local gridFrame = nil

-- ============================================================================
-- SNAP TO GRID HELPER
-- ============================================================================

function Movable:SnapToGrid(value)
    return math.floor(value / GRID_SIZE + 0.5) * GRID_SIZE
end

-- ============================================================================
-- ALIGNMENT GRID OVERLAY
-- ============================================================================

function Movable:CreateGrid()
    if gridFrame then return gridFrame end
    
    gridFrame = CreateFrame("Frame", "MidnightUI_GridOverlay", UIParent)
    gridFrame:SetAllPoints(UIParent)
    gridFrame:SetFrameStrata("BACKGROUND")
    gridFrame:SetFrameLevel(0)
    gridFrame:Hide()
    
    -- Create vertical and horizontal lines
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    
    gridFrame.lines = {}
    

    -- Draw gray grid lines (every 16 pixels) from center out
    local centerX = math.floor(screenWidth / 2)
    local centerY = math.floor(screenHeight / 2)
    for offset = GRID_SIZE, math.max(centerX, screenWidth - centerX), GRID_SIZE do
        -- Vertical lines right of center
        local xR = centerX + offset
        if xR < screenWidth and (xR % 80) ~= 0 then
            local line = gridFrame:CreateTexture(nil, "BACKGROUND")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(0.4, 0.4, 0.4, 0.5)
            line:SetWidth(1)
            line:SetHeight(screenHeight)
            line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", xR, 0)
            table.insert(gridFrame.lines, line)
        end
        -- Vertical lines left of center
        local xL = centerX - offset
        if xL > 0 and (xL % 80) ~= 0 then
            local line = gridFrame:CreateTexture(nil, "BACKGROUND")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(0.4, 0.4, 0.4, 0.5)
            line:SetWidth(1)
            line:SetHeight(screenHeight)
            line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", xL, 0)
            table.insert(gridFrame.lines, line)
        end
    end
    for offset = GRID_SIZE, math.max(centerY, screenHeight - centerY), GRID_SIZE do
        -- Horizontal lines below center
        local yB = centerY + offset
        if yB < screenHeight and (yB % 80) ~= 0 then
            local line = gridFrame:CreateTexture(nil, "BACKGROUND")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(0.4, 0.4, 0.4, 0.5)
            line:SetWidth(screenWidth)
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", 0, -yB)
            table.insert(gridFrame.lines, line)
        end
        -- Horizontal lines above center
        local yT = centerY - offset
        if yT > 0 and (yT % 80) ~= 0 then
            local line = gridFrame:CreateTexture(nil, "BACKGROUND")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(0.4, 0.4, 0.4, 0.5)
            line:SetWidth(screenWidth)
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", 0, -yT)
            table.insert(gridFrame.lines, line)
        end
    end

    -- Draw perfect vertical and horizontal center lines (bright green)
    local centerX = math.floor(screenWidth / 2)
    local centerY = math.floor(screenHeight / 2)
    local vCenter = gridFrame:CreateTexture(nil, "OVERLAY")
    vCenter:SetTexture("Interface\\Buttons\\WHITE8X8")
    vCenter:SetVertexColor(0, 1, 0, 1)
    vCenter:SetWidth(2)
    vCenter:SetHeight(screenHeight)
    vCenter:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", centerX, 0)
    table.insert(gridFrame.lines, vCenter)

    local hCenter = gridFrame:CreateTexture(nil, "OVERLAY")
    hCenter:SetTexture("Interface\\Buttons\\WHITE8X8")
    hCenter:SetVertexColor(0, 1, 0, 1)
    hCenter:SetWidth(screenWidth)
    hCenter:SetHeight(2)
    hCenter:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", 0, -centerY)
    table.insert(gridFrame.lines, hCenter)

    -- Now draw green emphasis lines every 80 pixels (excluding center lines), from center out
    for offset = 80, math.max(centerX, screenWidth - centerX), 80 do
        -- Vertical green lines right of center
        local xR = centerX + offset
        if xR < screenWidth then
            local line = gridFrame:CreateTexture(nil, "OVERLAY")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(0, 0.6, 0, 0.8)
            line:SetWidth(2)
            line:SetHeight(screenHeight)
            line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", xR, 0)
            table.insert(gridFrame.lines, line)
        end
        -- Vertical green lines left of center
        local xL = centerX - offset
        if xL > 0 then
            local line = gridFrame:CreateTexture(nil, "OVERLAY")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(0, 0.6, 0, 0.8)
            line:SetWidth(2)
            line:SetHeight(screenHeight)
            line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", xL, 0)
            table.insert(gridFrame.lines, line)
        end
    end
    for offset = 80, math.max(centerY, screenHeight - centerY), 80 do
        -- Horizontal green lines below center
        local yB = centerY + offset
        if yB < screenHeight then
            local line = gridFrame:CreateTexture(nil, "OVERLAY")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(0, 0.6, 0, 0.8)
            line:SetWidth(screenWidth)
            line:SetHeight(2)
            line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", 0, -yB)
            table.insert(gridFrame.lines, line)
        end
        -- Horizontal green lines above center
        local yT = centerY - offset
        if yT > 0 then
            local line = gridFrame:CreateTexture(nil, "OVERLAY")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(0, 0.6, 0, 0.8)
            line:SetWidth(screenWidth)
            line:SetHeight(2)
            line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", 0, -yT)
            table.insert(gridFrame.lines, line)
        end
    end
    
    return gridFrame
end

function Movable:ShowGrid()
    if not gridFrame then
        self:CreateGrid()
    end
    gridFrame:Show()
    
    -- Hide Blizzard's Edit Mode grid if it exists
    if EditModeManagerFrame and EditModeManagerFrame.Grid then
        EditModeManagerFrame.Grid:Hide()
    end
end

function Movable:HideGrid()
    if gridFrame then
        gridFrame:Hide()
    end
    
    -- Restore Blizzard's Edit Mode grid if it was showing
    if EditModeManagerFrame and EditModeManagerFrame.Grid then
        if EditModeManagerFrame.ShouldShowGridLayout and EditModeManagerFrame:ShouldShowGridLayout() then
            EditModeManagerFrame.Grid:Show()
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function Movable:OnInitialize()
    -- Initialize database namespace for saving Blizzard frame positions
    self.db = MidnightUI.db:RegisterNamespace("Movable", {
        profile = {
            blizzardFramePositions = {},
            enableBlizzardFrameMovement = true,
        }
    })
    
    if MidnightUI and MidnightUI.RegisterMessage then
        MidnightUI:RegisterMessage("MIDNIGHTUI_MOVEMODE_CHANGED", function(_, enabled)
            Movable:OnMoveModeChanged("MIDNIGHTUI_MOVEMODE_CHANGED", enabled)
        end)
    end
end

function Movable:OnEnable()
    -- Initialize Blizzard frame movement
    if self.db and self.db.profile.enableBlizzardFrameMovement then
        C_Timer.After(1, function()
            self:InitializeBlizzardFrames()
        end)
    end
    
    -- Listen for move mode changes (grid only)
    Movable:RegisterMessage("MIDNIGHTUI_MOVEMODE_CHANGED", function(event, enabled)
        if enabled then
            if not gridFrame then
                Movable:CreateGrid()
            end
            gridFrame:Show()
        else
            if gridFrame then
                gridFrame:Hide()
            end
        end
    end)
    -- Also register OnMoveModeChanged for safety
    Movable:RegisterMessage("MIDNIGHTUI_MOVEMODE_CHANGED", "OnMoveModeChanged")
end

function Movable:OnMoveModeChanged(event, enabled)
        for i, frame in ipairs(self.registeredFrames or {}) do end
    -- Debug output removed; highlight logic confirmed working
    if enabled then
        self:ShowGrid()
        -- Show green highlight overlay and fade frames in Move Mode
        for i, frame in ipairs(self.registeredFrames) do
            -- Force highlight and fade for player frame for direct test
            if frame:GetName() and frame:GetName():find("MidnightUI_PlayerFrame") then
                if frame.movableHighlightFrame then frame.movableHighlightFrame:Show() end
                if frame.movableHighlight then frame.movableHighlight:Show() end
                if frame.movableHighlightLabel then frame.movableHighlightLabel:Show() end
                if frame.movableHighlightBorder then frame.movableHighlightBorder:Show() end
                if frame.SetAlpha then frame:SetAlpha(0.3) end
            else
                -- Normal logic for other frames
                if frame.movableHighlight then frame.movableHighlight:Show() end
                if frame.movableHighlightLabel then 
                    -- Hide label for button bar (it has the MB label)
                    if frame:GetName() ~= "MidnightUI_MinimapButtonBar" then
                        frame.movableHighlightLabel:Show()
                    end
                end
                if frame.movableHighlightBorder then frame.movableHighlightBorder:Show() end
                if frame.movableHighlightFrame then frame.movableHighlightFrame:Show() end
                -- Change buttonBar color to green in move mode
                if frame:GetName() == "MidnightUI_MinimapButtonBar" and frame.buttonBarTab and frame.buttonBarTab.bar then 
                    frame.buttonBarTab.bar:SetVertexColor(0, 1, 0, 1)
                end
                -- Show buttonBar backdrop in move mode
                if frame:GetName() and frame:GetName() == "MidnightUI_MinimapButtonBar" then
                    frame:SetBackdropColor(0, 0, 0, 0.8)
                    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                end
                if frame:GetName() and (frame:GetName():find("MidnightUI_TargetFrame") or frame:GetName():find("MidnightUI_TargetTargetFrame") or frame:GetName():find("MidnightUI_FocusFrame")) then
                    if frame.SetAlpha then frame:SetAlpha(0.3) end
                end
                -- For unit frame highlight overlays, also fade the parent frame
                if frame.parentFrame and frame.parentFrame.SetAlpha then
                    frame.parentFrame:SetAlpha(0.3)
                end
            end
            
            -- Update container arrows if this frame has them
            if frame.arrows then
                self:UpdateNudgeArrows(frame)
            end
        end
    else
        self:HideGrid()
        -- Hide green highlight overlay and restore frame opacity
        for i, frame in ipairs(self.registeredFrames) do
            -- Hide both highlight fill and border if present
            if frame.movableHighlight then frame.movableHighlight:Hide() end
            if frame.movableHighlightLabel then frame.movableHighlightLabel:Hide() end
            if frame.movableHighlightBorder then frame.movableHighlightBorder:Hide() end
            if frame.movableHighlightFrame then frame.movableHighlightFrame:Hide() end
            -- Restore buttonBar color when move mode disabled
            if frame:GetName() == "MidnightUI_MinimapButtonBar" and frame.buttonBarTab and frame.buttonBarTab.bar then
                -- Restore to user's selected color
                local Maps = MidnightUI:GetModule("Maps", true)
                if Maps then
                    Maps:UpdateButtonBarColor()
                end
            end
            -- Hide buttonBar backdrop when move mode disabled
            if frame:GetName() and frame:GetName() == "MidnightUI_MinimapButtonBar" then
                frame:SetBackdropColor(0, 0, 0, 0)
                frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0)
            end
            -- Restore full opacity
            if frame:GetName() and (frame:GetName():find("MidnightUI_PlayerFrame") or frame:GetName():find("MidnightUI_TargetFrame") or frame:GetName():find("MidnightUI_TargetTargetFrame") or frame:GetName():find("MidnightUI_FocusFrame")) then
                if frame.SetAlpha then frame:SetAlpha(1) end
            end
            -- For unit frame highlight overlays, also restore parent frame opacity
            if frame.parentFrame and frame.parentFrame.SetAlpha then
                frame.parentFrame:SetAlpha(1)
            end
            
            -- Hide container arrows if this frame has them
            if frame.arrows then
                self:HideNudgeArrows(frame)
            end
        end
    end
end

-- ============================================================================
-- 1. DRAG FUNCTIONALITY
-- ============================================================================

--[[
    Makes a frame draggable with CTRL+ALT or Move Mode
    Also adds green highlight in Move Mode
    @param frame - The frame to make draggable
    @param saveCallback - Optional function(point, x, y) called when drag stops
    @param unlockCheck - Optional function() that returns true if frame should be movable
]]
function Movable:MakeFrameDraggable(frame, saveCallback, unlockCheck, label)
    if not frame then return end
    
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    
    local isDragging = false
    
    frame:SetScript("OnDragStart", function(self)
        -- Check if unlocked (if unlockCheck provided) OR CTRL+ALT held OR Move Mode active
        local canMove = true
        if unlockCheck then
            canMove = unlockCheck() or (IsControlKeyDown() and IsAltKeyDown()) or MidnightUI.moveMode
        else
            canMove = (IsControlKeyDown() and IsAltKeyDown()) or MidnightUI.moveMode
        end
        if canMove then
            isDragging = true
            self:StartMoving()
        end
    end)
    
    frame:SetScript("OnDragStop", function(self)
        if not isDragging then return end
        self:StopMovingOrSizing()
        isDragging = false
        
        if saveCallback then
            local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
            saveCallback(point, xOfs, yOfs)
        end
    end)
    
    -- Right-click to open config (DISABLED)
    --[[ frame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            MidnightUI:OpenConfig()
        end
    end) ]]
    
    -- Create green highlight overlay (hidden by default)
    if not frame.movableHighlight then
        frame.movableHighlight = frame:CreateTexture(nil, "OVERLAY")
        frame.movableHighlight:SetAllPoints()
        frame.movableHighlight:SetColorTexture(0, 1, 0, 0.2)
        frame.movableHighlight:SetDrawLayer("OVERLAY", 7)
        frame.movableHighlight:SetParent(frame)
        frame.movableHighlight:Hide()
    end
    
    -- Create label text for move mode (if provided)
    if label and not frame.movableHighlightLabel then
        frame.movableHighlightLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.movableHighlightLabel:SetPoint("CENTER")
        frame.movableHighlightLabel:SetText(label)
        frame.movableHighlightLabel:SetTextColor(1, 1, 1, 1)
        frame.movableHighlightLabel:Hide()
    end
    
    -- Remove any old registration for this frame
    for i = #self.registeredFrames, 1, -1 do
        if self.registeredFrames[i] == frame then
            table.remove(self.registeredFrames, i)
        end
    end
    table.insert(self.registeredFrames, frame)
    -- ...existing code...
end

-- ============================================================================
-- 2. NUDGE CONTROLS (Arrow Buttons)

--[[
    Registers a nudge frame to respond to Move Mode changes
    @param nudgeFrame - The nudge control frame
    @param parentFrame - The parent frame (for hover detection)
]]
function Movable:RegisterNudgeFrame(nudgeFrame, parentFrame)
    if not nudgeFrame or not parentFrame then return end
    table.insert(self.registeredNudgeFrames, {
        nudge = nudgeFrame,
        parent = parentFrame
    })
end
-- ============================================================================

--[[
    Creates a nudge control frame with arrow buttons
    @param parentFrame - The frame to attach nudge controls to
    @param db - Database table containing offsetX and offsetY
    @param applyCallback - Function() called when offset changes
    @param updateCallback - Optional function() called after nudge display updates
    @param titleText - Optional string to use as the title (defaults to "Move Frame")
    @return nudgeFrame - The created control frame
]]
function Movable:CreateNudgeControls(parentFrame, db, applyCallback, updateCallback, titleText)
    if not parentFrame or not db or not applyCallback then return end
    
    -- Create main nudge frame
    local nudge = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    nudge:SetSize(140, 140)
    nudge:SetFrameStrata("DIALOG")
    nudge:SetFrameLevel(1000)
    nudge:EnableMouse(true)
    nudge:SetMovable(true)
    nudge:RegisterForDrag("LeftButton")
    nudge:SetClampedToScreen(true)
    nudge:Hide()
    
    nudge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    nudge:SetBackdropColor(0, 0, 0, 0.5)
    nudge:SetBackdropBorderColor(0, 1, 0, 1)
    
    -- Make the nudge frame itself draggable
    nudge:SetScript("OnDragStart", function(self) self:StartMoving() end)
    nudge:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Title
    local title = nudge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -12)
    title:SetText(titleText or "Move Frame")
    title:SetTextColor(0, 1, 0)
    nudge.title = title
    
    -- Current offset display
    local offsetText = nudge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    offsetText:SetPoint("CENTER", 0, 0)
    offsetText:SetTextColor(1, 1, 1)
    nudge.offsetText = offsetText
    
    -- Create arrow buttons
    local function CreateArrow(direction, point, x, y)
        local btn = CreateFrame("Button", nil, nudge, "BackdropTemplate")
        btn:SetSize(24, 24)
        btn:SetPoint(point, nudge, point, x, y)
        
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        btn:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
        btn:SetBackdropBorderColor(0, 1, 0, 1)
        
        -- Arrow text using simple ASCII characters
        local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        arrow:SetPoint("CENTER")
        
        if direction == "UP" then arrow:SetText("^")
        elseif direction == "DOWN" then arrow:SetText("v")
        elseif direction == "LEFT" then arrow:SetText("<")
        elseif direction == "RIGHT" then arrow:SetText(">")
        end
        
        arrow:SetTextColor(0, 1, 0, 1)
        
        -- Button hover
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.3, 0.3, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Nudge "..direction)
            GameTooltip:AddLine("|cffaaaaaa(Hold Shift for 10px)|r", 1, 1, 1)
            GameTooltip:Show()
        end)
        
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
            GameTooltip:Hide()
        end)
        
        -- Click handler
        btn:SetScript("OnClick", function()
            local step = IsShiftKeyDown() and 10 or 1
            
            if direction == "UP" then
                db.offsetY = (db.offsetY or 0) + step
            elseif direction == "DOWN" then
                db.offsetY = (db.offsetY or 0) - step
            elseif direction == "LEFT" then
                db.offsetX = (db.offsetX or 0) - step
            elseif direction == "RIGHT" then
                db.offsetX = (db.offsetX or 0) + step
            end
            
            applyCallback()
            Movable:UpdateNudgeDisplay(nudge, db)
            if updateCallback then updateCallback() end
        end)
    end
    
    -- Create 4 arrow buttons
    CreateArrow("UP", "TOP", 0, 10)
    CreateArrow("DOWN", "BOTTOM", 0, -10)
    CreateArrow("LEFT", "LEFT", -10, 0)
    CreateArrow("RIGHT", "RIGHT", 10, 0)
    
    -- Reset button
    local reset = CreateFrame("Button", nil, nudge, "BackdropTemplate")
    reset:SetSize(50, 20)
    reset:SetPoint("BOTTOM", 0, 15)
    reset:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    reset:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
    reset:SetBackdropBorderColor(1, 0, 0, 1)
    
    local resetText = reset:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetText:SetPoint("CENTER")
    resetText:SetText("Reset")
    resetText:SetTextColor(1, 0, 0)
    
    reset:SetScript("OnClick", function()
        db.offsetX = 0
        db.offsetY = 0
        applyCallback()
        Movable:UpdateNudgeDisplay(nudge, db)
        if updateCallback then updateCallback() end
    end)
    
    reset:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.2, 0.2, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Reset to Center")
        GameTooltip:Show()
    end)
    
    reset:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
        GameTooltip:Hide()
    end)
    
    -- Store reference to parent and callbacks
    nudge.parentFrame = parentFrame
    nudge.db = db
    nudge.applyCallback = applyCallback
    
    -- Initial display update
    self:UpdateNudgeDisplay(nudge, db)
    
    -- Setup mouseover behavior for parent frame
    if parentFrame and not parentFrame.movableNudgeHooked then
        parentFrame:HookScript("OnEnter", function()
            if MidnightUI.moveMode and nudge then
                -- Cancel any pending hide timer
                if nudge.hideTimer then
                    nudge.hideTimer:Cancel()
                    nudge.hideTimer = nil
                end
                Movable:ShowNudgeControls(nudge, parentFrame)
            end
        end)
        
        parentFrame:HookScript("OnLeave", function()
            if nudge and not nudge.disableAutoHide then
                -- Delay hiding to allow mouse to move to nudge buttons
                nudge.hideTimer = C_Timer.NewTimer(0.3, function()
                    if nudge and not MouseIsOver(parentFrame) and not MouseIsOver(nudge) then
                        nudge:Hide()
                    end
                    nudge.hideTimer = nil
                end)
            end
        end)
        
        parentFrame.movableNudgeHooked = true
    end
    
    -- Hide nudge when mouse leaves nudge frame (with delay)
    nudge:SetScript("OnEnter", function(self)
        -- Cancel any pending hide timer when entering nudge frame
        if self.hideTimer then
            self.hideTimer:Cancel()
            self.hideTimer = nil
        end
    end)
    
    nudge:SetScript("OnLeave", function(self)
        if not self.disableAutoHide then
            -- Delay hiding to allow mouse movement
            self.hideTimer = C_Timer.NewTimer(0.3, function()
                if not MouseIsOver(parentFrame) and not MouseIsOver(self) then
                    self:Hide()
                end
                self.hideTimer = nil
            end)
        end
    end)
    
    return nudge
end

--[[
    Updates the offset display text on a nudge frame
    @param nudgeFrame - The nudge control frame
    @param db - Database table containing offsetX and offsetY
]]
function Movable:UpdateNudgeDisplay(nudgeFrame, db)
    if nudgeFrame and nudgeFrame.offsetText and db then
        local x = db.offsetX or 0
        local y = db.offsetY or 0
        nudgeFrame.offsetText:SetText(string.format("X: %d  Y: %d", x, y))
    end
end

--[[
    Shows nudge controls anchored near a parent frame
    @param nudgeFrame - The nudge control frame
    @param parentFrame - The frame to anchor near
]]
function Movable:ShowNudgeControls(nudgeFrame, parentFrame)
    if not nudgeFrame or not parentFrame or not MidnightUI.moveMode then return end
    
    -- Cancel any pending hide timer
    if nudgeFrame.hideTimer then
        nudgeFrame.hideTimer:Cancel()
        nudgeFrame.hideTimer = nil
    end
    
    nudgeFrame:ClearAllPoints()
    
    -- Special handling for Minimap - center the nudge frame on it
    if parentFrame == Minimap then
        nudgeFrame:SetPoint("CENTER", parentFrame, "CENTER", 0, 0)
    else
        -- Position nudge frame relative to parent's CURRENT position
        local parentX, parentY = parentFrame:GetCenter()
        if parentX and parentY then
            -- If parent is on right half of screen, put nudge on left
            if parentX > UIParent:GetWidth() / 2 then
                nudgeFrame:SetPoint("RIGHT", parentFrame, "LEFT", -10, 0)
            else
                nudgeFrame:SetPoint("LEFT", parentFrame, "RIGHT", 10, 0)
            end
        else
            nudgeFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
    
    nudgeFrame:Show()
end

--[[
    Hides nudge controls
    @param nudgeFrame - The nudge control frame or table of arrow buttons
]]
function Movable:HideNudgeControls(nudgeFrame)
    if not nudgeFrame then return end
    
    -- Cancel any pending hide timer
    if nudgeFrame.hideTimer then
        nudgeFrame.hideTimer:Cancel()
        nudgeFrame.hideTimer = nil
    end
    
    -- Check if it's a frame with Hide method (CreateNudgeControls)
    if nudgeFrame.Hide and type(nudgeFrame.Hide) == "function" then
        nudgeFrame:Hide()
    -- Or if it's a table of arrow buttons (CreateNudgeArrows)
    elseif nudgeFrame.UP and nudgeFrame.DOWN and nudgeFrame.LEFT and nudgeFrame.RIGHT then
        nudgeFrame.UP:Hide()
        nudgeFrame.DOWN:Hide()
        nudgeFrame.LEFT:Hide()
        nudgeFrame.RIGHT:Hide()
    end
end

-- ============================================================================
-- 3. MOVE MODE INTEGRATION
-- ============================================================================

-- (removed stray code after duplicate OnMoveModeChanged)

-- ============================================================================
-- 4. CONTAINER WITH ARROWS (UIButtons style)
-- ============================================================================

--[[
    Creates nudge arrows positioned around a container (UIButtons style)
    @param container - The container frame
    @param db - Database table with position = {point, x, y}
    @param resetCallback - Optional callback when reset button is clicked
    @param updateCallback - Optional callback when arrow buttons move the frame
    @return arrows table with UP, DOWN, LEFT, RIGHT keys
]]
function Movable:CreateNudgeArrows(container, db, resetCallback, updateCallback)
    if not container or not db then return end
    
    container.arrows = {}
    
    local directions = {"UP", "DOWN", "LEFT", "RIGHT"}
    
    for _, direction in ipairs(directions) do
        local btn = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
        btn:SetSize(24, 24)
        btn:SetFrameStrata("TOOLTIP")
        btn:SetFrameLevel(300)
        
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        btn:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
        btn:SetBackdropBorderColor(0, 1, 0, 1)
        
        -- Arrow text
        local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        arrow:SetPoint("CENTER")
        
        if direction == "UP" then arrow:SetText("^")
        elseif direction == "DOWN" then arrow:SetText("v")
        elseif direction == "LEFT" then arrow:SetText("<")
        elseif direction == "RIGHT" then arrow:SetText(">")
        end
        
        arrow:SetTextColor(0, 1, 0, 1)
        
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        end)
        
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
        end)
        
        btn:SetScript("OnClick", function()
            -- 1 pixel by default, grid size (8px) with Shift held
            local step = IsShiftKeyDown() and GRID_SIZE or 1
            
            -- CRITICAL FIX: Get CURRENT position from container, not from DB
            local currentPoint, _, _, currentX, currentY = container:GetPoint()
            
            -- Support both nested position table (bars) and flat structure (unit frames)
            local pos
            if db.position then
                -- Bars use db.position.x, db.position.y, db.position.point
                pos = db.position
                pos.point = pos.point or currentPoint or "CENTER"
                pos.x = pos.x or currentX or 0
                pos.y = pos.y or currentY or 0
            else
                -- Unit frames use db.posX, db.posY, db.anchorPoint, db.relativePoint
                pos = {
                    point = db.anchorPoint or db.relativePoint or currentPoint or "CENTER",
                    x = db.posX or currentX or 0,
                    y = db.posY or currentY or 0
                }
            end
            
            if direction == "UP" then
                pos.y = pos.y + step
            elseif direction == "DOWN" then
                pos.y = pos.y - step
            elseif direction == "LEFT" then
                pos.x = pos.x - step
            elseif direction == "RIGHT" then
                pos.x = pos.x + step
            end
            
            -- Save to database (use correct structure)
            if db.position then
                db.position = pos
            else
                db.posX = pos.x
                db.posY = pos.y
                db.anchorPoint = pos.point
                db.relativePoint = pos.point
            end
            
            -- Update container position
            container:ClearAllPoints()
            container:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
            
            -- Call update callback if provided
            if updateCallback then
                updateCallback(pos.point, pos.x, pos.y)
            end
        end)
        
        btn:Hide()
        container.arrows[direction] = btn
    end
    
    -- Create RESET button in the center
    local resetBtn = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    resetBtn:SetSize(24, 24)
    resetBtn:SetFrameStrata("TOOLTIP")
    resetBtn:SetFrameLevel(300)
    
    resetBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    resetBtn:SetBackdropColor(0.3, 0.1, 0.1, 0.8)
    resetBtn:SetBackdropBorderColor(1, 0, 0, 1)
    
    -- Reset text
    local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    resetText:SetPoint("CENTER")
    resetText:SetText("R")
    resetText:SetTextColor(1, 0, 0, 1)
    
    resetBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.5, 0.2, 0.2, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Reset Position", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    resetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.3, 0.1, 0.1, 0.8)
        GameTooltip:Hide()
    end)
    
    resetBtn:SetScript("OnClick", function()
        if resetCallback then
            resetCallback()
        end
    end)
    
    resetBtn:Hide()
    container.arrows.RESET = resetBtn
    
    -- Setup mouseover for container arrows
    if not container.movableArrowsHooked then
        container:HookScript("OnEnter", function()
            if MidnightUI.moveMode and container.arrows then
                -- Cancel any pending hide timer
                if container.arrowHideTimer then
                    container.arrowHideTimer:Cancel()
                    container.arrowHideTimer = nil
                end
                Movable:UpdateNudgeArrows(container)
            end
        end)
        
        container:HookScript("OnLeave", function()
            -- Delay hiding to allow mouse to move to arrows
            if container.arrowHideTimer then
                container.arrowHideTimer:Cancel()
            end
            container.arrowHideTimer = C_Timer.NewTimer(0.3, function()
                if not MouseIsOver(container) and container.arrows then
                    -- Check if mouse is over any arrow button
                    local overArrow = false
                    for _, arrow in pairs(container.arrows) do
                        if arrow and MouseIsOver(arrow) then
                            overArrow = true
                            break
                        end
                    end
                    
                    if not overArrow then
                        Movable:HideNudgeArrows(container)
                    end
                end
                container.arrowHideTimer = nil
            end)
        end)
        
        -- Add hover detection for arrow buttons themselves
        for _, arrow in pairs(container.arrows or {}) do
            arrow:HookScript("OnEnter", function()
                if container.arrowHideTimer then
                    container.arrowHideTimer:Cancel()
                    container.arrowHideTimer = nil
                end
            end)
            
            arrow:HookScript("OnLeave", function()
                -- Cancel any existing timer before creating a new one
                if container.arrowHideTimer then
                    container.arrowHideTimer:Cancel()
                end
                
                container.arrowHideTimer = C_Timer.NewTimer(0.3, function()
                    if not MouseIsOver(container) then
                        local overArrow = false
                        for _, btn in pairs(container.arrows or {}) do
                            if MouseIsOver(btn) then
                                overArrow = true
                                break
                            end
                        end
                        
                        if not overArrow then
                            Movable:HideNudgeArrows(container)
                        end
                    end
                    container.arrowHideTimer = nil
                end)
            end)
        end
        
        container.movableArrowsHooked = true
    end
    
    return container.arrows
end

--[[
    Updates container arrow positions based on container location
    @param container - The container with .arrows table
]]
function Movable:UpdateNudgeArrows(container)
    if not container or not container.arrows then return end
    
    local showArrows = MidnightUI and MidnightUI.moveMode
    
    if not showArrows then
        for _, arrow in pairs(container.arrows) do
            arrow:Hide()
        end
        return
    end
    
    -- Get container position - calculate from anchor points to avoid scale issues
    local point, relativeTo, relativePoint, xOfs, yOfs = container:GetPoint()
    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    
    -- Calculate actual screen position from anchor point
    local containerWidth = container:GetWidth() * (container:GetScale() or 1)
    local containerHeight = container:GetHeight() * (container:GetScale() or 1)
    
    local containerX, containerY
    
    -- Calculate center based on anchor point
    if point == "BOTTOMLEFT" then
        containerX = xOfs + (containerWidth / 2)
        containerY = yOfs + (containerHeight / 2)
    elseif point == "BOTTOMRIGHT" then
        containerX = screenWidth + xOfs - (containerWidth / 2)
        containerY = yOfs + (containerHeight / 2)
    elseif point == "TOPLEFT" then
        containerX = xOfs + (containerWidth / 2)
        containerY = screenHeight + yOfs - (containerHeight / 2)
    elseif point == "TOPRIGHT" then
        containerX = screenWidth + xOfs - (containerWidth / 2)
        containerY = screenHeight + yOfs - (containerHeight / 2)
    elseif point == "TOP" then
        containerX = (screenWidth / 2) + xOfs
        containerY = screenHeight + yOfs - (containerHeight / 2)
    elseif point == "BOTTOM" then
        containerX = (screenWidth / 2) + xOfs
        containerY = yOfs + (containerHeight / 2)
    elseif point == "LEFT" then
        containerX = xOfs + (containerWidth / 2)
        containerY = (screenHeight / 2) + yOfs
    elseif point == "RIGHT" then
        containerX = screenWidth + xOfs - (containerWidth / 2)
        containerY = (screenHeight / 2) + yOfs
    else -- CENTER
        containerX = (screenWidth / 2) + xOfs
        containerY = (screenHeight / 2) + yOfs
    end
    
    -- Determine if container is on top or bottom half
    local onTop = containerY > screenHeight / 2
    
    -- Determine if container is on left or right half
    local onLeft = containerX < screenWidth / 2
    
    -- Calculate arrow width (5 arrows * 24px + 4 spacing * 2px = 128px)
    local arrowRowWidth = (5 * 24) + (4 * 2)
    
    -- Check if arrows would go off-screen horizontally
    local arrowsOffScreenRight = (containerX + arrowRowWidth / 2) > screenWidth
    local arrowsOffScreenLeft = (containerX - arrowRowWidth / 2) < 0
    
    -- Define spacing and offset before using them
    local spacing = 2
    local offset = 5
    
    -- Calculate arrow column height (5 arrows * 24px + 4 spacing * 2px = 128px)
    local arrowColumnHeight = (5 * 24) + (4 * 2)
    
    -- Check if arrows would go off-screen vertically
    local arrowsOffScreenBottom = (containerY - arrowColumnHeight - offset) < 0
    local arrowsOffScreenTop = (containerY + arrowColumnHeight + offset) > screenHeight
    
    container.arrows.LEFT:ClearAllPoints()
    container.arrows.UP:ClearAllPoints()
    container.arrows.RESET:ClearAllPoints()
    container.arrows.DOWN:ClearAllPoints()
    container.arrows.RIGHT:ClearAllPoints()
    
    -- If arrows would go off-screen horizontally AND would also go off bottom when vertical, use horizontal layout
    if (arrowsOffScreenRight or arrowsOffScreenLeft) and arrowsOffScreenBottom then
        -- Calculate container's center position
        local containerWidth = container:GetWidth() or 0
        local containerLeft = containerX - (containerWidth / 2)
        local containerRight = containerX + (containerWidth / 2)
        
        -- Start by centering arrows above container (relative to container's center)
        local baseXOffset = 0
        
        -- Calculate where arrows would be if centered
        local arrowsLeft = containerX - (arrowRowWidth / 2)
        local arrowsRight = containerX + (arrowRowWidth / 2)
        
        -- Adjust if they go off the right edge
        if arrowsRight > screenWidth then
            local overhang = arrowsRight - screenWidth
            baseXOffset = -(overhang + 10)
        end
        
        -- Adjust if they go off the left edge
        if arrowsLeft < 10 then
            baseXOffset = 10 - arrowsLeft
        end
        
        -- Position arrows horizontally above the container, centered with adjustments
        container.arrows.LEFT:SetPoint("BOTTOM", container, "TOP", baseXOffset - (arrowRowWidth / 2) + 12, offset)
        container.arrows.UP:SetPoint("LEFT", container.arrows.LEFT, "RIGHT", spacing, 0)
        container.arrows.RESET:SetPoint("LEFT", container.arrows.UP, "RIGHT", spacing, 0)
        container.arrows.DOWN:SetPoint("LEFT", container.arrows.RESET, "RIGHT", spacing, 0)
        container.arrows.RIGHT:SetPoint("LEFT", container.arrows.DOWN, "RIGHT", spacing, 0)
    elseif arrowsOffScreenRight or arrowsOffScreenLeft then
        -- Position arrows vertically on the opposite side of the container
        local sideOffset = 5
        local side = arrowsOffScreenRight and "LEFT" or "RIGHT"
        local oppositeSide = arrowsOffScreenRight and "RIGHT" or "LEFT"
        
        -- Stack vertically downward: ^ v < > R
        container.arrows.UP:SetPoint(oppositeSide, container, side, arrowsOffScreenRight and -sideOffset or sideOffset, 0)
        container.arrows.DOWN:SetPoint("TOP", container.arrows.UP, "BOTTOM", 0, -spacing)
        container.arrows.LEFT:SetPoint("TOP", container.arrows.DOWN, "BOTTOM", 0, -spacing)
        container.arrows.RIGHT:SetPoint("TOP", container.arrows.LEFT, "BOTTOM", 0, -spacing)
        container.arrows.RESET:SetPoint("TOP", container.arrows.RIGHT, "BOTTOM", 0, -spacing)
    elseif arrowsOffScreenTop then
        -- Container near top and arrows would go off top, place arrows BELOW: < ^ R v >
        local baseXOffset = 0
        local arrowsLeft = containerX - (arrowRowWidth / 2)
        local arrowsRight = containerX + (arrowRowWidth / 2)
        
        -- Adjust if they go off the right edge
        if arrowsRight > screenWidth then
            local overhang = arrowsRight - screenWidth
            baseXOffset = -(overhang + 10)
        end
        
        -- Adjust if they go off the left edge
        if arrowsLeft < 10 then
            baseXOffset = 10 - arrowsLeft
        end
        
        container.arrows.LEFT:SetPoint("TOP", container, "BOTTOM", baseXOffset - (arrowRowWidth / 2) + 12, -offset)
        container.arrows.UP:SetPoint("LEFT", container.arrows.LEFT, "RIGHT", spacing, 0)
        container.arrows.RESET:SetPoint("LEFT", container.arrows.UP, "RIGHT", spacing, 0)
        container.arrows.DOWN:SetPoint("LEFT", container.arrows.RESET, "RIGHT", spacing, 0)
        container.arrows.RIGHT:SetPoint("LEFT", container.arrows.DOWN, "RIGHT", spacing, 0)
    elseif arrowsOffScreenBottom or not onTop then
        -- Container near bottom OR on bottom half, place arrows ABOVE: < ^ R v >
        local baseXOffset = 0
        local arrowsLeft = containerX - (arrowRowWidth / 2)
        local arrowsRight = containerX + (arrowRowWidth / 2)
        
        -- Adjust if they go off the right edge
        if arrowsRight > screenWidth then
            local overhang = arrowsRight - screenWidth
            baseXOffset = -(overhang + 10)
        end
        
        -- Adjust if they go off the left edge
        if arrowsLeft < 10 then
            baseXOffset = 10 - arrowsLeft
        end
        
        container.arrows.LEFT:SetPoint("BOTTOM", container, "TOP", baseXOffset - (arrowRowWidth / 2) + 12, offset)
        container.arrows.UP:SetPoint("LEFT", container.arrows.LEFT, "RIGHT", spacing, 0)
        container.arrows.RESET:SetPoint("LEFT", container.arrows.UP, "RIGHT", spacing, 0)
        container.arrows.DOWN:SetPoint("LEFT", container.arrows.RESET, "RIGHT", spacing, 0)
        container.arrows.RIGHT:SetPoint("LEFT", container.arrows.DOWN, "RIGHT", spacing, 0)
    else
        -- Container on top half and arrows won't go off screen, place arrows BELOW: < ^ R v >
        local baseXOffset = 0
        local arrowsLeft = containerX - (arrowRowWidth / 2)
        local arrowsRight = containerX + (arrowRowWidth / 2)
        
        -- Adjust if they go off the right edge
        if arrowsRight > screenWidth then
            local overhang = arrowsRight - screenWidth
            baseXOffset = -(overhang + 10)
        end
        
        -- Adjust if they go off the left edge
        if arrowsLeft < 10 then
            baseXOffset = 10 - arrowsLeft
        end
        
        container.arrows.LEFT:SetPoint("TOP", container, "BOTTOM", baseXOffset - (arrowRowWidth / 2) + 12, -offset)
        container.arrows.UP:SetPoint("LEFT", container.arrows.LEFT, "RIGHT", spacing, 0)
        container.arrows.RESET:SetPoint("LEFT", container.arrows.UP, "RIGHT", spacing, 0)
        container.arrows.DOWN:SetPoint("LEFT", container.arrows.RESET, "RIGHT", spacing, 0)
        container.arrows.RIGHT:SetPoint("LEFT", container.arrows.DOWN, "RIGHT", spacing, 0)
    end
    
    -- Show all arrows
    for _, arrow in pairs(container.arrows) do
        arrow:Show()
    end
end

--[[
    Hides container arrows
    @param container - The container with .arrows table
]]
function Movable:HideNudgeArrows(container)
    if not container or not container.arrows then return end
    
    for _, arrow in pairs(container.arrows) do
        arrow:Hide()
    end
end

-- ============================================================================
-- BLIZZARD FRAME MOVEMENT
-- Make default Blizzard UI frames draggable
-- ============================================================================

-- List of common Blizzard frames to make movable
local BLIZZARD_FRAMES = {
    -- Character & Equipment
    "CharacterFrame",
    "PaperDollFrame",
    "ReputationFrame",
    "TokenFrame",
    
    -- Spellbook & Professions
    "SpellBookFrame",
    "PlayerSpellsFrame",
    "ProfessionsFrame",
    
    -- Social
    "FriendsFrame",
    "GuildFrame",
    "CommunitiesFrame",
    "LFGParentFrame",
    "PVEFrame",
    "RaidInfoFrame",
    
    -- Collections
    "CollectionsJournal",
    "MountJournal",
    "PetJournal",
    "ToyBox",
    "HeirloomsJournal",
    "WardrobeFrame",
    
    -- Adventure Guide & Quests
    "EncounterJournal",
    "WorldMapFrame",
    "QuestLogPopupDetailFrame",
    "QuestFrame",
    
    -- Achievements & Calendar
    "AchievementFrame",
    "CalendarFrame",
    
    -- Mail & Merchants
    "MailFrame",
    "MerchantFrame",
    "GossipFrame",
    
    -- Bags & Bank
    "ContainerFrameCombinedBags",
    "BankFrame",
    
    -- Game Menu & Settings
    "GameMenuFrame",
    "VideoOptionsFrame",
    "InterfaceOptionsFrame",
    "SettingsPanel",
    
    -- Talents & Specialization  
    "PlayerTalentFrame",
    "ClassTalentFrame",
    
    -- Tracking & Timers
    "TimeManagerFrame",
    "StopwatchFrame",
    
    -- Auction House
    "AuctionHouseFrame",
    
    -- Trade & Crafting
    "TradeFrame",
    "CraftFrame",
    "TradeSkillFrame",
    
    -- Macro & Keybinds
    "MacroFrame",
    "KeyBindingFrame",
    
    -- Loot & Groups
    "LootFrame",
    "GroupLootContainer",
    "MasterLooterFrame",
    "RaidParentFrame",
    
    -- Misc
    "HelpFrame",
    "TicketStatusFrame",
    "ItemTextFrame",
    "DressUpFrame",
    "InspectFrame",
    "QuestChoiceFrame",
}

function Movable:MakeBlizzardFrameMovable(frameName)
    local frame = _G[frameName]
    if not frame then return end
    
    -- Skip if already made movable
    if self.blizzardFrames[frameName] then return end
    
    -- Make frame movable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    
    -- Register for dragging on left mouse button
    frame:RegisterForDrag("LeftButton")
    
    -- Set up drag scripts
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, x, y = self:GetPoint()
        if not Movable.db then return end
        if not Movable.db.profile.blizzardFramePositions then
            Movable.db.profile.blizzardFramePositions = {}
        end
        Movable.db.profile.blizzardFramePositions[frameName] = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end)
    
    -- Mark as handled
    self.blizzardFrames[frameName] = true
    
    -- Restore saved position if it exists
    if self.db and self.db.profile.blizzardFramePositions and self.db.profile.blizzardFramePositions[frameName] then
        local pos = self.db.profile.blizzardFramePositions[frameName]
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
end

function Movable:InitializeBlizzardFrames()
    -- Make all listed frames movable
    for _, frameName in ipairs(BLIZZARD_FRAMES) do
        self:MakeBlizzardFrameMovable(frameName)
    end
    
    -- Set up a hook to catch frames that load later
    C_Timer.After(2, function()
        for _, frameName in ipairs(BLIZZARD_FRAMES) do
            self:MakeBlizzardFrameMovable(frameName)
        end
    end)
    
    -- Hook ADDON_LOADED to catch addon frames as they load
    self:RegisterEvent("ADDON_LOADED")
end

function Movable:ADDON_LOADED(event, addonName)
    -- Re-attempt to make frames movable when relevant addons load
    C_Timer.After(0.5, function()
        for _, frameName in ipairs(BLIZZARD_FRAMES) do
            self:MakeBlizzardFrameMovable(frameName)
        end
    end)
end

return Movable