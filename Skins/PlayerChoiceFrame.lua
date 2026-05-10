-- Skins/PlayerChoiceFrame.lua
-- Custom skin for the Player Choice frame (story decisions)

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local PlayerChoiceSkin = AbstractUI:NewModule("PlayerChoiceSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_PLAYERCHOICE_WIP"] = {
    text = "The skinning for 'Player Choice Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function PlayerChoiceSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function PlayerChoiceSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("PlayerChoiceFrame") then
        StaticPopup_Show("ABSTRACTUI_PLAYERCHOICE_WIP")
    end
end
