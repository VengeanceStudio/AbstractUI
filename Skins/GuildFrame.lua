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

local hasShownPopup = false

function GuildSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function GuildSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["GuildFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("GuildFrame") then
                StaticPopup_Show("ABSTRACTUI_GUILD_WIP")
                hasShownPopup = true
            end
        end)
    end
end
