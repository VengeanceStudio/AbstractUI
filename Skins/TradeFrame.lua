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

local hasShownPopup = false

function TradeSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function TradeSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["TradeFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("TradeFrame") then
                StaticPopup_Show("ABSTRACTUI_TRADE_WIP")
                hasShownPopup = true
            end
        end)
    end
end
