-- Skins/MailFrame.lua
-- Custom skin for the Mail/Mailbox frame

local _, AbstractUI = ...
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

function MailSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function MailSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("MailFrame") then
        StaticPopup_Show("ABSTRACTUI_MAIL_WIP")
    end
end
