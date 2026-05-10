-- Skins/DialogFrame.lua
-- Custom skin for the Dialog & Story Choice frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local DialogSkin = AbstractUI:NewModule("DialogSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_DIALOG_WIP"] = {
    text = "The skinning for 'Dialog Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local hasShownPopup = false

function DialogSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function DialogSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["PlayerChoiceFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("PlayerChoiceFrame") then
                StaticPopup_Show("ABSTRACTUI_DIALOG_WIP")
                hasShownPopup = true
            end
        end)
    end
end
