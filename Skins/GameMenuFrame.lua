-- Skins/GameMenuFrame.lua
-- Custom skin for the Game Menu (ESC menu) frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local GameMenuSkin = AbstractUI:NewModule("GameMenuSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_GAMEMENU_WIP"] = {
    text = "The skinning for 'Game Menu Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local hasShownPopup = false

function GameMenuSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function GameMenuSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["GameMenuFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("GameMenuFrame") then
                StaticPopup_Show("ABSTRACTUI_GAMEMENU_WIP")
                hasShownPopup = true
            end
        end)
    end
end
