-- ============================================================================
-- Cursor Animate Module
-- ============================================================================
-- Enhanced cursor visibility with customizable animation effects and highlighting.
-- Incorporates features from CursorFX addon.
-- 
-- Features:
-- - Smooth particle trail with multiple styles (classic, rainbow, comet)
-- - Glowing highlight effect with optional pulse animation
-- - Sparkles effect when cursor is idle
-- - Ring effect with GCD tracking
-- - Health and combat alerts (low health warning, aggro detection)
-- - Customizable colors, sizes, textures, and blend modes
-- - Combat awareness (hide/show based on combat state)
-- - Performance optimized particle system with object pooling
-- ============================================================================

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local CursorTrail = AbstractUI:NewModule("CursorAnimate", "AceEvent-3.0")
local ColorPalette = _G.AbstractUI_ColorPalette

-- Frame pools
local trailFrames = {}
local sparkleFrames = {}
local maxTrailFrames = 30
local maxSparkleFrames = 20
local currentTrailIndex = 1
local sparkleFreeList = {}
local updateFrame
local highlightFrame
local ringFrame

-- State tracking
local lastCursorX, lastCursorY = 0, 0
local idleTime = 0
local rainbowPhase = 0
local pulseTime = 0
local isInCombat = false
local hasLowHealth = false

local defaults = {
    profile = {
        enabled = true,
        
        -- Trail settings
        trailEnabled = true,
        trailLength = 15,
        trailSize = 48, -- Increased from 32 for better visibility
        trailFadeSpeed = 0.25, -- Increased from 0.15 to last longer
        trailSpacing = 2, -- Reduced from 3 for more particles
        trailColor = { r = 0.6, g = 0.6, b = 0.6, a = 0.5 }, -- Minimal theme
        trailTexture = "Glow",
        trailBlendMode = "ADD",
        trailStyle = "classic", -- classic, rainbow, comet
        
        -- Highlight settings
        highlightEnabled = false,
        highlightSize = 64, -- Increased from 48 for better visibility
        highlightAlpha = 0.5,
        highlightPulse = true,
        highlightColor = { r = 0.65, g = 0.65, b = 0.65, a = 0.5 }, -- Minimal theme
        highlightTexture = "Glow",
        highlightBlendMode = "ADD",
        
        -- Sparkles settings
        sparklesEnabled = false,
        sparklesIdleDelay = 1.0, -- Seconds before sparkles appear
        sparklesSize = 12,
        sparklesSpawnRate = 0.1, -- Seconds between spawns
        sparklesLifetime = 0.8,
        sparklesColor = { r = 0.8, g = 0.8, b = 0.8, a = 0.4 }, -- Minimal theme
        sparklesTexture = "Star",
        
        -- Ring settings
        ringEnabled = false,
        ringSize = 64,
        ringColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }, -- Minimal theme
        ringTexture = "Circle",
        ringPulse = true,
        ringShowGCD = true,
        
        -- Combat/Health alerts
        alertsEnabled = false,
        lowHealthWarning = true,
        lowHealthThreshold = 30,
        aggroWarning = true,
        
        -- Combat settings
        hideInCombat = false,
        combatOnlyHighlight = false,
    }
}

-- Expanded texture library from CursorFX
local TEXTURES = {
    -- Basic shapes
    ["Glow"] = "Interface\\Cooldown\\star4",
    ["GlowSoft"] = "Interface\\AddOns\\AbstractUI\\Media\\Textures\\glow_soft_256",
    ["Star"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1",
    ["Circle"] = "Interface\\AddOns\\AbstractUI\\Media\\Textures\\ring_circle_512",
    ["CircleThick"] = "Interface\\AddOns\\AbstractUI\\Media\\Textures\\ring_thick_512",
    ["Spark"] = "Interface\\CastingBar\\UI-CastingBar-Spark",
    ["Square"] = "Interface\\Buttons\\UI-Quickslot2",
    
    -- Raid markers
    ["Diamond"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_3",
    ["Triangle"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_4",
    ["Moon"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_5",
    ["Cross"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7",
    ["Skull"] = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8",
    
    -- Additional effects
    ["Orb"] = "Interface\\Cooldown\\ping4",
}

-- Color theme definitions
local COLOR_THEMES = {
    ["Default"] = {
        trail = { r = 0.0, g = 0.8, b = 1.0, a = 1.0 },
        ring = { r = 1.0, g = 1.0, b = 1.0, a = 0.8 },
        sparkles = { r = 0.3, g = 0.9, b = 1.0, a = 0.7 },
        highlight = { r = 1.0, g = 1.0, b = 1.0, a = 0.7 },
    },
    ["Dark"] = {
        trail = { r = 0.15, g = 0.15, b = 0.15, a = 1.0 },
        ring = { r = 0.2, g = 0.2, b = 0.2, a = 0.8 },
        sparkles = { r = 0.3, g = 0.3, b = 0.3, a = 0.7 },
        highlight = { r = 0.25, g = 0.25, b = 0.25, a = 0.7 },
    },
    ["Light"] = {
        trail = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        ring = { r = 0.95, g = 0.95, b = 0.95, a = 0.8 },
        sparkles = { r = 1.0, g = 1.0, b = 1.0, a = 0.7 },
        highlight = { r = 0.9, g = 0.9, b = 0.9, a = 0.7 },
    },
    ["Neon"] = {
        trail = { r = 0.0, g = 1.0, b = 0.5, a = 1.0 },
        ring = { r = 0.0, g = 1.0, b = 0.5, a = 0.8 },
        sparkles = { r = 0.0, g = 1.0, b = 0.8, a = 0.7 },
        highlight = { r = 0.0, g = 1.0, b = 0.6, a = 0.7 },
    },
    ["Fire"] = {
        trail = { r = 1.0, g = 0.5, b = 0.0, a = 1.0 },
        ring = { r = 1.0, g = 0.3, b = 0.0, a = 0.8 },
        sparkles = { r = 1.0, g = 0.6, b = 0.2, a = 0.7 },
        highlight = { r = 1.0, g = 0.4, b = 0.0, a = 0.7 },
    },
    ["Frost"] = {
        trail = { r = 0.3, g = 0.7, b = 1.0, a = 1.0 },
        ring = { r = 0.4, g = 0.8, b = 1.0, a = 0.8 },
        sparkles = { r = 0.5, g = 0.85, b = 1.0, a = 0.7 },
        highlight = { r = 0.4, g = 0.75, b = 1.0, a = 0.7 },
    },
    ["Nature"] = {
        trail = { r = 0.2, g = 0.9, b = 0.2, a = 1.0 },
        ring = { r = 0.3, g = 1.0, b = 0.3, a = 0.8 },
        sparkles = { r = 0.4, g = 1.0, b = 0.4, a = 0.7 },
        highlight = { r = 0.25, g = 0.95, b = 0.25, a = 0.7 },
    },
    ["Shadow"] = {
        trail = { r = 0.4, g = 0.2, b = 0.6, a = 1.0 },
        ring = { r = 0.5, g = 0.3, b = 0.7, a = 0.8 },
        sparkles = { r = 0.6, g = 0.4, b = 0.8, a = 0.7 },
        highlight = { r = 0.45, g = 0.25, b = 0.65, a = 0.7 },
    },
    ["Golden"] = {
        trail = { r = 1.0, g = 0.8, b = 0.0, a = 1.0 },
        ring = { r = 1.0, g = 0.75, b = 0.0, a = 0.8 },
        sparkles = { r = 1.0, g = 0.85, b = 0.3, a = 0.7 },
        highlight = { r = 1.0, g = 0.8, b = 0.1, a = 0.7 },
    },
    ["Blood"] = {
        trail = { r = 0.8, g = 0.0, b = 0.0, a = 1.0 },
        ring = { r = 0.9, g = 0.1, b = 0.1, a = 0.8 },
        sparkles = { r = 1.0, g = 0.2, b = 0.2, a = 0.7 },
        highlight = { r = 0.85, g = 0.0, b = 0.0, a = 0.7 },
    },
    ["Arcane"] = {
        trail = { r = 0.6, g = 0.4, b = 1.0, a = 1.0 },
        ring = { r = 0.7, g = 0.5, b = 1.0, a = 0.8 },
        sparkles = { r = 0.8, g = 0.6, b = 1.0, a = 0.7 },
        highlight = { r = 0.65, g = 0.45, b = 1.0, a = 0.7 },
    },
    ["Minimal"] = {
        trail = { r = 0.6, g = 0.6, b = 0.6, a = 0.5 },
        ring = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 },
        sparkles = { r = 0.8, g = 0.8, b = 0.8, a = 0.4 },
        highlight = { r = 0.65, g = 0.65, b = 0.65, a = 0.5 },
    },
    ["Comet"] = {
        trail = { r = 0.0, g = 0.6, b = 1.0, a = 1.0 },
        ring = { r = 0.1, g = 0.7, b = 1.0, a = 0.8 },
        sparkles = { r = 0.2, g = 0.8, b = 1.0, a = 0.7 },
        highlight = { r = 0.0, g = 0.65, b = 1.0, a = 0.7 },
    },
    ["Class Color"] = {
        -- Special case: dynamically set in ApplyColorTheme
        trail = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        ring = { r = 1.0, g = 1.0, b = 1.0, a = 0.8 },
        sparkles = { r = 1.0, g = 1.0, b = 1.0, a = 0.7 },
        highlight = { r = 1.0, g = 1.0, b = 1.0, a = 0.7 },
    },
}

function CursorTrail:OnInitialize()
    self:RegisterMessage("AbstractUI_DB_READY", "OnDBReady")
    
    -- Register slash command for quick enable/disable
    SLASH_CURSORANIMATE1 = "/cursoranimate"
    SLASH_CURSORANIMATE2 = "/ca"
    SlashCmdList["CURSORANIMATE"] = function(msg)
        if msg == "on" or msg == "enable" then
            if CursorTrail.db then
                CursorTrail.db.profile.enabled = true
                CursorTrail:Disable()
                CursorTrail:Enable()
                CursorTrail:UpdateVisibility()
            else
            end
        elseif msg == "off" or msg == "disable" then
            if CursorTrail.db then
                CursorTrail.db.profile.enabled = false
                CursorTrail:Disable()
            else
            end
        elseif msg == "status" then
            if CursorTrail.db then
                print("|cff00FF7FCursor Animate:|r Enabled: " .. tostring(CursorTrail.db.profile.enabled))
                print("|cff00FF7FCursor Animate:|r UpdateFrame exists: " .. tostring(updateFrame ~= nil))
                if updateFrame then
                    print("|cff00FF7FCursor Animate:|r UpdateFrame:IsShown(): " .. tostring(updateFrame:IsShown()))
                    print("|cff00FF7FCursor Animate:|r UpdateFrame has OnUpdate: " .. tostring(updateFrame:GetScript("OnUpdate") ~= nil))
                end
                print("|cff00FF7FCursor Animate:|r HighlightFrame exists: " .. tostring(highlightFrame ~= nil))
                if highlightFrame then
                    print("|cff00FF7FCursor Animate:|r HighlightFrame:IsShown(): " .. tostring(highlightFrame:IsShown()))
                end
            end
        elseif msg == "test" then
            -- Force show highlight for testing
            if highlightFrame then
                local x, y = GetCursorPosition()
                local scale = UIParent:GetEffectiveScale()
                x = x / scale
                y = y / scale
                highlightFrame:ClearAllPoints()
                highlightFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
                highlightFrame.texture:SetVertexColor(1, 0, 0, 1) -- Red, full alpha
                highlightFrame:Show()
            end
        else
            print("|cff00FF7FCursor Animate Commands:|r")
            print("  /ca on     - Enable animations")
            print("  /ca off    - Disable animations")
            print("  /ca status - Show current status")
            print("  /ca test   - Force show red highlight at cursor")
        end
    end
end

function CursorTrail:OnDBReady()
    if not AbstractUI.db.profile.modules.cursorTrail then 
        self:Disable()
        return 
    end
    
    self.db = AbstractUI.db:RegisterNamespace("CursorTrail", defaults)
    
    -- Ensure colors are valid
    if not self:ValidateColor(self.db.profile.trailColor) then
        self.db.profile.trailColor = { r = 0.0, g = 0.8, b = 1.0, a = 0.8 }
    end
    
    if not self:ValidateColor(self.db.profile.highlightColor) then
        self.db.profile.highlightColor = { r = 1.0, g = 1.0, b = 1.0, a = 0.5 }
    end
    
    if not self:ValidateColor(self.db.profile.sparklesColor) then
        self.db.profile.sparklesColor = { r = 0.3, g = 0.9, b = 1.0, a = 0.7 }
    end
    
    if not self:ValidateColor(self.db.profile.ringColor) then
        self.db.profile.ringColor = { r = 1.0, g = 1.0, b = 1.0, a = 0.8 }
    end
    
    self:CreateTrailFrames()
    self:CreateHighlightFrame()
    self:CreateSparkleFrames()
    self:CreateRingFrame()
    self:CreateUpdateFrame()
    
    self:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entering combat
    self:RegisterEvent("PLAYER_REGEN_ENABLED") -- Leaving combat
    self:RegisterEvent("UNIT_HEALTH") -- Health changes
    
    if self.db.profile.enabled then
        self:Disable()
        self:Enable()
        self:UpdateVisibility()
    end
end

function CursorTrail:OnEnable()
    -- Don't do anything if DB isn't ready yet
    if not self.db then 
        return 
    end
    
    if updateFrame then
        updateFrame:Show()
    end
    
    self:UpdateVisibility()
end

function CursorTrail:OnDisable()
    if updateFrame then
        updateFrame:Hide()
    end
    if highlightFrame then
        highlightFrame:Hide()
    end
    if ringFrame then
        ringFrame:Hide()
    end
    for _, frame in ipairs(trailFrames) do
        frame:Hide()
    end
    for _, frame in ipairs(sparkleFrames) do
        frame:Hide()
    end
end

function CursorTrail:ValidateColor(color)
    if type(color) ~= "table" then return false end
    if type(color.r) ~= "number" or type(color.g) ~= "number" or 
       type(color.b) ~= "number" or type(color.a) ~= "number" then
        return false
    end
    return true
end

-- HSV to RGB conversion for rainbow trail effect
function CursorTrail:HSVtoRGB(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then return v, t, p end
    if i == 1 then return q, v, p end
    if i == 2 then return p, v, t end
    if i == 3 then return p, q, v end
    if i == 4 then return t, p, v end
    return v, p, q
end

function CursorTrail:CreateTrailFrames()
    for i = 1, maxTrailFrames do
        local frame = CreateFrame("Frame", "AbstractUI_CursorTrail" .. i, UIParent)
        frame:SetSize(32, 32)
        frame:SetFrameStrata("TOOLTIP")
        frame:SetFrameLevel(1000)
        frame:Hide()
        
        local texture = frame:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints()
        texture:SetTexture(TEXTURES["Glow"])
        texture:SetBlendMode("ADD")
        
        frame.texture = texture
        frame.age = 0
        frame.maxAge = 1
        frame.index = i -- For rainbow effect
        
        trailFrames[i] = frame
    end
end

function CursorTrail:CreateHighlightFrame()
    highlightFrame = CreateFrame("Frame", "AbstractUI_CursorHighlight", UIParent)
    highlightFrame:SetSize(48, 48)
    highlightFrame:SetFrameStrata("TOOLTIP")
    highlightFrame:SetFrameLevel(999)
    highlightFrame:Hide()
    
    local texture = highlightFrame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    local texPath = TEXTURES["Glow"] or "Interface\\Cooldown\\star4"
    texture:SetTexture(texPath)
    texture:SetBlendMode("ADD")
    -- Set initial color to white for testing
    texture:SetVertexColor(1, 1, 1, 0.8)
    
    highlightFrame.texture = texture
    highlightFrame.pulseDirection = 1
    highlightFrame.pulseAlpha = 0
end

function CursorTrail:CreateSparkleFrames()
    for i = 1, maxSparkleFrames do
        local frame = CreateFrame("Frame", "AbstractUI_Sparkle" .. i, UIParent)
        frame:SetSize(12, 12)
        frame:SetFrameStrata("TOOLTIP")
        frame:SetFrameLevel(998)
        frame:Hide()
        
        local texture = frame:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints()
        texture:SetTexture(TEXTURES["Star"])
        texture:SetBlendMode("ADD")
        
        frame.texture = texture
        frame.age = 0
        frame.maxAge = 1
        frame.velocityX = 0
        frame.velocityY = 0
        
        sparkleFrames[i] = frame
        sparkleFreeList[i] = i -- All sparkles start in free list
    end
end

function CursorTrail:CreateRingFrame()
    ringFrame = CreateFrame("Frame", "AbstractUI_CursorRing", UIParent)
    ringFrame:SetSize(64, 64)
    ringFrame:SetFrameStrata("TOOLTIP")
    ringFrame:SetFrameLevel(997)
    ringFrame:Hide()
    
    -- Main ring texture
    local texture = ringFrame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetTexture(TEXTURES["Circle"])
    texture:SetBlendMode("ADD")
    
    ringFrame.texture = texture
    
    -- GCD cooldown overlay
    local cooldown = CreateFrame("Cooldown", nil, ringFrame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetHideCountdownNumbers(true)
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
    
    -- Make cooldown circular by setting swipe texture to match ring
    if cooldown.SetSwipeTexture then
        cooldown:SetSwipeTexture("Interface\\AddOns\\AbstractUI\\Media\\Textures\\ring_circle_512")
    end
    
    -- Use circular mask
    cooldown:SetReverse(false)
    
    ringFrame.cooldown = cooldown
end

function CursorTrail:CreateUpdateFrame()
    updateFrame = CreateFrame("Frame", "AbstractUI_CursorUpdate", UIParent)
    updateFrame:Hide()
    
    local frameCount = 0
    local sparkleTimer = 0
    local lastX, lastY = 0, 0
    
    updateFrame:SetScript("OnUpdate", function(self, elapsed)
        if not CursorTrail.db then 
            return 
        end
        if not CursorTrail.db.profile.enabled then 
            return 
        end
        
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        x = x / scale
        y = y / scale
        
        -- Check if cursor moved
        local cursorMoved = (math.abs(x - lastX) > 2 or math.abs(y - lastY) > 2)
        if cursorMoved then
            idleTime = 0
            lastX, lastY = x, y
        else
            idleTime = idleTime + elapsed
        end
        
        -- Update combat/health alerts
        if CursorTrail.db.profile.alertsEnabled then
            CursorTrail:UpdateAlerts()
        end
        
        -- Determine active color (alert color overrides normal color)
        local alertR, alertG, alertB = CursorTrail:GetAlertColor()
        
        -- Update highlight
        if CursorTrail.db.profile.highlightEnabled and highlightFrame then
            local shouldShowHighlight = true
            
            if CursorTrail.db.profile.hideInCombat and isInCombat then
                shouldShowHighlight = false
            elseif CursorTrail.db.profile.combatOnlyHighlight and not isInCombat then
                shouldShowHighlight = false
            end
            
            if shouldShowHighlight then
                highlightFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
                
                -- Use alert color if available
                local color = CursorTrail.db.profile.highlightColor
                local r, g, b, a = alertR or color.r, alertG or color.g, alertB or color.b, color.a
                
                -- Pulse effect
                if CursorTrail.db.profile.highlightPulse then
                    pulseTime = pulseTime + elapsed * 2
                    local pulseAlpha = (math.sin(pulseTime) + 1) / 2
                    a = a * (0.5 + pulseAlpha * 0.5)
                end
                
                highlightFrame.texture:SetVertexColor(r, g, b, a)
                highlightFrame:Show()
            else
                highlightFrame:Hide()
            end
        else
            highlightFrame:Hide()
        end
        
        -- Update ring
        if CursorTrail.db.profile.ringEnabled and ringFrame then
            local shouldShowRing = not (CursorTrail.db.profile.hideInCombat and isInCombat)
            
            if shouldShowRing then
                ringFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
                
                local color = CursorTrail.db.profile.ringColor
                local r, g, b, a = alertR or color.r, alertG or color.g, alertB or color.b, color.a
                
                -- Pulse effect
                if CursorTrail.db.profile.ringPulse then
                    local pulse = (math.sin(GetTime() * 3) + 1) / 2
                    local size = CursorTrail.db.profile.ringSize * (0.9 + pulse * 0.2)
                    ringFrame:SetSize(size, size)
                end
                
                ringFrame.texture:SetVertexColor(r, g, b, a)
                ringFrame:Show()
                
                -- Update GCD cooldown
                if CursorTrail.db.profile.ringShowGCD then
                    CursorTrail:UpdateGCD()
                end
            else
                ringFrame:Hide()
            end
        else
            if ringFrame then ringFrame:Hide() end
        end
        
        -- Update trail
        if CursorTrail.db.profile.trailEnabled then
            local shouldShowTrail = not (CursorTrail.db.profile.hideInCombat and isInCombat)
            
            if shouldShowTrail and cursorMoved then
                frameCount = frameCount + 1
                
                if frameCount >= CursorTrail.db.profile.trailSpacing then
                    frameCount = 0
                    CursorTrail:AddTrailParticle(x, y, alertR, alertG, alertB)
                end
            end
            
            -- Update existing trail particles
            for _, frame in ipairs(trailFrames) do
                if frame:IsShown() then
                    frame.age = frame.age + elapsed
                    
                    if frame.age >= frame.maxAge then
                        frame:Hide()
                    else
                        local progress = frame.age / frame.maxAge
                        local alpha = (1 - progress)
                        
                        -- Apply style-specific coloring
                        local r, g, b
                        if CursorTrail.db.profile.trailStyle == "rainbow" then
                            rainbowPhase = rainbowPhase + elapsed * 0.5
                            local hue = (rainbowPhase + frame.index * 0.05) % 1
                            r, g, b = CursorTrail:HSVtoRGB(hue, 1, 1)
                        elseif CursorTrail.db.profile.trailStyle == "comet" then
                            local color = CursorTrail.db.profile.trailColor
                            r, g, b = color.r * (1 + progress), color.g * (1 + progress), color.b
                        else -- classic
                            local color = CursorTrail.db.profile.trailColor
                            r, g, b = alertR or color.r, alertG or color.g, alertB or color.b
                        end
                        
                        frame.texture:SetVertexColor(r, g, b, alpha * CursorTrail.db.profile.trailColor.a)
                    end
                end
            end
        else
            for _, frame in ipairs(trailFrames) do
                frame:Hide()
            end
        end
        
        -- Update sparkles (idle effect)
        if CursorTrail.db.profile.sparklesEnabled then
            local shouldShowSparkles = not (CursorTrail.db.profile.hideInCombat and isInCombat)
            
            if shouldShowSparkles and idleTime >= CursorTrail.db.profile.sparklesIdleDelay then
                sparkleTimer = sparkleTimer + elapsed
                
                if sparkleTimer >= CursorTrail.db.profile.sparklesSpawnRate then
                    sparkleTimer = 0
                    CursorTrail:SpawnSparkle(x, y)
                end
            end
            
            -- Update existing sparkles
            for i, frame in ipairs(sparkleFrames) do
                if frame:IsShown() then
                    frame.age = frame.age + elapsed
                    
                    if frame.age >= frame.maxAge then
                        frame:Hide()
                        table.insert(sparkleFreeList, i)
                    else
                        local progress = frame.age / frame.maxAge
                        local alpha = (1 - progress)
                        
                        -- Move sparkle
                        local currentX = select(4, frame:GetPoint())
                        local currentY = select(5, frame:GetPoint())
                        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 
                            currentX + frame.velocityX * elapsed, 
                            currentY + frame.velocityY * elapsed)
                        
                        local color = CursorTrail.db.profile.sparklesColor
                        frame.texture:SetVertexColor(color.r, color.g, color.b, alpha * color.a)
                    end
                end
            end
        else
            for _, frame in ipairs(sparkleFrames) do
                frame:Hide()
            end
        end
    end)
end

function CursorTrail:AddTrailParticle(x, y, alertR, alertG, alertB)
    if not self.db then return end
    
    -- Get next trail frame
    currentTrailIndex = currentTrailIndex + 1
    if currentTrailIndex > self.db.profile.trailLength then
        currentTrailIndex = 1
    end
    
    local frame = trailFrames[currentTrailIndex]
    if frame then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        frame:SetSize(self.db.profile.trailSize, self.db.profile.trailSize)
        frame.age = 0
        frame.maxAge = self.db.profile.trailFadeSpeed
        
        -- Set initial color (will be updated by style in OnUpdate)
        local color = self.db.profile.trailColor
        local r, g, b = alertR or color.r, alertG or color.g, alertB or color.b
        frame.texture:SetVertexColor(r, g, b, color.a)
        frame:Show()
    end
end

function CursorTrail:SpawnSparkle(cursorX, cursorY)
    if #sparkleFreeList == 0 then return end
    if not self.db then return end
    
    local idx = table.remove(sparkleFreeList)
    local frame = sparkleFrames[idx]
    if not frame then return end
    
    -- Random offset from cursor
    local angle = math.random() * 2 * math.pi
    local distance = math.random() * 25 + 10
    local offsetX = math.cos(angle) * distance
    local offsetY = math.sin(angle) * distance
    
    -- Random velocity for drift
    frame.velocityX = (math.random() - 0.5) * 30
    frame.velocityY = (math.random() - 0.5) * 30 + 15 -- Slight upward bias
    
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX + offsetX, cursorY + offsetY)
    frame:SetSize(self.db.profile.sparklesSize, self.db.profile.sparklesSize)
    frame.age = 0
    frame.maxAge = self.db.profile.sparklesLifetime
    
    local color = self.db.profile.sparklesColor
    frame.texture:SetVertexColor(color.r, color.g, color.b, color.a)
    frame:Show()
end

function CursorTrail:UpdateGCD()
    if not ringFrame or not ringFrame.cooldown then return end
    
    -- Use C_Spell.GetSpellCooldown for modern WoW API
    local cooldownInfo = C_Spell.GetSpellCooldown(61304) -- Global Cooldown spell ID
    if cooldownInfo and cooldownInfo.startTime and cooldownInfo.duration and 
       cooldownInfo.duration > 0 and cooldownInfo.duration <= 1.5 then
        ringFrame.cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration)
        ringFrame.cooldown:Show()
    else
        ringFrame.cooldown:Hide()
    end
end

function CursorTrail:UpdateAlerts()
    if not self.db then return end
    
    -- Check low health
    if self.db.profile.lowHealthWarning then
        local healthPercent = (UnitHealth("player") / UnitHealthMax("player")) * 100
        hasLowHealth = healthPercent <= self.db.profile.lowHealthThreshold
    else
        hasLowHealth = false
    end
end

function CursorTrail:GetAlertColor()
    if not self.db or not self.db.profile.alertsEnabled then return nil end
    
    -- Priority: Low health > Aggro
    if hasLowHealth and self.db.profile.lowHealthWarning then
        return 1, 0, 0 -- Red
    elseif self.db.profile.aggroWarning then
        local status = UnitThreatSituation("player")
        if status and status >= 2 then
            return 1, 0.5, 0 -- Orange for aggro
        end
    end
    
    return nil
end

function CursorTrail:UpdateVisibility()
    if not self.db then 
        return 
    end
    
    if self.db.profile.enabled then
        if updateFrame then 
            updateFrame:Show()
        end
    else
        if updateFrame then updateFrame:Hide() end
        if highlightFrame then highlightFrame:Hide() end
        if ringFrame then ringFrame:Hide() end
        for _, frame in ipairs(trailFrames) do frame:Hide() end
        for _, frame in ipairs(sparkleFrames) do frame:Hide() end
    end
end

function CursorTrail:PLAYER_REGEN_DISABLED()
    if not self.db then return end
    isInCombat = true
    self:UpdateVisibility()
end

function CursorTrail:PLAYER_REGEN_ENABLED()
    if not self.db then return end
    isInCombat = false
    self:UpdateVisibility()
end

function CursorTrail:UNIT_HEALTH(event, unit)
    if unit == "player" and self.db and self.db.profile.alertsEnabled then
        self:UpdateAlerts()
    end
end

function CursorTrail:UpdateTrailTexture()
    if not self.db then return end
    
    local texture = TEXTURES[self.db.profile.trailTexture] or TEXTURES["Glow"]
    for _, frame in ipairs(trailFrames) do
        frame.texture:SetTexture(texture)
        frame.texture:SetBlendMode(self.db.profile.trailBlendMode)
    end
end

function CursorTrail:UpdateHighlightTexture()
    if not self.db then return end
    
    if highlightFrame then
        local texture = TEXTURES[self.db.profile.highlightTexture] or TEXTURES["Glow"]
        highlightFrame.texture:SetTexture(texture)
        highlightFrame.texture:SetBlendMode(self.db.profile.highlightBlendMode)
        highlightFrame:SetSize(self.db.profile.highlightSize, self.db.profile.highlightSize)
    end
end

function CursorTrail:UpdateSparklesTexture()
    if not self.db then return end
    
    local texture = TEXTURES[self.db.profile.sparklesTexture] or TEXTURES["Star"]
    for _, frame in ipairs(sparkleFrames) do
        frame.texture:SetTexture(texture)
    end
end

function CursorTrail:UpdateRingTexture()
    if not self.db then return end
    
    if ringFrame then
        local texture = TEXTURES[self.db.profile.ringTexture] or TEXTURES["Circle"]
        ringFrame.texture:SetTexture(texture)
        ringFrame:SetSize(self.db.profile.ringSize, self.db.profile.ringSize)
    end
end

function CursorTrail:UpdateSettings()
    if not self.db then return end
    
    self:UpdateTrailTexture()
    self:UpdateHighlightTexture()
    self:UpdateSparklesTexture()
    self:UpdateRingTexture()
    self:UpdateVisibility()
end

-- Apply a color theme
function CursorTrail:ApplyColorTheme(themeName)
    if not self.db then return end
    
    local theme = COLOR_THEMES[themeName]
    if not theme then return end
    
    -- Handle Class Color theme specially
    if themeName == "Class Color" then
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            self.db.profile.trailColor = { r = classColor.r, g = classColor.g, b = classColor.b, a = 1.0 }
            self.db.profile.ringColor = { r = classColor.r, g = classColor.g, b = classColor.b, a = 0.8 }
            self.db.profile.sparklesColor = { r = classColor.r * 1.2, g = classColor.g * 1.2, b = classColor.b * 1.2, a = 0.7 }
            self.db.profile.highlightColor = { r = classColor.r * 1.1, g = classColor.g * 1.1, b = classColor.b * 1.1, a = 0.7 }
        end
    else
        -- Apply preset colors
        if theme.trail then
            self.db.profile.trailColor = CopyTable(theme.trail)
        end
        if theme.ring then
            self.db.profile.ringColor = CopyTable(theme.ring)
        end
        if theme.sparkles then
            self.db.profile.sparklesColor = CopyTable(theme.sparkles)
        end
        if theme.highlight then
            self.db.profile.highlightColor = CopyTable(theme.highlight)
        end
    end
    
    -- Refresh display
    self:UpdateSettings()
    print("|cff00FF7FCursor Animate:|r Applied '" .. themeName .. "' theme")
end

-- Options table
function CursorTrail:GetOptions()
    return {
        name = "Cursor Animate",
        type = "group",
        childGroups = "tab",
        args = {
            settings = {
                name = "Settings",
                type = "group",
                order = 1,
                args = {
                    enabled = {
                        name = "Enable Cursor Animate",
                        desc = "Enable or disable the cursor animation effect",
                        type = "toggle",
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
                    header1 = {
                        name = "Trail Settings",
                        type = "header",
                        order = 30,
                    },
            trailEnabled = {
                name = "Enable Trail",
                desc = "Show a trail following the cursor",
                type = "toggle",
                order = 31,
                get = function() return self.db.profile.trailEnabled end,
                set = function(_, value)
                    self.db.profile.trailEnabled = value
                end,
            },
            trailLength = {
                name = "Trail Length",
                desc = "Number of trail particles",
                type = "range",
                order = 32,
                min = 5,
                max = 30,
                step = 1,
                get = function() return self.db.profile.trailLength end,
                set = function(_, value)
                    self.db.profile.trailLength = value
                end,
            },
            trailSize = {
                name = "Trail Size",
                desc = "Size of each trail particle",
                type = "range",
                order = 33,
                min = 16,
                max = 64,
                step = 1,
                get = function() return self.db.profile.trailSize end,
                set = function(_, value)
                    self.db.profile.trailSize = value
                end,
            },
            trailFadeSpeed = {
                name = "Fade Speed",
                desc = "How quickly trail particles fade (seconds)",
                type = "range",
                order = 34,
                min = 0.05,
                max = 0.5,
                step = 0.01,
                get = function() return self.db.profile.trailFadeSpeed end,
                set = function(_, value)
                    self.db.profile.trailFadeSpeed = value
                end,
            },
            trailSpacing = {
                name = "Trail Spacing",
                desc = "Frames between trail updates (lower = smoother but more particles)",
                type = "range",
                order = 35,
                min = 1,
                max = 10,
                step = 1,
                get = function() return self.db.profile.trailSpacing end,
                set = function(_, value)
                    self.db.profile.trailSpacing = value
                end,
            },
            trailColor = {
                name = "Trail Color",
                desc = "Color of the trail effect",
                type = "color",
                order = 36,
                hasAlpha = true,
                get = function()
                    local c = self.db.profile.trailColor
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.trailColor = { r = r, g = g, b = b, a = a }
                end,
            },
            trailTexture = {
                name = "Trail Texture",
                desc = "Visual style of the trail",
                type = "select",
                order = 37,
                values = {
                    ["Glow"] = "Glow",
                    ["GlowSoft"] = "Glow Soft",
                    ["Star"] = "Star",
                    ["Circle"] = "Circle",
                    ["CircleThick"] = "Circle Thick",
                    ["Spark"] = "Spark",
                    ["Square"] = "Square",
                    ["Diamond"] = "Diamond",
                    ["Triangle"] = "Triangle",
                    ["Moon"] = "Moon",
                    ["Orb"] = "Orb",
                },
                get = function() return self.db.profile.trailTexture end,
                set = function(_, value)
                    self.db.profile.trailTexture = value
                    self:UpdateTrailTexture()
                end,
            },
            trailBlendMode = {
                name = "Trail Blend Mode",
                desc = "How the trail blends with the background",
                type = "select",
                order = 38,
                values = {
                    ["ADD"] = "Additive (Bright)",
                    ["BLEND"] = "Normal (Blend)",
                    ["ALPHAKEY"] = "Alpha Key",
                },
                get = function() return self.db.profile.trailBlendMode end,
                set = function(_, value)
                    self.db.profile.trailBlendMode = value
                    self:UpdateTrailTexture()
                end,
            },
            trailStyle = {
                name = "Trail Style",
                desc = "Visual style/animation of the trail",
                type = "select",
                order = 39,
                values = {
                    ["classic"] = "Classic (Solid Color)",
                    ["rainbow"] = "Rainbow (Cycling Colors)",
                    ["comet"] = "Comet (Bright Head)",
                },
                get = function() return self.db.profile.trailStyle end,
                set = function(_, value)
                    self.db.profile.trailStyle = value
                end,
            },
            header2 = {
                name = "Highlight Settings",
                type = "header",
                order = 40,
            },
            highlightEnabled = {
                name = "Enable Highlight",
                desc = "Show a glow/highlight around the cursor",
                type = "toggle",
                order = 41,
                get = function() return self.db.profile.highlightEnabled end,
                set = function(_, value)
                    self.db.profile.highlightEnabled = value
                end,
            },
            highlightSize = {
                name = "Highlight Size",
                desc = "Size of the cursor highlight",
                type = "range",
                order = 42,
                min = 24,
                max = 96,
                step = 1,
                get = function() return self.db.profile.highlightSize end,
                set = function(_, value)
                    self.db.profile.highlightSize = value
                    self:UpdateHighlightTexture()
                end,
            },
            highlightPulse = {
                name = "Pulse Effect",
                desc = "Make the highlight pulse",
                type = "toggle",
                order = 43,
                get = function() return self.db.profile.highlightPulse end,
                set = function(_, value)
                    self.db.profile.highlightPulse = value
                end,
            },
            highlightColor = {
                name = "Highlight Color",
                desc = "Color of the highlight effect",
                type = "color",
                order = 44,
                hasAlpha = true,
                get = function()
                    local c = self.db.profile.highlightColor
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.highlightColor = { r = r, g = g, b = b, a = a }
                end,
            },
            highlightTexture = {
                name = "Highlight Texture",
                desc = "Visual style of the highlight",
                type = "select",
                order = 45,
                values = {
                    ["Glow"] = "Glow",
                    ["GlowSoft"] = "Glow Soft",
                    ["Star"] = "Star",
                    ["Circle"] = "Circle",
                    ["CircleThick"] = "Circle Thick",
                    ["Orb"] = "Orb",
                    ["Moon"] = "Moon",
                },
                get = function() return self.db.profile.highlightTexture end,
                set = function(_, value)
                    self.db.profile.highlightTexture = value
                    self:UpdateHighlightTexture()
                end,
            },
            highlightBlendMode = {
                name = "Highlight Blend Mode",
                desc = "How the highlight blends with the background",
                type = "select",
                order = 46,
                values = {
                    ["ADD"] = "Additive (Bright)",
                    ["BLEND"] = "Normal (Blend)",
                    ["ALPHAKEY"] = "Alpha Key",
                },
                get = function() return self.db.profile.highlightBlendMode end,
                set = function(_, value)
                    self.db.profile.highlightBlendMode = value
                    self:UpdateHighlightTexture()
                end,
            },
            header3 = {
                name = "Sparkles Settings",
                type = "header",
                order = 50,
            },
            sparklesEnabled = {
                name = "Enable Sparkles",
                desc = "Show sparkle effects when cursor is idle",
                type = "toggle",
                order = 51,
                get = function() return self.db.profile.sparklesEnabled end,
                set = function(_, value)
                    self.db.profile.sparklesEnabled = value
                end,
            },
            sparklesIdleDelay = {
                name = "Idle Delay",
                desc = "Seconds before sparkles appear when cursor stops moving",
                type = "range",
                order = 52,
                min = 0.5,
                max = 3.0,
                step = 0.1,
                get = function() return self.db.profile.sparklesIdleDelay end,
                set = function(_, value)
                    self.db.profile.sparklesIdleDelay = value
                end,
            },
            sparklesSpawnRate = {
                name = "Spawn Rate",
                desc = "Seconds between sparkle spawns",
                type = "range",
                order = 53,
                min = 0.05,
                max = 0.5,
                step = 0.05,
                get = function() return self.db.profile.sparklesSpawnRate end,
                set = function(_, value)
                    self.db.profile.sparklesSpawnRate = value
                end,
            },
            sparklesSize = {
                name = "Sparkle Size",
                desc = "Size of sparkle particles",
                type = "range",
                order = 54,
                min = 8,
                max = 24,
                step = 1,
                get = function() return self.db.profile.sparklesSize end,
                set = function(_, value)
                    self.db.profile.sparklesSize = value
                end,
            },
            sparklesLifetime = {
                name = "Lifetime",
                desc = "How long sparkles last (seconds)",
                type = "range",
                order = 55,
                min = 0.3,
                max = 2.0,
                step = 0.1,
                get = function() return self.db.profile.sparklesLifetime end,
                set = function(_, value)
                    self.db.profile.sparklesLifetime = value
                end,
            },
            sparklesColor = {
                name = "Sparkle Color",
                desc = "Color of sparkle particles",
                type = "color",
                order = 56,
                hasAlpha = true,
                get = function()
                    local c = self.db.profile.sparklesColor
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.sparklesColor = { r = r, g = g, b = b, a = a }
                end,
            },
            sparklesTexture = {
                name = "Sparkle Texture",
                desc = "Visual style of sparkles",
                type = "select",
                order = 57,
                values = {
                    ["Glow"] = "Glow",
                    ["GlowSoft"] = "Glow Soft",
                    ["Star"] = "Star",
                    ["Diamond"] = "Diamond",
                    ["Orb"] = "Orb",
                },
                get = function() return self.db.profile.sparklesTexture end,
                set = function(_, value)
                    self.db.profile.sparklesTexture = value
                    self:UpdateSparklesTexture()
                end,
            },
             header4 = {
                name = "Ring Settings",
                type = "header",
                order = 60,
            },
            ringEnabled = {
                name = "Enable Ring",
                desc = "Show a ring around the cursor",
                type = "toggle",
                order = 61,
                get = function() return self.db.profile.ringEnabled end,
                set = function(_, value)
                    self.db.profile.ringEnabled = value
                end,
            },
            ringSize = {
                name = "Ring Size",
                desc = "Size of the cursor ring",
                type = "range",
                order = 62,
                min = 32,
                max = 128,
                step = 1,
                get = function() return self.db.profile.ringSize end,
                set = function(_, value)
                    self.db.profile.ringSize = value
                    self:UpdateRingTexture()
                end,
            },
            ringPulse = {
                name = "Pulse Effect",
                desc = "Make the ring pulse",
                type = "toggle",
                order = 63,
                get = function() return self.db.profile.ringPulse end,
                set = function(_, value)
                    self.db.profile.ringPulse = value
                end,
            },
            ringShowGCD = {
                name = "Show GCD",
                desc = "Display global cooldown on the ring",
                type = "toggle",
                order = 64,
                get = function() return self.db.profile.ringShowGCD end,
                set = function(_, value)
                    self.db.profile.ringShowGCD = value
                end,
            },
            ringColor = {
                name = "Ring Color",
                desc = "Color of the ring effect",
                type = "color",
                order = 65,
                hasAlpha = true,
                get = function()
                    local c = self.db.profile.ringColor
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.ringColor = { r = r, g = g, b = b, a = a }
                end,
            },
            ringTexture = {
                name = "Ring Texture",
                desc = "Visual style of the ring",
                type = "select",
                order = 66,
                values = {
                    ["Circle"] = "Circle",
                    ["CircleThick"] = "Circle Thick",
                    ["Square"] = "Square",
                    ["Diamond"] = "Diamond",
                    ["Star"] = "Star",
                },
                get = function() return self.db.profile.ringTexture end,
                set = function (_, value)
                    self.db.profile.ringTexture = value
                    self:UpdateRingTexture()
                end,
            },
            header5 = {
                name = "Health & Combat Alerts",
                type = "header",
                order = 70,
            },
            alertsEnabled = {
                name = "Enable Alerts",
                desc = "Change cursor color based on health and combat status",
                type = "toggle",
                order = 71,
                get = function() return self.db.profile.alertsEnabled end,
                set = function(_, value)
                    self.db.profile.alertsEnabled = value
                end,
            },
            lowHealthWarning = {
                name = "Low Health Warning",
                desc = "Turn cursor red when health is low",
                type = "toggle",
                order = 72,
                get = function() return self.db.profile.lowHealthWarning end,
                set = function(_, value)
                    self.db.profile.lowHealthWarning = value
                end,
            },
            lowHealthThreshold = {
                name = "Health Threshold",
                desc = "Health percentage to trigger warning",
                type = "range",
                order = 73,
                min = 10,
                max = 50,
                step = 5,
                get = function() return self.db.profile.lowHealthThreshold end,
                set = function(_, value)
                    self.db.profile.lowHealthThreshold = value
                end,
            },
            aggroWarning = {
                name = "Aggro Warning",
                desc = "Turn cursor orange when you have threat/aggro",
                type = "toggle",
                order = 74,
                get = function() return self.db.profile.aggroWarning end,
                set = function(_, value)
                    self.db.profile.aggroWarning = value
                end,
            },
            header6 = {
                name = "Combat Settings",
                type = "header",
                order = 80,
            },
            hideInCombat = {
                name = "Hide in Combat",
                desc = "Hide cursor effects during combat",
                type = "toggle",
                order = 81,
                get = function() return self.db.profile.hideInCombat end,
                set = function(_, value)
                    self.db.profile.hideInCombat = value
                    self:UpdateVisibility()
                end,
            },
            combatOnlyHighlight = {
                name = "Combat Only Highlight",
                desc = "Only show highlight during combat (ignores 'Hide in Combat')",
                type = "toggle",
                order = 82,
                get = function() return self.db.profile.combatOnlyHighlight end,
                set = function(_, value)
                    self.db.profile.combatOnlyHighlight = value
                end,
            },
                }  -- Close settings args
            },  -- Close settings group
            themes = {
                name = "Themes",
                type = "group",
                order = 2,
                args = {
                    themeDesc = {
                        name = "Click a theme to apply its colors to Ring, Trail, Sparkles, and Highlight.",
                        type = "description",
                        order = 1,
                    },
                    themeReset = {
                        name = "Reset",
                        type = "execute",
                        order = 2,
                        width = "normal",
                        color = function() return COLOR_THEMES["Default"].trail.r, COLOR_THEMES["Default"].trail.g, COLOR_THEMES["Default"].trail.b end,
                        func = function() self:ApplyColorTheme("Default") end,
                    },
                    themeClassColor = {
                        name = "Class Color",
                        type = "execute",
                        order = 3,
                        width = "normal",
                        color = function()
                            local _, class = UnitClass("player")
                            local classColor = RAID_CLASS_COLORS[class]
                            if classColor then
                                return classColor.r, classColor.g, classColor.b
                            end
                            return 1, 1, 1
                        end,
                        func = function() self:ApplyColorTheme("Class Color") end,
                    },
                    themeDefault = {
                        name = "Default",
                        type = "execute",
                        order = 4,
                        width = "normal",
                        color = function() return COLOR_THEMES["Default"].trail.r, COLOR_THEMES["Default"].trail.g, COLOR_THEMES["Default"].trail.b end,
                        func = function() self:ApplyColorTheme("Default") end,
                    },
                    themeDark = {
                        name = "Dark",
                        type = "execute",
                        order = 5,
                        width = "normal",
                        color = function() return COLOR_THEMES["Dark"].trail.r, COLOR_THEMES["Dark"].trail.g, COLOR_THEMES["Dark"].trail.b end,
                        func = function() self:ApplyColorTheme("Dark") end,
                    },
                    themeLight = {
                        name = "Light",
                        type = "execute",
                        order = 6,
                        width = "normal",
                        color = function() return COLOR_THEMES["Light"].trail.r, COLOR_THEMES["Light"].trail.g, COLOR_THEMES["Light"].trail.b end,
                        func = function() self:ApplyColorTheme("Light") end,
                    },
                    themeNeon = {
                        name = "Neon",
                        type = "execute",
                        order = 7,
                        width = "normal",
                        color = function() return COLOR_THEMES["Neon"].trail.r, COLOR_THEMES["Neon"].trail.g, COLOR_THEMES["Neon"].trail.b end,
                        func = function() self:ApplyColorTheme("Neon") end,
                    },
                    themeFire = {
                        name = "Fire",
                        type = "execute",
                        order = 8,
                        width = "normal",
                        color = function() return COLOR_THEMES["Fire"].trail.r, COLOR_THEMES["Fire"].trail.g, COLOR_THEMES["Fire"].trail.b end,
                        func = function() self:ApplyColorTheme("Fire") end,
                    },
                    themeFrost = {
                        name = "Frost",
                        type = "execute",
                        order = 9,
                        width = "normal",
                        color = function() return COLOR_THEMES["Frost"].trail.r, COLOR_THEMES["Frost"].trail.g, COLOR_THEMES["Frost"].trail.b end,
                        func = function() self:ApplyColorTheme("Frost") end,
                    },
                    themeNature = {
                        name = "Nature",
                        type = "execute",
                        order = 10,
                        width = "normal",
                        color = function() return COLOR_THEMES["Nature"].trail.r, COLOR_THEMES["Nature"].trail.g, COLOR_THEMES["Nature"].trail.b end,
                        func = function() self:ApplyColorTheme("Nature") end,
                    },
                    themeShadow = {
                        name = "Shadow",
                        type = "execute",
                        order = 11,
                        width = "normal",
                        color = function() return COLOR_THEMES["Shadow"].trail.r, COLOR_THEMES["Shadow"].trail.g, COLOR_THEMES["Shadow"].trail.b end,
                        func = function() self:ApplyColorTheme("Shadow") end,
                    },
                    themeGolden = {
                        name = "Golden",
                        type = "execute",
                        order = 12,
                        width = "normal",
                        color = function() return COLOR_THEMES["Golden"].trail.r, COLOR_THEMES["Golden"].trail.g, COLOR_THEMES["Golden"].trail.b end,
                        func = function() self:ApplyColorTheme("Golden") end,
                    },
                    themeBlood = {
                        name = "Blood",
                        type = "execute",
                        order = 13,
                        width = "normal",
                        color = function() return COLOR_THEMES["Blood"].trail.r, COLOR_THEMES["Blood"].trail.g, COLOR_THEMES["Blood"].trail.b end,
                        func = function() self:ApplyColorTheme("Blood") end,
                    },
                    themeArcane = {
                        name = "Arcane",
                        type = "execute",
                        order = 14,
                        width = "normal",
                        color = function() return COLOR_THEMES["Arcane"].trail.r, COLOR_THEMES["Arcane"].trail.g, COLOR_THEMES["Arcane"].trail.b end,
                        func = function() self:ApplyColorTheme("Arcane") end,
                    },
                    themeMinimal = {
                        name = "Minimal",
                        type = "execute",
                        order = 15,
                        width = "normal",
                        color = function() return COLOR_THEMES["Minimal"].trail.r, COLOR_THEMES["Minimal"].trail.g, COLOR_THEMES["Minimal"].trail.b end,
                        func = function() self:ApplyColorTheme("Minimal") end,
                    },
                    themeComet = {
                        name = "Comet",
                        type = "execute",
                        order = 16,
                        width = "normal",
                        color = function() return COLOR_THEMES["Comet"].trail.r, COLOR_THEMES["Comet"].trail.g, COLOR_THEMES["Comet"].trail.b end,
                        func = function() self:ApplyColorTheme("Comet") end,
                    },
                    themeTrailOnly = {
                        name = "Trail Only",
                        type = "execute",
                        order = 17,
                        width = "normal",
                        func = function()
                            self.db.profile.trailEnabled = true
                            self.db.profile.highlightEnabled = false
                            self.db.profile.ringEnabled = false
                            self.db.profile.sparklesEnabled = false
                            self:UpdateVisibility()
                            print("|cff00FF7FCursor Animate:|r Enabled Trail Only mode")
                        end,
                    },
                    themeSparkles = {
                        name = "Sparkles",
                        type = "execute",
                        order = 18,
                        width = "normal",
                        func = function()
                            self.db.profile.trailEnabled = true
                            self.db.profile.highlightEnabled = true
                            self.db.profile.ringEnabled = false
                            self.db.profile.sparklesEnabled = true
                            self:UpdateVisibility()
                            print("|cff00FF7FCursor Animate:|r Enabled Sparkles mode")
                        end,
                    },
                    themeFullFX = {
                        name = "Full FX",
                        type = "execute",
                        order = 19,
                        width = "normal",
                        func = function()
                            self.db.profile.trailEnabled = true
                            self.db.profile.highlightEnabled = true
                            self.db.profile.ringEnabled = true
                            self.db.profile.sparklesEnabled = true
                            self:UpdateVisibility()
                            print("|cff00FF7FCursor Animate:|r Enabled Full FX mode")
                        end,
                    },
                }  -- Close themes args
            },  -- Close themes group
        }  -- Close main args
    }  -- Close return table
end
