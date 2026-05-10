-- Skins/PVPUIFrame.lua
-- Custom skin for the PVP UI frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local PVPSkin = AbstractUI:NewModule("PVPSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_PVP_WIP"] = {
    text = "The skinning for 'PVP UI Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function PVPSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function PVPSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("PVPUIFrame") then
        StaticPopup_Show("ABSTRACTUI_PVP_WIP")
    end
end
