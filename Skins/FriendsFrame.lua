-- Skins/FriendsFrame.lua
-- Custom skin for the Friends & Social frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local FriendsSkin = AbstractUI:NewModule("FriendsSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_FRIENDS_WIP"] = {
    text = "The skinning for 'Friends Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function FriendsSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function FriendsSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("FriendsFrame") then
        StaticPopup_Show("ABSTRACTUI_FRIENDS_WIP")
    end
end
