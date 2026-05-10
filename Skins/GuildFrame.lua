-- Skins/GuildFrame.lua
-- Custom skin for the Guild frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local GuildSkin = AbstractUI:NewModule("GuildSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_GUILD_WIP"] = {
    text = "The skinning for 'Guild Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function GuildSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function GuildSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("GuildFrame") then
        StaticPopup_Show("ABSTRACTUI_GUILD_WIP")
    end
end
