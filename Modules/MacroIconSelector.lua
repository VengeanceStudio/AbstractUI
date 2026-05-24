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
    self:RegisterMessage("AbstractUI_DB_READY", "OnDBReady")
end

function MacroIconSelector:OnDBReady()
    if not AbstractUI.db.profile.modules.macroIconSelector then 
        self:Disable()
        return 
    end
    
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
        else
            print("|cff00FF7FAbstractUI MacroIconSelector:|r Usage: /iconscan start or /iconscan stop")
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
                        local name = frame:GetName() or "UnknownIconPicker"
                        print("|cff00FF7FAbstractUI MacroIconSelector:|r Detected icon picker frame:", name)
                        self:Initialize(frame)
                    end
                end)
            end
        end
        
        -- Also set up BANKFRAME_OPENED event to trigger aggressive scanning
        self:RegisterEvent("BANKFRAME_OPENED")
        self:RegisterEvent("BANKFRAME_CLOSED")
        
        -- Add a continuous light scanner for icon pickers (only checks when needed)
        local scanEnabled = false
        local function ScanForIconPickers()
            if not scanEnabled then return end
            
            for i = 1, UIParent:GetNumChildren() do
                local child = select(i, UIParent:GetChildren())
                if child then
                    local success = pcall(function()
                        if child:IsVisible() and not self.loadedFrames[child] then
                            if (child.IconPicker or child.BorderBox) and child.IconSelector then
                                local name = child:GetName() or "UnknownIconPicker"
                                print("|cff00FF7FAbstractUI MacroIconSelector:|r Found icon picker via scan:", name)
                                self:Initialize(child)
                            end
                        end
                    end)
                end
            end
            
            if scanEnabled then
                C_Timer.After(0.3, ScanForIconPickers)
            end
        end
        
        self.startScanning = function()
            if not scanEnabled then
                scanEnabled = true
                ScanForIconPickers()
                print("|cff00FF7FAbstractUI MacroIconSelector:|r Started scanning for icon pickers")
            end
        end
        
        self.stopScanning = function()
            scanEnabled = false
            print("|cff00FF7FAbstractUI MacroIconSelector:|r Stopped scanning for icon pickers")
        end
        
        print("|cff00FF7FAbstractUI MacroIconSelector:|r Ready - will detect icon pickers")
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
    EventUtil.ContinueOnAddOnLoaded("Blizzard_BankUI", function()
        print("|cff00FF7FAbstractUI MacroIconSelector:|r Blizzard_BankUI loaded")
        
        -- Try to find bank icon picker frames (Character bank and Warband bank may have separate ones)
        local function InitializeBankIconPickers()
            local initialized = false
            
            print("|cff00FF7FAbstractUI MacroIconSelector:|r Checking for bank icon pickers...")
            print("  BankFrame exists:", BankFrame ~= nil)
            if BankFrame then
                print("  BankFrame.BankPanel exists:", BankFrame.BankPanel ~= nil)
                print("  BankFrame.AccountBankPanel exists:", BankFrame.AccountBankPanel ~= nil)
                print("  BankFrame.TabSettingsMenu exists:", BankFrame.TabSettingsMenu ~= nil)
                
                if BankFrame.BankPanel then
                    print("  BankFrame.BankPanel.TabSettingsMenu exists:", BankFrame.BankPanel.TabSettingsMenu ~= nil)
                end
                if BankFrame.AccountBankPanel then
                    print("  BankFrame.AccountBankPanel.TabSettingsMenu exists:", BankFrame.AccountBankPanel.TabSettingsMenu ~= nil)
                end
            end
            
            -- Check for Character bank panel
            if BankFrame and BankFrame.BankPanel and BankFrame.BankPanel.TabSettingsMenu then
                print("|cff00FF7FAbstractUI MacroIconSelector:|r Found BankFrame.BankPanel.TabSettingsMenu, initializing")
                self:Initialize(BankFrame.BankPanel.TabSettingsMenu)
                initialized = true
            end
            
            -- Check for Warband/Account bank panel
            if BankFrame and BankFrame.AccountBankPanel and BankFrame.AccountBankPanel.TabSettingsMenu then
                print("|cff00FF7FAbstractUI MacroIconSelector:|r Found BankFrame.AccountBankPanel.TabSettingsMenu, initializing")
                self:Initialize(BankFrame.AccountBankPanel.TabSettingsMenu)
                initialized = true
            end
            
            -- Fallback: Check for direct TabSettingsMenu
            if BankFrame and BankFrame.TabSettingsMenu then
                print("|cff00FF7FAbstractUI MacroIconSelector:|r Found BankFrame.TabSettingsMenu, initializing")
                self:Initialize(BankFrame.TabSettingsMenu)
                initialized = true
            end
            
            if not initialized then
                print("|cff00FF7FAbstractUI MacroIconSelector:|r WARNING: No bank icon picker frames found!")
            end
            
            return initialized
        end
        
        -- Try immediate initialization
        if BankFrame then
            local success = InitializeBankIconPickers()
            
            -- If nothing found yet, hook bank show to catch it later
            if not success then
                print("|cff00FF7FAbstractUI MacroIconSelector:|r Bank icon pickers not found yet, hooking Show")
                hooksecurefunc(BankFrame, "Show", function()
                    C_Timer.After(0.3, InitializeBankIconPickers)
                end)
            end
        else
            print("|cff00FF7FAbstractUI MacroIconSelector:|r WARNING: BankFrame not found!")
        end
    end)
    
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Transmog", function()
        self:Initialize(TransmogFrame.OutfitPopup)
    end)
    
    if self.isMainline then
        EventUtil.ContinueOnAddOnLoaded("Baganator", function()
            print("|cff00FF7FAbstractUI MacroIconSelector:|r Baganator loaded, setting up API listener")
            Baganator.API.Skins.RegisterListener(function(details)
                -- Only log ButtonFrame types to reduce spam
                if details.regionType == "ButtonFrame" then
                    print("|cff00FF7FAbstractUI MacroIconSelector:|r Baganator ButtonFrame detected")
                    if details.tags and tIndexOf(details.tags, "bank") ~= nil then
                        print("|cff00FF7FAbstractUI MacroIconSelector:|r Found bank ButtonFrame")
                        if details.region.Character and details.region.Character.TabSettingsMenu then
                            print("|cff00FF7FAbstractUI MacroIconSelector:|r Initializing Character.TabSettingsMenu")
                            self:Initialize(details.region.Character.TabSettingsMenu)
                        end
                        if details.region.Warband and details.region.Warband.TabSettingsMenu then
                            print("|cff00FF7FAbstractUI MacroIconSelector:|r Initializing Warband.TabSettingsMenu")
                            self:Initialize(details.region.Warband.TabSettingsMenu)
                        end
                    end
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
                    print("|cff00FF7FAbstractUI MacroIconSelector:|r Found bank icon picker:", name)
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
                print("|cff00FF7FAbstractUI MacroIconSelector:|r Found icon picker on UIParent:", name)
                self:Initialize(child)
                return true
            end
        end
    end
    
    return false
end

function MacroIconSelector:BANKFRAME_OPENED()
    print("|cff00FF7FAbstractUI MacroIconSelector:|r BANKFRAME_OPENED event fired")
    -- When bank opens, start continuous scanning for icon pickers
    if self.startScanning then
        self.startScanning()
    end
end

function MacroIconSelector:BANKFRAME_CLOSED()
    print("|cff00FF7FAbstractUI MacroIconSelector:|r BANKFRAME_CLOSED event fired")
    -- Stop scanning when bank closes
    if self.stopScanning then
        self.stopScanning()
    end
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
        return
    end
    
    local popupName = popup:GetName() or "UnknownPopup"
    
    -- Determine the frame structure (different for bank frames vs macro frames)
    local isBankFrame = (popup.IconPicker ~= nil)
    local okayButton, cancelButton, iconSelectorEditBox, borderBox
    
    print("|cff00FF7FAbstractUI MacroIconSelector:|r Creating search box for", popupName)
    print("  isBankFrame:", isBankFrame)
    
    if isBankFrame then
        -- Bank frame structure: uses IconPicker instead of BorderBox
        if not popup.IconPicker then
            print("  ERROR: popup.IconPicker is nil")
            return
        end
        borderBox = popup.IconPicker
        iconSelectorEditBox = popup.IconPicker.IconSelectorEditBox
        
        -- Find the Okay and Cancel buttons - they should be children of the popup
        -- Try multiple methods to find them
        local children = {popup:GetChildren()}
        print("  Found", #children, "children")
        for i, child in ipairs(children) do
            if child:IsObjectType("Button") then
                local text = child:GetText()
                local childName = child:GetName() or "unnamed"
                print("    Button", i, ":", childName, "text:", text)
                if text then
                    -- Check for Okay button (various localizations)
                    if text:find("Okay") or text == OKAY or text:find("OK") then
                        okayButton = child
                        print("      -> This is Okay button")
                    -- Check for Cancel button
                    elseif text:find("Cancel") or text == CANCEL then
                        cancelButton = child
                        print("      -> This is Cancel button")
                    end
                end
            end
        end
        
        -- Fallback: find buttons by name
        if not okayButton then
            okayButton = popup.OkayButton or popup.Okay or _G[popup:GetName().."OkayButton"]
            if okayButton then
                print("  Found Okay button via fallback")
            end
        end
        if not cancelButton then
            cancelButton = popup.CancelButton or popup.Cancel or _G[popup:GetName().."CancelButton"]
        end
    else
        -- Standard structure (macro frame, guild bank, etc.)
        if not popup.BorderBox or not popup.BorderBox.OkayButton then
            print("  ERROR: Missing BorderBox or OkayButton")
            return
        end
        borderBox = popup.BorderBox
        okayButton = popup.BorderBox.OkayButton
        cancelButton = popup.BorderBox.CancelButton
        iconSelectorEditBox = popup.BorderBox.IconSelectorEditBox
    end
    
    -- Must have at least an okay button to position the search box
    if not okayButton then
        print("  ERROR: Could not find Okay button")
        return
    end
    
    print("  SUCCESS: Creating search box")
    
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
    if not popup then 
        print("|cffFF6B6BAbstractUI MacroIconSelector:|r Initialize called with nil popup")
        return 
    end
    
    local popupName = popup:GetName() or "UnknownPopup"
    
    popup:HookScript("OnShow", function()
        if not self.loadedFrames[popup] then
            self.loadedFrames[popup] = true
            
            -- Debug output
            print("|cff00FF7FAbstractUI MacroIconSelector:|r Initializing popup:", popupName)
            print("  Has BorderBox:", popup.BorderBox ~= nil)
            print("  Has IconPicker:", popup.IconPicker ~= nil)
            print("  Has IconSelector:", popup.IconSelector ~= nil)
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
