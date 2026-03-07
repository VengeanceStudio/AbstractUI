-- ============================================================================
-- Cursor Animate Module
-- ============================================================================
-- Enhanced cursor visibility with customizable animation effects and highlighting.
-- 
-- Features:
-- - Smooth particle trail following cursor movement
-- - Glowing highlight effect around cursor with optional pulse animation
-- - Customizable colors, sizes, textures, and blend modes
-- - Combat awareness (hide/show based on combat state)
-- - Performance optimized particle system
-- ============================================================================

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local CursorTrail = AbstractUI:NewModule("CursorTrail", "AceEvent-3.0")
local ColorPalette = _G.AbstractUI_ColorPalette

-- Trail frame pool
local trailFrames = {}
local maxTrailFrames = 30
local currentTrailIndex = 1
local updateFrame
local highlightFrame

local defaults = {
    profile = {
        enabled = true,
        trailEnabled = true,
        highlightEnabled = true,
        
        -- Trail settings
        trailLength = 15, -- Number of trail particles
        trailSize = 32,
        trailFadeSpeed = 0.15,
        trailSpacing = 3, -- Frames between trail updates
        trailColor = { r = 0.0, g = 0.8, b = 1.0, a = 0.8 },
        trailTexture = "Glow", -- Glow, Star, Circle, Spark
        trailBlendMode = "ADD",
        
        -- Highlight settings
        highlightSize = 48,
        highlightAlpha = 0.5,
        highlightPulse = true,
        highlightColor = { r = 1.0, g = 1.0, b = 1.0, a = 0.5 },
        highlightTexture = "Glow",
        highlightBlendMode = "ADD",
        
        -- Combat settings
        hideInCombat = false,
        combatOnlyHighlight = false,
    }
}

-- Texture options
local TEXTURES = {
    ["Glow"] = "Interface\\Buttons\\WHITE8X8",
    ["Star"] = "Interface\\Buttons\\WHITE8X8",
    ["Circle"] = "Interface\\Buttons\\WHITE8X8",
    ["Spark"] = "Interface\\CastingBar\\UI-CastingBar-Spark",
}

function CursorTrail:OnInitialize()
    self:RegisterMessage("AbstractUI_DB_READY", "OnDBReady")
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
    
    self:CreateTrailFrames()
    self:CreateHighlightFrame()
    self:CreateUpdateFrame()
    
    self:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entering combat
    self:RegisterEvent("PLAYER_REGEN_ENABLED") -- Leaving combat
    
    if self.db.profile.enabled then
        self:Enable()
    end
end

function CursorTrail:OnEnable()
    -- Don't do anything if DB isn't ready yet
    if not self.db then return end
    
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
    for _, frame in ipairs(trailFrames) do
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
    texture:SetTexture(TEXTURES["Glow"])
    texture:SetBlendMode("ADD")
    
    highlightFrame.texture = texture
    highlightFrame.pulseDirection = 1
    highlightFrame.pulseAlpha = 0
end

function CursorTrail:CreateUpdateFrame()
    updateFrame = CreateFrame("Frame", "AbstractUI_CursorUpdate", UIParent)
    updateFrame:Hide()
    
    local frameCount = 0
    local pulseTime = 0
    
    updateFrame:SetScript("OnUpdate", function(self, elapsed)
        if not CursorTrail.db then return end
        if not CursorTrail.db.profile.enabled then return end
        
        local inCombat = InCombatLockdown()
        
        -- Update highlight
        if CursorTrail.db.profile.highlightEnabled and highlightFrame then
            local shouldShowHighlight = true
            
            if CursorTrail.db.profile.hideInCombat and inCombat then
                shouldShowHighlight = false
            elseif CursorTrail.db.profile.combatOnlyHighlight and not inCombat then
                shouldShowHighlight = false
            end
            
            if shouldShowHighlight then
                local x, y = GetCursorPosition()
                local scale = UIParent:GetEffectiveScale()
                x = x / scale
                y = y / scale
                
                highlightFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
                
                -- Pulse effect
                if CursorTrail.db.profile.highlightPulse then
                    pulseTime = pulseTime + elapsed * 2
                    local pulseAlpha = (math.sin(pulseTime) + 1) / 2 -- Oscillates between 0 and 1
                    local baseAlpha = CursorTrail.db.profile.highlightColor.a
                    local color = CursorTrail.db.profile.highlightColor
                    highlightFrame.texture:SetVertexColor(color.r, color.g, color.b, baseAlpha * (0.5 + pulseAlpha * 0.5))
                else
                    local color = CursorTrail.db.profile.highlightColor
                    highlightFrame.texture:SetVertexColor(color.r, color.g, color.b, color.a)
                end
                
                highlightFrame:Show()
            else
                highlightFrame:Hide()
            end
        else
            highlightFrame:Hide()
        end
        
        -- Update trail
        if CursorTrail.db.profile.trailEnabled then
            local shouldShowTrail = not (CursorTrail.db.profile.hideInCombat and inCombat)
            
            if shouldShowTrail then
                frameCount = frameCount + 1
                
                if frameCount >= CursorTrail.db.profile.trailSpacing then
                    frameCount = 0
                    CursorTrail:AddTrailParticle()
                end
                
                -- Update existing trail particles
                for _, frame in ipairs(trailFrames) do
                    if frame:IsShown() then
                        frame.age = frame.age + elapsed
                        
                        if frame.age >= frame.maxAge then
                            frame:Hide()
                        else
                            -- Fade out based on age
                            local progress = frame.age / frame.maxAge
                            local alpha = (1 - progress) * CursorTrail.db.profile.trailColor.a
                            local color = CursorTrail.db.profile.trailColor
                            frame.texture:SetVertexColor(color.r, color.g, color.b, alpha)
                        end
                    end
                end
            else
                -- Hide all trail particles in combat if hideInCombat is enabled
                for _, frame in ipairs(trailFrames) do
                    frame:Hide()
                end
            end
        end
    end)
end

function CursorTrail:AddTrailParticle()
    if not self.db then return end
    
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x = x / scale
    y = y / scale
    
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
        
        local color = self.db.profile.trailColor
        frame.texture:SetVertexColor(color.r, color.g, color.b, color.a)
        frame:Show()
    end
end

function CursorTrail:UpdateVisibility()
    if not self.db then return end
    
    local inCombat = InCombatLockdown()
    
    if self.db.profile.hideInCombat and inCombat then
        if updateFrame then updateFrame:Hide() end
    else
        if updateFrame and self.db.profile.enabled then
            updateFrame:Show()
        end
    end
end

function CursorTrail:PLAYER_REGEN_DISABLED()
    if not self.db then return end
    self:UpdateVisibility()
end

function CursorTrail:PLAYER_REGEN_ENABLED()
    if not self.db then return end
    self:UpdateVisibility()
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

function CursorTrail:UpdateSettings()
    if not self.db then return end
    
    self:UpdateTrailTexture()
    self:UpdateHighlightTexture()
    self:UpdateVisibility()
end

-- Options table
function CursorTrail:GetOptions()
    return {
        name = "Cursor Animate",
        type = "group",
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
                order = 10,
            },
            trailEnabled = {
                name = "Enable Trail",
                desc = "Show a trail following the cursor",
                type = "toggle",
                order = 11,
                get = function() return self.db.profile.trailEnabled end,
                set = function(_, value)
                    self.db.profile.trailEnabled = value
                end,
            },
            trailLength = {
                name = "Trail Length",
                desc = "Number of trail particles",
                type = "range",
                order = 12,
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
                order = 13,
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
                order = 14,
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
                order = 15,
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
                order = 16,
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
                order = 17,
                values = {
                    ["Glow"] = "Glow",
                    ["Star"] = "Star",
                    ["Circle"] = "Circle",
                    ["Spark"] = "Spark",
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
                order = 18,
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
            header2 = {
                name = "Highlight Settings",
                type = "header",
                order = 20,
            },
            highlightEnabled = {
                name = "Enable Highlight",
                desc = "Show a glow/highlight around the cursor",
                type = "toggle",
                order = 21,
                get = function() return self.db.profile.highlightEnabled end,
                set = function(_, value)
                    self.db.profile.highlightEnabled = value
                end,
            },
            highlightSize = {
                name = "Highlight Size",
                desc = "Size of the cursor highlight",
                type = "range",
                order = 22,
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
                order = 23,
                get = function() return self.db.profile.highlightPulse end,
                set = function(_, value)
                    self.db.profile.highlightPulse = value
                end,
            },
            highlightColor = {
                name = "Highlight Color",
                desc = "Color of the highlight effect",
                type = "color",
                order = 24,
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
                order = 25,
                values = {
                    ["Glow"] = "Glow",
                    ["Star"] = "Star",
                    ["Circle"] = "Circle",
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
                order = 26,
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
                name = "Combat Settings",
                type = "header",
                order = 30,
            },
            hideInCombat = {
                name = "Hide in Combat",
                desc = "Hide cursor effects during combat",
                type = "toggle",
                order = 31,
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
                order = 32,
                get = function() return self.db.profile.combatOnlyHighlight end,
                set = function(_, value)
                    self.db.profile.combatOnlyHighlight = value
                end,
            },
        }
    }
end
