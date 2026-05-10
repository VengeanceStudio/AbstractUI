-- Skins/PVEFrame.lua
-- Custom skin for the PVE (Dungeon Finder/LFG) frame

local _, AbstractUI = ...
local PVESkin = AbstractUI:NewModule("PVESkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_PVE_WIP"] = {
    text = "The skinning for 'PVE Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function PVESkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function PVESkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("PVEFrame") then
        StaticPopup_Show("ABSTRACTUI_PVE_WIP")
    end
end
