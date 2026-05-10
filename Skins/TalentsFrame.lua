-- Skins/TalentsFrame.lua
-- Custom skin for the Talents & Specialization UI

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local TalentsSkin = AbstractUI:NewModule("TalentsSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_TALENTS_WIP"] = {
    text = "The skinning for 'Talents' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local hasShownPopup = false

function TalentsSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function TalentsSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["PlayerSpellsFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("PlayerSpellsFrame") then
                StaticPopup_Show("ABSTRACTUI_TALENTS_WIP")
                hasShownPopup = true
            end
        end)
    end
end
