-- Skins/EncounterJournal.lua
-- Custom skin for the Encounter Journal (dungeon/raid guide)

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
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

local hasShownPopup = false

function EncounterSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function EncounterSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["EncounterJournal"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("EncounterJournal") then
                StaticPopup_Show("ABSTRACTUI_ENCOUNTER_WIP")
                hasShownPopup = true
            end
        end)
    end
end
