-- Skins/CollectionsJournal.lua
-- Custom skin for the Collections (Mounts/Pets/Toys) frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local CollectionsSkin = AbstractUI:NewModule("CollectionsSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_COLLECTIONS_WIP"] = {
    text = "The skinning for 'Collections Journal' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local hasShownPopup = false

function CollectionsSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function CollectionsSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["CollectionsJournal"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("CollectionsJournal") then
                StaticPopup_Show("ABSTRACTUI_COLLECTIONS_WIP")
                hasShownPopup = true
            end
        end)
    end
end
