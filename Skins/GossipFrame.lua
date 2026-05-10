-- Skins/GossipFrame.lua
-- Custom skin for the NPC Gossip frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local GossipSkin = AbstractUI:NewModule("GossipSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_GOSSIP_WIP"] = {
    text = "The skinning for 'Gossip Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local hasShownPopup = false

function GossipSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function GossipSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["GossipFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("GossipFrame") then
                StaticPopup_Show("ABSTRACTUI_GOSSIP_WIP")
                hasShownPopup = true
            end
        end)
    end
end
