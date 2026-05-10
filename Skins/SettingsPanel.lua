-- Skins/SettingsPanel.lua
-- Custom skin for the Settings Panel frame

local _, AbstractUI = ...
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

function SettingsSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function SettingsSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("SettingsPanel") then
        StaticPopup_Show("ABSTRACTUI_SETTINGS_WIP")
    end
end
