-- Skins/ProfessionsFrame.lua
-- Custom skin for the Professions crafting frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local ProfessionsSkin = AbstractUI:NewModule("ProfessionsSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_PROFESSIONS_WIP"] = {
    text = "The skinning for 'Professions' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ProfessionsSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function ProfessionsSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("ProfessionsFrame") then
        StaticPopup_Show("ABSTRACTUI_PROFESSIONS_WIP")
    end
end
