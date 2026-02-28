
if not UnitFrames then return end
-- MidnightUI UnitFrames: Target of Target Frame Module

-- ============================================================================
-- TARGET-OF-TARGET FRAME CREATION
-- ============================================================================

function UnitFrames:CreateTargetTargetFrame()
    if not self.db.profile.showTargetTarget then return end
    local db = self.db.profile
    -- Anchor TargetTargetFrame to CENTER
    local anchorTo = UIParent
    local posX = (db.targettarget and db.targettarget.posX) or 0
    local posY = (db.targettarget and db.targettarget.posY) or 0
    self:CreateUnitFrame("TargetTargetFrame", "targettarget", anchorTo, "CENTER", "CENTER", posX, posY)
    -- Only show TargetTargetFrame if target has a target
    local customToTFrame = _G["MidnightUI_TargetTargetFrame"]
    if customToTFrame then
        -- Start hidden - state driver will show when targettarget exists
        customToTFrame:Hide()
        -- Also hide child bars explicitly (they don't auto-hide with parent)
        if customToTFrame.healthBar then customToTFrame.healthBar:Hide() end
        if customToTFrame.powerBar then customToTFrame.powerBar:Hide() end
        if customToTFrame.infoBar then customToTFrame.infoBar:Hide() end
        -- Safely unregister/register state drivers (protected call)
        if not InCombatLockdown() then
            UnregisterStateDriver(customToTFrame, "visibility")
            RegisterStateDriver(customToTFrame, "visibility", "[@targettarget,exists] show; hide")
        end
        -- If targettarget exists right now, force update
        if UnitExists("targettarget") then
            self:UpdateUnitFrame("TargetTargetFrame", "targettarget")
        end
    end
end

-- ============================================================================
-- OPTIONS
-- ============================================================================

function UnitFrames:GetTargetTargetOptions_Real()
    return self:GenerateFrameOptions("Target of Target Frame", "targettarget", "CreateTargetTargetFrame", "MidnightUI_TargetTargetFrame")
end
