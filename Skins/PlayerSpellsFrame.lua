-- Skins/PlayerSpellsFrame.lua
-- Custom skin for the Player Spells frame (modern talent UI)

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local PlayerSpellsSkin = AbstractUI:NewModule("PlayerSpellsSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_PLAYERSPELLS_WIP"] = {
    text = "The skinning for 'Player Spells' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function PlayerSpellsSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function PlayerSpellsSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("PlayerSpellsFrame") then
        StaticPopup_Show("ABSTRACTUI_PLAYERSPELLS_WIP")
    end
end
