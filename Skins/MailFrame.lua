-- Skins/MailFrame.lua
-- Custom skin for the Mail/Mailbox frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local MailSkin = AbstractUI:NewModule("MailSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_MAIL_WIP"] = {
    text = "The skinning for 'Mail Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local hasShownPopup = false

function MailSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function MailSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["MailFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("MailFrame") then
                StaticPopup_Show("ABSTRACTUI_MAIL_WIP")
                hasShownPopup = true
            end
        end)
    end
end
