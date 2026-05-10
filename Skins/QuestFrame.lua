-- Skins/QuestFrame.lua
-- Custom skin for the Quest frame

local _, AbstractUI = ...
local QuestSkin = AbstractUI:NewModule("QuestSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_QUEST_WIP"] = {
    text = "The skinning for 'Quest Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function QuestSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function QuestSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("QuestFrame") then
        StaticPopup_Show("ABSTRACTUI_QUEST_WIP")
    end
end
