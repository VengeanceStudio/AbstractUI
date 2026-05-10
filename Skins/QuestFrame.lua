-- Skins/QuestFrame.lua
-- Custom skin for the Quest frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
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

local hasShownPopup = false

function QuestSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function QuestSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["QuestFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("QuestFrame") then
                StaticPopup_Show("ABSTRACTUI_QUEST_WIP")
                hasShownPopup = true
            end
        end)
    end
end
