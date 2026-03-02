-- AbstractUI Addon Manager Module
-- Based on Addon Control Panel (ACP) - MIT Licensed
-- Original by Sylvanaar, based on rMCP by Rophy

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local AddonManager = AbstractUI:NewModule("AddonManager", "AceEvent-3.0")

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================

local LINEHEIGHT = 16
local SET_SIZE = 25
local MAXADDONS = 20
local DEFAULT_SET = 0
local NUM_ENTRIES = 20

-- API wrappers for compatibility
local C_AddOns = C_AddOns
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local EnableAddOn = C_AddOns and C_AddOns.EnableAddOn or EnableAddOn
local DisableAddOn = C_AddOns and C_AddOns.DisableAddOn or DisableAddOn
local DisableAllAddOns = C_AddOns and C_AddOns.DisableAllAddOns or DisableAllAddOns
local GetAddOnDependencies = C_AddOns and C_AddOns.GetAddOnDependencies or GetAddOnDependencies
local GetAddOnOptionalDependencies = C_AddOns and C_AddOns.GetAddOnOptionalDependencies or GetAddOnOptionalDependencies
local GetNumAddOns = C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns
local GetAddOnInfo = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
local IsAddOnLoadOnDemand = C_AddOns and C_AddOns.IsAddOnLoadOnDemand or IsAddOnLoadOnDemand
local GetAddOnEnableState = GetAddOnEnableState
if not GetAddOnEnableState then
    GetAddOnEnableState = function(character, name)
        return C_AddOns.GetAddOnEnableState(name, character)
    end
end

-- Blizzard Addons list
local BLIZZARD_ADDONS = {
    "Blizzard_AchievementUI",
    "Blizzard_ArchaeologyUI",
    "Blizzard_ArenaUI",
    "Blizzard_AuctionUI",
    "Blizzard_AuctionHouseUI",
    "Blizzard_AuthChallengeUI",
    "Blizzard_BarbershopUI",
    "Blizzard_BattlefieldMinimap",
    "Blizzard_BindingUI",
    "Blizzard_BlackMarketUI",
    "Blizzard_BoostTutorial",
    "Blizzard_Calendar",
    "Blizzard_ChallengesUI",
    "Blizzard_ChannelsUI",
    "Blizzard_ClassTalentUI",
    "Blizzard_ClickBindingUI",
    "Blizzard_Collections",
    "Blizzard_CombatLog",
    "Blizzard_CombatText",
    "Blizzard_Commentator",
    "Blizzard_Communities",
    "Blizzard_Contribution",
    "Blizzard_DeathRecap",
    "Blizzard_DebugTools",
    "Blizzard_EncounterJournal",
    "Blizzard_EventTrace",
    "Blizzard_ExpansionLandingPage",
    "Blizzard_FlightMap",
    "Blizzard_FrameXML",
    "Blizzard_GameMenu",
    "Blizzard_GarrisonUI",
    "Blizzard_GenericTraitUI",
    "Blizzard_GlyphUI",
    "Blizzard_GMChatUI",
    "Blizzard_GMSurveyUI",
    "Blizzard_GuildBankUI",
    "Blizzard_GuildControlUI",
    "Blizzard_GuildUI",
    "Blizzard_InspectUI",
    "Blizzard_IslandsPartyPoseUI",
    "Blizzard_IslandsQueueUI",
    "Blizzard_ItemInteractionUI",
    "Blizzard_ItemSocketingUI",
    "Blizzard_ItemUpgradeUI",
    "Blizzard_KeyBindingUI",
    "Blizzard_Kiosk",
    "Blizzard_LandingSoulbinds",
    "Blizzard_LookingForGroupUI",
    "Blizzard_MacroUI",
    "Blizzard_MajorFactions",
    "Blizzard_MovePad",
    "Blizzard_NewPlayerExperience",
    "Blizzard_ObliterumUI",
    "Blizzard_ObjectiveTracker",
    "Blizzard_OrderHallUI",
    "Blizzard_PartyPoseUI",
    "Blizzard_PetBattleUI",
    "Blizzard_PVPUI",
    "Blizzard_QuestChoice",
    "Blizzard_RaidUI",
    "Blizzard_RuneforgeUI",
    "Blizzard_ScrappingMachineUI",
    "Blizzard_SettingsDefinitions",
    "Blizzard_SharedXML",
    "Blizzard_SocialUI",
    "Blizzard_Soulbinds",
    "Blizzard_StoreUI",
    "Blizzard_Subtitles",
    "Blizzard_TalentUI",
    "Blizzard_TimeManager",
    "Blizzard_TokenUI",
    "Blizzard_TorghastLevelPicker",
    "Blizzard_TradeSkillUI",
    "Blizzard_TrainerUI",
    "Blizzard_Tutorial",
    "Blizzard_TutorialTemplates",
    "Blizzard_UIWidgets",
    "Blizzard_VoidStorageUI",
    "Blizzard_WarboardUI",
    "Blizzard_WarfrontsPartyPoseUI",
    "Blizzard_WeeklyRewards",
}

local NUM_BLIZZARD_ADDONS = #BLIZZARD_ADDONS

-- Data structures
local masterAddonList = {}
local sortedAddonList = {}
local collapsedAddons = {}
local addonSets = {}
local enabledList = {}

-- UI references
local mainFrame
local scrollFrame
local entries = {}

-- Sorting options
local SORT_DEFAULT = "Default"
local SORT_TITLES = "Titles" 
local SORT_AUTHOR = "Author"
local SORT_SEPARATE_LOD = "Separate LOD List"
local SORT_GROUP_BY_NAME = "Group By Name"

local addonListBuilders = {}
local currentSorter = SORT_DEFAULT

-- Settings
local NoRecurse = false
local ForceLoad = false

-- ============================================================================
-- COLOR UTILITIES
-- ============================================================================

local function ColorizeText(hexColor, text)
    if text == nil then text = "" end
    if hexColor == nil then return text end
    return "|cff" .. tostring(hexColor) .. tostring(text) .. "|r"
end

local function GetHexColor(r, g, b)
    return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- ============================================================================
-- ADDON UTILITIES
-- ============================================================================

local TAGS = {
    PART_OF = "X-Part-Of",
    CHILD_OF = "X-Child-Of",
    INTERFACE_MIN = "X-Min-Interface",
    INTERFACE_MAX = "X-Max-Interface",
}

local function SafeGetAddOnMetadata(name, tag)
    local retOK, ret1 = pcall(GetAddOnMetadata, name, tag)
    if retOK then return ret1 end
    return nil
end

function AddonManager:SpecialCaseName(name)
    local partof = SafeGetAddOnMetadata(name, TAGS.PART_OF)
    if partof == nil then
        partof = SafeGetAddOnMetadata(name, TAGS.CHILD_OF)
    end
    
    if partof ~= nil then
        return partof .. "_" .. name
    end
    
    if name == "DBM-Core" then
        return "DBM"
    elseif name:match("DBM%-") then
        return name:gsub("DBM%-", "DBM_")
    elseif name:match("CT_") then
        return name:gsub("CT_", "CT-")
    elseif name:sub(1, 1) == "+" or name:sub(1, 1) == "!" or name:sub(1, 1) == "_" then
        return name:sub(2, -1)
    elseif name == "ShadowedUF_Options" then
        return "ShadowedUnitFrames_Options"
    elseif name:match("WeakAuras") then
        return name:gsub("WeakAuras(%w+)", "WeakAuras_%1")
    end
    
    return name
end

function AddonManager:GetAddonStatus(addon)
    local addonnum = tonumber(addon)
    if addonnum and (addonnum == 0 or addonnum > GetNumAddOns()) then
        return "ffffff", ""
    end
    
    local name, title, notes, loadable, reason, security = GetAddOnInfo(addon)
    local loaded = IsAddOnLoaded(addon)
    local isondemand = IsAddOnLoadOnDemand(addon)
    local enabled = GetAddOnEnableState(UnitGUID("player"), addon) > 0
    local color, note
    
    if reason == "DISABLED" then
        color, note = "9d9d9d", "Disabled"
    elseif reason == "NOT_DEMAND_LOADED" then
        color, note = "0070dd", "Load on Demand"
    elseif reason and not loaded then
        color, note = "ff8000", reason
    elseif loadable and isondemand and not loaded and enabled then
        color, note = "1eff00", "Loadable on Demand"
    elseif loaded and not enabled then
        color, note = "a335ee", "Disabled on Reload"
    elseif reason == "MISSING" then
        color, note = "ff0000", "Missing"
    else
        color, note = "ffffff", ""
    end
    
    return color, note
end

function AddonManager:GetAddonIndex(addon)
    if type(addon) == "number" then
        return addon
    end
    
    for i = 1, GetNumAddOns() do
        local name = GetAddOnInfo(i)
        if name == addon then
            return i
        end
    end
    
    for i = 1, NUM_BLIZZARD_ADDONS do
        if BLIZZARD_ADDONS[i] == addon then
            return GetNumAddOns() + i
        end
    end
    
    return nil
end

-- ============================================================================
-- ADDON ENABLE/DISABLE
-- ============================================================================

function AddonManager:EnableAddon(addon, shift, ctrl)
    local index = self:GetAddonIndex(addon)
    if not index then return end
    
    -- Invert recursion if shift is held
    local useRecurse = shift and NoRecurse or not NoRecurse
    
    if index > GetNumAddOns() then
        -- Blizzard addon
        local blizzAddon = BLIZZARD_ADDONS[index - GetNumAddOns()]
        if blizzAddon then
            EnableAddOn(blizzAddon)
        end
    else
        EnableAddOn(index)
        
        if useRecurse then
            self:EnableDependencies(index)
        end
    end
end

function AddonManager:ReadDependencies(t, ...)
    for i = 1, select("#", ...) do
        local dep = select(i, ...)
        if dep then
            t[dep] = true
        end
    end
    return t
end

function AddonManager:EnableDependencies(addon)
    local deps = {}
    self:ReadDependencies(deps, GetAddOnDependencies(addon))
    self:ReadDependencies(deps, GetAddOnOptionalDependencies(addon))
    
    for dep in pairs(deps) do
        local depIndex = self:GetAddonIndex(dep)
        if depIndex then
            EnableAddOn(depIndex)
        end
    end
end

-- ============================================================================
-- ADDON LIST BUILDERS (SORTING)
-- ============================================================================

addonListBuilders[SORT_DEFAULT] = function()
    wipe(masterAddonList)
    
    local normal = {name = "Addons", addons = {}}
    local blizz = {name = "Blizzard", addons = {}}
    
    for i = 1, GetNumAddOns() do
        table.insert(normal.addons, i)
    end
    
    for i = 1, NUM_BLIZZARD_ADDONS do
        table.insert(blizz.addons, GetNumAddOns() + i)
    end
    
    table.insert(masterAddonList, normal)
    table.insert(masterAddonList, blizz)
end

addonListBuilders[SORT_TITLES] = function()
    wipe(masterAddonList)
    
    local addons = {}
    for i = 1, GetNumAddOns() do
        local name, title = GetAddOnInfo(i)
        title = title or name
        table.insert(addons, {index = i, title = title:upper()})
    end
    
    table.sort(addons, function(a, b) return a.title < b.title end)
    
    local normal = {name = "Addons", addons = {}}
    for _, data in ipairs(addons) do
        table.insert(normal.addons, data.index)
    end
    
    local blizz = {name = "Blizzard", addons = {}}
    for i = 1, NUM_BLIZZARD_ADDONS do
        table.insert(blizz.addons, GetNumAddOns() + i)
    end
    
    table.insert(masterAddonList, normal)
    table.insert(masterAddonList, blizz)
end

addonListBuilders[SORT_AUTHOR] = function()
    wipe(masterAddonList)
    
    local byAuthor = {}
    
    for i = 1, GetNumAddOns() do
        local author = SafeGetAddOnMetadata(i, "Author") or "Unknown"
        author = author:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        
        if not byAuthor[author] then
            byAuthor[author] = {name = author, addons = {}}
        end
        table.insert(byAuthor[author].addons, i)
    end
    
    local sorted = {}
    for author, data in pairs(byAuthor) do
        table.insert(sorted, data)
    end
    table.sort(sorted, function(a, b) return a.name:upper() < b.name:upper() end)
    
    for _, data in ipairs(sorted) do
        table.insert(masterAddonList, data)
    end
    
    local blizz = {name = "Blizzard", addons = {}}
    for i = 1, NUM_BLIZZARD_ADDONS do
        table.insert(blizz.addons, GetNumAddOns() + i)
    end
    table.insert(masterAddonList, blizz)
end

addonListBuilders[SORT_SEPARATE_LOD] = function()
    wipe(masterAddonList)
    
    local normal = {name = "Loaded", addons = {}}
    local lod = {name = "Load on Demand", addons = {}}
    local blizz = {name = "Blizzard", addons = {}}
    
    for i = 1, GetNumAddOns() do
        if IsAddOnLoadOnDemand(i) then
            table.insert(lod.addons, i)
        else
            table.insert(normal.addons, i)
        end
    end
    
    for i = 1, NUM_BLIZZARD_ADDONS do
        table.insert(blizz.addons, GetNumAddOns() + i)
    end
    
    table.insert(masterAddonList, normal)
    table.insert(masterAddonList, lod)
    table.insert(masterAddonList, blizz)
end

addonListBuilders[SORT_GROUP_BY_NAME] = function()
    wipe(masterAddonList)
    
    local groups = {}
    
    for i = 1, GetNumAddOns() do
        local name = GetAddOnInfo(i)
        local baseName = name:match("^([^_%-]+)")
        if not baseName or baseName == "" then
            baseName = name:sub(1, 1):upper()
        end
        
        if not groups[baseName] then
            groups[baseName] = {name = baseName, addons = {}}
        end
        table.insert(groups[baseName].addons, i)
    end
    
    local sorted = {}
    for group, data in pairs(groups) do
        if #data.addons > 1 then
            table.insert(sorted, data)
        end
    end
    table.sort(sorted, function(a, b) return a.name:upper() < b.name:upper() end)
    
    -- Add ungrouped addons
    local ungrouped = {name = "Other", addons = {}}
    for group, data in pairs(groups) do
        if #data.addons == 1 then
            table.insert(ungrouped.addons, data.addons[1])
        end
    end
    
    for _, data in ipairs(sorted) do
        table.insert(masterAddonList, data)
    end
    
    if #ungrouped.addons > 0 then
        table.insert(masterAddonList, ungrouped)
    end
    
    local blizz = {name = "Blizzard", addons = {}}
    for i = 1, NUM_BLIZZARD_ADDONS do
        table.insert(blizz.addons, GetNumAddOns() + i)
    end
    table.insert(masterAddonList, blizz)
end

function AddonManager:RebuildSortedAddonList()
    wipe(sortedAddonList)
    
    for _, category in ipairs(masterAddonList) do
        table.insert(sortedAddonList, category.name)
        
        if not collapsedAddons[category.name] then
            for _, addonIndex in ipairs(category.addons) do
                table.insert(sortedAddonList, addonIndex)
            end
        end
    end
end

function AddonManager:ReloadAddonList()
    local builder = addonListBuilders[currentSorter] or addonListBuilders[SORT_DEFAULT]
    builder()
    self:RebuildSortedAddonList()
    self:UpdateDisplay()
end

-- ============================================================================
-- SET MANAGEMENT
-- ============================================================================

function AddonManager:SaveSet(set, name)
    if not addonSets[set] then
        addonSets[set] = {}
    end
    
    addonSets[set].name = name or ("Set " .. set)
    addonSets[set].addons = {}
    
    for i = 1, GetNumAddOns() do
        if GetAddOnEnableState(UnitGUID("player"), i) > 0 then
            table.insert(addonSets[set].addons, GetAddOnInfo(i))
        end
    end
end

function AddonManager:LoadSet(set)
    if not addonSets[set] or not addonSets[set].addons then
        return
    end
    
    DisableAllAddOns()
    
    for _, addonName in ipairs(addonSets[set].addons) do
        EnableAddOn(addonName)
    end
    
    self:UpdateDisplay()
end

function AddonManager:GetSetName(set)
    if addonSets[set] and addonSets[set].name then
        return addonSets[set].name
    end
    return "Set " .. set
end

-- ============================================================================
-- UI CREATION
-- ============================================================================

function AddonManager:CreateUI()
    if mainFrame then return mainFrame end
    
    -- Get framework systems
    local FrameFactory = AbstractUI.FrameFactory
    local ColorPalette = _G.AbstractUI_ColorPalette
    local FontKit = AbstractUI.FontKit
    
    if not FrameFactory or not ColorPalette or not FontKit then
        AbstractUI:Print("Framework not initialized for Addon Manager")
        return
    end
    
    -- Main frame
    mainFrame = CreateFrame("Frame", "AbstractUI_AddonManager", UIParent, "BackdropTemplate")
    mainFrame:SetSize(700, 600)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:EnableMouse(true)
    mainFrame:SetMovable(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    mainFrame:Hide()
    
    -- Background
    mainFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    mainFrame:SetBackdropColor(ColorPalette:GetColor("panel-bg"))
    mainFrame:SetBackdropBorderColor(ColorPalette:GetColor("panel-border"))
    
    -- Title bar
    local titleBg = mainFrame:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT", 0, 0)
    titleBg:SetPoint("TOPRIGHT", 0, 0)
    titleBg:SetHeight(40)
    titleBg:SetColorTexture(ColorPalette:GetColor("bg-secondary"))
    
    local title = FontKit:CreateFontString(mainFrame, "title", "large")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Addon Manager")
    title:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    -- Close button
    local closeBtn = FrameFactory:CreateButton(mainFrame, 30, 30, "X")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        mainFrame:Hide()
    end)
    
    -- Sort dropdown
    local sortLabel = FontKit:CreateFontString(mainFrame, "body", "small")
    sortLabel:SetPoint("TOPLEFT", 20, -50)
    sortLabel:SetText("Sort by:")
    sortLabel:SetTextColor(ColorPalette:GetColor("text-secondary"))
    
    local sortDropdown = CreateFrame("Frame", "AbstractUI_AddonManager_SortDropdown", mainFrame, "UIDropDownMenuTemplate")
    sortDropdown:SetPoint("LEFT", sortLabel, "RIGHT", -15, -3)
    UIDropDownMenu_SetWidth(sortDropdown, 150)
    UIDropDownMenu_SetText(sortDropdown, currentSorter)
    
    UIDropDownMenu_Initialize(sortDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        for _, sorter in ipairs({SORT_DEFAULT, SORT_TITLES, SORT_AUTHOR, SORT_SEPARATE_LOD, SORT_GROUP_BY_NAME}) do
            info.text = sorter
            info.checked = (currentSorter == sorter)
            info.func = function()
                currentSorter = sorter
                UIDropDownMenu_SetText(sortDropdown, sorter)
                AddonManager:ReloadAddonList()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    -- Recursive enable checkbox
    local recurseCheck = CreateFrame("CheckButton", nil, mainFrame, "UICheckButtonTemplate")
    recurseCheck:SetPoint("LEFT", sortDropdown, "RIGHT", 120, 3)
    recurseCheck:SetSize(24, 24)
    recurseCheck:SetChecked(not NoRecurse)
    recurseCheck:SetScript("OnClick", function(self)
        NoRecurse = not self:GetChecked()
    end)
    
    local recurseLabel = FontKit:CreateFontString(mainFrame, "body", "small")
    recurseLabel:SetPoint("LEFT", recurseCheck, "RIGHT", 5, 0)
    recurseLabel:SetText("Enable Dependencies")
    recurseLabel:SetTextColor(ColorPalette:GetColor("text-secondary"))
    
    -- Scroll frame
    scrollFrame = CreateFrame("ScrollFrame", "AbstractUI_AddonManager_ScrollFrame", mainFrame, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 70)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, LINEHEIGHT, function()
            AddonManager:UpdateDisplay()
        end)
    end)
    
    -- Create entry frames
    for i = 1, NUM_ENTRIES do
        local entry = self:CreateEntryFrame(mainFrame, i)
        entry:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 5, -(i - 1) * LINEHEIGHT)
        entries[i] = entry
    end
    
    -- Bottom buttons
    local buttonY = 25
    
    local enableAllBtn = FrameFactory:CreateButton(mainFrame, 100, 25, "Enable All")
    enableAllBtn:SetPoint("BOTTOMLEFT", 20, buttonY)
    enableAllBtn:SetScript("OnClick", function()
        for i = 1, GetNumAddOns() do
            EnableAddOn(i)
        end
        AddonManager:UpdateDisplay()
    end)
    
    local disableAllBtn = FrameFactory:CreateButton(mainFrame, 100, 25, "Disable All")
    disableAllBtn:SetPoint("LEFT", enableAllBtn, "RIGHT", 5, 0)
    disableAllBtn:SetScript("OnClick", function()
        DisableAllAddOns()
        AddonManager:UpdateDisplay()
    end)
    
    local closeBottomBtn = FrameFactory:CreateButton(mainFrame, 80, 25, "Close")
    closeBottomBtn:SetPoint("BOTTOMRIGHT", -20, buttonY)
    closeBottomBtn:SetScript("OnClick", function()
        mainFrame:Hide()
    end)
    
    local reloadBtn = FrameFactory:CreateButton(mainFrame, 100, 25, "Reload UI")
    reloadBtn:SetPoint("RIGHT", closeBottomBtn, "LEFT", -5, 0)
    reloadBtn:SetScript("OnClick", function()
        C_UI.Reload()
    end)
    
    mainFrame:SetScript("OnShow", function()
        AddonManager:ReloadAddonList()
    end)
    
    return mainFrame
end

function AddonManager:CreateEntryFrame(parent, id)
    local FrameFactory = AbstractUI.FrameFactory
    local ColorPalette = _G.AbstractUI_ColorPalette
    local FontKit = AbstractUI.FontKit
    
    local entry = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    entry:SetSize(620, LINEHEIGHT)
    
    -- Checkbox
    entry.checkbox = CreateFrame("CheckButton", nil, entry)
    entry.checkbox:SetPoint("LEFT", 5, 0)
    entry.checkbox:SetSize(16, 16)
    entry.checkbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    entry.checkbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    entry.checkbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    entry.checkbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    entry.checkbox:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    
    entry.checkbox:SetScript("OnClick", function(self)
        local addonIndex = self.addonIndex
        if addonIndex then
            local shift = IsShiftKeyDown()
            local ctrl = IsControlKeyDown()
            
            if self:GetChecked() then
                AddonManager:EnableAddon(addonIndex, shift, ctrl)
            else
                if addonIndex > GetNumAddOns() then
                    local blizzAddon = BLIZZARD_ADDONS[addonIndex - GetNumAddOns()]
                    if blizzAddon then
                        DisableAddOn(blizzAddon)
                    end
                else
                    DisableAddOn(addonIndex)
                end
            end
            
            AddonManager:UpdateDisplay()
        end
    end)
    
    -- Collapse button (for categories)
    entry.collapseBtn = CreateFrame("Button", nil, entry)
    entry.collapseBtn:SetPoint("LEFT", 0, 0)
    entry.collapseBtn:SetSize(16, 16)
    entry.collapseBtn:SetNormalTexture("Interface\\Minimap\\UI-Minimap-ZoomOutButton-Up")
    entry.collapseBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    entry.collapseBtn:Hide()
    
    entry.collapseBtn:SetScript("OnClick", function(self)
        local category = self.category
        if category then
            collapsedAddons[category] = not collapsedAddons[category]
            AddonManager:RebuildSortedAddonList()
            AddonManager:UpdateDisplay()
            
            if collapsedAddons[category] then
                self:SetNormalTexture("Interface\\Minimap\\UI-Minimap-ZoomInButton-Up")
            else
                self:SetNormalTexture("Interface\\Minimap\\UI-Minimap-ZoomOutButton-Up")
            end
        end
    end)
    
    -- Title text
    entry.titleText = FontKit:CreateFontString(entry, "body", "normal")
    entry.titleText:SetPoint("LEFT", 30, 0)
    entry.titleText:SetJustifyH("LEFT")
    entry.titleText:SetWidth(350)
    
    -- Status text
    entry.statusText = FontKit:CreateFontString(entry, "body", "small")
    entry.statusText:SetPoint("LEFT", 390, 0)
    entry.statusText:SetJustifyH("LEFT")
    entry.statusText:SetWidth(200)
    
    -- Security icon
    entry.securityIcon = entry:CreateTexture(nil, "ARTWORK")
    entry.securityIcon:SetPoint("LEFT", 25, 0)
    entry.securityIcon:SetSize(16, 16)
    entry.securityIcon:SetTexture("Interface\\Glues\\CharacterSelect\\Glues-AddOn-Icons")
    entry.securityIcon:Hide()
    
    -- Load button (for LOD addons)
    entry.loadBtn = FrameFactory:CreateButton(entry, 60, 16, "Load")
    entry.loadBtn:SetPoint("RIGHT", -5, 0)
    entry.loadBtn:Hide()
    
    entry.loadBtn:SetScript("OnClick", function(self)
        local addonIndex = self.addonIndex
        if addonIndex and addonIndex <= GetNumAddOns() then
            local name = GetAddOnInfo(addonIndex)
            if name then
                EnableAddOn(name)
                LoadAddOn(name)
                AddonManager:UpdateDisplay()
            end
        end
    end)
    
    -- Tooltip support
    entry:SetScript("OnEnter", function(self)
        if self.addonIndex and type(self.addonIndex) == "number" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            
            local index = self.addonIndex
            local name, title, notes
            
            -- Check if this is a Blizzard addon
            if index > GetNumAddOns() then
                local blizzIndex = index - GetNumAddOns()
                local blizzName = BLIZZARD_ADDONS[blizzIndex]
                if blizzName then
                    name, title, notes = GetAddOnInfo(blizzName)
                end
            else
                name, title, notes = GetAddOnInfo(index)
            end
            
            if name then
                GameTooltip:SetText(title or name, 1, 1, 1)
                if notes then
                    GameTooltip:AddLine(notes, nil, nil, nil, true)
                end
                
                -- Only show dependencies for non-Blizzard addons
                if index <= GetNumAddOns() then
                    local deps = {GetAddOnDependencies(index)}
                    if #deps > 0 then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Dependencies:", 0.7, 0.7, 1)
                        for _, dep in ipairs(deps) do
                            GameTooltip:AddLine("  " .. dep, 1, 1, 1)
                        end
                    end
                end
                
                GameTooltip:Show()
            end
        end
    end)
    
    entry:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return entry
end

function AddonManager:UpdateDisplay()
    if not mainFrame or not mainFrame:IsShown() then return end
    
    local ColorPalette = _G.AbstractUI_ColorPalette
    local numAddons = #sortedAddonList
    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    
    FauxScrollFrame_Update(scrollFrame, numAddons, NUM_ENTRIES, LINEHEIGHT)
    
    for i = 1, NUM_ENTRIES do
        local entry = entries[i]
        local listIndex = i + offset
        
        if listIndex <= numAddons then
            local item = sortedAddonList[listIndex]
            
            if type(item) == "string" then
                -- Category header
                entry.checkbox:Hide()
                entry.collapseBtn:Show()
                entry.collapseBtn.category = item
                entry.securityIcon:Hide()
                entry.loadBtn:Hide()
                entry.statusText:SetText("")
                
                entry.titleText:SetText("|cff" .. GetHexColor(ColorPalette:GetColor("text-primary")) .. item)
                entry.addonIndex = nil
                
                if collapsedAddons[item] then
                    entry.collapseBtn:SetNormalTexture("Interface\\Minimap\\UI-Minimap-ZoomInButton-Up")
                else
                    entry.collapseBtn:SetNormalTexture("Interface\\Minimap\\UI-Minimap-ZoomOutButton-Up")
                end
            else
                -- Addon entry
                entry.collapseBtn:Hide()
                entry.checkbox:Show()
                entry.addonIndex = item
                entry.checkbox.addonIndex = item
                entry.loadBtn.addonIndex = item
                
                local index = item
                local isBlizzard = false
                
                if index > GetNumAddOns() then
                    -- Blizzard addon
                    isBlizzard = true
                    local blizzIndex = index - GetNumAddOns()
                    local blizzName = BLIZZARD_ADDONS[blizzIndex]
                    
                    if blizzName then
                        local loaded = IsAddOnLoaded(blizzName)
                        local enabled = GetAddOnEnableState(UnitGUID("player"), blizzName) > 0
                        
                        entry.checkbox:SetChecked(enabled)
                        entry.titleText:SetText("|cff7f7fff" .. blizzName)
                        
                        if loaded then
                            entry.statusText:SetText("|cff00ff00Loaded")
                        else
                            entry.statusText:SetText("")
                        end
                        
                        entry.loadBtn:Hide()
                        entry.securityIcon:Hide()
                    end
                else
                    -- Regular addon
                    local name, title, notes, loadable, reason, security = GetAddOnInfo(index)
                    
                    if name then
                        local loaded = IsAddOnLoaded(index)
                        local enabled = GetAddOnEnableState(UnitGUID("player"), index) > 0
                        local isondemand = IsAddOnLoadOnDemand(index)
                        
                        entry.checkbox:SetChecked(enabled)
                        
                        local color, statusText = self:GetAddonStatus(index)
                        entry.titleText:SetText("|cff" .. color .. (title or name))
                        entry.statusText:SetText("|cff" .. color .. statusText)
                        
                        -- Show load button for LOD addons
                        if isondemand and not loaded and loadable then
                            entry.loadBtn:Show()
                        else
                            entry.loadBtn:Hide()
                        end
                        
                        -- Security icon
                        if security == "BANNED" then
                            entry.securityIcon:Show()
                            entry.securityIcon:SetTexCoord(0, 0.25, 0, 1)
                        elseif security == "INSECURE" then
                            entry.securityIcon:Show()
                            entry.securityIcon:SetTexCoord(0.25, 0.5, 0, 1)
                        else
                            entry.securityIcon:Hide()
                        end
                    end
                end
            end
            
            entry:Show()
        else
            entry:Hide()
        end
    end
end

-- ============================================================================
-- MODULE INITIALIZATION
-- ============================================================================

function AddonManager:OnInitialize()
    -- Initialize database
    local defaults = {
        profile = {
            sorter = SORT_DEFAULT,
            noRecurse = false,
            collapsedCategories = {},
            sets = {},
        }
    }
    
    self.db = AbstractUI.db:RegisterNamespace("AddonManager", defaults)
    
    -- Load settings
    currentSorter = self.db.profile.sorter or SORT_DEFAULT
    NoRecurse = self.db.profile.noRecurse or false
    collapsedAddons = self.db.profile.collapsedCategories or {}
    addonSets = self.db.profile.sets or {}
    
    -- Register slash command
    SLASH_ABSTRACTADDONMANAGER1 = "/auiaddon"
    SLASH_ABSTRACTADDONMANAGER2 = "/auiam"
    SlashCmdList["ABSTRACTADDONMANAGER"] = function()
        AddonManager:Toggle()
    end
    
    AbstractUI:Print("Addon Manager module loaded. Use /auiaddon to open.")
end

function AddonManager:OnEnable()
    -- Module enabled
end

function AddonManager:OnDisable()
    -- Save settings
    if self.db then
        self.db.profile.sorter = currentSorter
        self.db.profile.noRecurse = NoRecurse
        self.db.profile.collapsedCategories = collapsedAddons
        self.db.profile.sets = addonSets
    end
end

-- ============================================================================
-- PUBLIC INTERFACE
-- ============================================================================

function AddonManager:Toggle()
    if not mainFrame then
        self:CreateUI()
    end
    
    if mainFrame then
        if mainFrame:IsShown() then
            mainFrame:Hide()
        else
            mainFrame:Show()
        end
    end
end

function AddonManager:Show()
    if not mainFrame then
        self:CreateUI()
    end
    
    if mainFrame then
        mainFrame:Show()
    end
end

function AddonManager:Hide()
    if mainFrame then
        mainFrame:Hide()
    end
end
