-- Skins/CommunitiesFrame.lua
-- Custom skin for the Communities & Guilds frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local CommunitiesSkin = AbstractUI:NewModule("CommunitiesSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_COMMUNITIES_WIP"] = {
    text = "The skinning for 'Communities Frame' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local hasShownPopup = false

function CommunitiesSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function CommunitiesSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["CommunitiesFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("CommunitiesFrame") then
                StaticPopup_Show("ABSTRACTUI_COMMUNITIES_WIP")
                hasShownPopup = true
            end
        end)
    end
end
