
if not UnitFrames then return end
-- AbstractUI UnitFrames: Player Frame Module

-- ============================================================================
-- PLAYER FRAME CREATION
-- ============================================================================

function UnitFrames:CreatePlayerFrame()
    if not self.db.profile.showPlayer then return end
    -- Anchor PlayerFrame to CENTER
    self:CreateUnitFrame("PlayerFrame", "player", UIParent, "CENTER", "CENTER", self.db.profile.player.posX or 0, self.db.profile.player.posY or 0)
    local frame = _G["AbstractUI_PlayerFrame"]
    -- Initial update to populate frame data immediately
    if frame then
        self:UpdateUnitFrame("PlayerFrame", "player")
    end
end

-- ============================================================================
-- PLAYER-SPECIFIC EVENT HANDLERS
-- ============================================================================

function UnitFrames:PLAYER_FLAGS_CHANGED()
    -- Update player frame when AFK/DND status changes
    if self.db.profile.showPlayer then
        self:UpdateUnitFrame("PlayerFrame", "player")
    end
end

function UnitFrames:PLAYER_UPDATE_RESTING()
    -- Update player frame when resting status changes
    if self.db.profile.showPlayer then
        self:UpdateUnitFrame("PlayerFrame", "player")
    end
end

function UnitFrames:PLAYER_REGEN_DISABLED()
    -- Update player frame when entering combat
    if self.db.profile.showPlayer then
        self:UpdateUnitFrame("PlayerFrame", "player")
    end
end

-- ============================================================================
-- OPTIONS
-- ============================================================================

function UnitFrames:GetPlayerOptions_Real()
    print("[GetPlayerOptions_Real] Called")
    local result = self:GenerateFrameOptions("Player Frame", "player", "CreatePlayerFrame", "AbstractUI_PlayerFrame")
    print("[GetPlayerOptions_Real] Result type:", type(result))
    if result then
        print("[GetPlayerOptions_Real] Result has args:", result.args and "YES" or "NO")
        if result.args then
            local keys = {}
            for k in pairs(result.args) do table.insert(keys, k) end
            print("[GetPlayerOptions_Real] Args keys: " .. table.concat(keys, ", "))
        end
    end
    return result
end

