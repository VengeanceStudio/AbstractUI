-- Skins/CommunitiesFrame.lua
-- Custom skin for the Communities & Guilds frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local CommunitiesSkin = AbstractUI:NewModule("CommunitiesSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_COMMUNITIES_WIP"] = {
    text = "The skinning for 'Communities Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function CommunitiesSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function CommunitiesSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("CommunitiesFrame") then
        StaticPopup_Show("ABSTRACTUI_COMMUNITIES_WIP")
    end
end
