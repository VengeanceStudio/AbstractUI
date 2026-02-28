local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local Tweaks = MidnightUI:NewModule("Tweaks", "AceEvent-3.0", "AceHook-3.0")

-- Create a hidden parent frame for hiding UI elements
local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()

local LOADOUT_SERIALIZATION_VERSION

local defaults = {
    profile = {
        fastLoot = true,
        hideGryphons = true,
        hideBagBar = true,
        importOverwriteEnabled = true,
        autoRepair = true,
        autoRepairGuild = false,
        autoSellJunk = true,
        revealMap = true,
        autoDelete = true,
        autoScreenshot = false,
        skipCutscenes = false,
        autoInsertKey = true,
    }
}

function Tweaks:OnInitialize()
    LOADOUT_SERIALIZATION_VERSION = C_Traits.GetLoadoutSerializationVersion and C_Traits.GetLoadoutSerializationVersion() or 1
    
    StaticPopupDialogs["MIDNIGHTUI_TALENT_IMPORT_ERROR"] = {
        text = "%s",
        button1 = OKAY,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
    
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "OnDBReady")
end

function Tweaks:OnDBReady()
    if not MidnightUI.db.profile.modules.tweaks then 
        self:Disable()
        return 
    end
    
    self.db = MidnightUI.db:RegisterNamespace("Tweaks", defaults)
    
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    self:RegisterEvent("MERCHANT_SHOW")
    self:RegisterEvent("MERCHANT_CLOSED")
    self:RegisterEvent("ADDON_LOADED")
    
    if self.db.profile.autoScreenshot then
        self:RegisterEvent("ACHIEVEMENT_EARNED")
    end
    
    -- Immediate bag bar hiding setup
    if self.db.profile.hideBagBar then
        self:HideBagBar()
        -- Set up repeated attempts to catch late-loading frames
        C_Timer.After(0.5, function() self:HideBagBar() end)
        C_Timer.After(2, function() self:HideBagBar() end)
        C_Timer.After(5, function() self:HideBagBar() end)
    end
    
    -- Hook cutscene frames for auto-skip
    if self.db.profile.skipCutscenes then
        self:HookCutscenes()
    end
    
    -- Hook StaticPopup for auto-delete
    if self.db.profile.autoDelete then
        self:HookAutoDelete()
    end
    
    -- Setup talent import immediately
    if self.db.profile.importOverwriteEnabled then
        C_Timer.After(2, function() 
            self:HookTalentImportDialog()
        end)
    end
    
    -- Use event-based approach instead of constant ticker
    -- Bag bar hiding is handled by UPDATE_INVENTORY_DURABILITY event
end

function Tweaks:UPDATE_INVENTORY_DURABILITY()
    if self.db.profile.hideBagBar then
        self:HideBagBar()
    end
end

function Tweaks:BAG_UPDATE_DELAYED()
    if self.db.profile.hideBagBar then
        self:HideBagBar()
    end
    
    if self.db.profile.autoInsertKey then
        self:AutoInsertKeystone()
    end
end

function Tweaks:PLAYER_LOGIN()
    if self.db.profile.hideBagBar then
        C_Timer.After(1, function()
            self:HideBagBar()
        end)
        C_Timer.After(3, function()
            self:HideBagBar()
        end)
    end
end

function Tweaks:ADDON_LOADED(event, addonName)
    -- Hide bag bar when relevant addons load
    if addonName == "Blizzard_EditMode" or addonName == "Blizzard_BagBar" then
        if self.db and self.db.profile.hideBagBar then
            C_Timer.After(0.5, function()
                self:HideBagBar()
            end)
        end
    end
end

function Tweaks:PLAYER_ENTERING_WORLD()
    -- Apply tweaks with delays
    C_Timer.After(0.1, function() self:ApplyTweaks() end)
    C_Timer.After(0.5, function() self:ApplyTweaks() end)
    C_Timer.After(1, function() self:ApplyTweaks() end)
    C_Timer.After(2, function() self:ApplyTweaks() end)
    C_Timer.After(5, function() self:ApplyTweaks() end)
    
    -- Bag bar hiding with repeated attempts
    if self.db.profile.hideBagBar then
        self:HideBagBar()
        C_Timer.After(1, function() self:HideBagBar() end)
        C_Timer.After(3, function() self:HideBagBar() end)
    end
    
    -- Reveal map if enabled
    if self.db.profile.revealMap then
        C_Timer.After(3, function()
            if self.db.profile.revealMap then
                self:RevealMap()
            end
        end)
    end
    
    -- Setup talent import overwrite hook when dialog is shown
    if self.db.profile.importOverwriteEnabled then
        C_Timer.After(2, function() 
            self:HookTalentImportDialog()
        end)
    end
end

function Tweaks:ACHIEVEMENT_EARNED(event, achievementID)
    if self.db.profile.autoScreenshot and achievementID then
        Screenshot()
        print("|cff00ff00[MidnightUI]|r Achievement earned, screenshot taken.")
    end
end

function Tweaks:RevealMap()
    -- Get the current map ID
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    
    -- Get map info
    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then return end
    
    -- Reveal all areas on the current map
    for x = 0, 100 do
        for y = 0, 100 do
            local normalizedX = x / 100
            local normalizedY = y / 100
            -- Request map preload which can help reveal unexplored areas
            C_Map.RequestPreloadMap(mapID)
        end
    end
end

-- ============================================================================
-- SKIP CUTSCENES
-- ============================================================================

function Tweaks:HookCutscenes()
    if self.cutscenesHooked then return end
    
    -- Hook cinematic frame (in-game cinematics)
    if CinematicFrame then
        CinematicFrame:HookScript("OnShow", function()
            if Tweaks.db.profile.skipCutscenes then
                CinematicFrame_CancelCinematic()
            end
        end)
    end
    
    -- Hook movie frame (pre-rendered movies)
    if MovieFrame then
        MovieFrame:HookScript("OnShow", function()
            if Tweaks.db.profile.skipCutscenes then
                MovieFrame:StopMovie()
            end
        end)
    end
    
    self.cutscenesHooked = true
end

-- ============================================================================
-- AUTO INSERT MYTHIC KEYSTONE
-- ============================================================================

function Tweaks:AutoInsertKeystone()
    -- Check if we're in a Mythic+ dungeon or can access the keystone slot
    if not C_ChallengeMode or not C_ChallengeMode.SlotKeystone then return end
    
    -- Don't try if a keystone is already slotted
    local hasKeystone = C_ChallengeMode.HasSlottedKeystone()
    if hasKeystone then return end
    
    -- Search bags for a keystone (Item ID: 180653 for Shadowlands+, 158923 for BFA)
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo then
                local itemLink = itemInfo.hyperlink
                if itemLink then
                    local itemID = C_Item.GetItemInfoInstant(itemLink)
                    -- Check if it's a Mythic Keystone (180653 = Titan Keystone, 158923 = Mythic Keystone)
                    if itemID == 180653 or itemID == 158923 then
                        -- Try to slot the keystone
                        C_Container.PickupContainerItem(bag, slot)
                        C_ChallengeMode.SlotKeystone()
                        return
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- AUTO DELETE CONFIRMATION
-- ============================================================================

function Tweaks:HookAutoDelete()
    if self.autoDeleteHooked then return end
    
    -- Hook StaticPopup_Show to auto-fill when dialog opens
    self:SecureHook("StaticPopup_Show", function(which, ...)
        if not which then return end
        
        if (which == "DELETE_ITEM" or which == "DELETE_GOOD_ITEM" or 
            which == "DELETE_QUEST_ITEM" or which == "DELETE_GOOD_QUEST_ITEM") then
            
            if Tweaks.db.profile.autoDelete then
                C_Timer.After(0.1, function()
                    -- STATICPOPUP_NUMDIALOGS doesn't exist in modern WoW, default to 4
                    local numDialogs = 4
                    for i = 1, numDialogs do
                        local dialog = _G["StaticPopup" .. i]
                        if dialog and dialog:IsShown() and dialog.which == which then
                            local editBox = dialog.editBox
                            if editBox then
                                editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
                                editBox:ClearFocus()
                                
                                -- Enable the accept button
                                if dialog.button1 then
                                    dialog.button1:Enable()
                                end
                            end
                            break
                        end
                    end
                end)
            end
        end
    end)
    
    self.autoDeleteHooked = true
end

function Tweaks:HideBagBar()
    if BagsBar then
        BagsBar:SetParent(hiddenFrame)
        BagsBar:Hide()
        BagsBar:SetAlpha(0)
        BagsBar:UnregisterAllEvents()
        
        -- Hook Show to prevent it from appearing
        if not BagsBar.midnightHooked then
            hooksecurefunc(BagsBar, "Show", function()
                if Tweaks.db and Tweaks.db.profile.hideBagBar then
                    BagsBar:Hide()
                end
            end)
            BagsBar.midnightHooked = true
        end
    end
    if MicroButtonAndBagsBar and MicroButtonAndBagsBar.BagsBar then
        MicroButtonAndBagsBar.BagsBar:SetParent(hiddenFrame)
        MicroButtonAndBagsBar.BagsBar:Hide()
        MicroButtonAndBagsBar.BagsBar:SetAlpha(0)
        MicroButtonAndBagsBar.BagsBar:UnregisterAllEvents()
        
        -- Hook Show to prevent it from appearing
        if not MicroButtonAndBagsBar.BagsBar.midnightHooked then
            hooksecurefunc(MicroButtonAndBagsBar.BagsBar, "Show", function()
                if Tweaks.db and Tweaks.db.profile.hideBagBar then
                    MicroButtonAndBagsBar.BagsBar:Hide()
                end
            end)
            MicroButtonAndBagsBar.BagsBar.midnightHooked = true
        end
    end
    
    -- Also try to hide EditMode bag bar
    if EditModeManagerFrame and EditModeManagerFrame.GetSystemFrame then
        local bagBar = EditModeManagerFrame:GetSystemFrame(Enum.EditModeSystem.BagBar)
        if bagBar then
            bagBar:SetParent(hiddenFrame)
            bagBar:Hide()
            bagBar:SetAlpha(0)
            
            -- Hook Show to prevent it from appearing
            if not bagBar.midnightHooked then
                hooksecurefunc(bagBar, "Show", function()
                    if Tweaks.db and Tweaks.db.profile.hideBagBar then
                        bagBar:Hide()
                    end
                end)
                bagBar.midnightHooked = true
            end
        end
    end
end

function Tweaks:ShowBagBar()
    -- Cancel ticker when showing
    if self.bagBarTicker then
        self.bagBarTicker:Cancel()
        self.bagBarTicker = nil
    end
    
    if BagsBar then
        BagsBar:SetParent(UIParent)
        BagsBar:Show()
        BagsBar:SetAlpha(1)
    end
    if MicroButtonAndBagsBar and MicroButtonAndBagsBar.BagsBar then
        MicroButtonAndBagsBar.BagsBar:SetParent(MicroButtonAndBagsBar)
        MicroButtonAndBagsBar.BagsBar:Show()
        MicroButtonAndBagsBar.BagsBar:SetAlpha(1)
    end
    
    -- Also show EditMode bag bar
    if EditModeManagerFrame and EditModeManagerFrame.GetSystemFrame then
        local bagBar = EditModeManagerFrame:GetSystemFrame(Enum.EditModeSystem.BagBar)
        if bagBar then
            bagBar:SetParent(UIParent)
            bagBar:Show()
            bagBar:SetAlpha(1)
        end
    end
    
    C_UI.Reload()
end

function Tweaks:ApplyTweaks()
    if self.db.profile.fastLoot then
        -- Set Auto Loot CVars
        SetCVar("autoLootDefault", "1")
    end
    
    if self.db.profile.revealMap then
        self:RevealMap()
    end
    
    if self.db.profile.hideBagBar then
        self:HideBagBar()
        
        -- Set up persistent hooks if not already done
        if not self.bagBarHooked then
            if BagsBar then
                hooksecurefunc(BagsBar, "Show", function()
                    if self.db.profile.hideBagBar then
                        BagsBar:Hide()
                    end
                end)
                hooksecurefunc(BagsBar, "SetParent", function(frame, parent)
                    if self.db.profile.hideBagBar and parent ~= hiddenFrame then
                        C_Timer.After(0, function()
                            frame:SetParent(hiddenFrame)
                        end)
                    end
                end)
            end
            if MicroButtonAndBagsBar and MicroButtonAndBagsBar.BagsBar then
                hooksecurefunc(MicroButtonAndBagsBar.BagsBar, "Show", function()
                    if self.db.profile.hideBagBar then
                        MicroButtonAndBagsBar.BagsBar:Hide()
                    end
                end)
                hooksecurefunc(MicroButtonAndBagsBar.BagsBar, "SetParent", function(frame, parent)
                    if self.db.profile.hideBagBar and parent ~= hiddenFrame then
                        C_Timer.After(0, function()
                            frame:SetParent(hiddenFrame)
                        end)
                    end
                end)
            end
            self.bagBarHooked = true
        end
    else
        self:ShowBagBar()
    end
end

-- ============================================================================
-- MERCHANT FUNCTIONS
-- ============================================================================

function Tweaks:MERCHANT_SHOW()
    if self.db.profile.autoRepair then
        C_Timer.After(0.5, function()
            if self.db.profile.autoRepair then
                self:AutoRepair()
            end
        end)
    end
    
    if self.db.profile.autoSellJunk then
        C_Timer.After(0.5, function()
            if self.db.profile.autoSellJunk then
                self:AutoSellJunk()
            end
        end)
    end
end

function Tweaks:MERCHANT_CLOSED()
    -- Cleanup if needed
end

function Tweaks:AutoRepair()
    if not CanMerchantRepair() then
        return
    end
    
    local repairCost, canRepair = GetRepairAllCost()
    if not canRepair or repairCost <= 0 then
        return
    end
    
    local useGuildBank = self.db.profile.autoRepairGuild and CanGuildBankRepair()
    
    if useGuildBank then
        RepairAllItems(true)
        local guildRepairCost = GetGuildBankWithdrawMoney()
        if guildRepairCost >= repairCost then
            print("|cff00ff00[MidnightUI]|r Repaired all items using guild bank funds for " .. GetCoinTextureString(repairCost))
        else
            print("|cff00ff00[MidnightUI]|r Guild bank repair failed, insufficient funds.")
        end
    else
        if GetMoney() >= repairCost then
            RepairAllItems(false)
            print("|cff00ff00[MidnightUI]|r Repaired all items for " .. GetCoinTextureString(repairCost))
        else
            print("|cffff6b6b[MidnightUI]|r Not enough gold to repair all items. Need " .. GetCoinTextureString(repairCost))
        end
    end
end

function Tweaks:AutoSellJunk()
    if not MerchantFrame:IsShown() then
        return
    end
    
    local totalValue = 0
    local itemsSold = 0
    
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo then
                local itemLink = itemInfo.hyperlink
                if itemLink then
                    local itemQuality = C_Item.GetItemQualityByID(itemLink)
                    local itemSellPrice = select(11, C_Item.GetItemInfo(itemLink))
                    
                    -- Sell grey (poor quality) items
                    if itemQuality == Enum.ItemQuality.Poor and itemSellPrice and itemSellPrice > 0 then
                        local stackCount = itemInfo.stackCount or 1
                        totalValue = totalValue + (itemSellPrice * stackCount)
                        itemsSold = itemsSold + stackCount
                        C_Container.UseContainerItem(bag, slot)
                    end
                end
            end
        end
    end
    
    if itemsSold > 0 then
        print("|cff00ff00[MidnightUI]|r Sold " .. itemsSold .. " junk item(s) for " .. GetCoinTextureString(totalValue))
    end
end

function Tweaks:GetOptions()
    return {
        type = "group", 
        name = "Tweaks",
        get = function(info) return self.db.profile[info[#info]] end,
        set = function(info, value) self.db.profile[info[#info]] = value end,
        args = {
            fastLoot = { name = "Fast Loot", type = "toggle", order = 1},
            hideGryphons = { name = "Hide Action Bar Art", type = "toggle", order = 2,
                set = function(_, v) self.db.profile.hideGryphons = v; C_UI.Reload() end },
            hideBagBar = { name = "Hide Bag Bar", type = "toggle", order = 3,
                set = function(_, v) self.db.profile.hideBagBar = v; self:ApplyTweaks() end },
            autoRepair = {
                name = "Auto Repair at Vendors",
                desc = "Automatically repair all items when opening a merchant that can repair",
                type = "toggle",
                order = 4,
            },
            autoRepairGuild = {
                name = "Use Guild Bank for Repairs",
                desc = "Use guild bank funds for repairs if available (requires guild repair privileges)",
                type = "toggle",
                order = 5,
                disabled = function() return not self.db.profile.autoRepair end,
            },
            autoSellJunk = {
                name = "Auto Sell Junk at Vendors",
                desc = "Automatically sell all grey (poor quality) items when opening a merchant",
                type = "toggle",
                order = 6,
            },
            revealMap = {
                name = "Reveal Entire Map",
                desc = "Automatically reveals unexplored areas on the world map (Note: May not work on all map types due to Blizzard restrictions)",
                type = "toggle",
                order = 7,
            },
            autoDelete = {
                name = "Auto-Fill Delete Confirmation",
                desc = "Automatically fills in the DELETE confirmation text and enables the delete button when deleting items",
                type = "toggle",
                order = 8,
                set = function(_, v)
                    self.db.profile.autoDelete = v
                    if v then
                        self:HookAutoDelete()
                    end
                end,
            },
            autoScreenshot = {
                name = "Auto Screenshot on Achievement",
                desc = "Automatically takes a screenshot whenever you earn an achievement",
                type = "toggle",
                order = 9,
                set = function(_, v)
                    self.db.profile.autoScreenshot = v
                    if v then
                        self:RegisterEvent("ACHIEVEMENT_EARNED")
                    else
                        self:UnregisterEvent("ACHIEVEMENT_EARNED")
                    end
                end,
            },
            skipCutscenes = {
                name = "Skip Cutscenes",
                desc = "Automatically skips cinematics and movie cutscenes",
                type = "toggle",
                order = 10,
                set = function(_, v)
                    self.db.profile.skipCutscenes = v
                    if v then
                        self:HookCutscenes()
                    end
                end,
            },
            autoInsertKey = {
                name = "Auto-Insert Mythic Keystone",
                desc = "Automatically places Mythic Keystones from your bags into the keystone font",
                type = "toggle",
                order = 11,
            },
            importOverwriteEnabled = { 
                name = "Enable Talent Import Overwrite", 
                desc = "Adds a checkbox to the talent import dialog to overwrite the current loadout instead of creating a new one",
                type = "toggle", 
                order = 12,
                set = function(_, v) 
                    self.db.profile.importOverwriteEnabled = v
                    if v then
                        self:HookTalentImportDialog()
                    else
                        self:DisableTalentImportHook()
                    end
                end 
            },
        }
    }
end

-- ============================================================================
-- TALENT IMPORT OVERWRITE FUNCTIONALITY
-- ============================================================================

function Tweaks:HookTalentImportDialog()
    if self.talentDialogHooked then return end
    
    -- Wait for the dialog to exist and hook its OnShow
    if ClassTalentLoadoutImportDialog then
        ClassTalentLoadoutImportDialog:HookScript("OnShow", function()
            C_Timer.After(0.1, function()
                self:SetupTalentImportHook()
            end)
        end)
        self.talentDialogHooked = true
    else
        C_Timer.After(2, function() self:HookTalentImportDialog() end)
    end
end

function Tweaks:SetupTalentImportHook()
    if not ClassTalentLoadoutImportDialog then
        return
    end
    
    local dialog = ClassTalentLoadoutImportDialog
    self:CreateImportCheckbox(dialog)
    self:CreateImportAcceptButton(dialog)
    
    if self.importCheckbox then
        self.importCheckbox:SetChecked(false)
        self:OnImportCheckboxClick(self.importCheckbox)
    end
end

function Tweaks:DisableTalentImportHook()
    self:UnhookAll()
    if self.importCheckbox then
        self.importCheckbox:Hide()
        ClassTalentLoadoutImportDialog.NameControl:SetShown(true)
        ClassTalentLoadoutImportDialog:UpdateAcceptButtonEnabledState()
    end
    if self.importAcceptButton then
        self.importAcceptButton:Hide()
    end
end

function Tweaks:CreateImportCheckbox(dialog)
    if self.importCheckbox then
        self.importCheckbox:Show()
        return
    end
    
    local checkbox = CreateFrame("CheckButton", "MidnightUI_ImportOverwriteCheckbox", dialog, "UICheckButtonTemplate")
    
    -- Position relative to the dialog itself if NameControl doesn't exist
    if dialog.NameControl then
        checkbox:SetPoint("TOPLEFT", dialog.NameControl, "BOTTOMLEFT", 0, 10)
    else
        checkbox:SetPoint("TOP", dialog, "TOP", 0, -100)
    end
    
    checkbox:SetSize(24, 24)
    checkbox:SetFrameStrata("DIALOG")
    checkbox:SetFrameLevel(dialog:GetFrameLevel() + 10)
    checkbox:SetScript("OnClick", function(cb) self:OnImportCheckboxClick(cb) end)
    checkbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Overwrite Current Loadout")
        GameTooltip:AddLine("If checked, the imported build will overwrite your currently selected loadout.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    checkbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    checkbox.text = checkbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 0, 1)
    checkbox.text:SetText("Overwrite Current Loadout")
    checkbox:SetHitRectInsets(-10, -checkbox.text:GetStringWidth(), -5, 0)
    
    checkbox:Show()
    
    self.importCheckbox = checkbox
end

function Tweaks:CreateImportAcceptButton(dialog)
    self:SecureHook(dialog, "OnTextChanged", function() 
        if self.importAcceptButton then
            self.importAcceptButton:SetEnabled(dialog.ImportControl:HasText()) 
        end
    end)
    
    if self.importAcceptButton then
        self.importAcceptButton:Show()
        return
    end
    
    local acceptButton = CreateFrame("Button", nil, dialog, "ClassTalentLoadoutDialogButtonTemplate")
    acceptButton:SetPoint("BOTTOMRIGHT", dialog.ContentArea, "BOTTOM", -5, 0)
    acceptButton:SetText("Import & Overwrite")
    acceptButton.disabledTooltip = "Enter an import string"
    acceptButton:SetScript("OnClick", function()
        local importString = dialog.ImportControl:GetText()
        if self:ImportLoadoutIntoActive(importString) then
            ClassTalentLoadoutImportDialog:OnCancel()
        end
    end)
    
    self.importAcceptButton = acceptButton
end

function Tweaks:OnImportCheckboxClick(checkbox)
    local dialog = checkbox:GetParent()
    dialog.NameControl:SetShown(not checkbox:GetChecked())
    dialog.NameControl:SetText(checkbox:GetChecked() and "" or "")
    
    if self.importAcceptButton then
        self.importAcceptButton:SetShown(checkbox:GetChecked())
    end
    dialog.AcceptButton:SetShown(not checkbox:GetChecked())
    
    if checkbox:GetChecked() and self.importAcceptButton then
        self.importAcceptButton:SetEnabled(dialog.ImportControl:HasText())
    else
        dialog:UpdateAcceptButtonEnabledState()
    end
end

function Tweaks:GetTreeID()
    local configInfo = C_Traits.GetConfigInfo(C_ClassTalents.GetActiveConfigID())
    return configInfo and configInfo.treeIDs and configInfo.treeIDs[1]
end

function Tweaks:ShowImportError(errorString)
    StaticPopup_Show("MIDNIGHTUI_TALENT_IMPORT_ERROR", errorString)
end

function Tweaks:ImportLoadoutIntoActive(importText)
    local importStream = ExportUtil.MakeImportDataStream(importText)
    
    local headerValid, serializationVersion, specID, treeHash = ClassTalentImportExportMixin:ReadLoadoutHeader(importStream)
    
    if not headerValid then
        self:ShowImportError(LOADOUT_ERROR_BAD_STRING)
        return false
    end
    
    if serializationVersion ~= LOADOUT_SERIALIZATION_VERSION then
        self:ShowImportError(LOADOUT_ERROR_SERIALIZATION_VERSION_MISMATCH)
        return false
    end
    
    if specID ~= PlayerUtil.GetCurrentSpecID() then
        self:ShowImportError(LOADOUT_ERROR_WRONG_SPEC)
        return false
    end
    
    local treeID = self:GetTreeID()
    if not ClassTalentImportExportMixin:IsHashEmpty(treeHash) then
        if not ClassTalentImportExportMixin:HashEquals(treeHash, C_Traits.GetTreeHash(treeID)) then
            self:ShowImportError(LOADOUT_ERROR_TREE_CHANGED)
            return false
        end
    end
    
    local loadoutContent = ClassTalentImportExportMixin:ReadLoadoutContent(importStream, treeID)
    local loadoutEntryInfo = self:ConvertToImportLoadoutEntryInfo(treeID, loadoutContent)
    
    return self:DoImport(loadoutEntryInfo)
end

function Tweaks:DoImport(loadoutEntryInfo)
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
        return false
    end
    
    C_Traits.ResetTree(configID, self:GetTreeID())
    
    while true do
        local removed = self:PurchaseLoadoutEntryInfo(configID, loadoutEntryInfo)
        if removed == 0 then
            break
        end
    end
    
    return true
end

function Tweaks:PurchaseLoadoutEntryInfo(configID, loadoutEntryInfo)
    local removed = 0
    for i, nodeEntry in pairs(loadoutEntryInfo) do
        local success = false
        if nodeEntry.selectionEntryID then
            success = C_Traits.SetSelection(configID, nodeEntry.nodeID, nodeEntry.selectionEntryID)
        elseif nodeEntry.ranksPurchased then
            for rank = 1, nodeEntry.ranksPurchased do
                success = C_Traits.PurchaseRank(configID, nodeEntry.nodeID)
            end
        end
        if success then
            removed = removed + 1
            loadoutEntryInfo[i] = nil
        end
    end
    return removed
end

function Tweaks:ConvertToImportLoadoutEntryInfo(treeID, loadoutContent)
    local results = {}
    local treeNodes = C_Traits.GetTreeNodes(treeID)
    local configID = C_ClassTalents.GetActiveConfigID()
    local count = 1
    
    for i, treeNodeID in ipairs(treeNodes) do
        local indexInfo = loadoutContent[i]
        
        if indexInfo.isNodeSelected then
            local treeNode = C_Traits.GetNodeInfo(configID, treeNodeID)
            local isChoiceNode = treeNode.type == Enum.TraitNodeType.Selection or treeNode.type == Enum.TraitNodeType.SubTreeSelection
            local choiceNodeSelection = indexInfo.isChoiceNode and indexInfo.choiceNodeSelection or nil
            
            if indexInfo.isNodeSelected and isChoiceNode ~= indexInfo.isChoiceNode then
                print(string.format("Import string is corrupt, node type mismatch at nodeID %d. First option will be selected.", treeNodeID))
                choiceNodeSelection = 1
            end
            
            local result = {}
            result.nodeID = treeNode.ID
            result.ranksPurchased = indexInfo.isPartiallyRanked and indexInfo.partialRanksPurchased or treeNode.maxRanks
            result.selectionEntryID = indexInfo.isNodeSelected and isChoiceNode and treeNode.entryIDs[choiceNodeSelection] or nil
            results[count] = result
            count = count + 1
        end
    end
    
    return results
end