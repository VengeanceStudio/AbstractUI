-- Skins/TradeFrame.lua
-- Custom skin for the Trade frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local TradeSkin = AbstractUI:NewModule("TradeSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_TRADE_WIP"] = {
    text = "The skinning for 'Trade Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function TradeSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function TradeSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("TradeFrame") then
        StaticPopup_Show("ABSTRACTUI_TRADE_WIP")
    end
end
