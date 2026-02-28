local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local Mailbox = MidnightUI:NewModule("Mailbox", "AceEvent-3.0", "AceHook-3.0")

-- ============================================================================
-- Module Initialization
-- ============================================================================

function Mailbox:OnInitialize()
    self.db = MidnightUI.db:RegisterNamespace("Mailbox", {
        profile = {
            -- BlackBook
            blackBookEnabled = true,
            trackAlts = true,
            trackRecentlyMailed = true,
            recentlyMailedLimit = 20,
            autocompleteAlts = true,
            autocompleteRecentlyMailed = true,
            autocompleteContacts = true,
            autocompleteFriends = true,
            autocompleteGuild = true,
            autofillLastRecipient = false,
            disableBlizzardAutocomplete = true,
            
            -- CarbonCopy
            carbonCopyEnabled = true,
            
            -- DoNotWant
            doNotWantEnabled = false,
            
            -- Express
            expressEnabled = true,
            disableMultiItemTooltips = false,
            
            -- Forward
            forwardEnabled = true,
            
            -- OpenAll
            openAllEnabled = true,
            openAllAHCancelled = true,
            openAllAHExpired = true,
            openAllAHOutbid = true,
            openAllAHSuccess = true,
            openAllAHWon = true,
            openAllNonAH = true,
            keepFreeSlots = 0,
            
            -- QuickAttach
            quickAttachEnabled = true,
            quickAttachBags = {true, true, true, true, true}, -- bags 0-4
            
            -- Rake
            rakeEnabled = true,
            
            -- Select
            selectEnabled = false,
            selectKeepFreeSlots = 0,
            
            -- TradeBlock
            tradeBlockEnabled = true,
            blockTrades = true,
            blockGuildCharters = true,
            
            -- Wire
            wireEnabled = true,
        }
    })
    
    -- Initialize data storage
    if not MidnightUI.db.global.mailbox then
        MidnightUI.db.global.mailbox = {
            alts = {},
            recentlyMailed = {},
            contacts = {},
        }
    end
    
    self.data = MidnightUI.db.global.mailbox
    
    -- Track current character
    self:TrackCurrentCharacter()
end

function Mailbox:OnEnable()
    self:RegisterEvent("MAIL_SHOW")
    self:RegisterEvent("MAIL_CLOSED")
    self:RegisterEvent("MAIL_INBOX_UPDATE")
end

function Mailbox:OnDisable()
    self:UnhookAll()
    self:UnregisterAllEvents()
end

-- ============================================================================
-- Character Tracking (BlackBook)
-- ============================================================================

function Mailbox:TrackCurrentCharacter()
    if not self.db.profile.trackAlts then return end
    
    local name = UnitName("player")
    local realm = GetRealmName()
    local faction = UnitFactionGroup("player")
    
    local key = realm .. "-" .. name
    
    if not self.data.alts[key] then
        self.data.alts[key] = {
            name = name,
            realm = realm,
            faction = faction,
            lastSeen = time(),
        }
    else
        self.data.alts[key].lastSeen = time()
    end
end

function Mailbox:GetAlts(sameRealmOnly)
    local alts = {}
    local currentRealm = GetRealmName()
    local currentFaction = UnitFactionGroup("player")
    local currentName = UnitName("player")
    
    for key, alt in pairs(self.data.alts) do
        if alt.name ~= currentName then
            if sameRealmOnly then
                if alt.realm == currentRealm and alt.faction == currentFaction then
                    table.insert(alts, alt)
                end
            else
                table.insert(alts, alt)
            end
        end
    end
    
    -- Sort by last seen
    table.sort(alts, function(a, b) return a.lastSeen > b.lastSeen end)
    
    return alts
end

function Mailbox:AddToRecentlyMailed(recipient)
    if not self.db.profile.trackRecentlyMailed then return end
    
    -- Remove if already exists
    for i = #self.data.recentlyMailed, 1, -1 do
        if self.data.recentlyMailed[i] == recipient then
            table.remove(self.data.recentlyMailed, i)
        end
    end
    
    -- Add to front
    table.insert(self.data.recentlyMailed, 1, recipient)
    
    -- Trim to limit
    while #self.data.recentlyMailed > self.db.profile.recentlyMailedLimit do
        table.remove(self.data.recentlyMailed)
    end
end

-- ============================================================================
-- Mail UI Enhancement
-- ============================================================================

function Mailbox:MAIL_SHOW()
    self:EnhanceMailUI()
    
    if self.db.profile.tradeBlockEnabled and self.db.profile.blockTrades then
        self:BlockTrades()
    end
end

function Mailbox:MAIL_CLOSED()
    if self.db.profile.tradeBlockEnabled then
        self:UnblockTrades()
    end
end

function Mailbox:EnhanceMailUI()
    if not MailFrame then return end
    
    -- Add BlackBook contact list
    if self.db.profile.blackBookEnabled then
        self:CreateBlackBookUI()
    end
    
    -- Add OpenAll button
    if self.db.profile.openAllEnabled then
        self:CreateOpenAllButton()
    end
    
    -- Add Select checkboxes
    if self.db.profile.selectEnabled then
        self:CreateSelectCheckboxes()
    end
    
    -- Add QuickAttach buttons
    if self.db.profile.quickAttachEnabled then
        self:CreateQuickAttachButtons()
    end
    
    -- Hook express shortcuts
    if self.db.profile.expressEnabled then
        self:SetupExpressShortcuts()
    end
    
    -- Setup wire auto-subject
    if self.db.profile.wireEnabled then
        self:SetupWireAutoSubject()
    end
    
    -- Add DoNotWant icons
    if self.db.profile.doNotWantEnabled then
        self:CreateDoNotWantIcons()
    end
end

-- ============================================================================
-- BlackBook UI
-- ============================================================================

function Mailbox:CreateBlackBookUI()
    if self.blackBookButton then return end
    
    -- Create dropdown button next to To: field
    local button = CreateFrame("Button", "MidnightUI_BlackBookButton", SendMailNameEditBox, "UIPanelButtonTemplate")
    button:SetSize(80, 22)
    button:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", 5, 0)
    button:SetText("Contacts")
    button:SetScript("OnClick", function(btn)
        self:ShowBlackBookMenu(btn)
    end)
    
    self.blackBookButton = button
    
    -- Hook autocomplete
    if self.db.profile.disableBlizzardAutocomplete then
        -- Modern WoW uses autoCompleteParams table directly
        SendMailNameEditBox.autoCompleteParams = nil
    end
    
    -- Autofill last recipient
    if self.db.profile.autofillLastRecipient and #self.data.recentlyMailed > 0 then
        SendMailNameEditBox:SetText(self.data.recentlyMailed[1])
    end
end

function Mailbox:ShowBlackBookMenu(button)
    local menu = {}
    
    -- Alts section
    if self.db.profile.autocompleteAlts then
        local alts = self:GetAlts(true)
        if #alts > 0 then
            table.insert(menu, {text = "Alts (Same Realm)", isTitle = true, notCheckable = true})
            for _, alt in ipairs(alts) do
                table.insert(menu, {
                    text = alt.name,
                    notCheckable = true,
                    func = function()
                        SendMailNameEditBox:SetText(alt.name)
                    end
                })
            end
        end
        
        -- All alts
        local allAlts = self:GetAlts(false)
        if #allAlts > #alts then
            table.insert(menu, {text = " ", isTitle = true, notCheckable = true})
            table.insert(menu, {text = "All Alts", isTitle = true, notCheckable = true})
            for _, alt in ipairs(allAlts) do
                if alt.realm ~= GetRealmName() or alt.faction ~= UnitFactionGroup("player") then
                    table.insert(menu, {
                        text = alt.name .. " - " .. alt.realm,
                        notCheckable = true,
                        func = function()
                            SendMailNameEditBox:SetText(alt.name .. "-" .. alt.realm)
                        end
                    })
                end
            end
        end
    end
    
    -- Recently mailed
    if self.db.profile.autocompleteRecentlyMailed and #self.data.recentlyMailed > 0 then
        table.insert(menu, {text = " ", isTitle = true, notCheckable = true})
        table.insert(menu, {text = "Recently Mailed", isTitle = true, notCheckable = true})
        for i = 1, math.min(10, #self.data.recentlyMailed) do
            table.insert(menu, {
                text = self.data.recentlyMailed[i],
                notCheckable = true,
                func = function()
                    SendMailNameEditBox:SetText(self.data.recentlyMailed[i])
                end
            })
        end
    end
    
    -- Friends
    if self.db.profile.autocompleteFriends then
        local numFriends = C_FriendList.GetNumFriends()
        if numFriends > 0 then
            table.insert(menu, {text = " ", isTitle = true, notCheckable = true})
            table.insert(menu, {text = "Friends", isTitle = true, notCheckable = true})
            for i = 1, numFriends do
                local friendInfo = C_FriendList.GetFriendInfoByIndex(i)
                if friendInfo and friendInfo.connected then
                    table.insert(menu, {
                        text = friendInfo.name,
                        notCheckable = true,
                        func = function()
                            SendMailNameEditBox:SetText(friendInfo.name)
                        end
                    })
                end
            end
        end
    end
    
    -- Guild
    if self.db.profile.autocompleteGuild and IsInGuild() then
        table.insert(menu, {text = " ", isTitle = true, notCheckable = true})
        table.insert(menu, {text = "Guild Members", isTitle = true, notCheckable = true})
        local numGuildMembers = GetNumGuildMembers()
        for i = 1, math.min(20, numGuildMembers) do
            local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if name and online then
                table.insert(menu, {
                    text = name,
                    notCheckable = true,
                    func = function()
                        SendMailNameEditBox:SetText(name)
                    end
                })
            end
        end
    end
    
    -- Show menu
    if #menu > 0 then
        local menuFrame = CreateFrame("Frame", "MidnightUI_BlackBookMenu", UIParent, "UIDropDownMenuTemplate")
        if UIDropDownMenu_Initialize then
            UIDropDownMenu_Initialize(menuFrame, function(frame, level)
                for i, item in ipairs(menu) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = item.text
                    info.isTitle = item.isTitle
                    info.notCheckable = item.notCheckable
                    info.func = item.func
                    UIDropDownMenu_AddButton(info, level)
                end
            end, "MENU")
            ToggleDropDownMenu(1, nil, menuFrame, button, 0, 0)
        end
    end
end

-- ============================================================================
-- OpenAll Button
-- ============================================================================

function Mailbox:CreateOpenAllButton()
    if self.openAllButton then return end
    
    local button = CreateFrame("Button", "MidnightUI_OpenAllButton", InboxFrame, "UIPanelButtonTemplate")
    button:SetSize(100, 22)
    button:SetPoint("TOPLEFT", InboxFrame, "TOPLEFT", 50, -40)
    button:SetText("Open All")
    button:SetScript("OnClick", function(btn)
        self:OpenAllMail(IsShiftKeyDown())
    end)
    button:RegisterForClicks("LeftButtonUp")
    
    self.openAllButton = button
    
    -- Add progress text
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("BOTTOM", button, "TOP", 0, 2)
    button.progressText = text
end

function Mailbox:OpenAllMail(ignoreFilters)
    local numItems, totalItems = GetInboxNumItems()
    if numItems == 0 then return end
    
    local opened = 0
    local bagSlots = 0
    
    -- Count free bag slots
    for bag = 0, 4 do
        bagSlots = bagSlots + C_Container.GetContainerNumFreeSlots(bag)
    end
    
    if bagSlots <= self.db.profile.keepFreeSlots then
        MidnightUI:Print("Not enough bag space to open mail.")
        return
    end
    
    self.openingMail = true
    self.mailsToOpen = {}
    
    -- Build list of mails to open
    for i = 1, numItems do
        local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(i)
        
        if self:ShouldOpenMail(i, ignoreFilters) then
            table.insert(self.mailsToOpen, i)
        end
    end
    
    if #self.mailsToOpen > 0 then
        self:ProcessNextMail()
    else
        MidnightUI:Print("No mail matching your filters.")
    end
end

function Mailbox:ShouldOpenMail(index, ignoreFilters)
    if ignoreFilters then return true end
    
    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(index)
    
    -- Don't open COD
    if CODAmount and CODAmount > 0 then return false end
    
    -- Check if it's AH mail
    if sender == "The Postmaster" or sender == "Auction House" then
        if subject:find("Auction cancelled") and self.db.profile.openAllAHCancelled then return true end
        if subject:find("Auction expired") and self.db.profile.openAllAHExpired then return true end
        if subject:find("Outbid") and self.db.profile.openAllAHOutbid then return true end
        if subject:find("Auction successful") and self.db.profile.openAllAHSuccess then return true end
        if subject:find("Auction won") and self.db.profile.openAllAHWon then return true end
        return false
    end
    
    -- Non-AH mail
    if self.db.profile.openAllNonAH and (hasItem or money > 0) then
        return true
    end
    
    return false
end

function Mailbox:ProcessNextMail()
    if not self.openingMail or #self.mailsToOpen == 0 then
        self.openingMail = false
        if self.openAllButton and self.openAllButton.progressText then
            self.openAllButton.progressText:SetText("")
        end
        return
    end
    
    -- Check bag space
    local bagSlots = 0
    for bag = 0, 4 do
        bagSlots = bagSlots + C_Container.GetContainerNumFreeSlots(bag)
    end
    
    if bagSlots <= self.db.profile.keepFreeSlots then
        MidnightUI:Print("Stopped opening mail - not enough bag space.")
        self.openingMail = false
        return
    end
    
    local index = table.remove(self.mailsToOpen, 1)
    
    -- Update progress
    if self.openAllButton and self.openAllButton.progressText then
        local total = GetInboxNumItems()
        self.openAllButton.progressText:SetText(string.format("Opening %d/%d", total - #self.mailsToOpen, total))
    end
    
    -- Take attachments
    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem = GetInboxHeaderInfo(index)
    if hasItem then
        TakeInboxItem(index)
    elseif money > 0 then
        TakeInboxMoney(index)
    end
    
    -- Continue after delay
    C_Timer.After(0.5, function()
        self:ProcessNextMail()
    end)
end

function Mailbox:MAIL_INBOX_UPDATE()
    if self.openingMail then
        -- Continue processing
    end
end

-- ============================================================================
-- Express Shortcuts
-- ============================================================================

function Mailbox:SetupExpressShortcuts()
    -- Hook inbox items for Shift-Click and Ctrl-Click
    for i = 1, 7 do
        local button = _G["MailItem" .. i .. "Button"]
        if button and not self:IsHooked(button, "OnClick") then
            self:HookScript(button, "OnClick", function(btn, mouseButton)
                local index = btn:GetParent():GetID()
                
                -- Shift-Click: Take item/money
                if IsShiftKeyDown() then
                    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem = GetInboxHeaderInfo(index)
                    if hasItem then
                        TakeInboxItem(index)
                    elseif money > 0 then
                        TakeInboxMoney(index)
                    end
                end
                
                -- Ctrl-Click: Return mail
                if IsControlKeyDown() then
                    ReturnInboxItem(index)
                end
            end)
        end
    end
    
    -- Note: Alt-Click to attach bag items would require hooking modern container frame events
    -- ContainerFrameItemButton_OnModifiedClick no longer exists in WoW 12.0
    -- TODO: Implement using EventRegistry or ContainerFrame item button hooks when bag frame structure is known
end

-- ============================================================================
-- Wire Auto-Subject
-- ============================================================================

function Mailbox:SetupWireAutoSubject()
    if not SendMailMoneyGold then return end
    
    -- Check if already hooked to avoid rehooking error
    if not self.wireHooksInstalled then
        self:SecureHookScript(SendMailMoneyGold, "OnTextChanged", function()
            self:UpdateWireSubject()
        end)
        self:SecureHookScript(SendMailMoneySilver, "OnTextChanged", function()
            self:UpdateWireSubject()
        end)
        self:SecureHookScript(SendMailMoneyCopper, "OnTextChanged", function()
            self:UpdateWireSubject()
        end)
        self.wireHooksInstalled = true
    end
end

function Mailbox:UpdateWireSubject()
    if SendMailSubjectEditBox:GetText() ~= "" then return end
    
    local gold = tonumber(SendMailMoneyGold:GetText()) or 0
    local silver = tonumber(SendMailMoneySilver:GetText()) or 0
    local copper = tonumber(SendMailMoneyCopper:GetText()) or 0
    
    local total = gold * 10000 + silver * 100 + copper
    
    if total > 0 then
        SendMailSubjectEditBox:SetText(GetMoneyString(total))
    end
end

-- ============================================================================
-- DoNotWant Icons
-- ============================================================================

function Mailbox:CreateDoNotWantIcons()
    if not self.db.profile.doNotWantEnabled then return end
    
    for i = 1, 7 do
        local mailItem = _G["MailItem" .. i]
        if mailItem and not mailItem.doNotWantIcon then
            local icon = mailItem:CreateTexture(nil, "OVERLAY")
            icon:SetSize(16, 16)
            icon:SetPoint("RIGHT", mailItem, "RIGHT", -5, 0)
            mailItem.doNotWantIcon = icon
            
            self:UpdateDoNotWantIcon(i)
        end
    end
end

function Mailbox:UpdateDoNotWantIcon(index)
    local mailItem = _G["MailItem" .. index]
    if not mailItem or not mailItem.doNotWantIcon then return end
    
    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned = GetInboxHeaderInfo(index)
    
    if not daysLeft then
        mailItem.doNotWantIcon:Hide()
        return
    end
    
    if daysLeft <= 3 then
        if wasReturned then
            -- Will be deleted
            mailItem.doNotWantIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
            mailItem.doNotWantIcon:Show()
        else
            -- Will be returned
            mailItem.doNotWantIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Waiting")
            mailItem.doNotWantIcon:Show()
        end
    else
        mailItem.doNotWantIcon:Hide()
    end
end

-- ============================================================================
-- Select Checkboxes
-- ============================================================================

function Mailbox:CreateSelectCheckboxes()
    if not self.db.profile.selectEnabled then return end
    
    for i = 1, 7 do
        local mailItem = _G["MailItem" .. i]
        if mailItem and not mailItem.selectCheckbox then
            local checkbox = CreateFrame("CheckButton", "MidnightUI_MailSelectCheckbox" .. i, mailItem, "UICheckButtonTemplate")
            checkbox:SetSize(20, 20)
            checkbox:SetPoint("LEFT", mailItem, "LEFT", 5, 0)
            mailItem.selectCheckbox = checkbox
            
            -- Shift-Click to select range
            checkbox:SetScript("OnClick", function(cb)
                if IsShiftKeyDown() and self.lastSelectedCheckbox then
                    self:SelectCheckboxRange(self.lastSelectedCheckbox, i)
                elseif IsControlKeyDown() then
                    self:SelectAllFromSender(i)
                end
                self.lastSelectedCheckbox = i
            end)
        end
    end
    
    -- Add action buttons
    if not self.selectOpenButton then
        local openBtn = CreateFrame("Button", "MidnightUI_SelectOpenButton", InboxFrame, "UIPanelButtonTemplate")
        openBtn:SetSize(80, 22)
        openBtn:SetPoint("BOTTOMLEFT", InboxFrame, "BOTTOMLEFT", 20, 80)
        openBtn:SetText("Open")
        openBtn:SetScript("OnClick", function()
            self:OpenSelectedMail()
        end)
        self.selectOpenButton = openBtn
        
        local returnBtn = CreateFrame("Button", "MidnightUI_SelectReturnButton", InboxFrame, "UIPanelButtonTemplate")
        returnBtn:SetSize(80, 22)
        returnBtn:SetPoint("LEFT", openBtn, "RIGHT", 5, 0)
        returnBtn:SetText("Return")
        returnBtn:SetScript("OnClick", function()
            self:ReturnSelectedMail()
        end)
        self.selectReturnButton = returnBtn
    end
end

function Mailbox:SelectCheckboxRange(start, finish)
    local min, max = math.min(start, finish), math.max(start, finish)
    for i = min, max do
        local mailItem = _G["MailItem" .. i]
        if mailItem and mailItem.selectCheckbox then
            mailItem.selectCheckbox:SetChecked(true)
        end
    end
end

function Mailbox:SelectAllFromSender(index)
    local packageIcon, stationeryIcon, sender = GetInboxHeaderInfo(index)
    if not sender then return end
    
    local numItems = GetInboxNumItems()
    for i = 1, math.min(7, numItems) do
        local _, _, mailSender = GetInboxHeaderInfo(i)
        if mailSender == sender then
            local mailItem = _G["MailItem" .. i]
            if mailItem and mailItem.selectCheckbox then
                mailItem.selectCheckbox:SetChecked(true)
            end
        end
    end
end

function Mailbox:OpenSelectedMail()
    -- Implement opening selected mails
end

function Mailbox:ReturnSelectedMail()
    -- Implement returning selected mails
end

-- ============================================================================
-- QuickAttach Buttons
-- ============================================================================

function Mailbox:CreateQuickAttachButtons()
    if self.quickAttachButtons then return end
    
    local buttons = {}
    local tradeSkillTypes = {
        {name = "Ore", itemType = "Trade Goods", itemSubType = "Metal & Stone"},
        {name = "Herb", itemType = "Trade Goods", itemSubType = "Herbs"},
        {name = "Leather", itemType = "Trade Goods", itemSubType = "Leather"},
        {name = "Cloth", itemType = "Trade Goods", itemSubType = "Cloth"},
        {name = "Gems", itemType = "Gem"},
    }
    
    for i, tradeType in ipairs(tradeSkillTypes) do
        local button = CreateFrame("Button", "MidnightUI_QuickAttach" .. tradeType.name, SendMailFrame, "UIPanelButtonTemplate")
        button:SetSize(60, 22)
        button:SetPoint("TOPLEFT", SendMailFrame, "TOPLEFT", 20 + (i - 1) * 65, -120)
        button:SetText(tradeType.name)
        button:SetScript("OnClick", function()
            self:AttachTradeItems(tradeType)
        end)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        buttons[i] = button
    end
    
    self.quickAttachButtons = buttons
end

function Mailbox:AttachTradeItems(tradeType)
    -- Find and attach items of this type
    for bag = 0, 4 do
        if self.db.profile.quickAttachBags[bag + 1] then
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo then
                    -- Check if item matches type
                    -- Attach to mail
                end
            end
        end
    end
end

-- ============================================================================
-- TradeBlock
-- ============================================================================

function Mailbox:BlockTrades()
    if self.db.profile.blockTrades then
        SetCVar("blockTrades", 1)
    end
end

function Mailbox:UnblockTrades()
    SetCVar("blockTrades", 0)
end

-- ============================================================================
-- Options
-- ============================================================================

function Mailbox:GetOptions()
    return {
        name = "Mailbox",
        type = "group",
        args = {
            description = {
                type = "description",
                name = "Enhanced mailbox functionality with contact management, bulk operations, and shortcuts.",
                order = 1,
                fontSize = "medium",
            },
            spacer1 = {
                type = "description",
                name = " ",
                order = 2,
            },
            
            -- BlackBook
            blackBookHeader = {
                type = "header",
                name = "BlackBook (Contact List)",
                order = 10
            },
            blackBookEnabled = {
                type = "toggle",
                name = "Enable BlackBook",
                desc = "Add contact list next to To: field",
                order = 11,
                get = function() return self.db.profile.blackBookEnabled end,
                set = function(_, value)
                    self.db.profile.blackBookEnabled = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            trackAlts = {
                type = "toggle",
                name = "Track Alts",
                desc = "Automatically track your characters",
                order = 12,
                get = function() return self.db.profile.trackAlts end,
                set = function(_, value)
                    self.db.profile.trackAlts = value
                end,
                disabled = function() return not self:IsEnabled() or not self.db.profile.blackBookEnabled end,
            },
            autofillLastRecipient = {
                type = "toggle",
                name = "Autofill Last Recipient",
                desc = "Automatically fill in the last person mailed",
                order = 13,
                get = function() return self.db.profile.autofillLastRecipient end,
                set = function(_, value)
                    self.db.profile.autofillLastRecipient = value
                end,
                disabled = function() return not self:IsEnabled() or not self.db.profile.blackBookEnabled end,
            },
            disableBlizzardAutocomplete = {
                type = "toggle",
                name = "Disable Blizzard Autocomplete",
                desc = "Disable Blizzard's name auto-completion popup",
                order = 14,
                get = function() return self.db.profile.disableBlizzardAutocomplete end,
                set = function(_, value)
                    self.db.profile.disableBlizzardAutocomplete = value
                end,
                disabled = function() return not self:IsEnabled() or not self.db.profile.blackBookEnabled end,
            },
            
            -- OpenAll
            openAllHeader = {
                type = "header",
                name = "OpenAll (Bulk Operations)",
                order = 20
            },
            openAllEnabled = {
                type = "toggle",
                name = "Enable OpenAll",
                desc = "Add button to open all mail at once",
                order = 21,
                get = function() return self.db.profile.openAllEnabled end,
                set = function(_, value)
                    self.db.profile.openAllEnabled = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            keepFreeSlots = {
                type = "range",
                name = "Keep Free Bag Slots",
                desc = "Always keep this many bag slots free when opening mail",
                min = 0,
                max = 20,
                step = 1,
                order = 22,
                get = function() return self.db.profile.keepFreeSlots end,
                set = function(_, value)
                    self.db.profile.keepFreeSlots = value
                end,
                disabled = function() return not self:IsEnabled() or not self.db.profile.openAllEnabled end,
            },
            
            -- Express
            expressHeader = {
                type = "header",
                name = "Express (Shortcuts)",
                order = 30
            },
            expressEnabled = {
                type = "toggle",
                name = "Enable Express",
                desc = "Shift-Click to take, Ctrl-Click to return, Alt-Click to attach",
                order = 31,
                get = function() return self.db.profile.expressEnabled end,
                set = function(_, value)
                    self.db.profile.expressEnabled = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            
            -- Other features
            otherHeader = {
                type = "header",
                name = "Other Features",
                order = 40
            },
            carbonCopyEnabled = {
                type = "toggle",
                name = "Enable CarbonCopy",
                desc = "Copy contents of mail",
                order = 41,
                get = function() return self.db.profile.carbonCopyEnabled end,
                set = function(_, value)
                    self.db.profile.carbonCopyEnabled = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            doNotWantEnabled = {
                type = "toggle",
                name = "Enable DoNotWant",
                desc = "Show icons for expiring mail",
                order = 42,
                get = function() return self.db.profile.doNotWantEnabled end,
                set = function(_, value)
                    self.db.profile.doNotWantEnabled = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            wireEnabled = {
                type = "toggle",
                name = "Enable Wire",
                desc = "Auto-update subject with money amount",
                order = 43,
                get = function() return self.db.profile.wireEnabled end,
                set = function(_, value)
                    self.db.profile.wireEnabled = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            quickAttachEnabled = {
                type = "toggle",
                name = "Enable QuickAttach",
                desc = "Show Ore, Herb, Leather, Cloth, Gems buttons on send mail screen",
                order = 44,
                get = function() return self.db.profile.quickAttachEnabled end,
                set = function(_, value)
                    self.db.profile.quickAttachEnabled = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
            tradeBlockEnabled = {
                type = "toggle",
                name = "Enable TradeBlock",
                desc = "Block trades while at mailbox",
                order = 45,
                get = function() return self.db.profile.tradeBlockEnabled end,
                set = function(_, value)
                    self.db.profile.tradeBlockEnabled = value
                end,
                disabled = function() return not self:IsEnabled() end,
            },
        }
    }
end
