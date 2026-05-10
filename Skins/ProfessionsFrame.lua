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

local hasShownPopup = false

function ProfessionsSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function ProfessionsSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["ProfessionsFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("ProfessionsFrame") then
                StaticPopup_Show("ABSTRACTUI_PROFESSIONS_WIP")
                hasShownPopup = true
            end
        end)
    end
end
