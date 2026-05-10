-- Skins/GameMenuFrame.lua
-- Custom skin for the Game Menu (ESC menu) frame

local _, AbstractUI = ...
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

function GameMenuSkin:OnInitialize()
    -- Wait for SkinFramework to be available
    SkinFramework = AbstractUI.SkinFramework
end

function GameMenuSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Check if this frame is enabled for skinning
    if SkinFramework:IsFrameEnabled("GameMenuFrame") then
        StaticPopup_Show("ABSTRACTUI_GAMEMENU_WIP")
    end
end
