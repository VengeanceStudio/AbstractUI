local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local Maps = MidnightUI:NewModule("Maps", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local ColorPalette, FontKit

-- -----------------------------------------------------------------------------
-- DATABASE DEFAULTS
-- -----------------------------------------------------------------------------
local defaults = {
    profile = {
        -- Appearance
        shape = "SQUARE", -- SQUARE or ROUND
        autoZoom = true,
        
        -- Manual positioning offset (relative to MinimapCluster)
        offsetX = 0,
        offsetY = 0,
        
        -- Text Elements
        showClock = true,
        showZone = true,
        showCoords = true,
        
        -- Icon Visibility
        showCalendar = false,
        showTracking = true,
        showMail = true,
        mailOffsetX = -25,
        mailOffsetY = -25,
        showMissions = false,
        showQueue = true,
        showDifficulty = false,
        difficultyOffsetX = -65,
        difficultyOffsetY = -5,
        
        -- Text Styling
        font = "Friz Quadrata TT",
        fontSize = 12,
        fontOutline = "OUTLINE",
        
        -- Widget Configs
        clock = { point = "BOTTOM", x = 0, y = -2, color = {1, 1, 1, 1} },
        zone = { point = "TOP", x = 0, y = 5, color = {1, 0.8, 0, 1} },
        coords = { point = "BOTTOM", x = 0, y = 12, color = {1, 1, 1, 1} },
        
        -- Button Bar
        buttonBarEnabled = true,
        buttonBarAnchor = "CENTER",
        buttonBarX = 0,
        buttonBarY = 0,
        buttonBarCollapsedSize = 20,
        buttonBarButtonSize = 32,
        buttonBarButtonsPerRow = 1,
        buttonBarColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
        buttonBarUseClassColor = false,
        buttonBarGrowthDirection = "right",
        buttonBarIconScale = 0.5,
        buttonBarSpacing = 2,
    }
}

-- -----------------------------------------------------------------------------
-- INITIALIZATION
-- -----------------------------------------------------------------------------
function Maps:OnInitialize()
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "OnDBReady")
end

function Maps:OnDBReady()
    if not MidnightUI.db or not MidnightUI.db.profile or not MidnightUI.db.profile.modules then
        self:Disable()
        return
    end
    
    if not MidnightUI.db.profile.modules.maps then 
        self:Disable()
        return 
    end
    
    -- Get framework systems
    ColorPalette = _G.MidnightUI_ColorPalette
    FontKit = _G.MidnightUI_FontKit
    
    self.db = MidnightUI.db:RegisterNamespace("Maps", defaults)
    
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterMessage("MIDNIGHTUI_MOVEMODE_CHANGED", "OnMoveModeChanged")
    
    -- Manually call setup since PLAYER_ENTERING_WORLD already fired
    C_Timer.After(0.1, function()
        self:PLAYER_ENTERING_WORLD()
    end)
end

function Maps:PLAYER_ENTERING_WORLD()
    -- CRITICAL FIX: Stub out Layout function to prevent errors
    if not Minimap.Layout or Minimap.Layout == nil then
        Minimap.Layout = function() end
    end
    
    self:SetupMinimapBorder()
    self:SetupMinimapPosition()
    self:SetupMinimapDragging()
    self:SetupNudgeControls()
    self:SetupElements()
    self:SkinBlizzardButtons()
    self:SetupButtonBar()
    self:UpdateLayout()
end

-- -----------------------------------------------------------------------------
-- MINIMAP POSITIONING
-- -----------------------------------------------------------------------------
function Maps:SetupMinimapBorder()
    -- Only create the border once
    if self.minimapBorderInitialized then
        return
    end
    
    -- Create a frame to hold the border
    if not self.minimapBorder then
        self.minimapBorder = CreateFrame("Frame", "MidnightUI_MinimapBorder", Minimap, "BackdropTemplate")
        self.minimapBorder:SetAllPoints(Minimap)
        self.minimapBorder:SetFrameLevel(Minimap:GetFrameLevel() + 1)
        
        -- Apply border with theme color
        self.minimapBorder:SetBackdrop({
            bgFile = nil,
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        
        -- Use background color from ColorPalette
        if ColorPalette then
            self.minimapBorder:SetBackdropBorderColor(ColorPalette:GetColor('panel-bg'))
        else
            -- Fallback to dark background
            self.minimapBorder:SetBackdropBorderColor(0.05, 0.05, 0.05, 1)
        end
    end
    
    self.minimapBorderInitialized = true
end

function Maps:SetupMinimapPosition()
    -- Only override SetPoint once - prevent function wrapping on zone changes
    if self.minimapPositionInitialized then
        return
    end
    
    -- Store original SetPoint function
    if not self.origSetPoint then
        self.origSetPoint = Minimap.SetPoint
    end
    
    -- Override SetPoint to add our offsets
    Minimap.SetPoint = function(frame, ...)
        local point, relativeTo, relativePoint, x, y = ...
        
        if x and y then
            local db = Maps.db.profile
            Maps.origSetPoint(frame, point, relativeTo, relativePoint, x + db.offsetX, y + db.offsetY)
        else
            Maps.origSetPoint(frame, ...)
        end
    end
    
    self.minimapPositionInitialized = true
    self:ApplyMinimapOffset()
end

function Maps:ApplyMinimapOffset()
    local db = self.db.profile
    Minimap:ClearAllPoints()
    self.origSetPoint(Minimap, "CENTER", MinimapCluster, "CENTER", db.offsetX, db.offsetY)
end

-- -----------------------------------------------------------------------------
-- MINIMAP DRAGGING (CTRL+ALT OR MOVE MODE)
-- -----------------------------------------------------------------------------
function Maps:SetupMinimapDragging()
    local Movable = MidnightUI:GetModule("Movable")
    
    -- Only set up once - prevent multiple OnUpdate scripts on zone changes
    if Maps.dragOverlay and Maps.dragOverlayInitialized then
        return
    end
    
    -- Create invisible overlay frame to capture drag events
    if not Maps.dragOverlay then
        Maps.dragOverlay = CreateFrame("Frame", "MidnightUI_MinimapDragOverlay", Minimap)
        Maps.dragOverlay:SetAllPoints(Minimap)
        Maps.dragOverlay:SetFrameLevel(Minimap:GetFrameLevel() + 100)
        Maps.dragOverlay:EnableMouse(false) -- Only enable when needed
        Maps.dragOverlay:SetFrameStrata("HIGH")
    end
    
    Maps.dragOverlayInitialized = true
    
    local dragStartOffsetX, dragStartOffsetY
    local dragStartMouseX, dragStartMouseY
    local isDragging = false
    
    -- Check on every frame if we should enable mouse on the overlay
    Maps.dragOverlay:SetScript("OnUpdate", function(self)
        -- Enable mouse on overlay if CTRL+ALT held or Move Mode active
        local shouldEnable = (IsControlKeyDown() and IsAltKeyDown()) or MidnightUI.moveMode
        
        if shouldEnable and not self:IsMouseEnabled() then
            self:EnableMouse(true)
        elseif not shouldEnable and self:IsMouseEnabled() and not isDragging then
            self:EnableMouse(false)
        end
        
        -- Handle dragging movement
        if isDragging then
            local currentMouseX, currentMouseY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            currentMouseX = currentMouseX / scale
            currentMouseY = currentMouseY / scale
            
            if dragStartMouseX and dragStartMouseY then
                local deltaX = currentMouseX - dragStartMouseX
                local deltaY = currentMouseY - dragStartMouseY
                
                Maps.db.profile.offsetX = dragStartOffsetX + deltaX
                Maps.db.profile.offsetY = dragStartOffsetY + deltaY
                
                Maps:ApplyMinimapOffset()
            end
        end
    end)
    
    Maps.dragOverlay:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            isDragging = true
            dragStartOffsetX = Maps.db.profile.offsetX
            dragStartOffsetY = Maps.db.profile.offsetY
            dragStartMouseX, dragStartMouseY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            dragStartMouseX = dragStartMouseX / scale
            dragStartMouseY = dragStartMouseY / scale
        end
    end)
    
    Maps.dragOverlay:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and isDragging then
            isDragging = false
            
            -- Round to whole numbers for final save
            Maps.db.profile.offsetX = math.floor(Maps.db.profile.offsetX + 0.5)
            Maps.db.profile.offsetY = math.floor(Maps.db.profile.offsetY + 0.5)
            
            Maps:ApplyMinimapOffset()
            Movable:UpdateNudgeDisplay(Maps.nudgeFrame, Maps.db.profile)
        end
    end)
    
    -- Show nudge controls on hover in Move Mode
    Minimap:HookScript("OnEnter", function(self)
        if MidnightUI.moveMode and Maps.nudgeFrame then
            Movable:ShowNudgeControls(Maps.nudgeFrame, Minimap)
        end
    end)
end

-- -----------------------------------------------------------------------------
-- NUDGE CONTROLS
-- -----------------------------------------------------------------------------
function Maps:SetupNudgeControls()
    if self.nudgeControlsInitialized then
        return
    end
    
    local Movable = MidnightUI:GetModule("Movable")
    
    self.nudgeFrame = Movable:CreateNudgeControls(
        Minimap,
        self.db.profile,
        function() Maps:ApplyMinimapOffset() end,
        function()
            -- Update nudge frame position to stay centered on minimap after offset change
            if Maps.nudgeFrame and Maps.nudgeFrame:IsShown() then
                Movable:ShowNudgeControls(Maps.nudgeFrame, Minimap)
            end
        end,
        "Move Minimap"  -- Custom title
    )
    
    -- Disable auto-hide behavior for minimap - it should stay visible while move mode is on
    if self.nudgeFrame then
        self.nudgeFrame.disableAutoHide = true
        
        -- Override the nudge frame's OnLeave to not hide
        self.nudgeFrame:SetScript("OnLeave", function(self)
            -- Don't hide - minimap mover stays visible during move mode
        end)
    end
    
    Movable:RegisterNudgeFrame(self.nudgeFrame, Minimap)
    self.nudgeControlsInitialized = true
end

function Maps:UpdateNudgeDisplay()
    local Movable = MidnightUI:GetModule("Movable")
    if self.nudgeFrame then
        Movable:UpdateNudgeDisplay(self.nudgeFrame, self.db.profile)
        -- Also reposition it to stay centered on minimap
        if self.nudgeFrame:IsShown() then
            Movable:ShowNudgeControls(self.nudgeFrame, Minimap)
        end
    end
end

function Maps:OnMoveModeChanged(event, enabled)
    local Movable = MidnightUI:GetModule("Movable")
    
    if enabled then
        -- Always show nudge controls immediately when Move Mode is enabled
        if self.nudgeFrame then
            Movable:ShowNudgeControls(self.nudgeFrame, Minimap)
        end
    else
        -- Hide nudge controls when Move Mode is disabled
        if self.nudgeFrame then
            Movable:HideNudgeControls(self.nudgeFrame)
        end
    end
end

-- -----------------------------------------------------------------------------
-- CUSTOM ELEMENTS (Clock, Coords, Zone)
-- -----------------------------------------------------------------------------
function Maps:SetupElements()
    -- Only set up once - prevent duplicate tickers on zone changes
    if self.elementsInitialized then
        return
    end
    
    local font, size, flag
    
    if FontKit then
        font = FontKit:GetFont('body')
        size = FontKit:GetSize('normal')
        flag = "OUTLINE"
    else
        font = LSM:Fetch("font", self.db.profile.font)
        size = self.db.profile.fontSize
        flag = self.db.profile.fontOutline
    end

    -- 1. CLOCK
    if not self.clock then
        self.clock = Minimap:CreateFontString(nil, "OVERLAY")
        self.clock:SetFont(font, size, flag)
        
        self.clockTicker = C_Timer.NewTicker(1, function()
            local h, m = tonumber(date("%H")), tonumber(date("%M"))
            local timeStr = ""
            if GetCVarBool("timeMgrUseMilitaryTime") then
                timeStr = string.format("%02d:%02d", h, m)
            else
                local suffix = (h >= 12) and " PM" or " AM"
                if h > 12 then h = h - 12 elseif h == 0 then h = 12 end
                timeStr = string.format("%d:%02d%s", h, m, suffix)
            end
            self.clock:SetText(timeStr)
        end)
        
        if TimeManagerClockButton then TimeManagerClockButton:Hide() end
    end
    
    -- 2. COORDINATES
    if not self.coords then
        self.coords = Minimap:CreateFontString(nil, "OVERLAY")
        self.coords:SetFont(font, size, flag)
        
        self.coordsTicker = C_Timer.NewTicker(0.2, function()
            local mapID = C_Map.GetBestMapForUnit("player")
            if mapID then
                local pos = C_Map.GetPlayerMapPosition(mapID, "player")
                if pos then
                    self.coords:SetFormattedText("%.1f, %.1f", pos.x * 100, pos.y * 100)
                    return
                end
            end
            self.coords:SetText("")
        end)
    end
    
    -- 3. ZONE TEXT
    if not self.zone then
        self.zone = Minimap:CreateFontString(nil, "OVERLAY")
        self.zone:SetFont(font, size, flag)
        self.zone:SetWidth(200)
        self.zone:SetWordWrap(false)
        
        self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateZoneText")
        self:RegisterEvent("ZONE_CHANGED", "UpdateZoneText")
        self:RegisterEvent("ZONE_CHANGED_INDOORS", "UpdateZoneText")
        self:UpdateZoneText()
        
        if MinimapCluster.ZoneTextButton then MinimapCluster.ZoneTextButton:Hide() end
        if MinimapZoneText then MinimapZoneText:Hide() end
        
        -- Hide unwanted MinimapCluster elements
        if MinimapCluster.BorderTop then MinimapCluster.BorderTop:Hide() end
        if MinimapCluster.Tracking and MinimapCluster.Tracking.Background then 
            MinimapCluster.Tracking.Background:Hide() 
        end
    end
    
    self.elementsInitialized = true
end

function Maps:UpdateZoneText()
    if self.zone then
        self.zone:SetText(GetMinimapZoneText() or "")
        
        local pvpType = C_PvP.GetZonePVPInfo()
        if pvpType == "friendly" then self.zone:SetTextColor(0.1, 1, 0.1)
        elseif pvpType == "hostile" then self.zone:SetTextColor(1, 0.1, 0.1)
        elseif pvpType == "contested" then self.zone:SetTextColor(1, 0.7, 0)
        elseif pvpType == "sanctuary" then self.zone:SetTextColor(0.4, 0.8, 0.9)
        else self.zone:SetTextColor(1, 0.82, 0) end
    end
end

-- -----------------------------------------------------------------------------
-- BUTTON SKINNING & HIDING
-- -----------------------------------------------------------------------------
function Maps:SkinBlizzardButtons()
    if self.blizzardButtonsSkinned then
        return
    end
    
    if Minimap.ZoomIn then Minimap.ZoomIn:Hide() end
    if Minimap.ZoomOut then Minimap.ZoomOut:Hide() end
    
    if MinimapCompassTexture then MinimapCompassTexture:SetAlpha(0) end
    if MinimapBorder then MinimapBorder:Hide() end
    if MinimapBorderTop then MinimapBorderTop:Hide() end
    if MinimapNorthTag then MinimapNorthTag:Hide() end
    
    -- Skin specific buttons
    local buttons = {
        GameTimeFrame,
        MinimapCluster.Tracking.Button,
        MinimapCluster.IndicatorFrame.MailFrame,
        MinimapCluster.IndicatorFrame.CraftingOrderFrame,
        ExpansionLandingPageMinimapButton,
        QueueStatusMinimapButton
    }

    for _, btn in pairs(buttons) do
        if btn then
            if btn.Border then btn.Border:SetAlpha(0) end
            if btn.Background then btn.Background:SetAlpha(0) end
            btn:SetParent(Minimap)
            btn:SetFrameStrata("MEDIUM")
            btn:SetFrameLevel(20)
        end
    end
    
    self.blizzardButtonsSkinned = true
end

-- -----------------------------------------------------------------------------
-- LAYOUT UPDATE
-- -----------------------------------------------------------------------------
function Maps:UpdateLayout()
    if self.layoutInitialized then
        return
    end
    
    local db = self.db.profile

    -- ONLY SET SHAPE ONCE - Never call SetMaskTexture again after this
    if not self.shapeInitialized then
        if db.shape == "SQUARE" then
            Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")
        else
            Minimap:SetMaskTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        end
        self.shapeInitialized = true
    end
    
    -- Apply position offset
    self:ApplyMinimapOffset()

    -- TEXT ELEMENTS
    if self.clock then
        self.clock:ClearAllPoints()
        self.clock:SetPoint(db.clock.point, Minimap, db.clock.point, db.clock.x, db.clock.y)
        self.clock:SetShown(db.showClock)
        if ColorPalette then
            self.clock:SetTextColor(ColorPalette:GetColor("text-secondary"))
        else
            self.clock:SetTextColor(unpack(db.clock.color))
        end
    end
    
    if self.coords then
        self.coords:ClearAllPoints()
        self.coords:SetPoint(db.coords.point, Minimap, db.coords.point, db.coords.x, db.coords.y)
        self.coords:SetShown(db.showCoords)
        if ColorPalette then
            self.coords:SetTextColor(ColorPalette:GetColor("text-secondary"))
        else
            self.coords:SetTextColor(unpack(db.coords.color))
        end
    end
    
    if self.zone then
        self.zone:ClearAllPoints()
        self.zone:SetPoint(db.zone.point, Minimap, db.zone.point, db.zone.x, db.zone.y)
        self.zone:SetShown(db.showZone)
    end
    
    -- BUTTONS
    self:PlaceButton(GameTimeFrame, "TOPRIGHT", -5, -5, db.showCalendar) 
    self:PlaceButton(MinimapCluster.Tracking.Button, "TOPLEFT", 5, -5, db.showTracking)
    self:PlaceButton(MinimapCluster.IndicatorFrame.MailFrame, "TOPRIGHT", db.mailOffsetX or -25, db.mailOffsetY or -25, db.showMail)
    self:PlaceButton(ExpansionLandingPageMinimapButton, "BOTTOMLEFT", 5, 5, db.showMissions)
    self:PlaceButton(QueueStatusMinimapButton, "BOTTOMRIGHT", -5, 5, db.showQueue)
    self:PlaceButton(MinimapCluster.InstanceDifficulty, "TOPRIGHT", db.difficultyOffsetX or -65, db.difficultyOffsetY or -5, db.showDifficulty)
    
    self.layoutInitialized = true
end

function Maps:PlaceButton(btn, point, x, y, isShown)
    if btn then
        btn:ClearAllPoints()
        btn:SetPoint(point, Minimap, point, x, y)
        btn:SetScale(0.8)
        btn:SetShown(isShown)
    end
end

-- -----------------------------------------------------------------------------
-- MINIMAP BUTTON BAR
-- -----------------------------------------------------------------------------
function Maps:SetupButtonBar()
    local db = self.db.profile
    if not db.buttonBarEnabled then
        if self.buttonBar then self.buttonBar:Hide() end
        return
    end
    
    -- Create button bar frame if it doesn't exist
    if not self.buttonBar then
        self.buttonBar = CreateFrame("Frame", "MidnightUI_MinimapButtonBar", UIParent, "BackdropTemplate")
        self.buttonBar:SetFrameStrata("MEDIUM")
        self.buttonBar:SetFrameLevel(50)
        
        -- Create backdrop
        self.buttonBar:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        -- Start with transparent backdrop (only visible when expanded)
        self.buttonBar:SetBackdropColor(0, 0, 0, 0)
        self.buttonBar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0)
        
        -- Create collapsed tab - make it the exact size of the bar (5x30)
        self.buttonBarTab = CreateFrame("Frame", nil, self.buttonBar, "BackdropTemplate")
        self.buttonBarTab:SetSize(5, 30)
        self.buttonBarTab:SetPoint("CENTER", self.buttonBar, "CENTER")
        -- No backdrop needed - the bar texture is the visual
        
        -- Add colored bar to tab (always visible when collapsed)
        local tabBar = self.buttonBarTab:CreateTexture(nil, "ARTWORK")
        tabBar:SetSize(5, 30)
        tabBar:SetPoint("CENTER")
        tabBar:SetTexture("Interface\\Buttons\\WHITE8X8")
        self.buttonBarTab.bar = tabBar
        
        -- Store reference on the button bar frame for move mode access
        self.buttonBar.buttonBarTab = self.buttonBarTab
        
        -- Set initial color
        self:UpdateButtonBarColor()
        
        -- Create collapse timer
        self.buttonBar.collapseTimer = nil
        
        -- Hover handlers with delay
        self.buttonBar:SetScript("OnEnter", function(self)
            -- Cancel any pending collapse
            if Maps.buttonBar.collapseTimer then
                Maps.buttonBar.collapseTimer:Cancel()
                Maps.buttonBar.collapseTimer = nil
            end
            Maps:ExpandButtonBar()
        end)
        self.buttonBar:SetScript("OnLeave", function(self)
            -- Delay collapse by 0.3 seconds
            if Maps.buttonBar.collapseTimer then
                Maps.buttonBar.collapseTimer:Cancel()
            end
            Maps.buttonBar.collapseTimer = C_Timer.NewTimer(0.3, function()
                -- Check if mouse is over any button before collapsing
                local mouseOver = false
                if Maps.buttonBar then
                    for button, data in pairs(Maps.buttonBar.buttons) do
                        if button and button:IsMouseOver() then
                            mouseOver = true
                            break
                        end
                    end
                end
                if not mouseOver then
                    Maps:CollapseButtonBar()
                end
                Maps.buttonBar.collapseTimer = nil
            end)
        end)
        
        self.buttonBar.buttons = {}
        self.buttonBar.isExpanded = false
        
        -- Initialize with bar size (5x30)
        self.buttonBar:SetSize(5, 30)
    end
    
    -- Position the bar
    self.buttonBar:ClearAllPoints()
    self.buttonBar:SetPoint(db.buttonBarAnchor or "CENTER", UIParent, db.buttonBarAnchor or "CENTER", db.buttonBarX or 0, db.buttonBarY or 0)
    
    -- Force collapse and clear existing buttons when settings change
    if self.buttonBar.isExpanded then
        self.buttonBar.isExpanded = false
    end
    
    -- Clear existing button collection
    if self.buttonBar.buttons then
        for button, data in pairs(self.buttonBar.buttons) do
            if button and data then
                -- Try to restore original state
                button:ClearAllPoints()
                if data.originalParent then
                    button:SetParent(data.originalParent)
                end
                if data.originalPoints and #data.originalPoints > 0 then
                    for _, pointData in ipairs(data.originalPoints) do
                        button:SetPoint(unpack(pointData))
                    end
                end
                if data.originalSize then
                    button:SetSize(unpack(data.originalSize))
                end
            end
        end
    end
    self.buttonBar.buttons = {}
    self.buttonBar.collapsedAnchor = nil
    self.buttonBar.collapsedPoint = nil
    
    -- Make it draggable with CTRL+ALT or Move Mode
    local Movable = MidnightUI:GetModule("Movable", true)
    if Movable then
        -- Create wrapper database structure for arrow controls
        local arrowDB = {
            position = {
                point = db.buttonBarAnchor or "CENTER",
                x = db.buttonBarX or 0,
                y = db.buttonBarY or 0
            }
        }
        
        Movable:MakeFrameDraggable(self.buttonBar, function(point, x, y)
            local point, relativeTo, relativePoint, xOfs, yOfs = self.buttonBar:GetPoint()
            db.buttonBarAnchor = point or "CENTER"
            db.buttonBarX = xOfs or 0
            db.buttonBarY = yOfs or 0
            
            -- Sync with arrow DB
            arrowDB.position.point = db.buttonBarAnchor
            arrowDB.position.x = db.buttonBarX
            arrowDB.position.y = db.buttonBarY
        end, nil, "MB")
        
        -- Create small inline arrow nudge controls for button bar
        self.buttonBarNudge = Movable:CreateNudgeArrows(
            self.buttonBar,
            arrowDB,
            function()
                -- Reset callback - restore to default position
                arrowDB.position.point = "CENTER"
                arrowDB.position.x = 0
                arrowDB.position.y = 0
                
                db.buttonBarAnchor = "CENTER"
                db.buttonBarX = 0
                db.buttonBarY = 0
                
                self.buttonBar:ClearAllPoints()
                self.buttonBar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end,
            function(point, x, y)
                -- Update callback - sync arrow changes back to main DB
                db.buttonBarAnchor = point
                db.buttonBarX = x
                db.buttonBarY = y
            end
        )
        
        -- Sync arrow DB changes back to main DB
        self.buttonBarArrowDB = arrowDB
        
        if self.buttonBarNudge then
            Movable:RegisterNudgeFrame(self.buttonBarNudge, self.buttonBar)
        end
    end
    
    -- Collect minimap buttons
    self:CollectMinimapButtons()
    
    -- Start collapsed
    self:CollapseButtonBar()
    self.buttonBar:Show()
end

function Maps:CollectMinimapButtons()
    if not self.buttonBar then return end
    
    local db = self.db.profile
    local iconScale = db.buttonBarIconScale or 0.5
    local buttonSize = (db.buttonBarButtonSize or 32) * iconScale
    local buttonsPerRow = db.buttonBarButtonsPerRow or 1
    local growthDirection = db.buttonBarGrowthDirection or "right"
    local spacing = db.buttonBarSpacing or 2
    
    -- List of frames to ignore (Blizzard frames we handle separately)
    local ignoreList = {
        ["MinimapCluster"] = true,
        ["Minimap"] = true,
        ["MinimapBackdrop"] = true,
        ["GameTimeFrame"] = true,
        ["MinimapZoomIn"] = true,
        ["MinimapZoomOut"] = true,
        ["MiniMapTracking"] = true,
        ["MiniMapMailFrame"] = true,
        ["QueueStatusMinimapButton"] = true,
        ["ExpansionLandingPageMinimapButton"] = true,
        ["GarrisonLandingPageMinimapButton"] = true,
        ["MidnightUI_MinimapButtonBar"] = true,
        ["MidnightUI_MinimapDragOverlay"] = true,
    }
    
    -- Collect all frames parented to Minimap
    local buttons = {}
    for i = 1, Minimap:GetNumChildren() do
        local child = select(i, Minimap:GetChildren())
        if child and child:GetName() and not ignoreList[child:GetName()] then
            -- Check if it looks like a minimap button (don't require it to be a Button object type)
            if (child:IsShown() or child:GetWidth() > 0) and child:GetObjectType() ~= "Frame" then
                table.insert(buttons, child)
            end
        end
    end
    
    -- Arrange buttons
    for i, button in ipairs(buttons) do
        -- Store original parent and settings
        if not self.buttonBar.buttons[button] then
            self.buttonBar.buttons[button] = {
                originalParent = button:GetParent(),
                originalSize = {button:GetSize()},
                originalPoints = {},
            }
            -- Save original anchor points
            for j = 1, button:GetNumPoints() do
                local point, relativeTo, relativePoint, xOfs, yOfs = button:GetPoint(j)
                table.insert(self.buttonBar.buttons[button].originalPoints, {point, relativeTo, relativePoint, xOfs, yOfs})
            end
        end
        
        -- Reparent - don't resize yet
        button:SetParent(self.buttonBar)
        button:ClearAllPoints()
        button:EnableMouse(true)
        button:SetMovable(false)
        
        -- Use scale instead of SetSize to preserve button structure
        local originalWidth, originalHeight = button:GetSize()
        local scale = buttonSize / math.max(originalWidth, originalHeight)
        button:SetScale(iconScale)
        
        -- Calculate position based on growth direction
        local row = math.floor((i - 1) / buttonsPerRow)
        local col = (i - 1) % buttonsPerRow
        local effectiveSize = math.max(originalWidth, originalHeight) * iconScale
        local x, y
        local barWidth, barHeight = 5, 30
        
        if growthDirection == "right" then
            -- Buttons grow to the right from the bar
            x = barWidth / 2 + col * (effectiveSize + spacing) + spacing + effectiveSize / 2
            y = -row * (effectiveSize + spacing)
        elseif growthDirection == "left" then
            -- Buttons grow to the left from the bar
            x = -barWidth / 2 - col * (effectiveSize + spacing) - spacing - effectiveSize / 2
            y = -row * (effectiveSize + spacing)
        elseif growthDirection == "down" then
            -- Buttons grow downward from the bar
            x = col * (effectiveSize + spacing)
            y = -barHeight / 2 - row * (effectiveSize + spacing) - spacing - effectiveSize / 2
        elseif growthDirection == "up" then
            -- Buttons grow upward from the bar
            x = col * (effectiveSize + spacing)
            y = barHeight / 2 + row * (effectiveSize + spacing) + spacing + effectiveSize / 2
        end
        
        button:SetPoint("CENTER", self.buttonBar, "CENTER", x, y)
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(self.buttonBar:GetFrameLevel() + 10)
        
        -- Force button to be visible and interactable
        button:Show()
        button:EnableMouse(true)
        button:SetAlpha(1)
        
        -- Add OnEnter/OnLeave to buttons to prevent collapse (only once per button)
        if not button._midnightUIButtonBarHooked then
            button:HookScript("OnEnter", function()
                if Maps.buttonBar and Maps.buttonBar.collapseTimer then
                    Maps.buttonBar.collapseTimer:Cancel()
                    Maps.buttonBar.collapseTimer = nil
                end
            end)
            button:HookScript("OnLeave", function()
                -- Start collapse timer when leaving a button
                if Maps.buttonBar and Maps.buttonBar.collapseTimer then
                    Maps.buttonBar.collapseTimer:Cancel()
                end
                if Maps.buttonBar then
                    Maps.buttonBar.collapseTimer = C_Timer.NewTimer(0.3, function()
                        Maps:CollapseButtonBar()
                        if Maps.buttonBar then
                            Maps.buttonBar.collapseTimer = nil
                        end
                    end)
                end
            end)
            button._midnightUIButtonBarHooked = true
        end
    end
    
    -- Calculate bar size when expanded (use effectiveSize for calculations)
    local numButtons = #buttons
    if numButtons > 0 then
        local rows = math.ceil(numButtons / buttonsPerRow)
        local cols = math.min(numButtons, buttonsPerRow)
        -- Use a more accurate size calculation based on actual button sizes
        local effectiveSize = buttonSize
        self.buttonBar.expandedWidth = cols * (effectiveSize + spacing) + spacing
        self.buttonBar.expandedHeight = rows * (effectiveSize + spacing) + spacing
    else
        self.buttonBar.expandedWidth = 100
        self.buttonBar.expandedHeight = 100
    end
    
    -- Store the growth direction for use in expand/collapse
    self.buttonBar.growthDirection = growthDirection
    
    -- Reset the cached anchor so it recalculates on next expand
    self.buttonBar.collapsedAnchor = nil
end

function Maps:ExpandButtonBar()
    if not self.buttonBar or self.buttonBar.isExpanded then return end
    
    -- Cancel any pending collapse
    if self.buttonBar.collapseTimer then
        self.buttonBar.collapseTimer:Cancel()
        self.buttonBar.collapseTimer = nil
    end
    
    local db = self.db.profile
    
    self.buttonBar.isExpanded = true
    
    -- Don't resize the frame at all - keep it at collapsed size
    -- Buttons are positioned relative to CENTER with proper offsets, so they appear correctly
    
    -- Don't show backdrop unless in move mode
    
    -- Show all buttons
    for button, data in pairs(self.buttonBar.buttons) do
        if button then button:Show() end
    end
end

function Maps:CollapseButtonBar()
    if not self.buttonBar then return end
    
    self.buttonBar.isExpanded = false
    self.buttonBar:SetSize(5, 30)
    
    -- Hide buttonBar backdrop when collapsed
    self.buttonBar:SetBackdropColor(0, 0, 0, 0)
    self.buttonBar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0)
    
    -- Tab is always shown, move mode controls backdrop visibility
    
    -- Hide all buttons when collapsed
    for button, data in pairs(self.buttonBar.buttons) do
        if button then button:Hide() end
    end
end

function Maps:UpdateButtonBarColor()
    if not self.buttonBarTab or not self.buttonBarTab.bar then return end
    
    local db = self.db.profile
    local r, g, b, a
    
    if db.buttonBarUseClassColor then
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            r, g, b, a = classColor.r, classColor.g, classColor.b, 1
        else
            r, g, b, a = 0.5, 0.5, 0.5, 1
        end
    else
        local c = db.buttonBarColor or { r = 0.5, g = 0.5, b = 0.5, a = 1 }
        r, g, b, a = c.r, c.g, c.b, c.a
    end
    
    self.buttonBarTab.bar:SetVertexColor(r, g, b, a)
end

function Maps:GetOptions()
    return {
        type = "group",
        name = "Maps",
        order = 10,
        get = function(info) return self.db.profile[info[#info]] end,
        set = function(info, value) 
            self.db.profile[info[#info]] = value
            if info[#info] == "shape" then
                -- Changing shape requires a reload
                ReloadUI()
            else
                self:UpdateLayout()
            end
        end,
        args = {
            headerShape = { type = "header", name = "Appearance", order = 1},
            shape = {
                name = "Map Shape (Requires /reload)",
                type = "select",
                order = 2,
                values = {SQUARE = "Square", ROUND = "Round"},
            },
            autoZoom = {
                name = "Auto Zoom Out",
                type = "toggle",
                order = 4,
            },
            positionNote = {
                name = "|cffaaaaaa(Use Blizzard Edit Mode to move MinimapCluster)\nThen hold CTRL+ALT and drag OR use /muimove to enable Move Mode\nUse nudge arrows for pixel-perfect positioning|r",
                type = "description",
                order = 5,
                fontSize = "medium",
            },
            
            headerPosition = { type = "header", name = "Position Fine-Tuning", order = 6},
            offsetX = {
                name = "Horizontal Offset",
                desc = "Manual horizontal offset (or drag minimap with CTRL+ALT / Move Mode)",
                type = "range",
                order = 7,
                min = -200,
                max = 200,
                step = 1,
                set = function(info, value)
                    self.db.profile.offsetX = value
                    self:UpdateLayout()
                    self:UpdateNudgeDisplay()
                end
            },
            offsetY = {
                name = "Vertical Offset",
                desc = "Manual vertical offset (or drag minimap with CTRL+ALT / Move Mode)",
                type = "range",
                order = 8,
                min = -200,
                max = 200,
                step = 1,
                set = function(info, value)
                    self.db.profile.offsetY = value
                    self:UpdateLayout()
                    self:UpdateNudgeDisplay()
                end
            },
            resetOffsets = {
                name = "Reset Offsets",
                desc = "Reset position offsets to 0",
                type = "execute",
                order = 9,
                func = function()
                    self.db.profile.offsetX = 0
                    self.db.profile.offsetY = 0
                    self:UpdateLayout()
                    self:UpdateNudgeDisplay()
                end
            },
            
            headerText = { type = "header", name = "Text Overlay", order = 10},
            showClock = { 
                name = "Show Clock", 
                type = "toggle", 
                order = 11,
                set = function(_, v) self.db.profile.showClock = v; self:UpdateLayout() end
            },
            showZone = { 
                name = "Show Zone Text", 
                type = "toggle", 
                order = 12,
                set = function(_, v) self.db.profile.showZone = v; self:UpdateLayout() end
            },
            showCoords = { 
                name = "Show Coordinates", 
                type = "toggle", 
                order = 13,
                set = function(_, v) self.db.profile.showCoords = v; self:UpdateLayout() end
            },
            
            headerIcons = { type = "header", name = "Icons & Buttons", order = 20},
            showCalendar = { 
                name = "Calendar", 
                type = "toggle", 
                order = 21,
                set = function(_, v) self.db.profile.showCalendar = v; self:UpdateLayout() end
            },
            showTracking = { 
                name = "Tracking", 
                type = "toggle", 
                order = 22,
                set = function(_, v) self.db.profile.showTracking = v; self:UpdateLayout() end
            },
            showMail = { 
                name = "Mail", 
                type = "toggle", 
                order = 23,
                set = function(_, v) self.db.profile.showMail = v; self:UpdateLayout() end
            },
            mailOffsetX = {
                type = "range",
                name = "Mail Icon X Offset",
                desc = "Horizontal offset from top-right of minimap. Negative = left.",
                min = -200, max = 200, step = 1,
                order = 23.1,
                get = function() return self.db.profile.mailOffsetX or -25 end,
                set = function(_, v) self.db.profile.mailOffsetX = v; self:UpdateLayout() end,
            },
            mailOffsetY = {
                type = "range",
                name = "Mail Icon Y Offset",
                desc = "Vertical offset from top-right of minimap. Negative = down.",
                min = -200, max = 200, step = 1,
                order = 23.2,
                get = function() return self.db.profile.mailOffsetY or -25 end,
                set = function(_, v) self.db.profile.mailOffsetY = v; self:UpdateLayout() end,
            },
            showMissions = { 
                name = "Missions / Landing Page", 
                type = "toggle", 
                order = 24,
                set = function(_, v) self.db.profile.showMissions = v; self:UpdateLayout() end
            },
            showQueue = { 
                name = "LFG / PvP Queue", 
                type = "toggle", 
                order = 25,
                set = function(_, v) self.db.profile.showQueue = v; self:UpdateLayout() end
            },
            showDifficulty = { 
                name = "Instance Difficulty", 
                type = "toggle", 
                order = 26,
                set = function(_, v) self.db.profile.showDifficulty = v; self:UpdateLayout() end
            },
            difficultyOffsetX = {
                type = "range",
                name = "Difficulty Icon X Offset",
                desc = "Horizontal offset from top-right of minimap. Negative = left.",
                min = -200, max = 200, step = 1,
                order = 26.1,
                get = function() return self.db.profile.difficultyOffsetX or -65 end,
                set = function(_, v) self.db.profile.difficultyOffsetX = v; self:UpdateLayout() end,
            },
            difficultyOffsetY = {
                type = "range",
                name = "Difficulty Icon Y Offset",
                desc = "Vertical offset from top-right of minimap. Negative = down.",
                min = -200, max = 200, step = 1,
                order = 26.2,
                get = function() return self.db.profile.difficultyOffsetY or -5 end,
                set = function(_, v) self.db.profile.difficultyOffsetY = v; self:UpdateLayout() end,
            },
            
            headerButtonBar = { type = "header", name = "Minimap Button Bar", order = 30},
            buttonBarEnabled = {
                name = "Enable Button Bar",
                desc = "Collect addon minimap buttons into an expandable bar",
                type = "toggle",
                order = 31,
                get = function() return self.db.profile.buttonBarEnabled end,
                set = function(_, v) self.db.profile.buttonBarEnabled = v; self:SetupButtonBar() end,
            },
            buttonBarAnchor = {
                name = "Anchor Point",
                type = "select",
                values = {
                    TOPLEFT = "Top Left",
                    TOPRIGHT = "Top Right",
                    BOTTOMLEFT = "Bottom Left",
                    BOTTOMRIGHT = "Bottom Right",
                    TOP = "Top",
                    BOTTOM = "Bottom",
                    LEFT = "Left",
                    RIGHT = "Right",
                },
                order = 32,
                get = function() return self.db.profile.buttonBarAnchor or "TOPRIGHT" end,
                set = function(_, v) self.db.profile.buttonBarAnchor = v; self:SetupButtonBar() end,
            },
            buttonBarX = {
                type = "range",
                name = "X Offset",
                min = -500, max = 500, step = 1,
                order = 33,
                get = function() return self.db.profile.buttonBarX or 0 end,
                set = function(_, v) self.db.profile.buttonBarX = v; self:SetupButtonBar() end,
            },
            buttonBarY = {
                type = "range",
                name = "Y Offset",
                min = -500, max = 500, step = 1,
                order = 34,
                get = function() return self.db.profile.buttonBarY or -200 end,
                set = function(_, v) self.db.profile.buttonBarY = v; self:SetupButtonBar() end,
            },
            buttonBarButtonSize = {
                type = "range",
                name = "Button Size",
                min = 16, max = 48, step = 1,
                order = 35,
                get = function() return self.db.profile.buttonBarButtonSize or 32 end,
                set = function(_, v) self.db.profile.buttonBarButtonSize = v; self:SetupButtonBar() end,
            },
            buttonBarButtonsPerRow = {
                type = "range",
                name = "Buttons Per Row",
                min = 1, max = 10, step = 1,
                order = 36,
                get = function() return self.db.profile.buttonBarButtonsPerRow or 1 end,
                set = function(_, v) self.db.profile.buttonBarButtonsPerRow = v; self:SetupButtonBar() end,
            },
            buttonBarCollapsedSize = {
                type = "range",
                name = "Collapsed Tab Size",
                min = 10, max = 40, step = 1,
                order = 37,
                get = function() return self.db.profile.buttonBarCollapsedSize or 20 end,
                set = function(_, v) self.db.profile.buttonBarCollapsedSize = v; self:SetupButtonBar() end,
            },
            buttonBarGrowthDirection = {
                name = "Growth Direction",
                desc = "Direction the bar expands when showing icons",
                type = "select",
                values = {
                    right = "Right",
                    left = "Left",
                    down = "Down",
                    up = "Up",
                },
                order = 38,
                get = function() return self.db.profile.buttonBarGrowthDirection or "right" end,
                set = function(_, v) self.db.profile.buttonBarGrowthDirection = v; self:SetupButtonBar() end,
            },
            buttonBarIconScale = {
                type = "range",
                name = "Icon Scale",
                desc = "Scale of minimap icons in the button bar (50% = half size)",
                min = 0.25, max = 1.5, step = 0.05,
                order = 39,
                get = function() return self.db.profile.buttonBarIconScale or 0.5 end,
                set = function(_, v) self.db.profile.buttonBarIconScale = v; self:SetupButtonBar() end,
            },
            buttonBarSpacing = {
                type = "range",
                name = "Button Spacing",
                desc = "Space between buttons in pixels",
                min = 0, max = 10, step = 1,
                order = 40,
                get = function() return self.db.profile.buttonBarSpacing or 2 end,
                set = function(_, v) self.db.profile.buttonBarSpacing = v; self:SetupButtonBar() end,
            },
            buttonBarUseClassColor = {
                name = "Use Class Color",
                desc = "Use your class color for the button bar",
                type = "toggle",
                order = 41,
                get = function() return self.db.profile.buttonBarUseClassColor end,
                set = function(_, v) self.db.profile.buttonBarUseClassColor = v; self:UpdateButtonBarColor() end,
            },
            buttonBarColor = {
                name = "Bar Color",
                desc = "Color of the button bar tab",
                type = "color",
                hasAlpha = true,
                order = 42,
                disabled = function() return self.db.profile.buttonBarUseClassColor end,
                get = function()
                    local c = self.db.profile.buttonBarColor or { r = 0.5, g = 0.5, b = 0.5, a = 1 }
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.buttonBarColor = { r = r, g = g, b = b, a = a }
                    self:UpdateButtonBarColor()
                end,
            },
        }
    }
end