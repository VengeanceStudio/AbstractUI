
if not UnitFrames then return end
-- MidnightUI UnitFrames: Pet Frame Module

-- ============================================================================
-- PET FRAME CREATION
-- ============================================================================

function UnitFrames:CreatePetFrame()
    if not self.db.profile.showPet then return end
    local db = self.db.profile
    -- Anchor PetFrame to CENTER
    local anchorTo = UIParent
    local posX = (db.pet and db.pet.posX) or 0
    local posY = (db.pet and db.pet.posY) or 0
    self:CreateUnitFrame("PetFrame", "pet", anchorTo, "CENTER", "CENTER", posX, posY)
    -- Only show PetFrame if pet exists
    local customPetFrame = _G["MidnightUI_PetFrame"]
    if customPetFrame then
        -- Start hidden - state driver will show when pet exists
        customPetFrame:Hide()
        -- Also hide child bars explicitly (they don't auto-hide with parent)
        if customPetFrame.healthBar then customPetFrame.healthBar:Hide() end
        if customPetFrame.powerBar then customPetFrame.powerBar:Hide() end
        if customPetFrame.infoBar then customPetFrame.infoBar:Hide() end
        -- Safely unregister/register state drivers (protected call)
        if not InCombatLockdown() then
            UnregisterStateDriver(customPetFrame, "visibility")
            RegisterStateDriver(customPetFrame, "visibility", "[@pet,exists] show; hide")
        end
        -- If pet exists right now, force update
        if UnitExists("pet") then
            self:UpdateUnitFrame("PetFrame", "pet")
        end
    end
end

-- ============================================================================
-- PET-SPECIFIC EVENT HANDLERS
-- ============================================================================

function UnitFrames:UNIT_PET(event, unit)
    if unit == "player" and self.db.profile.showPet then
        self:UpdateUnitFrame("PetFrame", "pet")
    end
end

-- ============================================================================
-- OPTIONS
-- ============================================================================

function UnitFrames:GetPetOptions_Real()
    return self:GenerateFrameOptions("Pet Frame", "pet", "CreatePetFrame", "MidnightUI_PetFrame")
end
