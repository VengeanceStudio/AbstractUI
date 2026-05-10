-- Skins/SpellBookFrame.lua
-- Custom skin for the Spell Book & Abilities frame

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local SpellBookSkin = AbstractUI:NewModule("SpellBookSkin", "AceEvent-3.0")

local SkinFramework

-- Work in progress dialog
StaticPopupDialogs["ABSTRACTUI_SPELLBOOK_WIP"] = {
    text = "The skinning for 'Spell Book' is not completed yet and is a work in progress.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local hasShownPopup = false

function SpellBookSkin:OnInitialize()
    SkinFramework = AbstractUI.SkinFramework
end

function SpellBookSkin:OnEnable()
    if not SkinFramework then return end
    
    -- Hook the frame to show popup when first opened
    local frame = _G["SpellBookFrame"]
    if frame then
        frame:HookScript("OnShow", function()
            if not hasShownPopup and SkinFramework:IsFrameEnabled("SpellBookFrame") then
                StaticPopup_Show("ABSTRACTUI_SPELLBOOK_WIP")
                hasShownPopup = true
            end
        end)
    end
end
