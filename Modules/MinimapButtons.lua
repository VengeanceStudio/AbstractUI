local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local MinimapButtons = AbstractUI:NewModule("MinimapButtons", "AceEvent-3.0")

-- -----------------------------------------------------------------------------
-- DATABASE DEFAULTS
-- -----------------------------------------------------------------------------
local defaults = {
    profile = {
        -- Button Bar
        anchor = "CENTER",
        x = 0,
        y = 0,
        collapsedSize = 20,
        buttonSize = 32,
        buttonsPerRow = 1,
        color = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
        useClassColor = false,
        growthDirection = "right",
        iconScale = 0.5,
        spacing = 2,
    }
}

-- -----------------------------------------------------------------------------
-- INITIALIZATION
-- -----------------------------------------------------------------------------
function MinimapButtons:OnInitialize()
    self:RegisterMessage("AbstractUI_DB_READY", "OnDBReady")
    
    -- Register slash command for manual collection
    SLASH_MINIMAPBUTTONS1 = "/collectbuttons"
    SLASH_MINIMAPBUTTONS2 = "/mbb"
    SlashCmdList["MINIMAPBUTTONS"] = function(msg)
        if MinimapButtons.buttonBar then
            MinimapButtons:CollectMinimapButtons()
        end
    end
end

function MinimapButtons:OnDBReady()
    if not AbstractUI.db or not AbstractUI.db.profile or not AbstractUI.db.profile.modules then
        self:Disable()
        return
    end
    
    if not AbstractUI.db.profile.modules.minimapButtons then 
        self:Disable()
        return 
    end
    
    self.db = AbstractUI.db:RegisterNamespace("MinimapButtons", defaults)
    
    -- Setup button bar after DB is ready
    self:SetupButtonBar()
end

function MinimapButtons:OnEnable()
    -- OnEnable is called before DB is ready, so we do nothing here
    -- SetupButtonBar is called from OnDBReady instead
end

function MinimapButtons:OnDisable()
    if self.buttonBar then
        self.buttonBar:Hide()
    end
end

-- -----------------------------------------------------------------------------
-- BUTTON SKINNING
-- -----------------------------------------------------------------------------
function MinimapButtons:SkinMinimapButton(button)
    if not button then return end
    
    -- Only skin once
    if button._abstractSkinned then return end
    button._abstractSkinned = true
    
    -- Texture IDs to remove (circular borders from LibDBIcon)
    local RemoveTextureID = {
        ['136430'] = true,  -- LibDBIcon border pieces
        ['136467'] = true,
        ['136477'] = true,
        ['136468'] = true,
        ['130924'] = true,
        ['982840'] = true
    }
    
    local icon = nil
    
    -- Process button AND all its children (like ProjectAzilroka does)
    for _, frame in pairs({ button, button:GetChildren() }) do
        for _, region in pairs({ frame:GetRegions() }) do
            if region:IsObjectType('Texture') then
                local texture = region.GetTextureFileID and region:GetTextureFileID() or region.GetTexture and region:GetTexture()
                local textureStr = tostring(texture)
                
                if texture and RemoveTextureID[textureStr] then
                    -- Remove circular border textures completely
                    region:SetTexture()
                    region:SetAlpha(0)
                elseif texture then
                    -- This is the icon - style it
                    icon = region
                    region:ClearAllPoints()
                    region:SetDrawLayer('ARTWORK')
                    
                    -- Apply border insets
                    local borderThickness = 2
                    region:SetPoint("TOPLEFT", button, "TOPLEFT", borderThickness, -borderThickness)
                    region:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -borderThickness, borderThickness)
                    
                    -- Apply square cropping (1% crop on each side)
                    region:SetTexCoord(0.01, 0.99, 0.01, 0.99)
                    
                    -- Prevent the region from being moved
                    region.SetPoint = function() return end
                end
            end
        end
    end
    
    -- Also hide specific LibDBIcon border property (check if it's an actual texture object)
    if button.border and type(button.border) == "table" and button.border.SetTexture then 
        button.border:SetTexture()
        button.border:SetAlpha(0)
    end
    
    -- Add custom background FIRST (lowest layer)
    if not button._abstractBackground then
        button._abstractBackground = button:CreateTexture(nil, "BACKGROUND")
        button._abstractBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
        local borderThickness = 2
        button._abstractBackground:SetPoint("TOPLEFT", button, "TOPLEFT", borderThickness, -borderThickness)
        button._abstractBackground:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -borderThickness, borderThickness)
        button._abstractBackground:SetVertexColor(0.05, 0.05, 0.05, 0.65)  -- Transparent grey background
        button._abstractBackground:SetDrawLayer("BACKGROUND", -8)
    end
    
    -- Add custom border (on BORDER layer - below ARTWORK where icons are)
    if not button._abstractBorder then
        button._abstractBorder = button:CreateTexture(nil, "BORDER")
        button._abstractBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
        button._abstractBorder:SetAllPoints(button)
        -- Make border semi-transparent to see background
        button._abstractBorder:SetVertexColor(0, 0, 0, 0.5)
    end
end

-- -----------------------------------------------------------------------------
-- BUTTON BAR SETUP
-- -----------------------------------------------------------------------------
function MinimapButtons:SetupButtonBar()
    local db = self.db.profile
    
    -- Create button bar frame if it doesn't exist
    if not self.buttonBar then
        self.buttonBar = CreateFrame("Frame", "AbstractUI_MinimapButtonBar", UIParent, "BackdropTemplate")
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
        
        -- Show the tab
        self.buttonBarTab:Show()
        
        -- Create collapse timer
        self.buttonBar.collapseTimer = nil
        
        -- Hover handlers with delay
        self.buttonBar:SetScript("OnEnter", function(self)
            -- Cancel any pending collapse
            if MinimapButtons.buttonBar.collapseTimer then
                MinimapButtons.buttonBar.collapseTimer:Cancel()
                MinimapButtons.buttonBar.collapseTimer = nil
            end
            MinimapButtons:ExpandButtonBar()
        end)
        self.buttonBar:SetScript("OnLeave", function(self)
            -- Delay collapse by 0.3 seconds
            if MinimapButtons.buttonBar.collapseTimer then
                MinimapButtons.buttonBar.collapseTimer:Cancel()
            end
            MinimapButtons.buttonBar.collapseTimer = C_Timer.NewTimer(0.3, function()
                -- Check if mouse is over any button before collapsing
                local mouseOver = false
                if MinimapButtons.buttonBar then
                    for button, data in pairs(MinimapButtons.buttonBar.buttons) do
                        if button and button:IsMouseOver() then
                            mouseOver = true
                            break
                        end
                    end
                end
                if not mouseOver then
                    MinimapButtons:CollapseButtonBar()
                end
                MinimapButtons.buttonBar.collapseTimer = nil
            end)
        end)
        
        self.buttonBar.buttons = {}
        self.buttonBar.isExpanded = false
        
        -- Initialize with bar size (5x30)
        self.buttonBar:SetSize(5, 30)
    end
    
    -- Position the bar
    self.buttonBar:ClearAllPoints()
    self.buttonBar:SetPoint(db.anchor or "CENTER", UIParent, db.anchor or "CENTER", db.x or 0, db.y or 0)
    
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
    local Movable = AbstractUI:GetModule("Movable", true)
    if Movable then
        -- Create wrapper database structure for arrow controls
        local arrowDB = {
            position = {
                point = db.anchor or "CENTER",
                x = db.x or 0,
                y = db.y or 0
            }
        }
        
        Movable:MakeFrameDraggable(self.buttonBar, function(point, x, y)
            local point, relativeTo, relativePoint, xOfs, yOfs = self.buttonBar:GetPoint()
            db.anchor = point or "CENTER"
            db.x = xOfs or 0
            db.y = yOfs or 0
            
            -- Sync with arrow DB
            arrowDB.position.point = db.anchor
            arrowDB.position.x = db.x
            arrowDB.position.y = db.y
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
                
                db.anchor = "CENTER"
                db.x = 0
                db.y = 0
                
                self.buttonBar:ClearAllPoints()
                self.buttonBar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end,
            function(point, x, y)
                -- Update callback - sync arrow changes back to main DB
                db.anchor = point
                db.x = x
                db.y = y
            end
        )
        
        -- Sync arrow DB changes back to main DB
        self.buttonBarArrowDB = arrowDB
        
        if self.buttonBarNudge then
            Movable:RegisterNudgeFrame(self.buttonBarNudge, self.buttonBar)
        end
    end
    
    -- Don't collect immediately - wait for all addons to load their buttons
    -- Danders Frames creates its button 1 second after PLAYER_LOGIN
    -- So we wait 2 seconds after setup to catch late-loading addon buttons
    C_Timer.After(2, function()
        if self.buttonBar then
            self:CollectMinimapButtons()
        end
    end)
    
    -- Start collapsed
    self:CollapseButtonBar()
    self.buttonBar:Show()
end

-- -----------------------------------------------------------------------------
-- BUTTON COLLECTION
-- -----------------------------------------------------------------------------
function MinimapButtons:CollectMinimapButtons()
    if not self.buttonBar then return end
    
    local db = self.db.profile
    local iconScale = db.iconScale or 0.5
    local buttonSize = (db.buttonSize or 32) * iconScale
    local buttonsPerRow = db.buttonsPerRow or 1
    local growthDirection = db.growthDirection or "right"
    local spacing = db.spacing or 2
    
    -- List of frames to ignore (Blizzard frames we handle separately)
    local ignoreList = {
        ["MinimapCluster"] = true,
        ["Minimap"] = true,
        ["MinimapBackdrop"] = true,
        ["GameTimeFrame"] = true,
        ["TimeManagerClockButton"] = true,
        ["MinimapZoomIn"] = true,
        ["MinimapZoomOut"] = true,
        ["MiniMapTracking"] = true,
        ["MiniMapTrackingFrame"] = true,
        ["MiniMapMailFrame"] = true,
        ["MiniMapBattlefieldFrame"] = true,
        ["MiniMapWorldMapButton"] = true,
        ["QueueStatusMinimapButton"] = true,
        ["ExpansionLandingPageMinimapButton"] = true,
        ["GarrisonLandingPageMinimapButton"] = true,
        ["MiniMapInstanceDifficulty"] = true,
        ["GuildInstanceDifficulty"] = true,
        ["MiniMapChallengeMode"] = true,
        ["AbstractUI_MinimapButtonBar"] = true,
        ["AbstractUI_MinimapDragOverlay"] = true,
        ["MinimapBorder"] = true,
        ["MinimapBorderTop"] = true,
        ["MinimapToggleButton"] = true,
        ["MinimapZoneTextButton"] = true,
    }
    
    -- Collect minimap buttons using proven MBB approach
    -- Check for actual interaction scripts rather than just mouse-enabled status
    local buttons = {}
    
    -- Helper function to check if frame has interaction scripts
    local function HasInteractionScript(frame)
        -- Check for click/mouse interaction scripts (actual scripts, not just capability)
        local hasClick = frame:HasScript("OnClick") and frame:GetScript("OnClick") ~= nil
        local hasMouseUp = frame:HasScript("OnMouseUp") and frame:GetScript("OnMouseUp") ~= nil
        local hasMouseDown = frame:HasScript("OnMouseDown") and frame:GetScript("OnMouseDown") ~= nil
        
        if hasClick then
            return true, "has OnClick"
        elseif hasMouseUp then
            return true, "has OnMouseUp"
        elseif hasMouseDown then
            return true, "has OnMouseDown"
        else
            return false, "no interaction scripts"
        end
    end
    
    -- Collect children from Minimap, MinimapBackdrop, and MinimapCluster
    local children = {Minimap:GetChildren()}
    
    if MinimapBackdrop then
        local additional = {MinimapBackdrop:GetChildren()}
        for _, child in ipairs(additional) do
            table.insert(children, child)
        end
    end
    
    if MinimapCluster then
        local clusterChildren = {MinimapCluster:GetChildren()}
        for _, child in ipairs(clusterChildren) do
            -- Avoid duplicates
            local isDuplicate = false
            for _, existing in ipairs(children) do
                if existing == child then
                    isDuplicate = true
                    break
                end
            end
            if not isDuplicate then
                table.insert(children, child)
            end
        end
    end
    
    -- Process each child frame
    for _, child in ipairs(children) do
        local name = child:GetName()
        
        if name and ignoreList[name] then
            -- Ignore this frame
        else
            local frameToCollect = child
            local hasScript, reason = HasInteractionScript(frameToCollect)
            
            -- Smart parent/child handling: If this frame doesn't have OnClick but a child does, use the child
            if not hasScript then
                local subchildren = {frameToCollect:GetChildren()}
                if #subchildren > 0 then
                    for i, subchild in ipairs(subchildren) do
                        local subName = subchild:GetName()
                        
                        -- Don't use subchildren that are in the ignore list!
                        if not (subName and ignoreList[subName]) then
                            local subHasScript, subReason = HasInteractionScript(subchild)
                            if subHasScript then
                                frameToCollect = subchild
                                hasScript = true
                                break
                            end
                        end
                    end
                end
            end
            
            -- Only collect frames with a name (or LibDBIcon pattern)
            -- Unnamed frames are usually Blizzard UI elements we don't want
            if hasScript and name then
                table.insert(buttons, frameToCollect)
            end
        end
    end
    
    -- Arrange buttons
    for i, button in ipairs(buttons) do
        -- Store original parent and settings
        self.buttonBar.buttons[button] = {
            originalParent = button:GetParent(),
            originalPoints = {},
            originalSize = { button:GetSize() },
        }
        
        -- Reparent to button bar
        button:SetParent(self.buttonBar)
        button:ClearAllPoints()
        
        -- Disable any LibDBIcon repositioning scripts
        button:SetScript("OnDragStart", nil)
        button:SetScript("OnDragStop", nil)
        
        -- Apply uniform scale to maintain aspect ratio
        button:SetScale(iconScale)
        
        -- Force consistent size (some addons like Zygor use non-standard sizes)
        local standardSize = db.buttonSize or 32
        button:SetSize(standardSize, standardSize)
        
        -- Skin the button BEFORE positioning to ensure proper sizing
        self:SkinMinimapButton(button)
        
        -- Calculate position based on growth direction
        local row = math.floor((i - 1) / buttonsPerRow)
        local col = (i - 1) % buttonsPerRow
        local originalWidth, originalHeight = button:GetSize()
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
        
        -- Store intended position and size for enforcement
        button._abstractIntendedPosition = {x = x, y = y}
        button._abstractIntendedSize = {width = standardSize, height = standardSize}
        
        -- AGGRESSIVE POSITION LOCKING - prevent any repositioning
        if not button._abstractPositionLocked then
            -- Save original functions before overriding
            button._abstractOriginalSetSize = button.SetSize
            button._abstractOriginalSetWidth = button.SetWidth
            button._abstractOriginalSetHeight = button.SetHeight
            button._abstractOriginalSetPoint = button.SetPoint
            button._abstractOriginalClearAllPoints = button.ClearAllPoints
            
            -- Override SetPoint to ONLY allow our exact positioning
            button.SetPoint = function(self, ...)
                local point, relativeTo, relativePoint, xOfs, yOfs = ...
                -- Only allow CENTER point to our buttonBar with exact offsets
                if relativeTo == MinimapButtons.buttonBar and point == "CENTER" and 
                   button._abstractIntendedPosition and
                   math.abs((xOfs or 0) - button._abstractIntendedPosition.x) < 0.5 and
                   math.abs((yOfs or 0) - button._abstractIntendedPosition.y) < 0.5 then
                    button._abstractOriginalSetPoint(self, ...)
                end
                -- Silently ignore all other SetPoint attempts
            end
            
            -- Override ClearAllPoints to immediately restore position
            button.ClearAllPoints = function(self)
                button._abstractOriginalClearAllPoints(self)
                if button._abstractIntendedPosition then
                    button._abstractOriginalSetPoint(self, "CENTER", MinimapButtons.buttonBar, "CENTER", 
                        button._abstractIntendedPosition.x, button._abstractIntendedPosition.y)
                end
            end
            
            -- Override SetAllPoints to prevent full-frame anchoring
            button.SetAllPoints = function(self, ...)
                -- Completely ignore SetAllPoints - buttons shouldn't fill anything
            end
            
            -- Override size functions to enforce our size
            button.SetSize = function(self, w, h)
                if button._abstractIntendedSize then
                    button._abstractOriginalSetSize(self, button._abstractIntendedSize.width, button._abstractIntendedSize.height)
                end
            end
            
            button.SetWidth = function(self, w)
                if button._abstractIntendedSize then
                    button._abstractOriginalSetWidth(self, button._abstractIntendedSize.width)
                end
            end
            
            button.SetHeight = function(self, h)
                if button._abstractIntendedSize then
                    button._abstractOriginalSetHeight(self, button._abstractIntendedSize.height)
                end
            end
            
            -- Disable movability completely
            button.SetMovable = function() end
            button.StartMoving = function() end
            button.StopMovingOrSizing = function() end
            
            button._abstractPositionLocked = true
        end
        
        -- Force button to be visible and interactable
        button:Show()
        button:EnableMouse(true)
        button:SetAlpha(1)
        
        -- Add OnEnter/OnLeave to buttons to prevent collapse (only once per button)
        if not button._AbstractUIButtonBarHooked then
            button:HookScript("OnEnter", function()
                if MinimapButtons.buttonBar and MinimapButtons.buttonBar.collapseTimer then
                    MinimapButtons.buttonBar.collapseTimer:Cancel()
                    MinimapButtons.buttonBar.collapseTimer = nil
                end
            end)
            button:HookScript("OnLeave", function()
                -- Start collapse timer when leaving a button
                if MinimapButtons.buttonBar and MinimapButtons.buttonBar.collapseTimer then
                    MinimapButtons.buttonBar.collapseTimer:Cancel()
                end
                if MinimapButtons.buttonBar then
                    MinimapButtons.buttonBar.collapseTimer = C_Timer.NewTimer(0.3, function()
                        MinimapButtons:CollapseButtonBar()
                        if MinimapButtons.buttonBar then
                            MinimapButtons.buttonBar.collapseTimer = nil
                        end
                    end)
                end
            end)
            button._AbstractUIButtonBarHooked = true
        end
    end
    
    -- Calculate bar size when expanded (use effectiveSize for calculations)
    local numButtons = #buttons
    if numButtons > 0 then
        local rows = math.ceil(numButtons / buttonsPerRow)
        local cols = math.min(numButtons, buttonsPerRow)
        -- Use a more accurate size calculation based on actual button sizes
        local firstButton = buttons[1]
        local buttonWidth, buttonHeight = firstButton:GetSize()
        local effectiveSize = math.max(buttonWidth, buttonHeight) * iconScale
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

-- -----------------------------------------------------------------------------
-- EXPAND/COLLAPSE
-- -----------------------------------------------------------------------------
function MinimapButtons:ExpandButtonBar()
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

function MinimapButtons:CollapseButtonBar()
    if not self.buttonBar then return end
    
    self.buttonBar.isExpanded = false
    self.buttonBar:SetSize(5, 30)
    
    -- Hide buttonBar backdrop when collapsed
    self.buttonBar:SetBackdropColor(0, 0, 0, 0)
    self.buttonBar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0)
    
    -- Ensure tab is visible when collapsed
    if self.buttonBarTab then
        self.buttonBarTab:Show()
    end
    
    -- Hide all buttons when collapsed
    for button, data in pairs(self.buttonBar.buttons) do
        if button then button:Hide() end
    end
    local db = self.db.profile
    local r, g, b, a
    
    if db.useClassColor then
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            r, g, b, a = classColor.r, classColor.g, classColor.b, 1
        else
            r, g, b, a = 0.5, 0.5, 0.5, 1
        end
    else
        local c = db.color or { r = 0.5, g = 0.5, b = 0.5, a = 1 }
        r, g, b, a = c.r, c.g, c.b, c.a
    end
    
    self.buttonBarTab.bar:SetVertexColor(r, g, b, a)
end

-- -----------------------------------------------------------------------------
-- COLOR UPDATE
-- -----------------------------------------------------------------------------
function MinimapButtons:UpdateButtonBarColor()
    if not self.buttonBarTab or not self.buttonBarTab.bar then return end
    
    local db = self.db.profile
    local r, g, b, a
    
    if db.useClassColor then
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            r, g, b, a = classColor.r, classColor.g, classColor.b, 1
        else
            r, g, b, a = 0.5, 0.5, 0.5, 1
        end
    else
        local c = db.color or { r = 0.5, g = 0.5, b = 0.5, a = 1 }
        r, g, b, a = c.r, c.g, c.b, c.a
    end
    
    self.buttonBarTab.bar:SetVertexColor(r, g, b, a)
end

-- -----------------------------------------------------------------------------
-- OPTIONS
-- -----------------------------------------------------------------------------
function MinimapButtons:GetOptions()
    return {
        type = "group",
        name = "Minimap Button Bar",
        order = 11,
        get = function(info) return self.db.profile[info[#info]] end,
        set = function(info, value) 
            self.db.profile[info[#info]] = value
            self:SetupButtonBar()
        end,
        args = {
            header = { type = "header", name = "Minimap Button Bar", order = 1},
            
            headerPosition = { type = "header", name = "Position", order = 10},
            positionNote = {
                name = "|cffaaaaaa(Hold CTRL+ALT and drag OR use /auimove to enable Move Mode)\nUse nudge arrows for pixel-perfect positioning|r",
                type = "description",
                order = 11,
                fontSize = "medium",
            },
            anchor = {
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
                    CENTER = "Center",
                },
                order = 12,
                get = function() return self.db.profile.anchor or "CENTER" end,
                set = function(_, v) self.db.profile.anchor = v; self:SetupButtonBar() end,
            },
            x = {
                type = "range",
                name = "X Offset",
                width = "inline",
                min = -500, max = 500, step = 1,
                order = 13,
                get = function() return self.db.profile.x or 0 end,
                set = function(_, v) self.db.profile.x = v; self:SetupButtonBar() end,
            },
            y = {
                type = "range",
                name = "Y Offset",
                width = "inline",
                min = -500, max = 500, step = 1,
                order = 14,
                get = function() return self.db.profile.y or 0 end,
                set = function(_, v) self.db.profile.y = v; self:SetupButtonBar() end,
            },
            
            headerLayout = { type = "header", name = "Layout", order = 20},
            buttonSize = {
                type = "range",
                name = "Button Size",
                width = "inline",
                min = 16, max = 48, step = 1,
                order = 21,
                get = function() return self.db.profile.buttonSize or 32 end,
                set = function(_, v) self.db.profile.buttonSize = v; self:SetupButtonBar() end,
            },
            buttonsPerRow = {
                type = "range",
                name = "Buttons Per Row",
                width = "inline",
                min = 1, max = 10, step = 1,
                order = 22,
                get = function() return self.db.profile.buttonsPerRow or 1 end,
                set = function(_, v) self.db.profile.buttonsPerRow = v; self:SetupButtonBar() end,
            },
            collapsedSize = {
                type = "range",
                name = "Collapsed Tab Size",
                width = "inline",
                min = 10, max = 40, step = 1,
                order = 23,
                get = function() return self.db.profile.collapsedSize or 20 end,
                set = function(_, v) self.db.profile.collapsedSize = v; self:SetupButtonBar() end,
            },
            growthDirection = {
                name = "Growth Direction",
                desc = "Direction the bar expands when showing icons",
                type = "select",
                values = {
                    right = "Right",
                    left = "Left",
                    down = "Down",
                    up = "Up",
                },
                order = 24,
                get = function() return self.db.profile.growthDirection or "right" end,
                set = function(_, v) self.db.profile.growthDirection = v; self:SetupButtonBar() end,
            },
            iconScale = {
                type = "range",
                name = "Icon Scale",
                desc = "Scale of minimap icons in the button bar (50% = half size)",
                width = "inline",
                min = 0.25, max = 1.5, step = 0.05,
                order = 25,
                get = function() return self.db.profile.iconScale or 0.5 end,
                set = function(_, v) self.db.profile.iconScale = v; self:SetupButtonBar() end,
            },
            spacing = {
                type = "range",
                name = "Button Spacing",
                desc = "Space between buttons in pixels",
                width = "inline",
                min = 0, max = 10, step = 1,
                order = 26,
                get = function() return self.db.profile.spacing or 2 end,
                set = function(_, v) self.db.profile.spacing = v; self:SetupButtonBar() end,
            },
            
            headerAppearance = { type = "header", name = "Appearance", order = 30},
            useClassColor = {
                name = "Use Class Color",
                desc = "Use your class color for the button bar",
                type = "toggle",
                order = 31,
                get = function() return self.db.profile.useClassColor end,
                set = function(_, v) self.db.profile.useClassColor = v; self:UpdateButtonBarColor() end,
            },
            color = {
                name = "Bar Color",
                desc = "Color of the button bar tab",
                type = "color",
                hasAlpha = true,
                order = 32,
                disabled = function() return self.db.profile.useClassColor end,
                get = function()
                    local c = self.db.profile.color or { r = 0.5, g = 0.5, b = 0.5, a = 1 }
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.color = { r = r, g = g, b = b, a = a }
                    self:UpdateButtonBarColor()
                end,
            },
        }
    }
end
