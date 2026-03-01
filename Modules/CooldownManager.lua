-- CooldownManager.lua
-- Skins and positions Blizzard's cooldown manager frames with AbstractUI styling

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local LSM = LibStub("LibSharedMedia-3.0")

-- Create the module
local CooldownManager = AbstractUI:NewModule("CooldownManager", "AceEvent-3.0", "AceHook-3.0")

-- Module reference for global access
_G.CooldownManager = CooldownManager

--------------------------------------------------------------------------------
-- Defaults
--------------------------------------------------------------------------------

local defaults = {
    profile = {
        enabled = true,
        
        -- Essential Cooldowns
        essential = {
            enabled = true,
            position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = -200 },
            iconWidth = 44,
            iconHeight = 44,
            iconSpacing = 4,
            maxPerRow = 12,
            borderThickness = 2,
            borderColor = { 0, 0, 0, 1 },
            backgroundColor = { 0, 0, 0, 0.8 },
            font = "Friz Quadrata TT",
            fontSize = 14,
            fontFlag = "OUTLINE",
            showKeybinds = true,
            showAssistedHighlight = true,
        },
        
        -- Utility Cooldowns
        utility = {
            enabled = true,
            position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = -250 },
            iconWidth = 36,
            iconHeight = 36,
            iconSpacing = 4,
            maxPerRow = 16,
            borderThickness = 2,
            borderColor = { 0, 0, 0, 1 },
            backgroundColor = { 0, 0, 0, 0.8 },
            font = "Friz Quadrata TT",
            fontSize = 12,
            fontFlag = "OUTLINE",
            showKeybinds = true,
            showAssistedHighlight = true,
        },
        
        -- Font settings
        font = "Friz Quadrata TT",
        fontSize = 14,
        fontFlag = "OUTLINE",
    }
}

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function CooldownManager:OnInitialize()
    -- Setup database
    self.db = AbstractUI.db:RegisterNamespace("CooldownManager", defaults)
    
    -- Track highlighted spells for assisted highlight feature
    self.highlightedSpells = {}
end

function CooldownManager:OnEnable()
    if not self.db.profile.enabled then return end
    
    -- Enable Blizzard's cooldown manager
    C_CVar.SetCVar("cooldownViewerEnabled", "1")
    
    -- Hook Blizzard's cooldown manager updates
    self:HookBlizzardCooldownManager()
    
    -- Hook spell activation overlays
    self:HookSpellActivationOverlays()
    
    -- Initial styling and layout
    self:UpdateCooldownManager()
    
    -- Register events
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateCooldownManager")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "UpdateCooldownManager")
    self:RegisterEvent("SPELLS_CHANGED", "UpdateCooldownManager")
end

function CooldownManager:HookSpellActivationOverlays()
    -- Try multiple approaches to detect spell activation overlays
    
    -- Approach 1: Hook the frame methods
    if SpellActivationOverlayFrame then
        print("DEBUG: Found SpellActivationOverlayFrame, hooking methods")
        
        -- Try hooking ShowOverlay
        if SpellActivationOverlayFrame.ShowOverlay then
            hooksecurefunc(SpellActivationOverlayFrame, "ShowOverlay", function(frame, spellID, texture, position, scale, r, g, b)
                print("DEBUG: ShowOverlay called - spellID:", spellID, C_Spell.GetSpellName(spellID))
                if spellID then
                    self.highlightedSpells[spellID] = true
                    self:UpdateSpellHighlight(spellID, true)
                end
            end)
        end
        
        -- Try hooking HideOverlays
        if SpellActivationOverlayFrame.HideOverlays then
            hooksecurefunc(SpellActivationOverlayFrame, "HideOverlays", function(frame)
                print("DEBUG: HideOverlays called")
                for spellID, _ in pairs(self.highlightedSpells) do
                    self:UpdateSpellHighlight(spellID, false)
                end
                wipe(self.highlightedSpells)
            end)
        end
    else
        print("DEBUG: SpellActivationOverlayFrame not found")
    end
    
    -- Approach 2: Poll for active overlays
    self:StartOverlayPolling()
end

function CooldownManager:StartOverlayPolling()
    print("DEBUG: Starting overlay polling")
    
    local debugOnce = false
    local lastOverlayCount = 0
    
    -- Poll every 0.1 seconds to check for active overlays
    self.overlayTimer = C_Timer.NewTicker(0.1, function()
        if not self.db.profile.essential.showAssistedHighlight and 
           not self.db.profile.utility.showAssistedHighlight then
            return
        end
        
        -- Debug: Print frame structure once
        if not debugOnce and SpellActivationOverlayFrame then
            debugOnce = true
            print("DEBUG: SpellActivationOverlayFrame structure:")
            print("  overlaysInUse:", SpellActivationOverlayFrame.overlaysInUse and #SpellActivationOverlayFrame.overlaysInUse or "nil")
            print("  Type:", type(SpellActivationOverlayFrame.overlaysInUse))
            
            -- Check for child frames
            local children = {SpellActivationOverlayFrame:GetChildren()}
            print("  Children count:", #children)
            
            -- Try to find overlays another way
            for key, value in pairs(SpellActivationOverlayFrame) do
                if type(key) == "string" and key:lower():find("overlay") then
                    print("  Found key:", key, "=", type(value))
                end
            end
        end
        
        -- Check all possible overlay positions for active overlays
        if SpellActivationOverlayFrame and SpellActivationOverlayFrame.overlaysInUse then
            local currentCount = #SpellActivationOverlayFrame.overlaysInUse
            
            -- Debug when overlay count changes
            if currentCount ~= lastOverlayCount then
                print("DEBUG: Overlay count changed from", lastOverlayCount, "to", currentCount)
                lastOverlayCount = currentCount
            end
            
            for i = 1, currentCount do
                local overlay = SpellActivationOverlayFrame.overlaysInUse[i]
                if overlay then
                    print("DEBUG: Checking overlay", i, "- spellID:", overlay.spellID, "shown:", overlay:IsShown())
                    
                    if overlay.spellID and overlay:IsShown() then
                        -- Check if this is a new highlight
                        if not self.highlightedSpells[overlay.spellID] then
                            print("DEBUG: Found NEW active overlay for spellID:", overlay.spellID, C_Spell.GetSpellName(overlay.spellID))
                            self.highlightedSpells[overlay.spellID] = true
                            self:UpdateSpellHighlight(overlay.spellID, true)
                        end
                    end
                end
            end
            
            -- Check for spells that are no longer highlighted
            for spellID, _ in pairs(self.highlightedSpells) do
                local stillActive = false
                for i = 1, currentCount do
                    local overlay = SpellActivationOverlayFrame.overlaysInUse[i]
                    if overlay and overlay.spellID == spellID and overlay:IsShown() then
                        stillActive = true
                        break
                    end
                end
                
                if not stillActive then
                    print("DEBUG: Overlay no longer active for spellID:", spellID)
                    self.highlightedSpells[spellID] = nil
                    self:UpdateSpellHighlight(spellID, false)
                end
            end
        end
    end)
end

function CooldownManager:OnDisable()
    -- Stop overlay polling
    if self.overlayTimer then
        self.overlayTimer:Cancel()
        self.overlayTimer = nil
    end
    
    self:UnhookAll()
    self:UnregisterAllEvents()
end

--------------------------------------------------------------------------------
-- Blizzard Frame Hooking
--------------------------------------------------------------------------------

function CooldownManager:HookBlizzardCooldownManager()
    -- Hook when Blizzard's cooldown manager updates
    if CooldownViewerSettings then
        self:SecureHook(CooldownViewerSettings, "RefreshLayout", function()
            C_Timer.After(0.1, function()
                self:UpdateCooldownManager()
            end)
        end)
    end
    
    -- Hook Edit Mode changes
    if EditModeManagerFrame then
        self:SecureHook(EditModeManagerFrame, "EnterEditMode", "OnEditModeEnter")
        self:SecureHook(EditModeManagerFrame, "ExitEditMode", "OnEditModeExit")
    end
end

function CooldownManager:OnEditModeEnter()
    -- User is in Blizzard's Edit Mode - don't interfere
end

function CooldownManager:OnEditModeExit()
    -- Re-apply our styling after Edit Mode changes
    self:UpdateCooldownManager()
end

--------------------------------------------------------------------------------
-- Main Update Function
--------------------------------------------------------------------------------

function CooldownManager:UpdateCooldownManager()
    if not self.db.profile.enabled then return end
    if InCombatLockdown() then
        -- Queue update for after combat
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UpdateCooldownManager()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        end)
        return
    end
    
    -- Update Essential Cooldowns
    if self.db.profile.essential.enabled then
        self:UpdateViewerDisplay("EssentialCooldownViewer", "essential")
    end
    
    -- Update Utility Cooldowns
    if self.db.profile.utility.enabled then
        self:UpdateViewerDisplay("UtilityCooldownViewer", "utility")
    end
    
    -- Update Resource Bars if they're attached to Essential Cooldowns
    C_Timer.After(0.1, function()
        local ResourceBars = AbstractUI:GetModule("ResourceBars", true)
        if ResourceBars and ResourceBars.db and ResourceBars.db.profile.primary.attachToEssentialCooldowns then
            ResourceBars:UpdatePrimaryResourceBar()
        end
    end)
end

function CooldownManager:UpdateViewerDisplay(viewerName, displayType)
    local viewer = _G[viewerName]
    if not viewer then return end
    
    -- Get all child frames from Blizzard's viewer
    local children = { viewer:GetChildren() }
    
    -- Skin each visible frame
    for _, childFrame in ipairs(children) do
        if childFrame and childFrame.layoutIndex and childFrame:IsShown() then
            self:SkinBlizzardFrame(childFrame, displayType)
        end
    end
    
    -- Refresh assisted highlights if enabled
    local db = self.db.profile[displayType]
    if db and db.showAssistedHighlight then
        self:RefreshAllHighlights(viewer)
    end
end

--------------------------------------------------------------------------------
-- Assisted Highlight Support
--------------------------------------------------------------------------------

function CooldownManager:UpdateSpellHighlight(spellID, show)
    print("DEBUG: UpdateSpellHighlight called for spellID:", spellID, "show:", show)
    
    -- Update Essential Cooldowns
    if self.db.profile.essential.enabled and self.db.profile.essential.showAssistedHighlight then
        print("  Checking Essential Cooldowns")
        local frame = _G["EssentialCooldownViewer"]
        if frame then
            self:ApplyHighlightToViewer(frame, spellID, show)
        else
            print("  EssentialCooldownViewer not found!")
        end
    end
    
    -- Update Utility Cooldowns
    if self.db.profile.utility.enabled and self.db.profile.utility.showAssistedHighlight then
        print("  Checking Utility Cooldowns")
        local frame = _G["UtilityCooldownViewer"]
        if frame then
            self:ApplyHighlightToViewer(frame, spellID, show)
        else
            print("  UtilityCooldownViewer not found!")
        end
    end
end

function CooldownManager:ApplyHighlightToViewer(viewerFrame, spellID, show)
    if not viewerFrame then return end
    
    print("  ApplyHighlightToViewer: Looking for spellID", spellID, "in viewer")
    local foundCount = 0
    
    -- Search through child frames to find ones with this spell ID
    for _, childFrame in ipairs({viewerFrame:GetChildren()}) do
        local frameSpellID = childFrame.spellID 
            or childFrame.spellId 
            or (childFrame.spell and childFrame.spell:GetSpellID())
            or (childFrame.GetSpellID and childFrame:GetSpellID())
        
        if frameSpellID then
            print("    Found frame with spellID:", frameSpellID, C_Spell.GetSpellName(frameSpellID))
        end
        
        if frameSpellID == spellID then
            foundCount = foundCount + 1
            print("    MATCH! Applying highlight, show:", show)
            
            if show then
                -- Add blue glow like Blizzard's assisted highlight
                if not childFrame.assistedHighlight then
                    childFrame.assistedHighlight = childFrame:CreateTexture(nil, "OVERLAY", nil, 1)
                    childFrame.assistedHighlight:SetAllPoints(childFrame)
                    childFrame.assistedHighlight:SetTexture("Interface\\Cooldown\\star4")
                    childFrame.assistedHighlight:SetBlendMode("ADD")
                    
                    -- Blue color to match Blizzard's highlight
                    childFrame.assistedHighlight:SetVertexColor(0.3, 0.7, 1.0, 0.8)
                    
                    -- Pulse animation
                    if not childFrame.assistedHighlightAnim then
                        childFrame.assistedHighlightAnim = childFrame.assistedHighlight:CreateAnimationGroup()
                        local alpha1 = childFrame.assistedHighlightAnim:CreateAnimation("Alpha")
                        alpha1:SetFromAlpha(0.4)
                        alpha1:SetToAlpha(0.8)
                        alpha1:SetDuration(0.6)
                        alpha1:SetOrder(1)
                        
                        local alpha2 = childFrame.assistedHighlightAnim:CreateAnimation("Alpha")
                        alpha2:SetFromAlpha(0.8)
                        alpha2:SetToAlpha(0.4)
                        alpha2:SetDuration(0.6)
                        alpha2:SetOrder(2)
                        
                        childFrame.assistedHighlightAnim:SetLooping("REPEAT")
                    end
                end
                
                childFrame.assistedHighlight:Show()
                childFrame.assistedHighlightAnim:Play()
            else
                -- Remove highlight
                if childFrame.assistedHighlight then
                    childFrame.assistedHighlight:Hide()
                end
                if childFrame.assistedHighlightAnim then
                    childFrame.assistedHighlightAnim:Stop()
                end
            end
        end
    end
    
    print("  ApplyHighlightToViewer: Found", foundCount, "matching frames")
end

function CooldownManager:RefreshAllHighlights(viewerFrame)
    if not viewerFrame then return end
    
    -- Re-apply highlights for all currently highlighted spells
    for spellID, _ in pairs(self.highlightedSpells) do
        self:ApplyHighlightToViewer(viewerFrame, spellID, true)
    end
end

--------------------------------------------------------------------------------
-- Viewer Display Management
--------------------------------------------------------------------------------
-- Frame Styling
--------------------------------------------------------------------------------

function CooldownManager:GetActionSlotBinding(actionSlot)
    -- First, try to find Dominos buttons with action attributes
    for i = 1, 180 do
        local button = _G["DominosActionButton" .. i]
        if button then
            local buttonAction = button.action or (button.GetAttribute and button:GetAttribute("action"))
            
            if buttonAction == actionSlot then
                -- Found the Dominos button displaying this action slot
                local bindName = "CLICK DominosActionButton" .. i .. ":HOTKEY"
                local key1, key2 = GetBindingKey(bindName)
                local clickBinding = key1 or key2
                
                if clickBinding then
                    clickBinding = clickBinding:gsub("SHIFT%-", "S")
                    clickBinding = clickBinding:gsub("CTRL%-", "C")
                    clickBinding = clickBinding:gsub("ALT%-", "A")
                    clickBinding = clickBinding:gsub("SPACE", "SP")
                    return clickBinding
                end
            end
        end
    end
    
    -- Fallback: Try standard WoW keybinding names 
    -- These work for both Blizzard bars and Dominos-skinned Blizzard bars
    local bindingName
    
    if actionSlot >= 1 and actionSlot <= 12 then
        bindingName = "ACTIONBUTTON" .. actionSlot
    elseif actionSlot >= 13 and actionSlot <= 24 then
        bindingName = "MULTIACTIONBAR1BUTTON" .. (actionSlot - 12)
    elseif actionSlot >= 25 and actionSlot <= 36 then
        bindingName = "MULTIACTIONBAR2BUTTON" .. (actionSlot - 24)
    elseif actionSlot >= 37 and actionSlot <= 48 then
        bindingName = "MULTIACTIONBAR3BUTTON" .. (actionSlot - 36)
    elseif actionSlot >= 49 and actionSlot <= 60 then
        bindingName = "MULTIACTIONBAR4BUTTON" .. (actionSlot - 48)
    elseif actionSlot >= 61 and actionSlot <= 72 then
        bindingName = "MULTIACTIONBAR5BUTTON" .. (actionSlot - 60)
    elseif actionSlot >= 73 and actionSlot <= 84 then
        bindingName = "MULTIACTIONBAR6BUTTON" .. (actionSlot - 72)
    elseif actionSlot >= 85 and actionSlot <= 96 then
        bindingName = "MULTIACTIONBAR7BUTTON" .. (actionSlot - 84)
    else
        bindingName = "ACTIONBUTTON" .. actionSlot
    end
    
    local key1, key2 = GetBindingKey(bindingName)
    local binding = key1 or key2
    
    if binding then
        binding = binding:gsub("SHIFT%-", "S")
        binding = binding:gsub("CTRL%-", "C")
        binding = binding:gsub("ALT%-", "A")
        binding = binding:gsub("SPACE", "SP")
        return binding
    end
    
    -- Last resort: Check for CLICK bindings on Blizzard UI buttons
    -- Dominos may bind keys to these buttons directly
    -- More importantly: Dominos may set custom action slot numbers on buttons,
    -- but the keybinds are still tied to the button's ORIGINAL bar position
    local blizzardButtons = {
        {pattern = "ActionButton", bar = nil, offset = 0},                -- Main bar, slots 1-12, ACTIONBUTTON
        {pattern = "MultiBarBottomLeftButton", bar = 1, offset = 12},     -- Bottom left, slots 13-24, MULTIACTIONBAR1BUTTON
        {pattern = "MultiBarBottomRightButton", bar = 2, offset = 24},    -- Bottom right, slots 25-36, MULTIACTIONBAR2BUTTON  
        {pattern = "MultiBarRightButton", bar = 3, offset = 36},          -- Right bar, slots 37-48, MULTIACTIONBAR3BUTTON
        {pattern = "MultiBarLeftButton", bar = 4, offset = 48},           -- Left bar, slots 49-60, MULTIACTIONBAR4BUTTON
        {pattern = "MultiBarRightActionButton", bar = 3, offset = 36},    -- Right bar alt name, MULTIACTIONBAR3BUTTON
        {pattern = "MultiBarLeftActionButton", bar = 4, offset = 48},     -- Left bar alt name, MULTIACTIONBAR4BUTTON
    }
    
    for _, buttonInfo in ipairs(blizzardButtons) do
        for i = 1, 12 do
            local buttonName = buttonInfo.pattern .. i
            local button = _G[buttonName]
            if button then
                local buttonAction = button.action or (button.GetAttribute and button:GetAttribute("action"))
                
                if buttonAction == actionSlot then
                    -- Found the button! Now check keybind based on button's BAR, not action slot
                    local barBindingName
                    if not buttonInfo.bar then
                        barBindingName = "ACTIONBUTTON" .. i
                    else
                        barBindingName = "MULTIACTIONBAR" .. buttonInfo.bar .. "BUTTON" .. i
                    end
                    
                    local k1, k2 = GetBindingKey(barBindingName)
                    local barBind = k1 or k2
                    
                    if barBind then
                        barBind = barBind:gsub("SHIFT%-", "S")
                        barBind = barBind:gsub("CTRL%-", "C")
                        barBind = barBind:gsub("ALT%-", "A")
                        barBind = barBind:gsub("SPACE", "SP")
                        return barBind
                    end
                    
                    -- Also try CLICK bindings
                    local bindFormats = {
                        "CLICK " .. buttonName .. ":HOTKEY",
                        "CLICK " .. buttonName .. ":LeftButton",
                    }
                    
                    for _, bindFormat in ipairs(bindFormats) do
                        local bk1, bk2 = GetBindingKey(bindFormat)
                        local clickBind = bk1 or bk2
                        
                        if clickBind then
                            clickBind = clickBind:gsub("SHIFT%-", "S")
                            clickBind = clickBind:gsub("CTRL%-", "C")
                            clickBind = clickBind:gsub("ALT%-", "A")
                            clickBind = clickBind:gsub("SPACE", "SP")
                            return clickBind
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

function CooldownManager:CleanKeybindText(text)
    if not text then return nil end
    
    -- Remove WoW formatting codes
    text = text:gsub("|c........", ""):gsub("|r", ""):gsub("|T.-|t", "")
    
    return text
end

function CooldownManager:GetSpellKeybind(spellID)
    if not spellID then return nil end
    
    -- First, try to get direct spell keybind (for spells bound directly, not via action bars)
    local spellName = C_Spell.GetSpellName(spellID)
    if spellName then
        local key1, key2 = GetBindingKey("SPELL " .. spellName)
        local directBind = key1 or key2
        if directBind then
            directBind = directBind:gsub("SHIFT%-", "S")
            directBind = directBind:gsub("CTRL%-", "C")
            directBind = directBind:gsub("ALT%-", "A")
            directBind = directBind:gsub("SPACE", "SP")
            return directBind
        end
    end
    
    -- Use WoW's C_ActionBar API to find all action slots containing this spell
    -- This works with macros AND is addon-agnostic (works with any action bar addon)
    if C_ActionBar and C_ActionBar.FindSpellActionButtons then
        local slots = C_ActionBar.FindSpellActionButtons(spellID)
        
        if slots and #slots > 0 then
            -- If spell is in multiple slots, try to find one with a keybind
            -- Prefer keybinds with modifiers (Ctrl, Shift, Alt) over plain keys
            local bestSlot = nil
            local bestKeybind = nil
            local bestScore = -1
            
            for _, slot in ipairs(slots) do
                local keybind = self:GetActionSlotBinding(slot)
                
                if keybind then
                    -- Score the keybind: modifiers are better than plain keys
                    local score = 0
                    if keybind:find("C") then score = score + 3 end  -- Ctrl
                    if keybind:find("A") then score = score + 2 end  -- Alt  
                    if keybind:find("S") then score = score + 1 end  -- Shift
                    
                    if score > bestScore or (score == bestScore and not bestKeybind) then
                        bestScore = score
                        bestKeybind = keybind
                        bestSlot = slot
                    end
                elseif not bestKeybind then
                    -- No keybind yet, use this slot as fallback
                    bestSlot = slot
                end
            end
            
            if bestKeybind then
                return bestKeybind
            elseif bestSlot then
                return self:GetActionSlotBinding(bestSlot)
            end
        end
    end
    
    return nil
end

function CooldownManager:SkinBlizzardFrame(childFrame, displayType)
    local db = self.db.profile[displayType]
    
    -- Resize the frame
    childFrame:SetSize(db.iconWidth, db.iconHeight)
    
    -- Style the icon
    if childFrame.Icon then
        childFrame.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        childFrame.Icon:ClearAllPoints()
        childFrame.Icon:SetPoint("TOPLEFT", childFrame, "TOPLEFT", db.borderThickness, -db.borderThickness)
        childFrame.Icon:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", -db.borderThickness, db.borderThickness)
    end
    
    -- Style the cooldown swipe - use dark swipe like Blizzard default
    if childFrame.Cooldown then
        childFrame.Cooldown:SetSwipeColor(0, 0, 0, 0.8)  -- Dark swipe overlay
        childFrame.Cooldown:SetDrawEdge(true)
        childFrame.Cooldown:SetDrawSwipe(true)
        childFrame.Cooldown:SetHideCountdownNumbers(false)
    end
    
    -- Add custom border if it doesn't exist
    if not childFrame.customBorder then
        childFrame.customBorder = childFrame:CreateTexture(nil, "BORDER")
        childFrame.customBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
        childFrame.customBorder:SetAllPoints(childFrame)
        childFrame.customBorder:SetVertexColor(db.borderColor[1], db.borderColor[2], db.borderColor[3], db.borderColor[4])
    end
    
    -- Add custom background
    if not childFrame.customBackground then
        childFrame.customBackground = childFrame:CreateTexture(nil, "BACKGROUND")
        childFrame.customBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
        childFrame.customBackground:SetPoint("TOPLEFT", childFrame, "TOPLEFT", db.borderThickness, -db.borderThickness)
        childFrame.customBackground:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", -db.borderThickness, db.borderThickness)
        childFrame.customBackground:SetVertexColor(db.backgroundColor[1], db.backgroundColor[2], db.backgroundColor[3], db.backgroundColor[4])
    end
    
    -- Add keybind text if enabled
    if db.showKeybinds then
        if not childFrame.customKeybind then
            childFrame.customKeybind = childFrame:CreateFontString(nil, "OVERLAY")
            childFrame.customKeybind:SetPoint("TOPLEFT", childFrame, "TOPLEFT", 3, -3)
            childFrame.customKeybind:SetJustifyH("LEFT")
            childFrame.customKeybind:SetDrawLayer("OVERLAY", 7)  -- High sublayer to be on top
        end
        
        local fontPath = LSM:Fetch("font", db.font)
        local keybindFontSize = math.max(11, db.fontSize)  -- Same size as main font, min 11
        childFrame.customKeybind:SetFont(fontPath, keybindFontSize, "OUTLINE")
        childFrame.customKeybind:SetTextColor(1, 1, 1, 1)  -- White, fully opaque
        childFrame.customKeybind:SetShadowColor(0, 0, 0, 1)
        childFrame.customKeybind:SetShadowOffset(1, -1)
        
        -- Get the spell ID - try multiple possible properties
        local spellID = childFrame.spellID 
            or childFrame.spellId 
            or (childFrame.spell and childFrame.spell:GetSpellID())
            or (childFrame.GetSpellID and childFrame:GetSpellID())
        
        if spellID then
            local keybind = self:GetSpellKeybind(spellID)
            if keybind then
                childFrame.customKeybind:SetText(keybind)
                childFrame.customKeybind:Show()
            else
                childFrame.customKeybind:Hide()
            end
        else
            childFrame.customKeybind:Hide()
        end
    elseif childFrame.customKeybind then
        childFrame.customKeybind:Hide()
    end
    
    -- Style charge count text
    if childFrame.ChargeCount and childFrame.ChargeCount.Current then
        local fontPath = LSM:Fetch("font", db.font)
        childFrame.ChargeCount.Current:SetFont(fontPath, db.fontSize, db.fontFlag)
        childFrame.ChargeCount.Current:SetTextColor(1, 1, 1, 1)
    end
    
    -- Style application count text
    if childFrame.Applications and childFrame.Applications.Applications then
        local fontPath = LSM:Fetch("font", db.font)
        childFrame.Applications.Applications:SetFont(fontPath, db.fontSize, db.fontFlag)
        childFrame.Applications.Applications:SetTextColor(1, 1, 1, 1)
    end
    
    -- Hide elements we don't want
    if childFrame.CooldownFlash then
        childFrame.CooldownFlash:SetAlpha(0)
    end
    if childFrame.DebuffBorder then
        childFrame.DebuffBorder:SetAlpha(0)
    end
    
    -- Make sure the frame is visible
    childFrame:Show()
end

--------------------------------------------------------------------------------
-- Configuration Options
--------------------------------------------------------------------------------

function CooldownManager:GetOptions()
    return {
        type = "group",
        name = "Cooldown Manager",
        args = {
            enabled = {
                type = "toggle",
                name = "Enable Cooldown Manager",
                desc = "Enable the cooldown manager module",
                order = 1,
                get = function() return self.db.profile.enabled end,
                set = function(_, value)
                    self.db.profile.enabled = value
                    if value then
                        self:Enable()
                    else
                        self:Disable()
                    end
                end,
            },
            essentialHeader = {
                type = "header",
                name = "Essential Cooldowns",
                order = 10
            },
            essentialEnabled = {
                type = "toggle",
                name = "Enable Essential Cooldowns",
                order = 11,
                get = function() return self.db.profile.essential.enabled end,
                set = function(_, value)
                    self.db.profile.essential.enabled = value
                    self:UpdateCooldownManager()
                end,
            },
            essentialIconSize = {
                type = "range",
                name = "Essential Icon Size",
                order = 12,
                width = "inline",
                min = 24,
                max = 64,
                step = 2,
                get = function() return self.db.profile.essential.iconWidth end,
                set = function(_, value)
                    self.db.profile.essential.iconWidth = value
                    self.db.profile.essential.iconHeight = value
                    self:UpdateCooldownManager()
                end,
            },
            essentialSpacing = {
                type = "range",
                name = "Essential Icon Spacing",
                order = 13,
                width = "inline",
                min = 0,
                max = 20,
                step = 1,
                get = function() return self.db.profile.essential.iconSpacing end,
                set = function(_, value)
                    self.db.profile.essential.iconSpacing = value
                    self:UpdateCooldownManager()
                end,
            },
            essentialMaxPerRow = {
                type = "range",
                name = "Essential Icons Per Row",
                order = 14,
                width = "inline",
                min = 1,
                max = 20,
                step = 1,
                get = function() return self.db.profile.essential.maxPerRow end,
                set = function(_, value)
                    self.db.profile.essential.maxPerRow = value
                    self:UpdateCooldownManager()
                end,
            },
            essentialShowKeybinds = {
                type = "toggle",
                name = "Show Keybinds",
                desc = "Display action bar keybinds on essential cooldown icons",
                order = 15,
                get = function() return self.db.profile.essential.showKeybinds end,
                set = function(_, value)
                    self.db.profile.essential.showKeybinds = value
                    self:UpdateCooldownManager()
                end,
            },
            essentialAssistedHighlight = {
                type = "toggle",
                name = "Show Assisted Highlight",
                desc = "Show blue glow when Blizzard's Assisted Highlight recommends using the spell",
                order = 16,
                get = function() return self.db.profile.essential.showAssistedHighlight end,
                set = function(_, value)
                    self.db.profile.essential.showAssistedHighlight = value
                    self:UpdateCooldownManager()
                end,
            },
            utilityHeader = {
                type = "header",
                name = "Utility Cooldowns",
                order = 20
            },
            utilityEnabled = {
                type = "toggle",
                name = "Enable Utility Cooldowns",
                order = 21,
                get = function() return self.db.profile.utility.enabled end,
                set = function(_, value)
                    self.db.profile.utility.enabled = value
                    self:UpdateCooldownManager()
                end,
            },
            utilityIconSize = {
                type = "range",
                name = "Utility Icon Size",
                order = 22,
                width = "inline",
                min = 24,
                max = 64,
                step = 2,
                get = function() return self.db.profile.utility.iconWidth end,
                set = function(_, value)
                    self.db.profile.utility.iconWidth = value
                    self.db.profile.utility.iconHeight = value
                    self:UpdateCooldownManager()
                end,
            },
            utilitySpacing = {
                type = "range",
                name = "Utility Icon Spacing",
                order = 23,
                width = "inline",
                min = 0,
                max = 20,
                step = 1,
                get = function() return self.db.profile.utility.iconSpacing end,
                set = function(_, value)
                    self.db.profile.utility.iconSpacing = value
                    self:UpdateCooldownManager()
                end,
            },
            utilityMaxPerRow = {
                type = "range",
                name = "Utility Icons Per Row",
                order = 24,
                width = "inline",
                min = 1,
                max = 20,
                step = 1,
                get = function() return self.db.profile.utility.maxPerRow end,
                set = function(_, value)
                    self.db.profile.utility.maxPerRow = value
                    self:UpdateCooldownManager()
                end,
            },
            utilityShowKeybinds = {
                type = "toggle",
                name = "Show Keybinds",
                desc = "Display action bar keybinds on utility cooldown icons",
                order = 25,
                get = function() return self.db.profile.utility.showKeybinds end,
                set = function(_, value)
                    self.db.profile.utility.showKeybinds = value
                    self:UpdateCooldownManager()
                end,
            },
            utilityAssistedHighlight = {
                type = "toggle",
                name = "Show Assisted Highlight",
                desc = "Show blue glow when Blizzard's Assisted Highlight recommends using the spell",
                order = 26,
                get = function() return self.db.profile.utility.showAssistedHighlight end,
                set = function(_, value)
                    self.db.profile.utility.showAssistedHighlight = value
                    self:UpdateCooldownManager()
                end,
            },
        },
    }
end

return CooldownManager
