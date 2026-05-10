-- Skins/AchievementFrame.lua
-- Custom skin for the Achievements frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local AchievementSkin = AbstractUI:NewModule("AchievementSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_ACHIEVEMENT_WIP"] = {
    text = "The skinning for 'Achievement Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local hasShownPopup = false

function AchievementSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function AchievementSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["AchievementFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("AchievementFrame") then
                StaticPopup_Show("ABSTRACTUI_ACHIEVEMENT_WIP")
                hasShownPopup = true
            end
        end)
    end
end
