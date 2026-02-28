-- ============================================================================
-- 0. GLOBALS FOR DRAG STATE
-- ============================================================================
local forceShowEmpty = false
local function ShouldShowEmpty(db)
    return forceShowEmpty or db.showEmpty
end

local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local AB = MidnightUI:NewModule("ActionBars", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- ============================================================================
-- 1. LOCAL VARIABLES & FRAMES
-- ============================================================================

local bars = {}
local buttonCache = {}
local Masque = LibStub("Masque", true)
local masqueGroup

-- Bar Definitions
local BAR_CONFIGS = {
    ["MainMenuBar"] = { name = "Action Bar 1", hasPages = true, buttonCount = 12, default = { point = "BOTTOM", x = 0, y = 0 } },
    ["MultiBarBottomLeft"] = { name = "Action Bar 2", hasPages = false, buttonCount = 12, default = { point = "BOTTOM", x = 0, y = 42 } },
    ["MultiBarBottomRight"] = { name = "Action Bar 3", hasPages = false, buttonCount = 12, default = { point = "BOTTOM", x = 0, y = 84 } },
    ["MultiBarRight"] = { name = "Action Bar 4", hasPages = false, buttonCount = 12, default = { point = "BOTTOM", x = 0, y = 126 } },
    ["MultiBarLeft"] = { name = "Action Bar 5", hasPages = false, buttonCount = 12, default = { point = "BOTTOM", x = 0, y = 168 } },
    ["MultiBar5"] = { name = "Action Bar 6", hasPages = false, buttonCount = 12, default = { point = "BOTTOM", x = 0, y = 210 } },
    ["MultiBar6"] = { name = "Action Bar 7", hasPages = false, buttonCount = 12, default = { point = "BOTTOM", x = 0, y = 252 } },
    ["MultiBar7"] = { name = "Action Bar 8", hasPages = false, buttonCount = 12, default = { point = "BOTTOM", x = 0, y = 294 } },
    ["PetActionBar"] = { name = "Pet Bar", hasPages = false, buttonCount = 10, default = { point = "BOTTOM", x = -250, y = 336 } },
    ["StanceBar"] = { name = "Stance Bar", hasPages = false, buttonCount = 10, default = { point = "BOTTOM", x = 250, y = 336 } },
}

-- Bar Paging Conditions (for Action Bar 1)
local DEFAULT_PAGING = "[possessbar] 16; [overridebar] 18; [shapeshift] 13; [vehicleui] 16; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1"

-- ============================================================================
-- 2. DATABASE DEFAULTS
-- ============================================================================

local defaults = {
    profile = {
        hideGryphons = true,
        buttonSize = 42, -- Blizzard default
        buttonSpacing = 4,
        globalScale = 1.0, -- New: global scale for all bars
        showHotkeys = true,
        showMacroNames = true,
        showCooldownNumbers = true,
        font = "Friz Quadrata TT",
        fontSize = 12,
        bars = {}
    }
}

-- Initialize bar defaults
for barKey, config in pairs(BAR_CONFIGS) do
    defaults.profile.bars[barKey] = {
        enabled = true,
        scale = 1.0, -- Individual scale
        alpha = 1.0,
        fadeAlpha = 0.2,
        fadeInCombat = false,
        fadeOutCombat = false,
        fadeMouseover = false,
        columns = (barKey == "PetActionBar" or barKey == "StanceBar") and 10 or 12,
        buttonSize = 42, -- Blizzard default
        buttonSpacing = 4,
        point = config.default.point,
        x = config.default.x,
        y = config.default.y,
        showInPetBattle = barKey == "PetActionBar",
        showInVehicle = barKey == "MainMenuBar",
        showEmpty = true,
        pagingCondition = (barKey == "MainMenuBar") and DEFAULT_PAGING or nil,
    }
end

-- ============================================================================
-- 3. INITIALIZATION
-- ============================================================================

function AB:OnInitialize()
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "OnDBReady")
    -- Use OnUpdate polling to detect cursor changes for showing empty buttons
    -- Show empty buttons whenever any icon is being dragged from any UI page (Spellbook, Talents, Macros, Mounts, Pets, Heirlooms, Bags, etc.)
    if not self.cursorUpdateFrame then
        self.cursorUpdateFrame = CreateFrame("Frame")
        self.cursorUpdateFrame.lastCursorActive = false
        self.cursorUpdateFrame:SetScript("OnUpdate", function()
            -- Use pcall to handle secret values from GetCursorInfo
            local success, cursorType = pcall(GetCursorInfo)
            local dragging = success and cursorType ~= nil
            if dragging ~= self.cursorUpdateFrame.lastCursorActive then
                self.cursorUpdateFrame.lastCursorActive = dragging
                AB:CURSOR_UPDATE()
            end
        end)
    end
    -- Removed invalid UIParent:HookScript("OnCursorChanged"). Now handled by per-button drag event hooks.
end

-- ============================================================================
-- CHECK FOR CONFLICTING ACTION BAR ADDONS
-- ============================================================================

function AB:CheckForConflicts()
    local conflictingAddons = {}
    
    -- Use C_AddOns API (modern) or fallback to legacy IsAddOnLoaded
    local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    
    -- Check for common action bar addons
    if IsAddOnLoaded("Bartender4") then
        table.insert(conflictingAddons, "Bartender4")
    end
    if IsAddOnLoaded("Dominos") then
        table.insert(conflictingAddons, "Dominos")
    end
    if IsAddOnLoaded("ElvUI") then
        table.insert(conflictingAddons, "ElvUI")
    end
    if IsAddOnLoaded("LUI") then
        table.insert(conflictingAddons, "LUI")
    end
    if IsAddOnLoaded("RealUI") then
        table.insert(conflictingAddons, "RealUI")
    end
    if IsAddOnLoaded("TukUI") then
        table.insert(conflictingAddons, "TukUI")
    end
    
    -- If conflicts found, show warning
    if #conflictingAddons > 0 then
        -- Only show warning once per session
        if not AB.conflictWarningShown then
            AB.conflictWarningShown = true
            
            local addonList = table.concat(conflictingAddons, ", ")
            
            -- Create a popup dialog
            StaticPopupDialogs["MIDNIGHTUI_ACTIONBAR_CONFLICT"] = {
                text = string.format(
                    "|cffff6600MidnightUI Action Bars Conflict|r\n\n" ..
                    "You have the following action bar addon(s) enabled:\n" ..
                    "|cff00ff00%s|r\n\n" ..
                    "Having multiple action bar addons enabled can cause conflicts and unexpected behavior.\n\n" ..
                    "Would you like to disable MidnightUI's Action Bars module?",
                    addonList
                ),
                button1 = "Disable MidnightUI ActionBars",
                button2 = "Keep Both (Not Recommended)",
                button3 = "Disable Other Addon",
                OnAccept = function()
                    -- Disable MidnightUI action bars
                    MidnightUI.db.profile.modules.actionbars = false
                    print("|cff9482c9MidnightUI:|r Action Bars module disabled. Reloading UI...")
                    C_Timer.After(0.5, ReloadUI)
                end,
                OnCancel = function()
                    -- User chose to keep both - warn them and offer reload
                    print("|cff9482c9MidnightUI:|r Warning: Running multiple action bar addons may cause conflicts.")
                    StaticPopupDialogs["MIDNIGHTUI_ACTIONBAR_RELOAD"] = {
                        text = "Reload UI to ensure changes take effect?",
                        button1 = "Reload Now",
                        button2 = "Later",
                        OnAccept = function()
                            ReloadUI()
                        end,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                        preferredIndex = 3,
                    }
                    C_Timer.After(0.5, function()
                        StaticPopup_Show("MIDNIGHTUI_ACTIONBAR_RELOAD")
                    end)
                end,
                OnAlt = function()
                    -- Show instructions to disable the other addon
                    print("|cff9482c9MidnightUI:|r To disable " .. addonList .. ", type /reload, then at the character select screen, click 'AddOns' and uncheck it.")
                    StaticPopupDialogs["MIDNIGHTUI_ACTIONBAR_RELOAD"] = {
                        text = "Reload UI now to access the AddOns menu?",
                        button1 = "Reload Now",
                        button2 = "Later",
                        OnAccept = function()
                            ReloadUI()
                        end,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                        preferredIndex = 3,
                    }
                    C_Timer.After(0.5, function()
                        StaticPopup_Show("MIDNIGHTUI_ACTIONBAR_RELOAD")
                    end)
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            
            -- Show the popup after a short delay to ensure UI is loaded
            C_Timer.After(2, function()
                StaticPopup_Show("MIDNIGHTUI_ACTIONBAR_CONFLICT")
            end)
        end
    end
end

function AB:OnDBReady()
    if not MidnightUI.db.profile.modules.actionbars then return end
    
    -- CRITICAL: Check for conflicting addons FIRST and bail out if detected
    local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if IsAddOnLoaded("Bartender4") or IsAddOnLoaded("Dominos") or IsAddOnLoaded("ElvUI") or 
       IsAddOnLoaded("LUI") or IsAddOnLoaded("RealUI") or IsAddOnLoaded("TukUI") then
        print("|cff9482c9MidnightUI:|r Action bar addon detected. Disabling MidnightUI ActionBars to prevent conflicts.")
        self:CheckForConflicts() -- Show the popup
        return -- Exit immediately - don't initialize anything
    end
    
    self.db = MidnightUI.db:RegisterNamespace("ActionBars", defaults)
    
    if Masque then
        masqueGroup = Masque:Group("Midnight ActionBars")
    end
    
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PET_BATTLE_OPENING_START")
    self:RegisterEvent("PET_BATTLE_CLOSE")
    self:RegisterEvent("UNIT_ENTERED_VEHICLE")
    self:RegisterEvent("UNIT_EXITED_VEHICLE")
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    self:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    
    -- ADDED: Register for Move Mode changes
    self:RegisterMessage("MIDNIGHTUI_MOVEMODE_CHANGED", "OnMoveModeChanged")
    
    -- CHANGED: Initialize bars immediately instead of waiting for PLAYER_ENTERING_WORLD
    -- This ensures bars are created even on /reload
    self:HideBlizzardElements()
    self:InitializeAllBars()
    self:UpdateAllBars()
end

function AB:PLAYER_ENTERING_WORLD()
    -- Only run initialization once - bars persist across zone changes
    if self.barsInitialized then
        return
    end
    
    self:HideBlizzardElements()
    self:InitializeAllBars()
    self:UpdateAllBars()
    self.barsInitialized = true
    
    -- TEMPORARILY DISABLED - Skinning disabled for now
    -- C_Timer.After(0.5, function()
    --     local Skin = MidnightUI:GetModule("Skin", true)
    --     if Skin and Skin.SkinActionBarButtons then
    --         Skin:SkinActionBarButtons()
    --     end
    -- end)
end

-- ADDED: Handle Move Mode changes
function AB:OnMoveModeChanged(event, enabled)
    -- Update all bars to show/hide drag frames and nudge controls
    self:UpdateAllBars()
end

-- ============================================================================
-- 4. HIDE BLIZZARD ELEMENTS
-- ============================================================================

function AB:HideBlizzardElements()
    -- Hide MainActionBar page controls and move it out of the way
    if MainActionBar then
        MainActionBar:EnableMouse(false)
        MainActionBar:SetAlpha(0)
        MainActionBar:ClearAllPoints()
        MainActionBar:SetPoint("BOTTOM", UIParent, "TOP", 0, 1000)
        
        if MainActionBar.ActionBarPageNumber then
            MainActionBar.ActionBarPageNumber:Hide()
            MainActionBar.ActionBarPageNumber:SetAlpha(0)
            
            if MainActionBar.ActionBarPageNumber.UpButton then
                MainActionBar.ActionBarPageNumber.UpButton:Hide()
            end
            if MainActionBar.ActionBarPageNumber.DownButton then
                MainActionBar.ActionBarPageNumber.DownButton:Hide()
            end
        end
    end
    
    -- Hide MainMenuBar art and arrows (old frame, might still exist)
    if MainMenuBar then
        MainMenuBar:Hide()
        MainMenuBar:SetAlpha(0)
        
        if MainMenuBar.ArtFrame then
            MainMenuBar.ArtFrame:Hide()
            MainMenuBar.ArtFrame:SetAlpha(0)
        end
    end
    
    -- Hide the XP/Rep bar if hideGryphons is enabled, otherwise just reposition it
    if StatusTrackingBarManager then
        if self.db.profile.hideGryphons then
            StatusTrackingBarManager:Hide()
            StatusTrackingBarManager:SetAlpha(0)
        else
            -- Just skin it
            MidnightUI:SkinFrame(StatusTrackingBarManager)
        end
    end
end

-- ============================================================================
-- 5. BAR CREATION & MANAGEMENT
-- ============================================================================

function AB:InitializeAllBars()
    for barKey, config in pairs(BAR_CONFIGS) do
        self:CreateBar(barKey, config)
    end
    
    -- Update empty button visibility after all bars are created
    C_Timer.After(0.5, function()
        self:UpdateAllEmptyButtons()
    end)
end

function AB:CreateBar(barKey, config)
    if bars[barKey] then return end
    
    -- Create container frame (SecureHandlerStateTemplate for paging support)
    local container = CreateFrame("Frame", "MidnightAB_"..barKey, UIParent, "SecureHandlerStateTemplate")
    container:SetFrameStrata("LOW")
    container:SetMovable(true)
    container:EnableMouse(false)
    container:SetClampedToScreen(true)
    
    -- Store references
    container.barKey = barKey
    container.config = config
    container.buttons = {}
    bars[barKey] = container
    
    -- Get the actual Blizzard bar frame
    local blizzBar = _G[barKey]
    if blizzBar then
        container.blizzBar = blizzBar
        
        -- Show the Blizzard bar so its buttons are visible
        blizzBar:Show()
        blizzBar:SetAlpha(1)

        -- Special handling for StanceBar: parent Blizzard StanceBarFrame and its buttons
        if barKey == "StanceBar" and StanceBarFrame then
            StanceBarFrame:SetParent(container)
            StanceBarFrame:ClearAllPoints()
            StanceBarFrame:SetAllPoints(container)
            StanceBarFrame:SetFrameStrata(container:GetFrameStrata())
            StanceBarFrame:SetFrameLevel(container:GetFrameLevel() + 10)
            StanceBarFrame:Show()
            for i = 1, 10 do
                local btn = _G["StanceButton"..i]
                if btn then
                    btn:SetParent(container)
                    btn:SetFrameStrata(container:GetFrameStrata())
                    btn:SetFrameLevel(container:GetFrameLevel() + 15)
                    btn:Show()
                end
            end
        end

        -- Special handling for MainMenuBar
        if barKey == "MainMenuBar" then
            -- Unregister from EditModeManager completely
            if EditModeManagerFrame then
                EditModeManagerFrame:UnregisterFrame(blizzBar)
            end
            
            -- Completely detach from Blizzard's management
            blizzBar:SetMovable(true)
            blizzBar:SetUserPlaced(true)
            blizzBar:SetParent(container)
            blizzBar.ignoreFramePositionManager = true
            blizzBar:EnableMouse(false)
            
            -- Stop ALL scripts that could interfere
            blizzBar:SetScript("OnUpdate", nil)
            blizzBar:SetScript("OnShow", nil)
            blizzBar:SetScript("OnHide", nil)
            blizzBar:SetScript("OnEvent", nil)
            
            -- Kill Blizzard's positioning by hooking the functions
            hooksecurefunc(blizzBar, "SetPoint", function(self)
                if not self.midnightLock then
                    self.midnightLock = true
                    self:ClearAllPoints()
                    self:SetPoint("CENTER", container, "CENTER", 0, 0)
                    self.midnightLock = false
                end
            end)
            
            -- Position it in the container
            blizzBar:ClearAllPoints()
            blizzBar:SetPoint("CENTER", container, "CENTER", 0, 0)
            
            -- Make buttons parent to container instead of MainMenuBar
            for i = 1, 12 do
                local btn = _G["ActionButton"..i]
                if btn then
                    btn:SetParent(container)
                end
            end
        else
            -- Normal handling for other bars
            blizzBar:SetParent(container)
            blizzBar:ClearAllPoints()
            blizzBar:SetAllPoints(container)
            blizzBar:Show()
            blizzBar:SetAlpha(1)
            
            if blizzBar.SetMovable then blizzBar:SetMovable(true) end
            if blizzBar.SetUserPlaced then blizzBar:SetUserPlaced(true) end
            if blizzBar.ignoreFramePositionManager then
                blizzBar.ignoreFramePositionManager = true
            end
        end
        
        -- Setup bar paging for Action Bar 1
        if barKey == "MainMenuBar" and config.hasPages then
            self:SetupBarPaging(container)
        end
    end
    
    -- Collect buttons (do this even if blizzBar is nil, for MainMenuBar)
    self:CollectButtons(container, barKey)
    
    -- Ensure container allows mouse clicks to pass through to buttons
    container:EnableMouse(false)
    container:SetFrameStrata("LOW")
    
    -- CHANGED: Create drag frame for Move Mode with enhanced styling
    container.dragFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    container.dragFrame:SetAllPoints()
    container.dragFrame:EnableMouse(false) -- Disabled by default to not block clicks
    container.dragFrame:SetFrameStrata("DIALOG")
    container.dragFrame:SetFrameLevel(100) -- Ensure it's above buttons
    
    -- Green border and semi-transparent background
    container.dragFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, 
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    container.dragFrame:SetBackdropColor(0, 0.5, 0, 0.2)  -- Semi-transparent green
    container.dragFrame:SetBackdropBorderColor(0, 1, 0, 1) -- Bright green border
    container.dragFrame:Hide() -- Hidden by default
    
    -- CHANGED: Create label with larger, more visible text
    container.label = container.dragFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    container.label:SetPoint("CENTER")
    container.label:SetText(config.name)
    container.label:SetTextColor(1, 1, 1, 1)
    container.label:SetShadowOffset(2, -2)
    container.label:SetShadowColor(0, 0, 0, 1)

    -- Add a red dot at the top edge to indicate the center of the bar
    if not container.centerDot then
        local dot = container.dragFrame:CreateTexture(nil, "OVERLAY")
        dot:SetColorTexture(1, 0, 0, 1) -- Solid red
        dot:SetSize(10, 10)
        dot:SetPoint("TOP", container.dragFrame, "TOP", 0, 0)
        container.centerDot = dot
    end
    
    -- Drag handlers using Movable module
    local Movable = MidnightUI:GetModule("Movable")
    
    -- Store barKey on container so Movable can identify it
    container.barKey = barKey
    
    container.dragFrame:RegisterForDrag("LeftButton")
    container.dragFrame:SetScript("OnDragStart", function(self)
        -- Only allow dragging with CTRL+ALT or Move Mode
        if (IsControlKeyDown() and IsAltKeyDown()) or MidnightUI.moveMode then
            container:StartMoving()
        end
    end)
    container.dragFrame:SetScript("OnDragStop", function(self)
        container:StopMovingOrSizing()
        -- All snapping logic is disabled. Bar will remain exactly where dropped.
        AB:SaveBarPosition(barKey)
    end)
    container.dragFrame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            MidnightUI:OpenConfig()
        end
    end)
    
    -- Create compact arrow nudge controls for this action bar
    local db = self.db.profile.bars[barKey]
    local nudgeFrame = Movable:CreateNudgeArrows(
        container.dragFrame,
        db, -- Pass the bar's database directly
        function()
            -- Reset callback
            local config = BAR_CONFIGS[barKey]
            if config and config.default then
                db.point = config.default.point
                db.x = config.default.x
                db.y = config.default.y
                
                container:ClearAllPoints()
                container:SetPoint(db.point, UIParent, db.point, db.x, db.y)
                if DEFAULT_CHAT_FRAME then
                    local p, relTo, relP, px, py = container:GetPoint()
                    DEFAULT_CHAT_FRAME:AddMessage("[MidnightUI] After SetPoint (restore): point="..tostring(p)..", relativeTo="..tostring(relTo and relTo:GetName() or "nil")..", relativePoint="..tostring(relP)..", x="..tostring(px)..", y="..tostring(py))
                    DEFAULT_CHAT_FRAME:AddMessage("[MidnightUI] debugstack after SetPoint (restore):\n"..debugstack(2, 10, 10))
                end
                -- Refresh move mode state after reset
                if MidnightUI.moveMode then
                    AB:UpdateBar(barKey)
                end
            end
        end
    )
    
    container.nudgeFrame = nudgeFrame
    
    -- Hook into nudge arrows to use ActionBars database structure
    if nudgeFrame and nudgeFrame.UP then
        for _, direction in ipairs({"UP", "DOWN", "LEFT", "RIGHT"}) do
            local btn = nudgeFrame[direction]
            if btn then
                btn:SetScript("OnClick", function()
                    local step = IsShiftKeyDown() and 8 or 1
                    
                    -- Ensure x and y are initialized (safety for old profiles or imports)
                    db.x = db.x or 0
                    db.y = db.y or 0
                    
                    -- Work directly with ActionBars database
                    if direction == "UP" then
                        db.y = db.y + step
                    elseif direction == "DOWN" then
                        db.y = db.y - step
                    elseif direction == "LEFT" then
                        db.x = db.x - step
                    elseif direction == "RIGHT" then
                        db.x = db.x + step
                    end
                    
                    -- Update container position
                    container:ClearAllPoints()
                    container:SetPoint(db.point, UIParent, db.point, db.x, db.y)
                    
                    -- Refresh move mode state
                    if MidnightUI.moveMode then
                        C_Timer.After(0, function()
                            AB:UpdateBar(barKey)
                        end)
                    end
                end)
            end
        end
    end
    
    -- Register nudge frame with dragFrame as parent
    if nudgeFrame then
        Movable:RegisterNudgeFrame(nudgeFrame, container.dragFrame)
    end
    
    return container
end

-- ============================================================================
-- 5.5 BAR PAGING SYSTEM
-- ============================================================================

function AB:CollectButtons(container, barKey)
    local buttons = {}
    
    if barKey == "MainMenuBar" then
        for i = 1, 12 do
            local btn = _G["ActionButton"..i]
            if btn then 
                btn:Show()
                btn:SetAlpha(1)
                table.insert(buttons, btn) 
            end
        end
    elseif barKey == "PetActionBar" then
        for i = 1, 10 do
            local btn = _G["PetActionButton"..i]
            if btn then 
                btn:Show()
                btn:SetAlpha(1)
                table.insert(buttons, btn) 
            end
        end
    elseif barKey == "StanceBar" then
        for i = 1, 10 do
            local btn = _G["StanceButton"..i]
            if btn then
                btn:Show()
                btn:SetAlpha(1)
                -- Parent to container for visibility
                if btn:GetParent() ~= container then
                    btn:SetParent(container)
                end
                -- Try all possible icon references
                local icon = btn.Icon or btn.icon or _G[btn:GetName().."Icon"]
                local texture = nil
                if GetShapeshiftFormInfo then
                    texture = select(1, GetShapeshiftFormInfo(i))
                end
                if icon then
                    icon:SetDrawLayer("OVERLAY", 1)
                    if texture then
                        icon:SetTexture(texture)
                        icon:Show()
                        if btn.emptyBackground then btn.emptyBackground:Hide() end
                        if btn.emptyBorder then btn.emptyBorder:Hide() end
                    else
                        icon:SetTexture(nil)
                        icon:Hide()
                        if btn.emptyBackground then btn.emptyBackground:Show() end
                        if btn.emptyBorder then btn.emptyBorder:Show() end
                    end
                end
                table.insert(buttons, btn)
            end
        end
    else
        -- Standard action bars
        local barName = barKey
        for i = 1, 12 do
            local btn = _G[barName.."Button"..i]
            if btn then 
                btn:Show()
                btn:SetAlpha(1)
                table.insert(buttons, btn) 
            end
        end
    end
    
    container.buttons = buttons
    
    -- Cache buttons globally for skinning
    for _, btn in ipairs(buttons) do
        buttonCache[btn] = true
        -- Hook drag events to show/hide empty buttons during drag-and-drop
        if not btn._hookedDrag then
            btn:HookScript("OnDragStart", function()
                forceShowEmpty = true
                AB:UpdateAllEmptyButtons()
            end)
            btn:HookScript("OnReceiveDrag", function()
                local cursorType = GetCursorInfo and GetCursorInfo()
                if cursorType then
                    -- Still holding something, keep empty buttons visible
                    forceShowEmpty = true
                else
                    forceShowEmpty = false
                end
                AB:UpdateAllEmptyButtons()
            end)
            btn:HookScript("OnMouseUp", function()
                if forceShowEmpty then
                    local cursorType = GetCursorInfo and GetCursorInfo()
                    if cursorType then
                        -- Still holding something, keep empty buttons visible
                        forceShowEmpty = true
                    else
                        forceShowEmpty = false
                    end
                    AB:UpdateAllEmptyButtons()
                end
            end)
            btn._hookedDrag = true
        end
        -- Register button with Masque for skinning
        if masqueGroup and masqueGroup.AddButton then
            masqueGroup:AddButton(btn)
        end
    end
    
    -- Re-skin after adding buttons
    if masqueGroup and masqueGroup.ReSkin then
        masqueGroup:ReSkin()
    end
end

function AB:SetupBarPaging(container)
    local db = self.db.profile.bars["MainMenuBar"]
    local pagingCondition = db.pagingCondition or DEFAULT_PAGING
    
    print("[AB DEBUG] SetupBarPaging called for MainMenuBar")
    
    -- Unregister any existing state driver first to prevent accumulation
    DebugUnregisterStateDriver(container, "actionpage")
    
    -- Register state driver for bar paging
    DebugRegisterStateDriver(container, "actionpage", pagingCondition)
    
    -- Handle state changes
    container:SetAttribute("_onstate-actionpage", [[
        self:SetAttribute("actionpage", newstate)
        control:ChildUpdate("actionpage", newstate)
    ]])
    
    -- Update buttons when page changes
    container:HookScript("OnAttributeChanged", function(self, name, value)
        if name == "actionpage" and value then
            AB:UpdateMainBarButtons(tonumber(value))
        end
    end)
end

function AB:UpdateMainBarButtons(page)
    if not page then return end
    
    local container = bars["MainMenuBar"]
    if not container then return end
    
    -- Update button actions based on current page
    for i, btn in ipairs(container.buttons) do
        if btn and btn.UpdateAction then
            btn:UpdateAction()
        end
    end
end

function AB:UpdateBarPaging(barKey)
    if barKey ~= "MainMenuBar" then return end
    
    local container = bars[barKey]
    if not container then return end
    
    local db = self.db.profile.bars[barKey]
    local pagingCondition = db.pagingCondition or DEFAULT_PAGING
    
    print("[AB DEBUG] UpdateBarPaging called for MainMenuBar")
    
    -- Unregister existing state driver first to prevent accumulation
    DebugUnregisterStateDriver(container, "actionpage")
    
    -- Update the state driver
    DebugRegisterStateDriver(container, "actionpage", pagingCondition)
end

-- ============================================================================
-- 6. BAR LAYOUT & POSITIONING
-- ============================================================================

function AB:UpdateAllBars()
    for barKey, container in pairs(bars) do
        self:UpdateBar(barKey)
    end
end

function AB:UpdateBar(barKey)
    local container = bars[barKey]
    if not container then return end
    
    local db = self.db.profile.bars[barKey]
    if not db then return end
    
    -- Show/Hide based on settings
    if db.enabled then
        container:Show()
    else
        container:Hide()
        -- Also hide all hotkey frames on buttons when bar is disabled
        for _, btn in ipairs(container.buttons) do
            if btn then
                local hotkey = btn.HotKey or _G[btn:GetName().."HotKey"]
                if hotkey then
                    hotkey:Hide()
                end
            end
        end
        return
    end
    
    -- Apply scale and alpha
    local globalScale = self.db.profile.globalScale or 1.0
    container:SetScale((db.scale or 1.0) * globalScale)
    container:SetAlpha(db.alpha)
    
    -- Update position
    container:ClearAllPoints()
    container:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    
    -- Layout buttons
    self:LayoutButtons(container, barKey)
    
    -- Update fading
    self:UpdateBarFading(barKey)
    
    -- Handle Move Mode display
    if MidnightUI.moveMode then
        -- Ensure container is visible
        container:Show()
        container:SetAlpha(1)
        
        -- Show drag frame with green border (make visible and enable dragging)
        if container.dragFrame then
            container.dragFrame:Show()
            container.dragFrame:EnableMouse(true)
            container.dragFrame:RegisterForDrag("LeftButton")
        end
        
        -- Fade the actual action buttons to 30% opacity
        for _, btn in ipairs(container.buttons) do
            if btn then
                btn:SetAlpha(0.3)
            end
        end
        
        -- Show arrow nudge controls (they show automatically with parent drag frame)
        if container.nudgeFrame then
            -- Arrow buttons are already parented to dragFrame and will show when it shows
            -- Just make sure they're visible
            if container.nudgeFrame.UP then container.nudgeFrame.UP:Show() end
            if container.nudgeFrame.DOWN then container.nudgeFrame.DOWN:Show() end
            if container.nudgeFrame.LEFT then container.nudgeFrame.LEFT:Show() end
            if container.nudgeFrame.RIGHT then container.nudgeFrame.RIGHT:Show() end
            if container.nudgeFrame.RESET then container.nudgeFrame.RESET:Show() end
        end
    else
        -- Hide drag frame visually and disable mouse
        if container.dragFrame then
            container.dragFrame:Hide()
            container.dragFrame:EnableMouse(false)
            container.dragFrame:RegisterForDrag() -- Disable dragging
        end
        
        -- Restore button opacity to 100%
        for _, btn in ipairs(container.buttons) do
            if btn then
                btn:SetAlpha(1.0)
            end
        end
        
        -- Hide arrow nudge controls
        if container.nudgeFrame then
            if container.nudgeFrame.UP then container.nudgeFrame.UP:Hide() end
            if container.nudgeFrame.DOWN then container.nudgeFrame.DOWN:Hide() end
            if container.nudgeFrame.LEFT then container.nudgeFrame.LEFT:Hide() end
            if container.nudgeFrame.RIGHT then container.nudgeFrame.RIGHT:Hide() end
            if container.nudgeFrame.RESET then container.nudgeFrame.RESET:Hide() end
        end
    end
    
    -- Special handling for MainMenuBar
    if barKey == "MainMenuBar" and container.blizzBar then
        container.blizzBar:Show()
    end
end

function AB:LayoutButtons(container, barKey)
    local db = self.db.profile.bars[barKey]
    local buttons = container.buttons
    
    if #buttons == 0 then return end
    
    local buttonSize = db.buttonSize
    local spacing = db.buttonSpacing
    local columns = db.columns
    
    -- Calculate container size
    local rows = math.ceil(#buttons / columns)
    local width = (buttonSize * columns) + (spacing * (columns - 1))
    local height = (buttonSize * rows) + (spacing * (rows - 1))
    
    container:SetSize(width, height)
    
    -- Position buttons
    for i, btn in ipairs(buttons) do
        btn:ClearAllPoints()
        btn:SetParent(container)
        btn:SetSize(buttonSize, buttonSize)
        btn:Show() -- Ensure button is shown
        
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        
        local xOffset = col * (buttonSize + spacing)
        local yOffset = -row * (buttonSize + spacing)
        
        btn:SetPoint("TOPLEFT", container, "TOPLEFT", xOffset, yOffset)
        
        -- Update button elements
        self:UpdateButtonElements(btn)
    end
    
    -- Update empty button visibility after layout
    self:UpdateEmptyButtons(barKey)
end

function AB:UpdateButtonElements(btn)
    local db = self.db.profile
    
    -- Completely hide TextOverlayContainer - we'll create our own keybind display
    if btn.TextOverlayContainer then
        btn.TextOverlayContainer:Hide()
        btn.TextOverlayContainer:SetAlpha(0)
    end
    
    -- Create our own custom hotkey fontstring if it doesn't exist
    if not btn.customHotkey then
        btn.customHotkey = btn:CreateFontString(nil, "OVERLAY")
        btn.customHotkey:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -2)
        btn.customHotkey:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        btn.customHotkey:SetTextColor(1, 1, 1)
        btn.customHotkey:SetJustifyH("RIGHT")
    end
    
    -- Update custom hotkey text from the button's action binding
    -- Check if button, its parent container, and the original Blizzard bar are all visible
    local parentBar = btn.bar or btn:GetParent()
    local shouldShow = db.showHotkeys and btn:IsVisible()
    
    -- Additional check: if this is a StanceBar or PetActionBar, check if Blizzard is showing the bar
    if shouldShow and parentBar then
        local parentName = parentBar:GetName()
        if parentName == "StanceBar" or parentName == "PetActionBar" then
            -- These bars are hidden by Blizzard for classes without stances/pets
            shouldShow = parentBar:IsVisible() and parentBar:IsShown()
        end
    end
    
    if shouldShow then
        local key = GetBindingKey(btn.commandName or btn.bindingAction)
        if key then
            local text = GetBindingText(key, "KEY_", 1)
            text = string.upper(text)
            
            -- Abbreviate common patterns
            text = text:gsub("MOUSEWHEELUP", "MWU")
            text = text:gsub("MOUSEWHEELDOWN", "MWD")
            text = text:gsub("CTRL%-", "C")
            text = text:gsub("SHIFT%-", "S")
            text = text:gsub("ALT%-", "A")
            text = text:gsub("BUTTON", "M")
            
            text = string.sub(text, 1, 4) -- Limit to 4 characters
            btn.customHotkey:SetText(text)
            btn.customHotkey:Show()
        else
            btn.customHotkey:Hide()
        end
    else
        btn.customHotkey:Hide()
    end
    
    -- Ensure icon matches button size exactly
    if btn.icon then
        btn.icon:ClearAllPoints()
        btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    end
    
    -- Fix highlight to match button perfectly
    local highlight = btn:GetHighlightTexture()
    if highlight then
        highlight:ClearAllPoints()
        highlight:SetAllPoints(btn)
        highlight:SetDrawLayer("HIGHLIGHT")
        highlight:SetBlendMode("ADD")
    end
    
    -- Fix pushed texture - align properly with button edges
    local pushed = btn:GetPushedTexture()
    if pushed then
        pushed:ClearAllPoints()
        pushed:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -2)
        pushed:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -4)
        pushed:SetTexCoord(0, 1, 0, 1)
        pushed:SetDrawLayer("ARTWORK", 1)
    end
    
    -- Fix flash texture
    if btn.Flash then
        btn.Flash:ClearAllPoints()
        btn.Flash:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -2)
        btn.Flash:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -4)
    end
    
    -- Hide checked texture (green equipped item border)
    local checked = btn:GetCheckedTexture()
    if checked then
        checked:SetAlpha(0)
        checked:Hide()
    end
    
    -- Hide the green equipped item Border texture and keep it hidden
    if btn.Border then
        btn.Border:SetAlpha(0)
        btn.Border:Hide()
        hooksecurefunc(btn.Border, "Show", function(self)
            self:Hide()
        end)
    end
    
    -- Hide NormalTexture (the default button border/background)
    local normalTex = btn:GetNormalTexture()
    if normalTex then
        normalTex:SetAlpha(0)
    end
    
    -- Create Blizzard-style empty button border if it doesn't exist
    if not btn.emptyBackground then
        btn.emptyBackground = btn:CreateTexture(nil, "BACKGROUND")
        btn.emptyBackground:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        -- Crop out transparent padding: these values work well for Blizzard's button border
        btn.emptyBackground:SetTexCoord(0.14, 0.86, 0.14, 0.86)
        btn.emptyBackground:SetDrawLayer("BACKGROUND", 0)
        btn.emptyBackground:SetAllPoints(btn)
        btn.emptyBackground:SetAlpha(1)
    end
    -- Remove custom empty border (not needed with Blizzard border)
    if btn.emptyBorder then
        btn.emptyBorder:Hide()
    end
    
    -- Hide border textures that might show as rectangles
    if btn.Border then
        btn.Border:SetAlpha(0)
    end
    if btn.SlotBackground then
        btn.SlotBackground:SetAlpha(0)
    end
    
    -- Macro name
    local name = btn.Name or _G[btn:GetName().."Name"]
    if name then
        if db.showMacroNames then
            name:Show()
            name:ClearAllPoints()
            name:SetPoint("BOTTOM", 0, 2)
        else
            name:Hide()
        end
    end
    
    -- Cooldown numbers (handled by Cooldowns module, but we can hide the frame)
    local cooldown = btn.cooldown or btn.Cooldown
    if cooldown and not db.showCooldownNumbers then
        if cooldown.SetHideCountdownNumbers then
            cooldown:SetHideCountdownNumbers(true)
        end
    end
end

function AB:SaveBarPosition(barKey)
    local container = bars[barKey]
    if not container then return end
    
    local point, _, _, x, y = container:GetPoint()
    local db = self.db.profile.bars[barKey]
    
    db.point = point
    db.x = math.floor(x + 0.5)
    db.y = math.floor(y + 0.5)
end

-- Update visibility of empty buttons for a bar
function AB:UpdateEmptyButtons(barKey)
    -- Safety check: if module is disabled or db is not initialized, do nothing
    if not self.db or not self.db.profile or not self.db.profile.bars then return end
    
    local container = bars[barKey]
    local db = self.db.profile.bars[barKey]
    
    if not container or not container.buttons or not db then return end
    
    -- Check if this bar should even be visible for this class
    local barShouldBeHidden = false
    if barKey == "PetActionBar" then
        -- Hide if player has no pet action bar
        barShouldBeHidden = not HasPetUI()
    elseif barKey == "StanceBar" then
        -- Hide if player has no stance bar
        barShouldBeHidden = GetNumShapeshiftForms() == 0
    end
    
    -- If bar shouldn shouldn't exist for this class, hide everything including keybinds
    if barShouldBeHidden then
        for _, btn in ipairs(container.buttons) do
            if btn then
                -- PetActionBar and StanceBar buttons are Blizzard-protected; avoid Hide in combat
                if (barKey == "PetActionBar" or barKey == "StanceBar") and InCombatLockdown() then
                    -- Do nothing in combat
                else
                    btn:Hide()
                end
                if btn.customHotkey then
                    btn.customHotkey:Hide()
                end
            end
        end
        return
    end
    
    -- Override Blizzard's empty button hiding if we want to show empty buttons
    if barKey ~= "PetActionBar" and barKey ~= "StanceBar" then
        local settings = Settings.GetCategory("ActionBars")
        if settings then
            -- Try to find and set the "Always Show Action Bars" setting
            for _, setting in pairs(settings:GetSettings()) do
                if setting.name == "alwaysShowActionBars" then
                    Settings.SetValue(setting, db.showEmpty)
                    break
                end
            end
        end
    end
    
    for i, btn in ipairs(container.buttons) do
        if btn then
            -- Always set up button for drag-and-drop
            if btn.RegisterForDrag then
                btn:RegisterForDrag("LeftButton", "RightButton")
            end
            -- Only call RegisterForClicks out of combat to avoid taint
            if btn.RegisterForClicks and not InCombatLockdown() then
                btn:RegisterForClicks("AnyUp")
            end
            if barKey == "StanceBar" then
                local icon = btn.Icon or btn.icon or _G[btn:GetName().."Icon"]
                local texture = nil
                if GetShapeshiftFormInfo then
                    texture = select(1, GetShapeshiftFormInfo(i))
                end
                if icon and texture then
                    btn:SetAlpha(1)
                    btn:Show()
                    btn:Enable()
                    -- Stance buttons do not use action type
                    if btn.SetAttribute then
                        btn:SetAttribute("type", nil)
                        btn:SetAttribute("action", nil)
                    end
                    icon:SetTexture(texture)
                    icon:SetAlpha(1)
                    icon:Show()
                    if btn.emptyBackground then btn.emptyBackground:Hide() end
                    if btn.emptyBorder then btn.emptyBorder:Hide() end
                    if btn.customHotkey then btn.customHotkey:Show() end
                else
                    btn:Hide()
                    btn:Disable()
                    if btn.SetAttribute then
                        btn:SetAttribute("type", nil)
                        btn:SetAttribute("action", nil)
                    end
                    if icon then
                        icon:SetAlpha(0)
                        icon:Hide()
                    end
                    if btn.emptyBackground then btn.emptyBackground:Hide() end
                    if btn.emptyBorder then btn.emptyBorder:Hide() end
                    if btn.customHotkey then btn.customHotkey:Hide() end
                end
            else
                local actionID = btn.action
                if not actionID and btn.GetPagedID then
                    actionID = btn:GetPagedID()
                elseif not actionID and btn.GetActionID then
                    actionID = btn:GetActionID()
                end
                local hasAction = actionID and HasAction(actionID)
                -- Only set attributes out of combat to avoid taint
                if btn.SetAttribute and actionID and not InCombatLockdown() then
                    btn:SetAttribute("type", "action")
                    btn:SetAttribute("action", actionID)
                end
                if ShouldShowEmpty(db) then
                    btn:SetAlpha(1)
                    if not InCombatLockdown() then
                        btn:Show()
                        btn:Enable()
                    end
                    if btn.icon then
                        if hasAction then
                            btn.icon:SetAlpha(1)
                            btn.icon:Show()
                            if btn.emptyBackground then btn.emptyBackground:Hide() end
                            if btn.emptyBorder then btn.emptyBorder:Hide() end
                        else
                            btn.icon:SetAlpha(0)
                            btn.icon:Hide()
                            if btn.emptyBackground then btn.emptyBackground:Show() end
                            if btn.emptyBorder then btn.emptyBorder:Show() end
                        end
                    else
                        if btn.emptyBackground then btn.emptyBackground:Show() end
                        if btn.emptyBorder then btn.emptyBorder:Show() end
                    end
                else
                    if hasAction then
                        btn:SetAlpha(1)
                        if not InCombatLockdown() then
                            btn:Show()
                            btn:Enable()
                        end
                        if btn.icon then
                            btn.icon:SetAlpha(1)
                            btn.icon:Show()
                        end
                        if btn.emptyBackground then btn.emptyBackground:Hide() end
                        if btn.emptyBorder then btn.emptyBorder:Hide() end
                    else
                        if not InCombatLockdown() then
                            btn:Hide()
                            btn:Disable()
                        end
                        if btn.customHotkey then
                            btn.customHotkey:Hide()
                        end
                        if btn.emptyBackground then btn.emptyBackground:Hide() end
                        if btn.emptyBorder then btn.emptyBorder:Hide() end
                    end
                end
            end
        end
    end
end

function AB:CURSOR_UPDATE()
    -- Safety check: if module is disabled or db is not initialized, do nothing
    if not self.db or not self.db.profile then return end
    
    -- Show empty buttons if anything is being dragged from any UI page (spell, macro, item, mount, pet, heirloom, etc.)
    -- Use pcall to handle secret values from GetCursorInfo
    local success, cursorType = pcall(GetCursorInfo)
    local dragging = success and cursorType ~= nil
    if dragging then
        if not forceShowEmpty then
            forceShowEmpty = true
            AB:UpdateAllEmptyButtons()
        end
    else
        if forceShowEmpty then
            forceShowEmpty = false
            AB:UpdateAllEmptyButtons()
        end
    end
end

-- Update all bars' empty button visibility
function AB:UpdateAllEmptyButtons()
    -- Safety check: if module is disabled or db is not initialized, do nothing
    if not self.db or not self.db.profile then return end
    
    for barKey in pairs(BAR_CONFIGS) do
        self:UpdateEmptyButtons(barKey)
    end
end

-- ============================================================================
-- 7. FADING SYSTEM
-- ============================================================================

function AB:UpdateBarFading(barKey)
    local container = bars[barKey]
    local db = self.db.profile.bars[barKey]
    
    if not container or not db then return end
    
    -- Remove existing fading scripts
    container:SetScript("OnEnter", nil)
    container:SetScript("OnLeave", nil)
    container:SetScript("OnUpdate", nil)
    
    if db.fadeMouseover then
        container:EnableMouse(true)
        container:SetAlpha(db.fadeAlpha)
        
        container:SetScript("OnEnter", function()
            UIFrameFadeIn(container, 0.2, container:GetAlpha(), db.alpha)
        end)
        
        container:SetScript("OnLeave", function()
            UIFrameFadeOut(container, 0.2, container:GetAlpha(), db.fadeAlpha)
        end)
    elseif db.fadeInCombat or db.fadeOutCombat then
        -- CHANGED: Use event-driven updates instead of OnUpdate polling
        -- This prevents checking InCombatLockdown() every frame (60+ times/sec)
        container:EnableMouse(false)
        
        local function UpdateCombatFade()
            local inCombat = InCombatLockdown()
            local targetAlpha = db.alpha
            
            if db.fadeInCombat and inCombat then
                targetAlpha = db.alpha
            elseif db.fadeOutCombat and not inCombat then
                targetAlpha = db.fadeAlpha
            end
            
            if container:GetAlpha() ~= targetAlpha then
                UIFrameFadeIn(container, 0.3, container:GetAlpha(), targetAlpha)
            end
        end
        
        -- Store handler reference for potential cleanup
        container.combatFadeHandler = UpdateCombatFade
        container.combatFadeFrame = container.combatFadeFrame or CreateFrame("Frame", nil, container)
        container.combatFadeFrame:SetScript("OnEvent", UpdateCombatFade)
        container.combatFadeFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        container.combatFadeFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        
        -- Set initial state
        UpdateCombatFade()
    else
        container:EnableMouse(false)
        container:SetAlpha(db.alpha)
    end
end

-- ============================================================================
-- 9. EVENT HANDLERS
-- ============================================================================

function AB:PLAYER_REGEN_ENABLED()
    self:UpdateAllBars()
end

function AB:PLAYER_REGEN_DISABLED()
    self:UpdateAllBars()
end

function AB:PET_BATTLE_OPENING_START()
    for barKey, container in pairs(bars) do
        local db = self.db.profile.bars[barKey]
        if not db.showInPetBattle then
            container:Hide()
        end
    end
end

function AB:PET_BATTLE_CLOSE()
    self:UpdateAllBars()
end

function AB:UNIT_ENTERED_VEHICLE(event, unit)
    if unit == "player" then
        for barKey, container in pairs(bars) do
            local db = self.db.profile.bars[barKey]
            if not db.showInVehicle then
                container:Hide()
            end
        end
    end
end

function AB:UNIT_EXITED_VEHICLE(event, unit)
    if unit == "player" then
        self:UpdateAllBars()
    end
end

function AB:ACTIONBAR_SLOT_CHANGED(event, slot)
    -- Update empty button visibility when actions change
    self:UpdateAllEmptyButtons()
end

function AB:UPDATE_BONUS_ACTIONBAR()
    -- Update when bonus action bar changes (stance/form changes)
    self:UpdateAllEmptyButtons()
end

function AB:UPDATE_SHAPESHIFT_FORMS()
    -- Update when shapeshift forms are learned or changed
    local container = bars["StanceBar"]
    if container then
        -- Update icons for all stance buttons
        for i = 1, 10 do
            local btn = _G["StanceButton"..i]
            if btn then
                local icon = btn.icon or _G[btn:GetName().."Icon"]
                if icon then
                    local texture, isActive, isCastable = GetShapeshiftFormInfo(i)
                    if texture then
                        icon:SetTexture(texture)
                        icon:Show()
                        btn:Show()
                    else
                        icon:Hide()
                        btn:Hide()
                    end
                end
            end
        end
        self:UpdateBar("StanceBar")
        self:UpdateEmptyButtons("StanceBar")
    end
end

function AB:UPDATE_SHAPESHIFT_FORM()
    -- Update when player changes form (just update active state)
    local container = bars["StanceBar"]
    if container then
        for i = 1, 10 do
            local btn = _G["StanceButton"..i]
            if btn and btn.Update then
                btn:Update()
            end
        end
        self:UpdateEmptyButtons("StanceBar")
    end
end

-- ============================================================================
-- 10. OPTIONS
-- ============================================================================

function AB:GetOptions()
    if not self.db then
        self.db = MidnightUI.db:RegisterNamespace("ActionBars", defaults)
    end
    
    local options = {
        type = "group",
        name = "Action Bars",
        childGroups = "tab",
        args = {
            general = {
                name = "General",
                type = "group",
                order = 1,
                args = {
                    -- Note: Button skinning is controlled by the Skins module
                    hideGryphons = {
                        name = "Hide Gryphons",
                        desc = "Hide main bar gryphons and art",
                        type = "toggle",
                        order = 3,
                        get = function() return self.db.profile.hideGryphons end,
                        set = function(_, v)
                            self.db.profile.hideGryphons = v
                            self:HideBlizzardElements()
                        end
                    },
                    globalScale = {
                        name = "Global Action Bar Scale",
                        desc = "Scale all action bars at once (multiplies individual bar scale)",
                        type = "range",
                        order = 4,
                        min = 0.5,
                        max = 2.0,
                        step = 0.01,
                        get = function() return self.db.profile.globalScale end,
                        set = function(_, v)
                            self.db.profile.globalScale = v
                            self:UpdateAllBars()
                        end
                    },
                    spacer0 = { name = "", type = "header", order = 5},
                    moveNote = {
                        name = "|cffaaaaaa(Use /muimove or click M button to enable Move Mode)\nThen hover over bars to see nudge controls|r",
                        type = "description",
                        order = 5.5,
                        fontSize = "medium",
                    },
                    resetAllPositions = {
                        name = "Reset All Bar Positions",
                        desc = "Reset all action bars to their default positions",
                        type = "execute",
                        order = 6,
                        confirm = true,
                        confirmText = "Are you sure you want to reset all bar positions to default?",
                        func = function()
                            for barKey, config in pairs(BAR_CONFIGS) do
                                local db = self.db.profile.bars[barKey]
                                db.point = config.default.point
                                db.x = config.default.x
                                db.y = config.default.y
                                self:UpdateBar(barKey)
                            end
                            print("|cff00ff00MidnightUI:|r All action bar positions have been reset to default.")
                        end
                    },
                    spacer1 = { name = "", type = "description", order = 10 },
                    buttonSize = {
                        name = "Global Button Size",
                        desc = "Default button size for all bars",
                        type = "range",
                        order = 11,
                        min = 20,
                        max = 64,
                        step = 1,
                        get = function() return self.db.profile.buttonSize end,
                        set = function(_, v)
                            self.db.profile.buttonSize = v
                            for barKey in pairs(BAR_CONFIGS) do
                                self.db.profile.bars[barKey].buttonSize = v
                            end
                            self:UpdateAllBars()
                        end
                    },
                    buttonSpacing = {
                        name = "Global Button Spacing",
                        desc = "Default spacing between buttons",
                        type = "range",
                        order = 12,
                        min = 0,
                        max = 20,
                        step = 1,
                        get = function() return self.db.profile.buttonSpacing end,
                        set = function(_, v)
                            self.db.profile.buttonSpacing = v
                            for barKey in pairs(BAR_CONFIGS) do
                                self.db.profile.bars[barKey].buttonSpacing = v
                            end
                            self:UpdateAllBars()
                        end
                    },
                    spacer2 = { name = "", type = "description", order = 20 },
                    showHotkeys = {
                        name = "Show Hotkeys",
                        desc = "Display keybind text on buttons",
                        type = "toggle",
                        order = 21,
                        get = function() return self.db.profile.showHotkeys end,
                        set = function(_, v)
                            self.db.profile.showHotkeys = v
                            self:UpdateAllBars()
                        end
                    },
                    showMacroNames = {
                        name = "Show Macro Names",
                        desc = "Display macro names on buttons",
                        type = "toggle",
                        order = 22,
                        get = function() return self.db.profile.showMacroNames end,
                        set = function(_, v)
                            self.db.profile.showMacroNames = v
                            self:UpdateAllBars()
                        end
                    },
                    showCooldownNumbers = {
                        name = "Show Cooldown Numbers",
                        desc = "Display cooldown countdown numbers",
                        type = "toggle",
                        order = 23,
                        get = function() return self.db.profile.showCooldownNumbers end,
                        set = function(_, v)
                            self.db.profile.showCooldownNumbers = v
                            self:UpdateAllBars()
                        end
                    },
                }
            },
            bars = {
                name = "Bars",
                type = "group",
                order = 2,
                args = {}
            }
        }
    }

    -- Define the desired order for bars
    local barDisplayOrder = {
        "MainMenuBar",
        "MultiBarBottomLeft",
        "MultiBarBottomRight",
        "MultiBarRight",
        "MultiBarLeft",
        "MultiBar5",
        "MultiBar6",
        "MultiBar7",
        "PetActionBar",
        "StanceBar"
    }

    -- Add individual bar options in the specified order
    for barOrder, barKey in ipairs(barDisplayOrder) do
        local config = BAR_CONFIGS[barKey]
        if config then
            local barOptions = {
                name = config.name,
                type = "group",
                order = barOrder,
                args = {
                    enabled = {
                        name = "Enable",
                        desc = "Show this action bar",
                        type = "toggle",
                        order = 1,
                        get = function() return self.db.profile.bars[barKey].enabled end,
                        set = function(_, v)
                            self.db.profile.bars[barKey].enabled = v
                            self:UpdateBar(barKey)
                        end
                    },
                    scale = {
                        name = "Scale",
                        desc = "Scale of the entire bar",
                        type = "range",
                        order = 2,
                        min = 0.5,
                        max = 2.0,
                        step = 0.05,
                        get = function() return self.db.profile.bars[barKey].scale end,
                        set = function(_, v)
                            self.db.profile.bars[barKey].scale = v
                            self:UpdateBar(barKey)
                        end
                    },
                    alpha = {
                        name = "Opacity",
                        desc = "Normal opacity of the bar",
                        type = "range",
                        order = 3,
                        min = 0,
                        max = 1,
                        step = 0.05,
                        get = function() return self.db.profile.bars[barKey].alpha end,
                        set = function(_, v)
                            self.db.profile.bars[barKey].alpha = v
                            self:UpdateBar(barKey)
                        end
                    },
                    columns = {
                        name = "Columns",
                        desc = "Number of buttons per row",
                        type = "range",
                        order = 4,
                        min = 1,
                        max = config.buttonCount,
                        step = 1,
                        get = function() return self.db.profile.bars[barKey].columns end,
                        set = function(_, v)
                            self.db.profile.bars[barKey].columns = v
                            self:UpdateBar(barKey)
                        end
                    },
                    buttonSize = {
                        name = "Button Size",
                        desc = "Size of buttons in this bar",
                        type = "range",
                        order = 5,
                        min = 20,
                        max = 64,
                        step = 1,
                        get = function() return self.db.profile.bars[barKey].buttonSize end,
                        set = function(_, v)
                            self.db.profile.bars[barKey].buttonSize = v
                            self:UpdateBar(barKey)
                        end
                    },
                    buttonSpacing = {
                        name = "Button Spacing",
                        desc = "Space between buttons",
                        type = "range",
                        order = 6,
                        min = 0,
                        max = 20,
                        step = 1,
                        get = function() return self.db.profile.bars[barKey].buttonSpacing end,
                        set = function(_, v)
                            self.db.profile.bars[barKey].buttonSpacing = v
                            self:UpdateBar(barKey)
                        end
                    },
                    spacer1 = { name = "", type = "header", order = 10},
                    showEmpty = {
                        name = "Show Empty Buttons",
                        desc = "Show buttons even when they have no action assigned",
                        type = "toggle",
                        order = 10.5,
                        get = function() return self.db.profile.bars[barKey].showEmpty end,
                        set = function(_, v)
                            self.db.profile.bars[barKey].showEmpty = v
                            self:UpdateEmptyButtons(barKey)
                        end
                    },
                    fadeMouseover = {
                        name = "Fade on Mouseover",
                        desc = "Fade bar until you mouse over it",
                        type = "toggle",
                        order = 11,
                        get = function() return self.db.profile.bars[barKey].fadeMouseover end,
                        set = function(_, v)
                            self.db.profile.bars[barKey].fadeMouseover = v
                            if v then
                                self.db.profile.bars[barKey].fadeInCombat = false
                                self.db.profile.bars[barKey].fadeOutCombat = false
                            end
                            self:UpdateBar(barKey)
                        end
                    },
                    fadeInCombat = {
                        name = "Fade In Combat",
                        desc = "Show bar fully in combat",
                        type = "toggle",
                        order = 12,
                        disabled = function() return self.db.profile.bars[barKey].fadeMouseover end,
                        get = function() return self.db.profile.bars[barKey].fadeInCombat end,
                        set = function(_, v)
                            self.db.profile.bars[barKey].fadeInCombat = v
                            self:UpdateBar(barKey)
                        end
                    },
                    fadeOutCombat = {
                        name = "Fade Out of Combat",
                        desc = "Fade bar when out of combat",
                        type = "toggle",
                        order = 13,
                        disabled = function() return self.db.profile.bars[barKey].fadeMouseover end,
                        get = function() return self.db.profile.bars[barKey].fadeOutCombat end,
                        set = function(_, v)
                            self.db.profile.bars[barKey].fadeOutCombat = v
                            self:UpdateBar(barKey)
                        end
                    },
                    fadeAlpha = {
                        name = "Faded Opacity",
                        desc = "Opacity when faded",
                        type = "range",
                        order = 14,
                        min = 0,
                        max = 1,
                        step = 0.05,
                        get = function() return self.db.profile.bars[barKey].fadeAlpha end,
                        set = function(_, v)
                            self.db.profile.bars[barKey].fadeAlpha = v
                            self:UpdateBar(barKey)
                        end
                    },
                    spacer2 = { name = "", type = "header", order = 20},
                    showInPetBattle = {
                        name = "Show in Pet Battles",
                        desc = "Keep bar visible during pet battles",
                        type = "toggle",
                        order = 21,
                        get = function() return self.db.profile.bars[barKey].showInPetBattle end,
                        set = function(_, v)
                            self.db.profile.bars[barKey].showInPetBattle = v
                        end
                    },
                    showInVehicle = {
                        name = "Show in Vehicles",
                        desc = "Keep bar visible when in a vehicle",
                        type = "toggle",
                        order = 22,
                        get = function() return self.db.profile.bars[barKey].showInVehicle end,
                        set = function(_, v)
                            self.db.profile.bars[barKey].showInVehicle = v
                        end
                    },
                    spacer3 = { name = "", type = "header", order = 30},
                    resetPosition = {
                        name = "Reset Position",
                        desc = "Reset bar to default position",
                        type = "execute",
                        order = 31,
                        func = function()
                            local db = self.db.profile.bars[barKey]
                            db.point = config.default.point
                            db.x = config.default.x
                            db.y = config.default.y
                            self:UpdateBar(barKey)
                        end
                    }
                }
            }
            
            -- Add paging options for Action Bar 1
            if barKey == "MainMenuBar" and config.hasPages then
                barOptions.args.spacer4 = { name = "", type = "header", order = 40}
                barOptions.args.pagingHeader = {
                    name = "Bar Paging",
                    type = "description",
                    order = 41,
                    fontSize = "medium",
                }
                barOptions.args.pagingCondition = {
                    name = "Paging Condition",
                    desc = "Macro condition that controls which bar page is shown. Advanced users only.",
                    type = "input",
                    width = "full",
                    multiline = 3,
                    order = 42,
                    get = function() return self.db.profile.bars[barKey].pagingCondition or DEFAULT_PAGING end,
                    set = function(_, v)
                        self.db.profile.bars[barKey].pagingCondition = v
                        self:UpdateBarPaging(barKey)
                    end
                }
                barOptions.args.resetPaging = {
                    name = "Reset to Default",
                    desc = "Reset paging condition to default",
                    type = "execute",
                    order = 43,
                    func = function()
                        self.db.profile.bars[barKey].pagingCondition = DEFAULT_PAGING
                        self:UpdateBarPaging(barKey)
                    end
                }
                barOptions.args.pagingHelp = {
                    name = "Default condition handles: Possess bar, Override bar, Shapeshift forms, Vehicles, and manual bar switching (via keybinds).",
                    type = "description",
                    order = 44,
                    fontSize = "small",
                }
            end
            
            options.args.bars.args[barKey] = barOptions
        end
    end
    
    return options
end