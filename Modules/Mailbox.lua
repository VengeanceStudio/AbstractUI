--[[
    AbstractUI Mailbox Module
    
    Enhanced mailbox functionality for WoW 12.0.1 Retail
    
    Features:
    - OpenAll: One-click mail collection with filters
    - BulkSelect: Checkbox selection for batch operations
    - AddressBook: Contact management & autocomplete
    - QuickSend: Modifier-click shortcuts  
    - EnhancedUI: UI improvements
    - CarbonCopy: Copy mail to clipboard
    - DoNotWant: Quick delete/return icons
    - Forward: Forward mail to others
    - QuickAttach: Category attachment buttons
    - Rake: Session gold tracking
    - TradeBlock: Block interruptions
    - MailBag: Grid view inbox (optional)
    - InboxBar: Filter status bar (optional)
]]

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local Mailbox = AbstractUI:NewModule("Mailbox", "AceEvent-3.0", "AceHook-3.0")

-- ============================================================================
-- DEFAULTS & INITIALIZATION
-- ============================================================================

local defaults = {
    profile = {
        -- OpenAll Settings
        openAll = {
            enabled = true,
            ahCancelled = true,
            ahExpired = true,
            ahOutbid = true,
            ahSuccess = true,
            ahWon = true,
            postmaster = true,
            attachments = true,
            keepFreeSpace = 1,
            openNewestFirst = false,
            speed = 0.5,
        },
        
        -- BulkSelect Settings
        bulkSelect = {
            enabled = true,
            keepFreeSpace = 1,
        },
        
        -- AddressBook Settings
        addressBook = {
            enabled = true,
            autoFill = true,
            autoCompleteAlts = true,
            autoCompleteAllAlts = true,
            autoCompleteRecent = true,
            autoCompleteContacts = true,
            autoCompleteFriends = false,
            autoCompleteGuild = false,
            useAutoComplete = true,
        },
        
        -- QuickSend Settings
        quickSend = {
            enabled = true,
            enableAltClick = true,
            autoSend = true,
            bulkSend = true,
        },
        
        -- EnhancedUI Settings
        enhancedUI = {
            enabled = true,
            longSubjectTooltip = true,
            autoSubjectMoney = true,
            closeSummary = true,
        },
        
        -- Feature Toggles
        carbonCopy = { enabled = true },
        doNotWant = { enabled = true },
        forward = { enabled = true },
        quickAttach = { 
            enabled = true,
            enableBags = {true, true, true, true, true, true}, -- 0-4 + reagent
        },
        rake = { enabled = true },
        tradeBlock = {
            enabled = true,
            blockTrades = true,
            blockPetitions = true,
        },
        mailBag = { 
            enabled = false,  -- Optional advanced feature
            groupStacks = true,
            qualityColors = false,
        },
        inboxBar = { enabled = false },  -- Optional status bar
    },
    global = {
        alts = {},  -- Character registry
        contacts = {},  -- Saved contacts
        recent = {},  -- Recent recipients by realm/faction
        quickAttachDefaults = {},  -- Default recipients by category
    }
}

function Mailbox:OnInitialize()
    -- Check if module is enabled in settings
    if not AbstractUI.db or not AbstractUI.db.profile or not AbstractUI.db.profile.modules or not AbstractUI.db.profile.modules.mailbox then
        self:Disable()
        return
    end
    
    self.db = AbstractUI.db:RegisterNamespace("Mailbox", defaults)
    
    -- Register current character as alt
    self:RegisterAlt()
    
    -- State tracking
    self.mailSession = {
        opened = false,
        goldSpent = 0,
        goldCollected = 0,
        goldMailCount = 0,
    }
    
    -- Module states
    self.openAllRunning = false
    self.bulkSelectRunning = false
    self.forwardAttachQueue = {}
end

function Mailbox:OnEnable()
    -- Check if module is enabled in settings
    if not AbstractUI.db or not AbstractUI.db.profile or not AbstractUI.db.profile.modules or not AbstractUI.db.profile.modules.mailbox then
        self:Disable()
        return
    end
    
    self:RegisterEvent("MAIL_SHOW")
    self:RegisterEvent("MAIL_CLOSED")
    self:RegisterEvent("MAIL_INBOX_UPDATE")
    
    -- Hook game functions (deferred to avoid taint)
    C_Timer.After(0, function()
        if not self:IsEnabled() then return end
        self:HookMailFunctions()
    end)
end

function Mailbox:OnDisable()
    self:UnhookAll()
    self:UnregisterAllEvents()
    
    -- Clean up any UI elements
    if self.openAllButton then self.openAllButton:Hide() end
    if self.bulkSelectFrames then
        for _, frame in pairs(self.bulkSelectFrames) do
            frame:Hide()
        end
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

function Mailbox:MAIL_SHOW()
    self.mailSession.opened = true
    self.mailSession.goldSpent = 0
    self.mailSession.goldCollected = 0
    self.mailSession.goldMailCount = 0
    
    -- Initialize active modules
    if self.db.profile.openAll.enabled then
        C_Timer.After(0.1, function() self:OpenAll_Initialize() end)
    end
    
    if self.db.profile.bulkSelect.enabled then
        C_Timer.After(0.1, function() self:BulkSelect_Initialize() end)
    end
    
    if self.db.profile.addressBook.enabled then
        C_Timer.After(0.1, function() self:AddressBook_Initialize() end)
    end
    
    if self.db.profile.enhancedUI.enabled then
        C_Timer.After(0.1, function() self:EnhancedUI_Initialize() end)
    end
    
    if self.db.profile.carbonCopy.enabled then
        C_Timer.After(0.1, function() self:CarbonCopy_Initialize() end)
    end
    
    if self.db.profile.doNotWant.enabled then
        C_Timer.After(0.1, function() self:DoNotWant_Initialize() end)
    end
    
    if self.db.profile.forward.enabled then
        C_Timer.After(0.1, function() self:Forward_Initialize() end)
    end
    
    if self.db.profile.quickAttach.enabled then
        C_Timer.After(0.1, function() self:QuickAttach_Initialize() end)
    end
    
    if self.db.profile.tradeBlock.enabled then
        self:TradeBlock_Apply()
    end
    
    if self.db.profile.mailBag.enabled then
        C_Timer.After(0.1, function() self:MailBag_Initialize() end)
    end
    
    if self.db.profile.inboxBar.enabled then
        C_Timer.After(0.1, function() self:InboxBar_Initialize() end)
    end
end

function Mailbox:MAIL_CLOSED()
    self.mailSession.opened = false
    
    -- Print session summary
    if self.db.profile.rake.enabled and (self.mailSession.goldCollected > 0 or self.mailSession.goldSpent > 0) then
        self:Rake_PrintSummary()
    end
    
    -- Restore trade/petition settings
    if self.db.profile.tradeBlock.enabled then
        self:TradeBlock_Restore()
    end
    
    -- Stop any running operations
    self.openAllRunning = false
    self.bulkSelectRunning = false
    
    -- Hide UI elements
    if self.mailBagFrame then
        self.mailBagFrame:Hide()
    end
end

function Mailbox:MAIL_INBOX_UPDATE()
    -- Update UI when inbox changes
    if self.db.profile.bulkSelect.enabled and self.bulkSelectFrames then
        C_Timer.After(0, function() self:BulkSelect_UpdateCheckboxes() end)
    end
    
    if self.db.profile.doNotWant.enabled then
        C_Timer.After(0, function() self:DoNotWant_UpdateIcons() end)
    end
    
    if self.db.profile.inboxBar.enabled and self.inboxBarFrame then
        C_Timer.After(0, function() self:InboxBar_Update() end)
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function Mailbox:GetCharKey()
    local player = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    return player .. " - " .. realm
end

function Mailbox:RegisterAlt()
    local key = self:GetCharKey()
    local _, class = UnitClass("player")
    local level = UnitLevel("player")
    local faction = UnitFactionGroup("player")
    
    self.db.global.alts[key] = {
        name = UnitName("player"),
        realm = GetRealmName(),
        class = class,
        level = level,
        faction = faction,
    }
end

function Mailbox:GetBagFreeSlots()
    local free = 0
    for bag = 0, 4 do
        free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
    end
    return free
end

function Mailbox:GetMailUID(index)
    -- Create stable fingerprint for mail tracking
    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(index)
    return string.format("%s:%s:%d:%d", sender or "", subject or "", money or 0, daysLeft or 0)
end

function Mailbox:IsSoulbound(bag, slot)
    -- Scan tooltip for binding text
    if not self.scanTooltip then
        self.scanTooltip = CreateFrame("GameTooltip", "MailboxScanTooltip", nil, "GameTooltipTemplate")
        self.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    
    self.scanTooltip:ClearLines()
    self.scanTooltip:SetBagItem(bag, slot)
    
    for i = 1, self.scanTooltip:NumLines() do
        local line = _G["MailboxScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and (text:find("Soulbound") or text:find("Bound to")) then
                return true
            end
        end
    end
    
    return false
end

function Mailbox:Print(...)
    local text = "|cff00ff00AbstractUI Mailbox:|r"
    for i = 1, select("#", ...) do
        text = text .. " " .. tostring(select(i, ...))
    end
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

-- ============================================================================
-- HOOK MAIL FUNCTIONS
-- ============================================================================

function Mailbox:HookMailFunctions()
    -- Hook for QuickSend inbox clicks
    if self.db.profile.quickSend.enabled then
        hooksecurefunc("InboxFrame_OnClick", function(self, index)
            if not Mailbox.db.profile.quickSend.enabled then return end
            Mailbox:QuickSend_HandleInboxClick(index)
        end)
    end
    
    -- Hook for Rake gold tracking
    if self.db.profile.rake.enabled then
        hooksecurefunc("TakeInboxMoney", function(index)
            if not Mailbox.db.profile.rake.enabled then return end
            Mailbox:Rake_TrackIncoming(index)
        end)
        
        hooksecurefunc("SendMail", function(recipient, subject, body)
            if not Mailbox.db.profile.rake.enabled then return end
            Mailbox:Rake_TrackOutgoing()
        end)
    end
    
    -- Hook InboxFrame_Update for UI modules
    hooksecurefunc("InboxFrame_Update", function()
        C_Timer.After(0, function()
            if Mailbox.db.profile.bulkSelect.enabled then
                Mailbox:BulkSelect_UpdateCheckboxes()
            end
            if Mailbox.db.profile.doNotWant.enabled then
                Mailbox:DoNotWant_UpdateIcons()
            end
        end)
    end)
    
    -- Hook OpenMail_Update for Forward button
    if self.db.profile.forward.enabled then
        hooksecurefunc("OpenMail_Update", function()
            C_Timer.After(0, function()
                if Mailbox.db.profile.forward.enabled and Mailbox.forwardButton then
                    Mailbox:Forward_UpdateButton()
                end
            end)
        end)
    end
end

-- ============================================================================
-- MODULE 1: OPEN ALL
-- ============================================================================

function Mailbox:OpenAll_Initialize()
    if self.openAllButton then
        self.openAllButton:Show()
        return
    end
    
    -- Create main button at bottom between Prev/Next
    local button = CreateFrame("Button", "AbstractUI_MailOpenAll", InboxFrame, "UIPanelButtonTemplate")
    button:SetSize(90, 22)
    button:SetPoint("BOTTOM", InboxFrame, "BOTTOM", -30, 105)
    button:SetText("Open All")
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            if IsShiftKeyDown() then
                Mailbox:OpenAll_Start(true)  -- Override filters
            else
                Mailbox:OpenAll_Start(false)
            end
        end
    end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Create filter menu button next to Open All
    local filterButton = CreateFrame("Button", nil, InboxFrame, "UIPanelButtonTemplate")
    filterButton:SetSize(22, 22)
    filterButton:SetPoint("LEFT", button, "RIGHT", 2, 0)
    filterButton:SetText("|cffffd700...|r")
    filterButton:SetScript("OnClick", function(self, btn)
        Mailbox:OpenAll_ShowFilterMenu(self)
    end)
    
    self.openAllButton = button
    self.openAllFilterButton = filterButton
    
    -- Hide Blizzard's button if it exists
    if OpenAllMail then
        OpenAllMail:Hide()
    end
end

function Mailbox:OpenAll_Start(override)
    if self.openAllRunning then
        self:Print("Collection already running")
        return
    end
    
    self.openAllRunning = true
    self.openAllIndex = 1
    self.openAllOverride = override
    
    self:OpenAll_ProcessNext()
end

function Mailbox:OpenAll_ProcessNext()
    if not self.openAllRunning then return end
    
    local numItems, totalItems = GetInboxNumItems()
    if numItems == 0 then
        self:OpenAll_Finish()
        return
    end
    
    -- Check bag space
    local free = self:GetBagFreeSlots()
    if free <= self.db.profile.openAll.keepFreeSpace then
        self:Print("Stopping - bag space limit reached")
        self:OpenAll_Finish()
        return
    end
    
    -- Find next valid mail
    local found = false
    for i = 1, numItems do
        if self:OpenAll_ShouldTake(i) then
            self.openAllIndex = i
            found = true
            break
        end
    end
    
    if not found then
        self:OpenAll_Finish()
        return
    end
    
    -- Take this mail
    local _, _, sender, subject, money, CODAmount, daysLeft, hasItem = GetInboxHeaderInfo(self.openAllIndex)
    
    -- Skip CoD and GM mail
    if CODAmount and CODAmount > 0 then
        self.openAllIndex = self.openAllIndex + 1
        C_Timer.After(0.1, function() self:OpenAll_ProcessNext() end)
        return
    end
    
    -- Take items and money
    if hasItem then
        AutoLootMailItem(self.openAllIndex)
    elseif money and money > 0 then
        TakeInboxMoney(self.openAllIndex)
    else
        -- Text-only mail, skip it
        self.openAllIndex = self.openAllIndex + 1
        C_Timer.After(0.1, function() self:OpenAll_ProcessNext() end)
        return
    end
    
    -- Continue processing
    C_Timer.After(self.db.profile.openAll.speed, function()
        self:OpenAll_ProcessNext()
    end)
end

function Mailbox:OpenAll_ShouldTake(index)
    if self.openAllOverride then return true end
    
    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem = GetInboxHeaderInfo(index)
    
    if not hasItem and (not money or money == 0) then return false end
    
    -- Check filters
    local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(index)
    
    if invoiceType then
        if invoiceType == "seller" and not self.db.profile.openAll.ahSuccess then return false end
        if invoiceType == "buyer" and not self.db.profile.openAll.ahWon then return false end
    end
    
    -- Check sender patterns
    sender = sender or ""
    if sender:find("Auction") or sender:find("Auctioneer") then
        if subject:find("Outbid") and not self.db.profile.openAll.ahOutbid then return false end
        if subject:find("Cancelled") and not self.db.profile.openAll.ahCancelled then return false end
        if subject:find("Expired") and not self.db.profile.openAll.ahExpired then return false end
    end
    
    if sender == "The Postmaster" and not self.db.profile.openAll.postmaster then return false end
    
    return true
end

function Mailbox:OpenAll_Finish()
    self.openAllRunning = false
    self:Print("Collection complete")
end

function Mailbox:OpenAll_ShowFilterMenu(button)
    local menu = CreateFrame("Frame", "MailboxFilterMenu", button, "UIDropDownMenuTemplate")
    
    local menuData = {
        {text = "AH Won", checked = function() return self.db.profile.openAll.ahWon end, func = function() self.db.profile.openAll.ahWon = not self.db.profile.openAll.ahWon end},
        {text = "AH Sold", checked = function() return self.db.profile.openAll.ahSuccess end, func = function() self.db.profile.openAll.ahSuccess = not self.db.profile.openAll.ahSuccess end},
        {text = "AH Outbid", checked = function() return self.db.profile.openAll.ahOutbid end, func = function() self.db.profile.openAll.ahOutbid = not self.db.profile.openAll.ahOutbid end},
        {text = "AH Cancelled", checked = function() return self.db.profile.openAll.ahCancelled end, func = function() self.db.profile.openAll.ahCancelled = not self.db.profile.openAll.ahCancelled end},
        {text = "AH Expired", checked = function() return self.db.profile.openAll.ahExpired end, func = function() self.db.profile.openAll.ahExpired = not self.db.profile.openAll.ahExpired end},
        {text = "Postmaster", checked = function() return self.db.profile.openAll.postmaster end, func = function() self.db.profile.openAll.postmaster = not self.db.profile.openAll.postmaster end},
    }
    
    EasyMenu(menuData, menu, "cursor", 0, 0, "MENU")
end

-- ============================================================================
-- MODULE 2: BULK SELECT
-- ============================================================================

function Mailbox:BulkSelect_Initialize()
    if self.bulkSelectFrames then
        for _, frame in pairs(self.bulkSelectFrames) do
            frame:Show()
        end
        self:BulkSelect_UpdateCheckboxes()
        return
    end
    
    self.bulkSelectFrames = {}
    self.bulkSelectChecked = {}
    
    -- Create checkboxes for each inbox slot
    for i = 1, 7 do
        local checkbox = CreateFrame("CheckButton", "MailboxBulkCheck" .. i, InboxFrame, "UICheckButtonTemplate")
        checkbox:SetSize(18, 18)
        checkbox:SetPoint("LEFT", "MailItem" .. i, "LEFT", -22, 0)
        checkbox:SetScript("OnClick", function(self) Mailbox:BulkSelect_OnCheckClick(i, self:GetChecked()) end)
        
        -- Add number text
        local text = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER", checkbox, "CENTER", 1, 0)
        text:SetText(i)
        
        self.bulkSelectFrames[i] = checkbox
    end
    
    -- Create action buttons at top
    local openButton = CreateFrame("Button", nil, InboxFrame, "UIPanelButtonTemplate")
    openButton:SetSize(109, 22)
    openButton:SetPoint("TOP", InboxFrame, "TOP", -80, -35)
    openButton:SetText("Open Selected")
    openButton:SetScript("OnClick", function() self:BulkSelect_OpenSelected() end)
    
    local returnButton = CreateFrame("Button", nil, InboxFrame, "UIPanelButtonTemplate")
    returnButton:SetSize(109, 22)
    returnButton:SetPoint("LEFT", openButton, "RIGHT", 5, 0)
    returnButton:SetText("Return Selected")
    returnButton:SetScript("OnClick", function() self:BulkSelect_ReturnSelected() end)
    
    self.bulkSelectOpenButton = openButton
    self.bulkSelectReturnButton = returnButton
end

function Mailbox:BulkSelect_OnCheckClick(index, checked)
    local uid = self:GetMailUID(index)
    if checked then
        self.bulkSelectChecked[uid] = index
    else
        self.bulkSelectChecked[uid] = nil
    end
end

function Mailbox:BulkSelect_UpdateCheckboxes()
    if not self.bulkSelectFrames then return end
    
    local numItems = GetInboxNumItems()
    for i = 1, 7 do
        if i <= numItems then
            self.bulkSelectFrames[i]:Show()
            
            -- Restore check state
            local uid = self:GetMailUID(i)
            if self.bulkSelectChecked[uid] then
                self.bulkSelectFrames[i]:SetChecked(true)
            else
                self.bulkSelectFrames[i]:SetChecked(false)
            end
        else
            self.bulkSelectFrames[i]:Hide()
        end
    end
end

function Mailbox:BulkSelect_OpenSelected()
    if self.bulkSelectRunning then return end
    
    self.bulkSelectRunning = true
    self.bulkSelectQueue = {}
    
    -- Build queue
    for uid, index in pairs(self.bulkSelectChecked) do
        table.insert(self.bulkSelectQueue, index)
    end
    
    if #self.bulkSelectQueue == 0 then
        self:Print("No mail selected")
        self.bulkSelectRunning = false
        return
    end
    
    self:BulkSelect_ProcessQueue("open")
end

function Mailbox:BulkSelect_ReturnSelected()
    if self.bulkSelectRunning then return end
    
    self.bulkSelectRunning = true
    self.bulkSelectQueue = {}
    
    -- Build queue
    for uid, index in pairs(self.bulkSelectChecked) do
        table.insert(self.bulkSelectQueue, index)
    end
    
    if #self.bulkSelectQueue == 0 then
        self:Print("No mail selected")
        self.bulkSelectRunning = false
        return
    end
    
    self:BulkSelect_ProcessQueue("return")
end

function Mailbox:BulkSelect_ProcessQueue(mode)
    if not self.bulkSelectRunning or #self.bulkSelectQueue == 0 then
        self.bulkSelectRunning = false
        self.bulkSelectChecked = {}
        self:BulkSelect_UpdateCheckboxes()
        self:Print("Batch operation complete")
        return
    end
    
    local index = table.remove(self.bulkSelectQueue, 1)
    
    if mode == "open" then
        local hasItem = select(8, GetInboxHeaderInfo(index))
        if hasItem then
            AutoLootMailItem(index)
        end
    elseif mode == "return" then
        ReturnInboxItem(index)
    end
    
    C_Timer.After(0.5, function()
        self:BulkSelect_ProcessQueue(mode)
    end)
end

-- ============================================================================
-- MODULE 3: ADDRESS BOOK
-- ============================================================================

function Mailbox:AddressBook_Initialize()
    -- Hook send mail editbox for autocomplete
    if not self:IsHooked(SendMailNameEditBox, "OnChar") then
        SendMailNameEditBox:HookScript("OnChar", function(self)
            C_Timer.After(0, function()
                Mailbox:AddressBook_HandleAutoComplete()
            end)
        end)
    end
    
    -- Hook for autofill on tab open
    if not self:IsHooked("SendMailFrame_Reset") then
        hooksecurefunc("SendMailFrame_Reset", function()
            C_Timer.After(0, function()
                if Mailbox.db.profile.addressBook.autoFill then
                    Mailbox:AddressBook_AutoFill()
                end
            end)
        end)
    end
    
    -- Create dropdown button
    if not self.addressBookButton then
        local button = CreateFrame("Button", nil, SendMailFrame, "UIPanelButtonTemplate")
        button:SetSize(25, 25)
        button:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", 2, 0)
        button:SetText("▼")
        button:SetScript("OnClick", function(self)
            Mailbox:AddressBook_ShowMenu(self)
        end)
        
        self.addressBookButton = button
    end
end

function Mailbox:AddressBook_HandleAutoComplete()
    if not self.db.profile.addressBook.useAutoComplete then return end
    
    local text = SendMailNameEditBox:GetText()
    if not text or text == "" then return end
    
    -- Build match list
    local matches = {}
    
    -- Search alts
    if self.db.profile.addressBook.autoCompleteAlts then
        for key, alt in pairs(self.db.global.alts) do
            if alt.name:lower():find(text:lower(), 1, true) then
                table.insert(matches, {name = alt.name, source = "Alt"})
            end
        end
    end
    
    -- Search recent
    if self.db.profile.addressBook.autoCompleteRecent then
        local recentList = self.db.global.recent[GetRealmName()] or {}
        for _, name in ipairs(recentList) do
            if name:lower():find(text:lower(), 1, true) then
                table.insert(matches, {name = name, source = "Recent"})
            end
        end
    end
    
    -- Search friends
    if self.db.profile.addressBook.autoCompleteFriends then
        for i = 1, C_FriendList.GetNumFriends() do
            local friend = C_FriendList.GetFriendInfoByIndex(i)
            if friend and friend.name:lower():find(text:lower(), 1, true) then
                table.insert(matches, {name = friend.name, source = "Friend"})
            end
        end
    end
    
    -- Show matches (simple implementation)
    if #matches > 0 and #matches < 10 then
        -- For now, just auto-complete first match if it's exact
        for _, match in ipairs(matches) do
            if match.name:lower() == text:lower() then
                SendMailNameEditBox:SetText(match.name)
                break
            end
        end
    end
end

function Mailbox:AddressBook_AutoFill()
    local recentList = self.db.global.recent[GetRealmName()] or {}
    if #recentList > 0 then
        SendMailNameEditBox:SetText(recentList[1])
    end
end

function Mailbox:AddressBook_ShowMenu(button)
    local menu = CreateFrame("Frame", "MailboxAddressMenu", button, "UIDropDownMenuTemplate")
    
    local menuData = {}
    
    -- Add alts
    table.insert(menuData, {text = "Alts", isTitle = true})
    for key, alt in pairs(self.db.global.alts) do
        table.insert(menuData, {
            text = alt.name,
            func = function()
                SendMailNameEditBox:SetText(alt.name)
            end
        })
    end
    
    -- Add recent
    local recentList = self.db.global.recent[GetRealmName()] or {}
    if #recentList > 0 then
        table.insert(menuData, {text = "Recent", isTitle = true})
        for _, name in ipairs(recentList) do
            table.insert(menuData, {
                text = name,
                func = function()
                    SendMailNameEditBox:SetText(name)
                end
            })
        end
    end
    
    EasyMenu(menuData, menu, "cursor", 0, 0, "MENU")
end

function Mailbox:TrackRecent(name)
    if not name or name == "" then return end
    
    local realm = GetRealmName()
    if not self.db.global.recent[realm] then
        self.db.global.recent[realm] = {}
    end
    
    -- Remove if exists
    for i, n in ipairs(self.db.global.recent[realm]) do
        if n == name then
            table.remove(self.db.global.recent[realm], i)
            break
        end
    end
    
    -- Insert at front
    table.insert(self.db.global.recent[realm], 1, name)
    
    -- Limit to 20
    while #self.db.global.recent[realm] > 20 do
        table.remove(self.db.global.recent[realm])
    end
end

-- ============================================================================
-- MODULE 4: QUICK SEND
-- ============================================================================

function Mailbox:QuickSend_HandleInboxClick(index)
    if IsShiftKeyDown() then
        -- Shift-click to auto-loot
        local hasItem = select(8, GetInboxHeaderInfo(index))
        local money = select(5, GetInboxHeaderInfo(index))
        local COD = select(6, GetInboxHeaderInfo(index))
        
        if COD and COD > 0 then return end  -- Skip CoD
        
        if hasItem then
            AutoLootMailItem(index)
        elseif money and money > 0 then
            TakeInboxMoney(index)
        end
    elseif IsControlKeyDown() then
        -- Ctrl-click to return
        ReturnInboxItem(index)
    end
end

-- ============================================================================
-- MODULE 5: ENHANCED UI
-- ============================================================================

function Mailbox:EnhancedUI_Initialize()
    -- Hook money editbox for auto-subject
    if self.db.profile.enhancedUI.autoSubjectMoney and not self:IsHooked(SendMailMoneyGold, "OnTextChanged") then
        SendMailMoneyGold:HookScript("OnTextChanged", function()
            C_Timer.After(0, function()
                Mailbox:EnhancedUI_UpdateMoneySubject()
            end)
        end)
    end
    
    -- Hook for long subject tooltips
    if self.db.profile.enhancedUI.longSubjectTooltip then
        for i = 1, 7 do
            local item = _G["MailItem" .. i]
            if item and not self:IsHooked(item, "OnEnter") then
                item:HookScript("OnEnter", function(self)
                    local index = self.index
                    if index then
                        local subject = select(4, GetInboxHeaderInfo(index))
                        if subject and #subject > 30 then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetText(subject, 1, 1, 1, 1, true)
                            GameTooltip:Show()
                        end
                    end
                end)
                
                item:HookScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
            end
        end
    end
end

function Mailbox:EnhancedUI_UpdateMoneySubject()
    local gold = tonumber(SendMailMoneyGold:GetText()) or 0
    local silver = tonumber(SendMailMoneySilver:GetText()) or 0
    local copper = tonumber(SendMailMoneyCopper:GetText()) or 0
    
    if gold > 0 or silver > 0 or copper > 0 then
        local subject = ""
        if gold > 0 then subject = subject .. gold .. "g " end
        if silver > 0 then subject = subject .. silver .. "s " end
        if copper > 0 then subject = subject .. copper .. "c" end
        
        SendMailSubjectEditBox:SetText(subject:trim())
    end
end

-- ============================================================================
-- MODULE 6: CARBON COPY
-- ============================================================================

function Mailbox:CarbonCopy_Initialize()
    if self.carbonCopyButton then
        self.carbonCopyButton:Show()
        return
    end
    
    -- Create copy button on open mail frame
    local button = CreateFrame("Button", nil, OpenMailFrame, "UIPanelButtonTemplate")
    button:SetSize(60, 22)
    button:SetPoint("TOPRIGHT", OpenMailFrame, "TOPRIGHT", -40, -30)
    button:SetText("Copy")
    button:SetScript("OnClick", function()
        Mailbox:CarbonCopy_ShowFrame()
    end)
    
    self.carbonCopyButton = button
    
    -- Hook to show/hide based on mail content
    hooksecurefunc("OpenMail_Update", function()
        C_Timer.After(0, function()
            if OpenMailFrame:IsShown() and Mailbox.carbonCopyButton then
                local bodyText = OpenMailBodyText:GetText()
                if bodyText and bodyText ~= "" then
                    Mailbox.carbonCopyButton:Show()
                else
                    Mailbox.carbonCopyButton:Hide()
                end
            end
        end)
    end)
end

function Mailbox:CarbonCopy_ShowFrame()
    if not self.carbonCopyFrame then
        local frame = CreateFrame("Frame", "MailboxCopyFrame", UIParent, "BackdropTemplate")
        frame:SetSize(420, 320)
        frame:SetPoint("CENTER")
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = {left = 11, right = 12, top = 12, bottom = 11}
        })
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        
        -- Close button
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
        
        -- Scroll frame
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -30)
        scroll:SetPoint("BOTTOMRIGHT", -30, 20)
        
        -- Edit box
        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(360)
        editBox:SetAutoFocus(true)
        editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
        
        scroll:SetScrollChild(editBox)
        
        frame.editBox = editBox
        self.carbonCopyFrame = frame
    end
    
    -- Build mail text
    local mailID = InboxFrame.openMailID
    if not mailID then return end
    
    local _, _, sender, subject = GetInboxHeaderInfo(mailID)
    local bodyText = OpenMailBodyText:GetText() or ""
    
    local text = "From: " .. (sender or "Unknown") .. "\n"
    text = text .. "Subject: " .. (subject or "(No Subject)") .. "\n\n"
    text = text .. bodyText
    
    self.carbonCopyFrame.editBox:SetText(text)
    self.carbonCopyFrame.editBox:HighlightText()
    self.carbonCopyFrame:Show()
end

-- ============================================================================
-- MODULE 7: DO NOT WANT
-- ============================================================================

function Mailbox:DoNotWant_Initialize()
    if self.doNotWantIcons then
        for _, icon in pairs(self.doNotWantIcons) do
            icon:Show()
        end
        self:DoNotWant_UpdateIcons()
        return
    end
    
    self.doNotWantIcons = {}
    
    for i = 1, 7 do
        local icon = CreateFrame("Button", nil, _G["MailItem" .. i])
        icon:SetSize(14, 14)
        icon:SetPoint("TOPRIGHT", "MailItem" .. i, "TOPRIGHT", -5, -25)
        icon:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        icon:SetScript("OnClick", function(self)
            Mailbox:DoNotWant_OnIconClick(i)
        end)
        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Delete/Return", 1, 1, 1)
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        self.doNotWantIcons[i] = icon
    end
end

function Mailbox:DoNotWant_UpdateIcons()
    if not self.doNotWantIcons then return end
    
    local numItems = GetInboxNumItems()
    for i = 1, 7 do
        if i <= numItems then
            local wasReturned = select(10, GetInboxHeaderInfo(i))
            if wasReturned then
                self.doNotWantIcons[i]:Show()
            else
                self.doNotWantIcons[i]:Hide()
            end
        else
            self.doNotWantIcons[i]:Hide()
        end
    end
end

function Mailbox:DoNotWant_OnIconClick(index)
    local wasReturned = select(10, GetInboxHeaderInfo(index))
    
    StaticPopup_Show("MAILBOX_DELETE_CONFIRM", index)
end

StaticPopupDialogs["MAILBOX_DELETE_CONFIRM"] = {
    text = "Delete this mail?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, index)
        DeleteInboxItem(index)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- ============================================================================
-- MODULE 8: FORWARD
-- ============================================================================

function Mailbox:Forward_Initialize()
    if self.forwardButton then
        self.forwardButton:Show()
        return
    end
    
    local button = CreateFrame("Button", nil, OpenMailFrame, "UIPanelButtonTemplate")
    button:SetSize(82, 22)
    button:SetPoint("RIGHT", OpenMailReplyButton, "LEFT", -2, 0)
    button:SetText("Forward")
    button:SetScript("OnClick", function()
        Mailbox:Forward_DoForward()
    end)
    
    self.forwardButton = button
end

function Mailbox:Forward_UpdateButton()
    if not self.forwardButton then return end
    
    local mailID = InboxFrame.openMailID
    if not mailID then
        self.forwardButton:Disable()
        return
    end
    
    local money = select(5, GetInboxHeaderInfo(mailID))
    local COD = select(6, GetInboxHeaderInfo(mailID))
    
    -- Can't forward money or CoD
    if (money and money > 0) or (COD and COD > 0) then
        self.forwardButton:Disable()
        return
    end
    
    self.forwardButton:Enable()
end

function Mailbox:Forward_DoForward()
    local mailID = InboxFrame.openMailID
    if not mailID then return end
    
    -- Switch to send tab
    MailFrameTab_OnClick(nil, 2)
    
    -- Copy subject with FW: prefix
    local subject = select(4, GetInboxHeaderInfo(mailID))
    if subject then
        if not subject:find("^FW:") then
            subject = "FW: " .. subject
        end
        SendMailSubjectEditBox:SetText(subject)
    end
    
    -- Copy body
    local bodyText = OpenMailBodyText:GetText()
    if bodyText then
        SendMailBodyEditBox:SetText(bodyText)
    end
    
    -- Queue attachments
    self.forwardAttachQueue = {}
    for i = 1, ATTACHMENTS_MAX_RECEIVE do
        local name, itemTexture, count = GetInboxItem(mailID, i)
        if name then
            table.insert(self.forwardAttachQueue, {mailID = mailID, index = i})
        end
    end
    
    -- Couldn't forward feature because items need to be in bags
    -- This is a WoW limitation - must be manually handled
    self:Print("Mail content copied. You'll need to manually attach items from your bags.")
end

-- ============================================================================
-- MODULE 9: QUICK ATTACH
-- ============================================================================

function Mailbox:QuickAttach_Initialize()
    if self.quickAttachButtons then
        for _, button in pairs(self.quickAttachButtons) do
            button:Show()
        end
        return
    end
    
    self.quickAttachButtons = {}
    
    -- Category data: classID, subclassID, icon, name
    local categories = {
        {5, 0, 4305420, "Cloth"},              -- Cloth
        {7, 6, 134366, "Leather/Hide"},        -- Leather
        {7, 7, 134567, "Metal/Stone"},         -- Metal & Stone
        {7, 5, 133971, "Cooking"},             -- Meat / Cooking
        {7, 9, 134192, "Herbs"},               -- Herb
        {7, 12, 132858, "Enchanting"},         -- Enchanting
        {7, 16, 237171, "Inscription"},        -- Inscription
        {7, 4, 134071, "Jewelcrafting"},       -- Jewelcrafting
        {7, 1, 136243, "Parts"},               -- Parts
        {7, 10, 134437, "Elemental"},          -- Elemental
        {7, 18, 4620673, "Optional Reagents"}, -- Optional Reagents
        {7, 19, 4620676, "Finishing Reagents"},-- Finishing Reagents
        {7, 0, 134939, "Other Trade"},         -- Other Trade Goods
        {nil, nil, 132763, "All Trade"},       -- All trade goods
    }
    
    for i, cat in ipairs(categories) do
        local button = CreateFrame("Button", nil, SendMailFrame)
        button:SetSize(30, 30)
        button:SetPoint("TOPLEFT", SendMailFrame, "TOPRIGHT", 5, -40 - ((i - 1) * 32))
        button:SetNormalTexture(cat[3])
        button:SetScript("OnClick", function(self, btn)
            if btn == "LeftButton" then
                Mailbox:QuickAttach_AttachByCategory(cat[1], cat[2])
            elseif btn == "RightButton" then
                Mailbox:QuickAttach_SetDefaultRecipient(i, cat[4])
            end
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(cat[4], 1, 1, 1)
            local def = Mailbox.db.global.quickAttachDefaults[i]
            if def then
                GameTooltip:AddLine("Default: " .. def, 0.5, 1, 0.5)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        button.categoryIndex = i
        button.classID = cat[1]
        button.subID = cat[2]
        
        self.quickAttachButtons[i] = button
    end
end

function Mailbox:QuickAttach_AttachByCategory(classID, subID)
    local attached = 0
    
    for bag = 0, 5 do
        if self.db.profile.quickAttach.enableBags[bag + 1] then
            local numSlots = C_Container.GetContainerNumSlots(bag)
            if numSlots then
                for slot = 1, numSlots do
                    local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                    if itemInfo and itemInfo.itemID then
                        local itemClassID = select(6, C_Item.GetItemInfoInstant(itemInfo.itemID))
                        local itemSubClassID = select(7, C_Item.GetItemInfoInstant(itemInfo.itemID))
                        
                        -- Check if matches category
                        local matches = false
                        if classID == nil then
                            -- All trade goods
                            matches = (itemClassID == 7)
                        else
                            matches = (itemClassID == classID and (subID == nil or subID == 0 or itemSubClassID == subID))
                        end
                        
                        if matches and not self:IsSoulbound(bag, slot) and not itemInfo.isLocked then
                            C_Container.PickupContainerItem(bag, slot)
                            ClickSendMailItemButton()
                            attached = attached + 1
                            
                            if attached >= ATTACHMENTS_MAX_SEND then
                                return
                            end
                        end
                    end
                end
            end
        end
    end
    
    if attached > 0 then
        self:Print("Attached " .. attached .. " items")
    else
        self:Print("No items found in that category")
    end
end

function Mailbox:QuickAttach_SetDefaultRecipient(categoryIndex, categoryName)
    StaticPopup_Show("MAILBOX_QUICKATTACH_RECIPIENT", categoryName, nil, categoryIndex)
end

StaticPopupDialogs["MAILBOX_QUICKATTACH_RECIPIENT"] = {
    text = "Set default recipient for %s:",
    button1 = "Set",
    button2 = "Cancel",
    hasEditBox = true,
    OnAccept = function(self, categoryIndex)
        local text = self.editBox:GetText()
        Mailbox.db.global.quickAttachDefaults[categoryIndex] = text
        Mailbox:Print("Default recipient set")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- ============================================================================
-- MODULE 10: RAKE (Gold Tracking)
-- ============================================================================

function Mailbox:Rake_TrackIncoming(index)
    local money = select(5, GetInboxHeaderInfo(index))
    if money and money > 0 then
        self.mailSession.goldCollected = self.mailSession.goldCollected + money
        self.mailSession.goldMailCount = self.mailSession.goldMailCount + 1
    end
end

function Mailbox:Rake_TrackOutgoing()
    local gold = tonumber(SendMailMoneyGold:GetText()) or 0
    local silver = tonumber(SendMailMoneySilver:GetText()) or 0
    local copper = tonumber(SendMailMoneyCopper:GetText()) or 0
    
    local total = (gold * 10000) + (silver * 100) + copper
    self.mailSession.goldSpent = self.mailSession.goldSpent + total
end

function Mailbox:Rake_PrintSummary()
    if self.mailSession.goldCollected > 0 then
        local gold = math.floor(self.mailSession.goldCollected / 10000)
        local silver = math.floor((self.mailSession.goldCollected % 10000) / 100)
        local copper = self.mailSession.goldCollected % 100
        
        self:Print(string.format("Collected: %dg %ds %dc from %d mail(s)", gold, silver, copper, self.mailSession.goldMailCount))
    end
    
    if self.mailSession.goldSpent > 0 then
        local gold = math.floor(self.mailSession.goldSpent / 10000)
        local silver = math.floor((self.mailSession.goldSpent % 10000) / 100)
        local copper = self.mailSession.goldSpent % 100
        
        self:Print(string.format("Sent: %dg %ds %dc", gold, silver, copper))
    end
end

-- ============================================================================
-- MODULE 11: TRADE BLOCK
-- ============================================================================

function Mailbox:TradeBlock_Apply()
    -- Save original states
    self.tradeBlockOriginalTrades = C_CVar.GetCVar("BlockTrades")
    self.tradeBlockOriginalPetitions = PetitionFrame:IsEventRegistered("PETITION_SHOW")
    
    -- Apply blocks
    if self.db.profile.tradeBlock.blockTrades then
        C_CVar.SetCVar("BlockTrades", "1")
    end
    
    if self.db.profile.tradeBlock.blockPetitions then
        PetitionFrame:UnregisterEvent("PETITION_SHOW")
    end
end

function Mailbox:TradeBlock_Restore()
    -- Restore original states
    if self.tradeBlockOriginalTrades then
        C_CVar.SetCVar("BlockTrades", self.tradeBlockOriginalTrades)
    end
    
    if self.tradeBlockOriginalPetitions then
        PetitionFrame:RegisterEvent("PETITION_SHOW")
    end
end

-- ============================================================================
-- MODULE 12: MAIL BAG (Optional - Grid View)
-- ============================================================================

function Mailbox:MailBag_Initialize()
    -- This is a complex optional feature
    -- For now, we'll leave it as a placeholder
    -- Can be implemented later if needed
    self:Print("MailBag grid view not yet implemented")
end

-- ============================================================================
-- MODULE 13: INBOX BAR (Optional - Status Bar)
-- ============================================================================

function Mailbox:InboxBar_Initialize()
    -- This is an optional status bar feature
    -- Can be implemented later if needed
    self:Print("InboxBar status display not yet implemented")
end

function Mailbox:InboxBar_Update()
    -- Update status bar when inbox changes
end

-- ============================================================================
-- OPTIONS/CONFIGURATION
-- ============================================================================

function Mailbox:GetOptions()
    return {
        type = "group",
        name = "Mailbox",
        args = {
            openAll = {
                type = "group",
                name = "Open All",
                order = 1,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enable Open All",
                        order = 1,
                        get = function() return self.db.profile.openAll.enabled end,
                        set = function(_, v) self.db.profile.openAll.enabled = v end,
                    },
                    speed = {
                        type = "range",
                        name = "Collection Speed (seconds)",
                        order = 2,
                        min = 0.1,
                        max = 2.0,
                        step = 0.1,
                        get = function() return self.db.profile.openAll.speed end,
                        set = function(_, v) self.db.profile.openAll.speed = v end,
                    },
                    keepFreeSpace = {
                        type = "range",
                        name = "Keep Free Bag Slots",
                        order = 3,
                        min = 0,
                        max = 20,
                        step = 1,
                        get = function() return self.db.profile.openAll.keepFreeSpace end,
                        set = function(_, v) self.db.profile.openAll.keepFreeSpace = v end,
                    },
                },
            },
            bulkSelect = {
                type = "group",
                name = "Bulk Select",
                order = 2,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enable Bulk Select",
                        order = 1,
                        get = function() return self.db.profile.bulkSelect.enabled end,
                        set = function(_, v) self.db.profile.bulkSelect.enabled = v end,
                    },
                },
            },
            addressBook = {
                type = "group",
                name = "Address Book",
                order = 3,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enable Address Book",
                        order = 1,
                        get = function() return self.db.profile.addressBook.enabled end,
                        set = function(_, v) self.db.profile.addressBook.enabled = v end,
                    },
                    autoFill = {
                        type = "toggle",
                        name = "Auto-fill Last Recipient",
                        order = 2,
                        get = function() return self.db.profile.addressBook.autoFill end,
                        set = function(_, v) self.db.profile.addressBook.autoFill = v end,
                    },
                },
            },
            quickSend = {
                type = "group",
                name = "Quick Send",
                order = 4,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enable Quick Send",
                        order = 1,
                        get = function() return self.db.profile.quickSend.enabled end,
                        set = function(_, v) self.db.profile.quickSend.enabled = v end,
                    },
                },
            },
            features = {
                type = "group",
                name = "Other Features",
                order = 5,
                args = {
                    carbonCopy = {
                        type = "toggle",
                        name = "Carbon Copy (Copy Mail)",
                        order = 1,
                        get = function() return self.db.profile.carbonCopy.enabled end,
                        set = function(_, v) self.db.profile.carbonCopy.enabled = v end,
                    },
                    doNotWant = {
                        type = "toggle",
                        name = "Do Not Want (Delete Icons)",
                        order = 2,
                        get = function() return self.db.profile.doNotWant.enabled end,
                        set = function(_, v) self.db.profile.doNotWant.enabled = v end,
                    },
                    forward = {
                        type = "toggle",
                        name = "Forward Mail",
                        order = 3,
                        get = function() return self.db.profile.forward.enabled end,
                        set = function(_, v) self.db.profile.forward.enabled = v end,
                    },
                    quickAttach = {
                        type = "toggle",
                        name = "Quick Attach (Category Buttons)",
                        order = 4,
                        get = function() return self.db.profile.quickAttach.enabled end,
                        set = function(_, v) self.db.profile.quickAttach.enabled = v end,
                    },
                    rake = {
                        type = "toggle",
                        name = "Rake (Gold Tracking)",
                        order = 5,
                        get = function() return self.db.profile.rake.enabled end,
                        set = function(_, v) self.db.profile.rake.enabled = v end,
                    },
                    tradeBlock = {
                        type = "toggle",
                        name = "Trade Block (Block Interruptions)",
                        order = 6,
                        get = function() return self.db.profile.tradeBlock.enabled end,
                        set = function(_, v) self.db.profile.tradeBlock.enabled = v end,
                    },
                },
            },
        },
    }
end

return Mailbox
