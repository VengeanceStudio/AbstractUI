-- ============================================================================
-- Macro Icon Selector Module
-- ============================================================================
-- Enhanced macro icon selection with search and filtering
-- Integrated from LargerMacroIconSelection addon
-- ============================================================================

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local MacroIconSelector = AbstractUI:NewModule("MacroIconSelector", "AceEvent-3.0")

-- Module setup
MacroIconSelector.isMainline = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
MacroIconSelector.isMop = (WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC)
MacroIconSelector.isTBC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
MacroIconSelector.isVanilla = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)

-- Remove custom/duplicate icons from icon packs until Blizzard fixes their non-FileDataID icon support
GetLooseMacroItemIcons = function() end
GetLooseMacroIcons = function() end

MacroIconSelector.loadedFrames = {}
MacroIconSelector.searchIcons = {}

local defaults = {
    profile = {
        enabled = true,
    }
}

-- ============================================================================
-- MODULE LIFECYCLE
-- ============================================================================

function MacroIconSelector:OnInitialize()
    print("|cff00FF7FAbstractUI MacroIconSelector:|r OnInitialize called")
    self:RegisterMessage("AbstractUI_DB_READY", "OnDBReady")
    print("|cff00FF7FAbstractUI MacroIconSelector:|r Registered for DB_READY message")
end

function MacroIconSelector:OnDBReady()
    print("|cff00FF7FAbstractUI MacroIconSelector:|r OnDBReady called")
    print("  Module enabled:", AbstractUI.db.profile.modules.macroIconSelector)
    
    if not AbstractUI.db.profile.modules.macroIconSelector then 
        print("|cffFF6B6BAbstractUI MacroIconSelector:|r Module disabled, exiting")
        self:Disable()
        return 
    end
    
    print("|cff00FF7FAbstractUI MacroIconSelector:|r Module is enabled, continuing initialization")
    
    self.db = AbstractUI.db:RegisterNamespace("MacroIconSelector", defaults)
    
    -- Add slash command for manual scanning
    SLASH_ABSTRACTUI_ICONSCAN1 = "/iconscan"
    SlashCmdList["ABSTRACTUI_ICONSCAN"] = function(msg)
        if msg == "start" then
            if MacroIconSelector.startScanning then
                MacroIconSelector.startScanning()
            end
        elseif msg == "stop" then
            if MacroIconSelector.stopScanning then
                MacroIconSelector.stopScanning()
            end
        elseif msg == "bank" then
            print("|cff00FF7FAbstractUI MacroIconSelector:|r Manual bank check:")
            print("  BankFrame exists:", BankFrame ~= nil)
            if BankFrame then
                print("  BankFrame.BankPanel exists:", BankFrame.BankPanel ~= nil)
                if BankFrame.BankPanel then
                    print("  TabSettingsMenu exists:", BankFrame.BankPanel.TabSettingsMenu ~= nil)
                    if BankFrame.BankPanel.TabSettingsMenu then
                        print("  Attempting to initialize TabSettingsMenu now...")
                        MacroIconSelector:Initialize(BankFrame.BankPanel.TabSettingsMenu)
                    end
                end
            end
            print("  Blizzard_BankUI loaded:", C_AddOns.IsAddOnLoaded("Blizzard_BankUI"))
        else
            print("|cff00FF7FAbstractUI MacroIconSelector:|r Usage:")
            print("  /iconscan start - Start scanning")
            print("  /iconscan stop - Stop scanning")
            print("  /iconscan bank - Check bank frame and force init (open bank first)")
        end
    end
    
    if not self.isVanilla and not self.isTBC then
        self:Initialize(GearManagerPopupFrame)
    end
    if self.isMainline then
        -- Hook into frame creation to detect icon pickers as they're created
        -- Use hooksecurefunc on CreateFrame to catch new frames
        local OriginalCreateFrame = CreateFrame
        local function CheckForIconPicker(frame)
            if frame and not self.loadedFrames[frame] then
                C_Timer.After(0.2, function()
                    if frame and (frame.IconPicker or frame.BorderBox) and frame.IconSelector then
                        self:Initialize(frame)
                    end
                end)
            end
        end
    end
    
    EventUtil.ContinueOnAddOnLoaded("Blizzard_MacroUI", function()
        -- Only the macro popup frame seems affected when it is user placed
        if MacroPopupFrame:IsUserPlaced() then
            print("|cff00FF7FAbstractUI:|r Macro Icon Selector requires a /reload to fix the MacroPopupFrame.")
            MacroPopupFrame:SetUserPlaced(false)
        end
        self:Initialize(MacroPopupFrame)
    end)
    
    EventUtil.ContinueOnAddOnLoaded("Blizzard_GuildBankUI", function()
        if GuildBankPopupFrame.BorderBox then
            self:Initialize(GuildBankPopupFrame)
        end
    end)
    
    -- Add support for regular bank icon picker (personal bank tabs)
    local function InitializeBankIconPickers()
        local initialized = false
        
        print("|cff00FF7FAbstractUI MacroIconSelector:|r Checking bank icon pickers...")
        
        if BankFrame and BankFrame.BankPanel then
            print("  BankFrame.BankPanel exists")
            -- Check if TabSettingsMenu already exists
            if BankFrame.BankPanel.TabSettingsMenu then
                print("  TabSettingsMenu exists immediately, initializing")
                self:Initialize(BankFrame.BankPanel.TabSettingsMenu)
                initialized = true
                
                -- Hook Show to re-initialize if needed
                hooksecurefunc(BankFrame.BankPanel.TabSettingsMenu, "Show", function()
                    print("  TabSettingsMenu Show hook fired!")
                    if not self.loadedFrames[BankFrame.BankPanel.TabSettingsMenu] then
                        print("  Not loaded yet, initializing now")
                        self:Initialize(BankFrame.BankPanel.TabSettingsMenu)
                    else
                        print("  Already loaded, skipping")
                    end
                end)
            else
                print("  TabSettingsMenu doesn't exist yet, setting up detection")
                -- TabSettingsMenu doesn't exist yet, hook its creation
                -- Monitor BankPanel for when TabSettingsMenu gets added
                local checkTimer
                local function CheckForTabSettingsMenu()
                    if BankFrame.BankPanel.TabSettingsMenu then
                        print("  TabSettingsMenu appeared!")
                        if checkTimer then
                            checkTimer:Cancel()
                            checkTimer = nil
                        end
                        
                        -- Hook the Show event immediately
                        hooksecurefunc(BankFrame.BankPanel.TabSettingsMenu, "Show", function()
                            print("  TabSettingsMenu Show hook fired (delayed detection)!")
                            if not self.loadedFrames[BankFrame.BankPanel.TabSettingsMenu] then
                                print("  Initializing from delayed Show hook")
                                self:Initialize(BankFrame.BankPanel.TabSettingsMenu)
                            end
                        end)
                        
                        -- If it's already visible, initialize now
                        if BankFrame.BankPanel.TabSettingsMenu:IsVisible() then
                            print("  TabSettingsMenu is already visible, initializing immediately")
                            self:Initialize(BankFrame.BankPanel.TabSettingsMenu)
                        end
                    end
                end
                
                -- Check immediately and then every 0.5s for up to 10 seconds
                CheckForTabSettingsMenu()
                local attempts = 0
                checkTimer = C_Timer.NewTicker(0.5, function()
                    CheckForTabSettingsMenu()
                    attempts = attempts + 1
                    if attempts >= 20 then
                        print("  Gave up waiting for TabSettingsMenu after 10 seconds")
                        checkTimer:Cancel()
                    end
                end)
            end
            
            -- Also hook ShowTabSettingsMenu if it exists (for vanilla behavior)
            if BankFrame.BankPanel.ShowTabSettingsMenu then
                print("  Found ShowTabSettingsMenu function, hooking it")
                hooksecurefunc(BankFrame.BankPanel, "ShowTabSettingsMenu", function()
                    print("  ShowTabSettingsMenu function called!")
                    C_Timer.After(0.1, function()
                        if BankFrame.BankPanel.TabSettingsMenu and not self.loadedFrames[BankFrame.BankPanel.TabSettingsMenu] then
                            print("  Initializing from ShowTabSettingsMenu hook")
                            self:Initialize(BankFrame.BankPanel.TabSettingsMenu)
                        end
                    end)
                end)
            end
        end
        
        -- Same for AccountBankPanel (warband bank)
        if BankFrame and BankFrame.AccountBankPanel then
            if BankFrame.AccountBankPanel.TabSettingsMenu then
                self:Initialize(BankFrame.AccountBankPanel.TabSettingsMenu)
                initialized = true
                
                hooksecurefunc(BankFrame.AccountBankPanel.TabSettingsMenu, "Show", function()
                    if not self.loadedFrames[BankFrame.AccountBankPanel.TabSettingsMenu] then
                        self:Initialize(BankFrame.AccountBankPanel.TabSettingsMenu)
                    end
                end)
            end
            
            if BankFrame.AccountBankPanel.ShowTabSettingsMenu then
                hooksecurefunc(BankFrame.AccountBankPanel, "ShowTabSettingsMenu", function()
                    C_Timer.After(0.1, function()
                        if BankFrame.AccountBankPanel.TabSettingsMenu and not self.loadedFrames[BankFrame.AccountBankPanel.TabSettingsMenu] then
                            self:Initialize(BankFrame.AccountBankPanel.TabSettingsMenu)
                        end
                    end)
                end)
            end
        end
        
        return initialized
    end
    
    -- Check if already loaded
    print("|cff00FF7FAbstractUI MacroIconSelector:|r Checking for bank frames...")
    print("  Blizzard_BankUI addon loaded:", C_AddOns.IsAddOnLoaded("Blizzard_BankUI"))
    print("  BankFrame exists:", BankFrame ~= nil)
    
    if BankFrame then
        print("  BankFrame exists, initializing immediately")
        InitializeBankIconPickers()
    else
        print("  BankFrame doesn't exist yet, will check when bank opens")
        -- BankFrame doesn't exist yet - poll for it to appear
        local checkCount = 0
        local checkTimer
        checkTimer = C_Timer.NewTicker(1, function()
            checkCount = checkCount + 1
            if BankFrame then
                print("|cff00FF7FAbstractUI MacroIconSelector:|r BankFrame detected after", checkCount, "seconds")
                if checkTimer then
                    checkTimer:Cancel()
                end
                InitializeBankIconPickers()
            elseif checkCount >= 60 then
                print("|cffFF6B6BAbstractUI MacroIconSelector:|r Gave up waiting for BankFrame after 60 seconds")
                if checkTimer then
                    checkTimer:Cancel()
                end
            end
        end)
    end
    
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Transmog", function()
        self:Initialize(TransmogFrame.OutfitPopup)
    end)
    
    if self.isMainline then
        EventUtil.ContinueOnAddOnLoaded("Baganator", function()
            print("|cff00FF7FAbstractUI MacroIconSelector:|r Baganator loaded, setting up hooks")
            
            -- Method 1: Use Baganator's skin listener API
            Baganator.API.Skins.RegisterListener(function(details)
                if details.regionType == "ButtonFrame" then
                    if details.tags and tIndexOf(details.tags, "bank") ~= nil then
                        if details.region.Character and details.region.Character.TabSettingsMenu then
                            print("  Baganator skin listener: Found Character TabSettingsMenu")
                            self:Initialize(details.region.Character.TabSettingsMenu)
                        end
                        if details.region.Warband and details.region.Warband.TabSettingsMenu then
                            print("  Baganator skin listener: Found Warband TabSettingsMenu")
                            self:Initialize(details.region.Warband.TabSettingsMenu)
                        end
                    end
                end
            end)
            
            -- Method 2: Directly search for Baganator bank frames by name
            -- Baganator creates frames like "Baganator_CategoryViewBankViewFrame1" or "Baganator_SingleViewBankViewFrame1"
            local baganatorFramesInitialized = false
            local function InitializeBaganatorBankFrames()
                if baganatorFramesInitialized then return end
                
                -- Scan for Baganator bank frames (they use "blizzard" as frame group suffix)
                local viewTypes = {"CategoryView", "SingleView"}
                local frameGroups = {"blizzard", "1", "2", ""}
                
                for _, viewType in ipairs(viewTypes) do
                    for _, group in ipairs(frameGroups) do
                        local frameName = "Baganator_" .. viewType .. "BankViewFrame" .. group
                        local bankFrame = _G[frameName]
                        
                        if bankFrame then
                            -- Check Character tab (personal bank tabs)
                            if bankFrame.Character and bankFrame.Character.TabSettingsMenu and not self.loadedFrames[bankFrame.Character.TabSettingsMenu] then
                                self:Initialize(bankFrame.Character.TabSettingsMenu)
                            end
                            
                            -- Check Warband tab
                            if bankFrame.Warband and bankFrame.Warband.TabSettingsMenu and not self.loadedFrames[bankFrame.Warband.TabSettingsMenu] then
                                self:Initialize(bankFrame.Warband.TabSettingsMenu)
                            end
                        end
                    end
                end
                
                baganatorFramesInitialized = true
            end
            
            -- Try immediately
            InitializeBaganatorBankFrames()
            
            -- Also set up a delayed check in case frames aren't created yet
            C_Timer.After(2, InitializeBaganatorBankFrames)
            
            -- Listen for bank open event to check one more time
            local eventFrame = CreateFrame("Frame")
            eventFrame:RegisterEvent("BANKFRAME_OPENED")
            eventFrame:SetScript("OnEvent", function(_, event)
                if event == "BANKFRAME_OPENED" then
                    C_Timer.After(0.1, InitializeBaganatorBankFrames)
                end
            end)
        end)
    end
    
    EventUtil.ContinueOnAddOnLoaded("Bagnon", function()
        if self.isMainline then
            RunNextFrame(function()
                self:Initialize(Bagnon.BankBag.Settings)
            end)
        end
    end)
    
    print("|cff00FF7FAbstractUI MacroIconSelector:|r OnDBReady completed successfully")
end

function MacroIconSelector:OnEnable()
    if not self.db then return end
end

function MacroIconSelector:OnDisable()
end

function MacroIconSelector:FindAndInitializeBankIconPicker()
    -- Try to find the bank icon picker by checking known frame names
    local possibleFrames = {
        "BankItemAutoSortButton",
        "BankFrameTab1",
        "BankFrameTab2",
    }
    
    -- Check if BankFrame has panels with icon pickers
    if BankFrame and BankFrame.BankPanel then
        local panel = BankFrame.BankPanel
        -- Look through children for frames with IconPicker
        for i = 1, panel:GetNumChildren() do
            local child = select(i, panel:GetChildren())
            if child and child.IconPicker and child.IconSelector then
                local name = child:GetName() or "UnnamedBankIconPicker"
                if not self.loadedFrames[child] then
                    self:Initialize(child)
                    return true
                end
            end
        end
    end
    
    -- Also check top-level frames
    for i = 1, UIParent:GetNumChildren() do
        local child = select(i, UIParent:GetChildren())
        if child and child.IconPicker and child.IconSelector and not self.loadedFrames[child] then
            local name = child:GetName()
            if name and (name:match("Bank") or name:match("Tab")) then
                self:Initialize(child)
                return true
            end
        end
    end
    
    return false
end

-- ============================================================================
-- ICON DATA PROVIDER
-- ============================================================================

local QuestionMarkIconFileDataID = 134400
local NumActiveIconDataProviders = 0
local BaseIconFilenames = nil

-- Builds the table BaseIconFilenames with known spells followed by all icons
local function IconDataProvider_RefreshIconTextures()
    if BaseIconFilenames ~= nil then
        return
    end

    BaseIconFilenames = {}
    BaseIconFilenames[IconDataProviderIconType.Spell] = {}
    BaseIconFilenames[IconDataProviderIconType.Item] = {}
    GetLooseMacroIcons(BaseIconFilenames[IconDataProviderIconType.Spell])
    GetLooseMacroItemIcons(BaseIconFilenames[IconDataProviderIconType.Item])
    GetMacroIcons(BaseIconFilenames[IconDataProviderIconType.Spell])
    GetMacroItemIcons(BaseIconFilenames[IconDataProviderIconType.Item])
end

local function IconDataProvider_ClearIconTextures()
    BaseIconFilenames = nil
    collectgarbage()
end

local function IconDataProvider_GetBaseIconTexture(iconType, index)
    local texture = BaseIconFilenames[iconType][index]
    local fileDataID = tonumber(texture)
    if fileDataID ~= nil then
        return fileDataID
    elseif texture then
        return [[INTERFACE\ICONS\]]..texture
    end
end

IconDataProviderLmisMixin = {}

local function FillOutExtraIconsMapWithSpells(extraIconsMap)
    for skillLineIndex = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)
        if skillLineInfo then
            for i = 1, skillLineInfo.numSpellBookItems do
                local spellIndex = skillLineInfo.itemIndexOffset + i
                local spellType, ID = C_SpellBook.GetSpellBookItemType(spellIndex, Enum.SpellBookSpellBank.Player)
                if spellType ~= "FUTURESPELL" then
                    local fileID = C_SpellBook.GetSpellBookItemTexture(spellIndex, Enum.SpellBookSpellBank.Player)
                    if fileID ~= nil then
                        extraIconsMap[fileID] = true
                    end
                end

                if spellType == "FLYOUT" then
                    local _, _, numSlots, isKnown = GetFlyoutInfo(ID)
                    if isKnown and (numSlots > 0) then
                        for k = 1, numSlots do
                            local spellID, overrideSpellID, isSlotKnown = GetFlyoutSlotInfo(ID, k)
                            if isSlotKnown then
                                local fileID = C_Spell.GetSpellTexture(spellID)
                                if fileID ~= nil then
                                    extraIconsMap[fileID] = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function FillOutExtraIconsMapWithTalents(extraIconsMap)
    local isInspect = false
    for specIndex = 1, GetNumSpecGroups(isInspect) do
        for tier = 1, MAX_TALENT_TIERS do
            for column = 1, NUM_TALENT_COLUMNS do
                local talentInfoQuery = {}
                talentInfoQuery.tier = tier
                talentInfoQuery.column = column
                talentInfoQuery.specializationIndex = specIndex
                local talentInfo = C_SpecializationInfo.GetTalentInfo(talentInfoQuery)
                if talentInfo and talentInfo.icon then
                    extraIconsMap[talentInfo.icon] = true
                end
            end
        end
    end

    for pvpTalentSlot = 1, 3 do
        local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(pvpTalentSlot)
        if slotInfo ~= nil then
            for i, pvpTalentID in ipairs(slotInfo.availableTalentIDs) do
                local icon = select(3, GetPvpTalentInfoByID(pvpTalentID))
                if icon ~= nil then
                    extraIconsMap[icon] = true
                end
            end
        end
    end
end

local function FillOutExtraIconsMapWithEquipment(extraIconsMap)
    for i = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local itemTexture = GetInventoryItemTexture("player", i)
        if itemTexture ~= nil then
            extraIconsMap[itemTexture] = true
        end
    end
end

function IconDataProviderLmisMixin:Init(type, extraIconsOnly, requestedIconTypes)
    self.extraIcons = {}
    self.extraIconType = type
    self.requestedIconTypes = requestedIconTypes or IconDataProvider_GetAllIconTypes()

    if type == IconDataProviderExtraType.Spellbook then
        local extraIconsMap = {}
        FillOutExtraIconsMapWithSpells(extraIconsMap)
        FillOutExtraIconsMapWithTalents(extraIconsMap)
        self.extraIcons = GetKeysArray(extraIconsMap)
    elseif type == IconDataProviderExtraType.Equipment then
        local extraIconsMap = {}
        FillOutExtraIconsMapWithEquipment(extraIconsMap)
        self.extraIcons = GetKeysArray(extraIconsMap)
    end

    if not extraIconsOnly then
        NumActiveIconDataProviders = NumActiveIconDataProviders + 1
        IconDataProvider_RefreshIconTextures()
    end
end

function IconDataProviderLmisMixin:SetIconTypes(iconTypes)
    self.requestedIconTypes = iconTypes or IconDataProvider_GetAllIconTypes()
end

function IconDataProviderLmisMixin:GetNumIcons()
    local numIcons = 1
    if self:ShouldShowExtraIcons() then
        numIcons = numIcons + #self.extraIcons
    end
    if BaseIconFilenames then
        for _, v in pairs(self.requestedIconTypes) do
            numIcons = numIcons + #BaseIconFilenames[v]
        end
    end
    return numIcons
end

function IconDataProviderLmisMixin:GetIconByIndex(index)
    if index == 1 then
        return [[INTERFACE\ICONS\INV_MISC_QUESTIONMARK]]
    end

    index = index - 1

    local numExtraIcons = self:ShouldShowExtraIcons() and #self.extraIcons or 0
    if index <= numExtraIcons then
        return self.extraIcons[index]
    end

    local baseIndex = index - numExtraIcons
    local lookupIconType = nil
    for _, v in pairs(self.requestedIconTypes) do
        local numIconsForType = #BaseIconFilenames[v]
        if baseIndex <= numIconsForType then
            lookupIconType = v
            break
        end
        baseIndex = baseIndex - numIconsForType
    end

    if lookupIconType then
        return IconDataProvider_GetBaseIconTexture(lookupIconType, baseIndex)
    else
        return nil
    end
end

function IconDataProviderLmisMixin:GetIconForSaving(index)
    local icon = self:GetIconByIndex(index)
    if type(icon) == "string" then
        icon = string.gsub(icon, [[INTERFACE\ICONS\]], "")
    end
    return icon
end

function IconDataProviderLmisMixin:GetIndexOfIcon(icon)
    if icon == QuestionMarkIconFileDataID then
        return 1
    end

    local numIcons = self:GetNumIcons()
    for i = 1, numIcons do
        if self:GetIconByIndex(i) == icon then
            return i
        end
    end

    return nil
end

function IconDataProviderLmisMixin:ShouldShowExtraIcons()
    return (self.extraIconType == IconDataProviderExtraType.Spellbook and tContains(self.requestedIconTypes, IconDataProviderIconType.Spell)) or 
           (self.extraIconType == IconDataProviderExtraType.Equipment and tContains(self.requestedIconTypes, IconDataProviderIconType.Item))
end

function IconDataProviderLmisMixin:Release()
    NumActiveIconDataProviders = NumActiveIconDataProviders - 1
    if NumActiveIconDataProviders <= 0 then
        IconDataProvider_ClearIconTextures()
    end
end

function IconDataProviderLmisMixin:SetIconData(icons)
    BaseIconFilenames[IconDataProviderIconType.Spell] = icons
    BaseIconFilenames[IconDataProviderIconType.Item] = icons
end

-- ============================================================================
-- SEARCH FUNCTIONALITY
-- ============================================================================

local LibAIS = LibStub("LibAdvancedIconSelector-1.0-LMIS")
local LibAIS_options = {
    sectionOrder = {"FileDataIcons"},
}

-- Load IconFileNames data on demand
function MacroIconSelector:LoadIconFileData()
    if not self.FileData then
        -- Icon data will be loaded from the external data folder
        if _G.LargerMacroIconSelectionData then
            self.FileData = _G.LargerMacroIconSelectionData:GetFileData()
        else
            self.FileData = {}
            print("|cffFF6B6BAbstractUI:|r Icon data not found. Icon names will not be available.")
        end
    end
end

function MacroIconSelector:CreateSearchBox(popup)
    -- Skip if search box already exists
    if popup.SearchBox then
        print("|cff00FF7FAbstractUI MacroIconSelector:|r Search box already exists, skipping")
        return
    end
    
    -- Determine the frame structure (different for bank frames vs macro frames)
    local isBankFrame = (popup.IconPicker ~= nil)
    local okayButton, cancelButton, iconSelectorEditBox, borderBox
    
    if isBankFrame then
        -- Bank frame structure: uses IconPicker instead of BorderBox
        if not popup.IconPicker then return end
        borderBox = popup.IconPicker
        iconSelectorEditBox = popup.IconPicker.IconSelectorEditBox
        
        -- Find the Okay and Cancel buttons - they should be children of the popup
        local children = {popup:GetChildren()}
        for i, child in ipairs(children) do
            if child:IsObjectType("Button") then
                local text = child:GetText()
                if text then
                    -- Check for Okay button (various localizations)
                    if text:find("Okay") or text == OKAY or text:find("OK") then
                        okayButton = child
                    -- Check for Cancel button
                    elseif text:find("Cancel") or text == CANCEL then
                        cancelButton = child
                    end
                end
            end
        end
        
        -- Fallback: find buttons by name
        if not okayButton then
            okayButton = popup.OkayButton or popup.Okay or _G[popup:GetName().."OkayButton"]
        end
        if not cancelButton then
            cancelButton = popup.CancelButton or popup.Cancel or _G[popup:GetName().."CancelButton"]
        end
    else
        -- Standard structure (macro frame, guild bank, etc.)
        if not popup.BorderBox or not popup.BorderBox.OkayButton then return end
        borderBox = popup.BorderBox
        okayButton = popup.BorderBox.OkayButton
        cancelButton = popup.BorderBox.CancelButton
        iconSelectorEditBox = popup.BorderBox.IconSelectorEditBox
    end
    
    -- Must have at least an okay button to position the search box
    if not okayButton then return end
    
    local sb = CreateFrame("EditBox", "$parentSearchBox", popup, "InputBoxTemplate")
    sb:SetPoint("BOTTOMLEFT", 74, 15)
    sb:SetPoint("RIGHT", okayButton, "LEFT", -5, 0)
    sb:SetHeight(15)
    sb:SetFrameLevel((borderBox:GetFrameLevel() or 1) + 1)
    
    sb.searchLabel = sb:CreateFontString()
    sb.searchLabel:SetPoint("RIGHT", sb, "LEFT", -8, 0)
    sb.searchLabel:SetFontObject("GameFontNormal")
    sb.searchLabel:SetText(SEARCH..":")
    
    sb.linkLabel = sb:CreateFontString()
    sb.linkLabel:SetPoint("RIGHT", okayButton, "LEFT", -5, -1)
    sb.linkLabel:SetFontObject("GameFontNormal")
    sb.linkLabel:SetTextColor(.62, .62, .62)
    
    sb:SetScript("OnTextChanged", function(self, userInput)
        MacroIconSelector:SearchBox_OnTextChanged(self, userInput)
    end)
    
    sb:SetScript("OnEscapePressed", function()
        if iconSelectorEditBox then
            iconSelectorEditBox:SetFocus()
        end
    end)
    
    sb:SetScript("OnEnterPressed", function()
        if iconSelectorEditBox then
            iconSelectorEditBox:SetFocus()
        end
    end)
    
    sb.spinner = CreateFrame("Frame", nil, sb, "LoadingSpinnerTemplate")
    sb.spinner:SetPoint("RIGHT")
    sb.spinner:SetSize(24, 24)
    sb.spinner:Hide()
    
    popup:HookScript("OnHide", function()
        self:ClearSearch(popup)
        sb:SetText("")
        sb:SetTextColor(1, 1, 1)
        sb.linkLabel:SetText()
    end)
    
    -- Support shift-clicking links to the search box
    hooksecurefunc("ChatEdit_InsertLink", function(text)
        if text and sb:IsVisible() then
            sb:SetText(strmatch(text, "H(%l+:%d+)") or "")
            RunNextFrame(function() StackSplitFrame:Hide() end)
        end
    end)
    
    sb.popup = popup
    popup.SearchBox = sb
end

function MacroIconSelector:InitSearch()
    if not self.searchObject then
        self.searchObject = LibAIS:CreateSearch(LibAIS_options)
        
        self.searchObject:SetScript("OnSearchStarted", function()
            wipe(self.searchIcons)
            if self.activeSearch then
                self.activeSearch.SearchBox.spinner:Show()
            end
        end)
        
        self.searchObject:SetScript("OnSearchResultAdded", function(_self, texture, _, _, _, fdid)
            tinsert(self.searchIcons, fdid)
        end)
        
        self.searchObject:SetScript("OnSearchComplete", function()
            local popup = self.activeSearch
            if popup then
                if not popup:IsShown() then return end
                if #self.searchIcons == 0 then
                    popup.SearchBox:SetTextColor(1, 0, 0)
                else
                    popup.SearchBox:SetTextColor(1, 1, 1)
                    self:SetSearchData(popup)
                    self:UpdatePopup(popup)
                end
                self.activeSearch = nil
                popup.SearchBox.spinner:Hide()
            end
        end)
    end
end

function MacroIconSelector:ClearSearch(popup)
    self.activeSearch = nil
    wipe(self.searchIcons)
    if self.searchObject then
        self.searchObject:Stop()
    end
    if popup.SearchBox then
        popup.SearchBox.spinner:Hide()
    end
end

function MacroIconSelector:SetSearchData(popup)
    -- Hack because "All Icons" shows everything double
    local iconTypeDropdown
    if popup.IconPicker and popup.IconPicker.IconTypeDropdown then
        iconTypeDropdown = popup.IconPicker.IconTypeDropdown
    elseif popup.BorderBox and popup.BorderBox.IconTypeDropdown then
        iconTypeDropdown = popup.BorderBox.IconTypeDropdown
    end
    
    if iconTypeDropdown then
        iconTypeDropdown:Increment()
        iconTypeDropdown:Increment()
    else -- cata/vanilla
        local iconTypeDropDown
        if popup.IconPicker and popup.IconPicker.IconTypeDropDown then
            iconTypeDropDown = popup.IconPicker.IconTypeDropDown
        elseif popup.BorderBox and popup.BorderBox.IconTypeDropDown then
            iconTypeDropDown = popup.BorderBox.IconTypeDropDown
        end
        
        if iconTypeDropDown then
            iconTypeDropDown:SetSelectedValue(IconSelectorPopupFrameIconFilterTypes.Item)
            iconTypeDropDown:SetSelectedValue(IconSelectorPopupFrameIconFilterTypes.Spell)
        end
    end

    wipe(popup.iconDataProvider.extraIcons)
    popup.iconDataProvider:SetIconData(self.searchIcons)
end

function MacroIconSelector:SearchBox_OnTextChanged(sb, userInput)
    local popup = sb.popup
    local text = sb:GetText()
    local isNumber = tonumber(text)
    
    if isNumber or strfind(text, "[:=]") then -- Search by spell/item/achievement id
        local link, id = text:lower():match("(%a+)[:=](%d+)")
        local fileID
        self:ClearSearch(popup)
        
        if isNumber or link == "filedata" and id then
            fileID = isNumber or tonumber(id)
        elseif link == "spell" and id then
            local spell = C_Spell.GetSpellInfo(id)
            if spell then
                fileID = spell.iconID
            end
        elseif link == "item" and id then
            fileID = select(5, C_Item.GetItemInfoInstant(id))
        elseif link == "achievement" and id then
            fileID = select(10, GetAchievementInfo(id))
        end
        
        if self.FileData and self.FileData[fileID] then
            self.activeSearch = popup
            self.searchIcons[1] = fileID
            sb:SetTextColor(1, 1, 1)
            sb.linkLabel:SetText(self.FileData[fileID])
            
            -- More hacks so the searched icon doesn't show double
            local iconTypeDropdown
            if popup.IconPicker and popup.IconPicker.IconTypeDropdown then
                iconTypeDropdown = popup.IconPicker.IconTypeDropdown
            elseif popup.BorderBox and popup.BorderBox.IconTypeDropdown then
                iconTypeDropdown = popup.BorderBox.IconTypeDropdown
            end
            
            if iconTypeDropdown then
                iconTypeDropdown:Decrement()
                iconTypeDropdown:Increment()
            end
            
            self:SetSearchData(popup)
            self:UpdatePopup(popup)
        else
            sb:SetTextColor(1, 0, 0)
            sb.linkLabel:SetText()
        end
    else
        sb:SetTextColor(1, 1, 1)
        sb.linkLabel:SetText()
        
        if #text > 0 then -- Search by texture name
            if self.searchObject then
                self.searchObject:SetSearchParameter(text)
                self.activeSearch = popup
            end
        else
            self:ClearSearch(popup)
            self:UpdateIconSelector(popup)
        end
    end
end

-- ============================================================================
-- POPUP FRAME MANAGEMENT
-- ============================================================================

local ProviderTypes = {
    MacroPopupFrame = IconDataProviderExtraType.Spell,
    GearManagerPopupFrame = IconDataProviderExtraType.Equipment,
}

function MacroIconSelector:Initialize(popup)
    if not popup then return end
    
    popup:HookScript("OnShow", function()
        if not self.loadedFrames[popup] then
            self.loadedFrames[popup] = true
        else
            self:UpdateIconSelector(popup)
            return
        end
        
        popup:HookScript("OnHide", function()
            if popup.iconDataProvider then
                popup.iconDataProvider:Release()
            end
        end)
        
        self:LoadIconFileData()
        self:InitSearch()
        
        if popup ~= MacroPopupFrame then
            self:SetFrameMovable(popup)
        end
        
        self:CreateSearchBox(popup)
        self:CreateIconTooltip(popup)
        self:UpdateIconSelector(popup)
    end)
    
    -- If frame is already visible (e.g., with Baganator), trigger setup immediately
    if popup:IsVisible() then
        print("|cff00FF7FAbstractUI MacroIconSelector:|r Frame is already visible, triggering setup immediately")
        if not self.loadedFrames[popup] then
            self.loadedFrames[popup] = true
            
            popup:HookScript("OnHide", function()
                if popup.iconDataProvider then
                    popup.iconDataProvider:Release()
                end
            end)
            
            self:LoadIconFileData()
            self:InitSearch()
            
            if popup ~= MacroPopupFrame then
                self:SetFrameMovable(popup)
            end
            
            self:CreateSearchBox(popup)
            self:CreateIconTooltip(popup)
            self:UpdateIconSelector(popup)
        end
    end
end

function MacroIconSelector:SetFrameMovable(popup)
    popup:SetMovable(true)
    popup:SetClampedToScreen(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", function()
        popup:StartMoving()
        popup:SetUserPlaced(false)
    end)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
end

function MacroIconSelector:CreateIconTooltip(popup)
    -- Handle icon selector scroll box
    if popup.IconSelector and popup.IconSelector.ScrollBox then
        for _, btn in pairs(popup.IconSelector.ScrollBox:GetFrames()) do
            btn:HookScript("OnEnter", function(self)
                MacroIconSelector:ShowTooltip(self)
            end)
            btn:HookScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
    end
    
    -- Handle selected icon button - different structure for bank vs macro frames
    local selectedIconButton
    if popup.IconPicker and popup.IconPicker.SelectedIconArea then
        -- Bank frame structure
        selectedIconButton = popup.IconPicker.SelectedIconArea.SelectedIconButton
    elseif popup.BorderBox and popup.BorderBox.SelectedIconArea then
        -- Macro frame structure
        selectedIconButton = popup.BorderBox.SelectedIconArea.SelectedIconButton
    end
    
    if selectedIconButton then
        selectedIconButton:HookScript("OnEnter", function(btn)
            local fileid = btn:GetIconTexture()
            MacroIconSelector:SetIconTooltip(btn, function()
                if fileid ~= 134400 then
                    GameTooltip:AddLine(format("|cff71D5FF%s|r", fileid))
                    if MacroIconSelector.FileData and MacroIconSelector.FileData[fileid] then
                        GameTooltip:AddLine(MacroIconSelector.FileData[fileid], 1, 1, 1)
                    end
                end
            end)
        end)
    end
end

function MacroIconSelector:ShowTooltip(btn)
    local idx = btn:GetSelectionIndex()
    local fileid = btn:GetSelection()
    local isValid = (type(fileid) == "number")
    
    self:SetIconTooltip(btn, function()
        GameTooltip:AddLine(isValid and format("%s |cff71D5FF%s|r", idx, fileid) or idx)
        if idx == 1 then
            GameTooltip:AddLine("inv_misc_questionmark", 1, 1, 1)
        else
            GameTooltip:AddLine(isValid and self.FileData and self.FileData[fileid] or fileid, 1, 1, 1)
        end
    end)
end

function MacroIconSelector:SetIconTooltip(parent, func)
    GameTooltip:SetOwner(parent, "ANCHOR_TOPLEFT")
    func()
    GameTooltip:Show()
end

function MacroIconSelector:UpdateIconSelector(popup)
    if popup.iconDataProvider then
        popup.iconDataProvider:Release()
    end
    popup.iconDataProvider = CreateAndInitFromMixin(IconDataProviderLmisMixin, ProviderTypes[popup:GetName()])
    self:UpdatePopup(popup)
end

function MacroIconSelector:UpdatePopup(popup)
    -- Handle both bank frame and macro frame structures
    local iconSelectorEditBox, selectedIconButton
    
    if popup.IconPicker then
        -- Bank frame structure
        iconSelectorEditBox = popup.IconPicker.IconSelectorEditBox
        if popup.IconPicker.SelectedIconArea then
            selectedIconButton = popup.IconPicker.SelectedIconArea.SelectedIconButton
        end
    elseif popup.BorderBox then
        -- Macro frame structure
        iconSelectorEditBox = popup.BorderBox.IconSelectorEditBox
        if popup.BorderBox.SelectedIconArea then
            selectedIconButton = popup.BorderBox.SelectedIconArea.SelectedIconButton
        end
    end
    
    local text = iconSelectorEditBox and iconSelectorEditBox:GetText() or ""
    local selectedIcon = selectedIconButton and selectedIconButton:GetIconTexture()
    
    popup.Update(popup)
    
    if iconSelectorEditBox then
        iconSelectorEditBox:SetText(text)
    end
    if selectedIconButton and selectedIcon then
        selectedIconButton:SetIconTexture(selectedIcon)
    end
    
    if selectedIcon then
        local index = popup.iconDataProvider:GetIndexOfIcon(selectedIcon)
        popup.IconSelector:SetSelectedIndex(index)
    end
    
    popup:SetSelectedIconText()
end

-- ============================================================================
-- OPTIONS
-- ============================================================================

function MacroIconSelector:GetOptions()
    return {
        name = "Macro Icon Selector",
        type = "group",
        args = {
            description = {
                name = "Enhances the macro icon selection frame with search functionality and icon file names.\n\n|cff00FF7FFeatures:|r\n• Search icons by name, spell ID, item ID, or file ID\n• View icon file names in tooltips\n• Movable icon selection frame\n• Shows spells from your spellbook\n• Support for various WoW frames (macros, equipment sets, guild bank, transmog)",
                type = "description",
                order = 1,
                fontSize = "medium",
            },
            header1 = {
                name = "Usage",
                type = "header",
                order = 10,
            },
            usage = {
                name = "• Open any macro or icon selection frame\n• Type in the search box to filter icons\n• Use spell:12345 or item:12345 to find specific icons\n• Shift-click spells/items in chat to search\n• Hover over icons to see file names and IDs",
                type = "description",
                order = 11,
            },
        }
    }
end
