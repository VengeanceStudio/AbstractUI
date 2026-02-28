
if not UnitFrames then return end
-- MidnightUI UnitFrames: Focus Frame Module

-- ============================================================================
-- FOCUS FRAME CREATION
-- ============================================================================

function UnitFrames:CreateFocusFrame()
    if not self.db or not self.db.profile or not self.db.profile.showFocus then return end
    local db = self.db.profile
    -- Anchor FocusFrame to CENTER
    local anchorTo = UIParent
    local posX = (db.focus and db.focus.posX) or 0
    local posY = (db.focus and db.focus.posY) or 0
    self:CreateUnitFrame("FocusFrame", "focus", anchorTo, "CENTER", "CENTER", posX, posY)
    -- Only show FocusFrame if a focus exists
    local customFocusFrame = _G["MidnightUI_FocusFrame"]
    if customFocusFrame then
        -- Start hidden - state driver will show when focus exists
        customFocusFrame:Hide()
        -- Also hide child bars explicitly (they don't auto-hide with parent)
        if customFocusFrame.healthBar then customFocusFrame.healthBar:Hide() end
        if customFocusFrame.powerBar then customFocusFrame.powerBar:Hide() end
        if customFocusFrame.infoBar then customFocusFrame.infoBar:Hide() end
        -- Safely unregister/register state drivers (protected call)
        if not InCombatLockdown() then
            UnregisterStateDriver(customFocusFrame, "visibility")
            RegisterStateDriver(customFocusFrame, "visibility", "[@focus,exists] show; hide")
        end
        -- If focus exists right now, force update
        if UnitExists("focus") then
            self:UpdateUnitFrame("FocusFrame", "focus")
        end
    end
end

-- ============================================================================
-- FOCUS-SPECIFIC EVENT HANDLERS
-- ============================================================================

function UnitFrames:PLAYER_FOCUS_CHANGED()
    if self.db.profile.showFocus then self:UpdateUnitFrame("FocusFrame", "focus") end
end

-- ============================================================================
-- OPTIONS
-- ============================================================================

function UnitFrames:GetFocusOptions_Real()
    return self:GenerateFrameOptions("Focus Frame", "focus", "CreateFocusFrame", "MidnightUI_FocusFrame")
end
