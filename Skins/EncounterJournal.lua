-- Skins/EncounterJournal.lua
-- Custom skin for the Encounter Journal (dungeon/raid guide)

local _, AbstractUI = ...
local EncounterSkin = AbstractUI:NewModule("EncounterSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_ENCOUNTER_WIP"] = {
    text = "The skinning for 'Encounter Journal' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function EncounterSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function EncounterSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("EncounterJournal") then
        StaticPopup_Show("ABSTRACTUI_ENCOUNTER_WIP")
    end
end
