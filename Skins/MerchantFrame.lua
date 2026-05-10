-- Skins/MerchantFrame.lua
-- Custom skin for the Merchant/Vendor frame

local _, AbstractUI = ...
local MerchantSkin = AbstractUI:NewModule("MerchantSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_MERCHANT_WIP"] = {
    text = "The skinning for 'Merchant Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function MerchantSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function MerchantSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("MerchantFrame") then
        StaticPopup_Show("ABSTRACTUI_MERCHANT_WIP")
    end
end
