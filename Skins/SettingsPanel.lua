-- Skins/SettingsPanel.lua
-- Custom skin for the Settings Panel frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local SettingsSkin = AbstractUI:NewModule("SettingsSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_SETTINGS_WIP"] = {
    text = "The skinning for 'Settings Panel' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local hasShownPopup = false

function SettingsSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function SettingsSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["SettingsPanel"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("SettingsPanel") then
                StaticPopup_Show("ABSTRACTUI_SETTINGS_WIP")
                hasShownPopup = true
            end
        end)
    end
end
