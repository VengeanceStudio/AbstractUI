-- Skins/LFG.lua
-- Custom skin for the LFG (Looking For Group) / Dungeon Finder

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local LFGSkin = AbstractUI:NewModule("LFGSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_LFG_WIP"] = {
    text = "The skinning for 'LFG' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local hasShownPopup = false

function LFGSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function LFGSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["PVEFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("PVEFrame") then
                StaticPopup_Show("ABSTRACTUI_LFG_WIP")
                hasShownPopup = true
            end
        end)
    end
end
