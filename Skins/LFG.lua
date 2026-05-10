-- Skins/LFG.lua
-- Custom skin for the LFG (Looking For Group) / Dungeon Finder

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local LFGSkin = AbstractUI:NewModule("LFGSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_LFG_WIP"] = {
    text = "The skinning for 'LFG' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function LFGSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function LFGSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("PVEFrame") then
        StaticPopup_Show("ABSTRACTUI_LFG_WIP")
    end
end
