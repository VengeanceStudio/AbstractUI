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

local hasShownPopup = false

function PVPSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function PVPSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["PVPUIFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("PVPUIFrame") then
                StaticPopup_Show("ABSTRACTUI_PVP_WIP")
                hasShownPopup = true
            end
        end)
    end
end
