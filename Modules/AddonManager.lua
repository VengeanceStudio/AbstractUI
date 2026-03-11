-- AbstractUI Addon Manager Module
-- Based on Addon Control Panel (ACP) - MIT Licensed
-- Original by Sylvanaar, based on rMCP by Rophy

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local AddonManager = AbstractUI:NewModule("AddonManager", "AceEvent-3.0")

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================

local LINEHEIGHT = 22
local SET_SIZE = 25
local MAXADDONS = 20
local DEFAULT_SET = 0
local NUM_ENTRIES = 20
local protectedAddons = {}

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

function AddonManager:StripColorCodes(text)
    if not text then return text end
    -- Strip color codes like |cffRRGGBB and |cRRGGBBRR
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    -- Strip color reset |r
    text = text:gsub("|r", "")
    return text
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
    
    -- Color legend:
    -- Red (ff0000): Incompatible/Out of date addons that won't load
    -- Orange (ff8000): Dependencies issues or other warnings
    -- Gray (9d9d9d): Disabled addons
    -- Blue (0070dd): Load on demand addons (not loaded)
    -- Purple (a335ee): Loaded but will be disabled on reload
    -- White (ffffff): Normal/loaded addons
    -- Note: Yellow/gold colors in addon names come from the addon's own TOC file
    
    -- Check loaded status first
    if loaded and enabled then
        color, note = "ffffff", ""
    elseif loaded and not enabled then
        color, note = "a335ee", "Disabled on Reload"
    elseif reason == "DISABLED" then
        color, note = "9d9d9d", "Disabled"
    elseif reason == "INTERFACE_VERSION" or reason == "INCOMPATIBLE" then
        color, note = "ff0000", "Out of Date - Will Not Load"
    elseif reason == "DEP_INTERFACE_VERSION" or reason == "DEP_INCOMPATIBLE" then
        color, note = "ff8000", "Dependency Out of Date"
    elseif reason == "MISSING" then
        color, note = "ff0000", "Missing"
    elseif isondemand and not loaded then
        -- Load on demand addons (use isondemand flag, not reason string)
        color, note = "0070dd", "Load on Demand"
    elseif reason and not loaded then
        color, note = "ff8000", reason
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
    
    -- Enable addons from the set
    for _, addonName in ipairs(addonSets[set].addons) do
        EnableAddOn(addonName)
    end
    
    -- Always enable AbstractUI and protected addons
    EnableAddOn("AbstractUI")
    for addonName, _ in pairs(protectedAddons) do
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

function AddonManager:RenameSet(set, newName)
    if not addonSets[set] then
        addonSets[set] = { addons = {} }
    end
    addonSets[set].name = newName
    self:Print("Set renamed to: " .. newName)
end

function AddonManager:AddToSet(set)
    if not addonSets[set] then
        addonSets[set] = { name = "Set " .. set, addons = {} }
    end
    
    for i = 1, GetNumAddOns() do
        if GetAddOnEnableState(UnitGUID("player"), i) > 0 then
            local addonName = GetAddOnInfo(i)
            local found = false
            for _, name in ipairs(addonSets[set].addons) do
                if name == addonName then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(addonSets[set].addons, addonName)
            end
        end
    end
    self:Print("Added current addons to " .. self:GetSetName(set))
end

function AddonManager:RemoveFromSet(set)
    if not addonSets[set] or not addonSets[set].addons then
        return
    end
    
    for i = 1, GetNumAddOns() do
        if GetAddOnEnableState(UnitGUID("player"), i) > 0 then
            local addonName = GetAddOnInfo(i)
            for j = #addonSets[set].addons, 1, -1 do
                if addonSets[set].addons[j] == addonName then
                    table.remove(addonSets[set].addons, j)
                end
            end
        end
    end
    self:Print("Removed current addons from " .. self:GetSetName(set))
end

function AddonManager:GetSetCount(set)
    if addonSets[set] and addonSets[set].addons then
        return #addonSets[set].addons
    end
    return 0
end

function AddonManager:Print(msg)
    print("|cff9d7bffAbstractUI Addon Manager:|r " .. msg)
end

function AddonManager:ShowSetsMenu(button)
    -- Close existing menu if open
    if self.setsMenu and self.setsMenu:IsShown() then
        self.setsMenu:Hide()
        return
    end
    
    -- Create menu frame if it doesn't exist
    if not self.setsMenu then
        local FrameFactory = AbstractUI.FrameFactory
        local ColorPalette = _G.AbstractUI_ColorPalette
        local FontKit = AbstractUI.FontKit
        
        local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        menu:SetSize(250, 450)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 16,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        local r, g, b = ColorPalette:GetColor("panel-bg")
        if type(r) == "table" then
            g, b = r[2] or r.g or 0.05, r[3] or r.b or 0.1
            r = r[1] or r.r or 0.05
        end
        menu:SetBackdropColor(r, g, b, 1.0)
        menu:SetBackdropBorderColor(ColorPalette:GetColor("primary"))
        menu:EnableMouse(true)
        menu:Hide()
        
        -- Scroll area for sets
        menu.scrollFrame = CreateFrame("ScrollFrame", nil, menu)
        menu.scrollFrame:SetPoint("TOPLEFT", 5, -5)
        menu.scrollFrame:SetPoint("BOTTOMRIGHT", -5, 5)
        menu.scrollFrame:EnableMouseWheel(true)
        menu.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
            local current = self:GetVerticalScroll()
            local maxScroll = self:GetVerticalScrollRange()
            local newScroll = math.max(0, math.min(current - (delta * 20), maxScroll))
            self:SetVerticalScroll(newScroll)
        end)
        
        menu.scrollChild = CreateFrame("Frame", nil, menu.scrollFrame)
        menu.scrollChild:SetSize(240, 1)
        menu.scrollFrame:SetScrollChild(menu.scrollChild)
        
        menu.buttons = {}
        
        -- Create invisible backdrop to catch outside clicks
        menu.backdrop = CreateFrame("Frame", nil, UIParent)
        menu.backdrop:SetFrameStrata("FULLSCREEN")
        menu.backdrop:SetFrameLevel(1)
        menu.backdrop:SetAllPoints()
        menu.backdrop:EnableMouse(true)
        menu.backdrop:Hide()
        menu.backdrop:SetScript("OnMouseDown", function()
            menu:Hide()
        end)
        
        menu:SetFrameLevel(100)
        
        -- Close when clicking outside
        menu:SetScript("OnShow", function()
            menu.backdrop:Show()
        end)
        
        menu:SetScript("OnHide", function()
            menu.backdrop:Hide()
            if menu.submenu then
                menu.submenu:Hide()
            end
        end)
        
        self.setsMenu = menu
    end
    
    -- Clear existing buttons
    for _, btn in ipairs(self.setsMenu.buttons) do
        btn:Hide()
    end
    wipe(self.setsMenu.buttons)
    
    -- Populate menu
    local FrameFactory = AbstractUI.FrameFactory
    local ColorPalette = _G.AbstractUI_ColorPalette
    local FontKit = AbstractUI.FontKit
    local yOffset = 0
    
    -- Add numbered sets 1-25
    for i = 1, 25 do
        local btn = self:CreateSetMenuButton(i, yOffset)
        table.insert(self.setsMenu.buttons, btn)
        yOffset = yOffset + 25
    end
    
    -- Add default set
    local defaultBtn = self:CreateSetMenuButton("Default", yOffset)
    table.insert(self.setsMenu.buttons, defaultBtn)
    yOffset = yOffset + 25
    
    self.setsMenu.scrollChild:SetHeight(yOffset)
    
    -- Position menu relative to button
    self.setsMenu:ClearAllPoints()
    self.setsMenu:SetPoint("BOTTOM", button, "TOP", 0, 5)
    self.setsMenu:Show()
end

function AddonManager:CreateSetMenuButton(setID, yOffset)
    local FrameFactory = AbstractUI.FrameFactory
    local ColorPalette = _G.AbstractUI_ColorPalette
    local FontKit = AbstractUI.FontKit
    
    local parent = self.setsMenu.scrollChild
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(230, 22)
    btn:SetPoint("TOPLEFT", 5, -yOffset)
    
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
    })
    btn:SetBackdropColor(0, 0, 0, 0)
    
    btn.text = FontKit:CreateFontString(btn, "body", "small")
    btn.text:SetPoint("LEFT", 5, 0)
    btn.text:SetText(string.format("%s (%d)", self:GetSetName(setID), self:GetSetCount(setID)))
    btn.text:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    -- Arrow indicator
    btn.arrow = btn:CreateTexture(nil, "ARTWORK")
    btn.arrow:SetSize(12, 12)
    btn.arrow:SetPoint("RIGHT", -5, 0)
    btn.arrow:SetTexture("Interface\\AddOns\\AbstractUI\\Media\\dropdown")
    btn.arrow:SetRotation(math.rad(-90))
    btn.arrow:SetVertexColor(ColorPalette:GetColor("text-secondary"))
    
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ColorPalette:GetColor("button-hover"))
    end)
    
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0, 0, 0, 0)
    end)
    
    btn:SetScript("OnClick", function(self)
        AddonManager:ShowSetSubmenu(self, setID)
    end)
    
    return btn
end

function AddonManager:ShowSetSubmenu(button, setID)
    -- Close existing submenu
    if self.setsMenu.submenu then
        self.setsMenu.submenu:Hide()
    end
    
    local FrameFactory = AbstractUI.FrameFactory
    local ColorPalette = _G.AbstractUI_ColorPalette
    local FontKit = AbstractUI.FontKit
    
    -- Create submenu frame
    local submenu = CreateFrame("Frame", nil, self.setsMenu, "BackdropTemplate")
    submenu:SetSize(200, 150)
    submenu:SetFrameStrata("FULLSCREEN_DIALOG")
    submenu:SetFrameLevel(self.setsMenu:GetFrameLevel() + 10)
    submenu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    local r, g, b = ColorPalette:GetColor("panel-bg")
    if type(r) == "table" then
        g, b = r[2] or r.g or 0.05, r[3] or r.b or 0.1
        r = r[1] or r.r or 0.05
    end
    submenu:SetBackdropColor(r, g, b, 1.0)
    submenu:SetBackdropBorderColor(ColorPalette:GetColor("primary"))
    submenu:EnableMouse(true)
    
    -- Position submenu
    submenu:SetPoint("TOPLEFT", self.setsMenu, "TOPRIGHT", 5, 0)
    
    local setName = self:GetSetName(setID)
    local yOffset = 5
    
    -- Helper function to create submenu buttons
    local function CreateSubmenuButton(text, func)
        local btn = CreateFrame("Button", nil, submenu, "BackdropTemplate")
        btn:SetSize(190, 22)
        btn:SetPoint("TOP", 0, -yOffset)
        yOffset = yOffset + 25
        
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
        })
        btn:SetBackdropColor(0, 0, 0, 0)
        
        btn.text = FontKit:CreateFontString(btn, "body", "small")
        btn.text:SetPoint("LEFT", 5, 0)
        btn.text:SetText(text)
        btn.text:SetTextColor(ColorPalette:GetColor("text-primary"))
        
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(ColorPalette:GetColor("button-hover"))
        end)
        
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
        end)
        
        btn:SetScript("OnClick", function()
            func()
            self.setsMenu:Hide()
        end)
    end
    
    -- Save button
    CreateSubmenuButton("Save", function()
        self:SaveSet(setID, setName)
        self:Print("Saved current addons to " .. setName)
    end)
    
    -- Load button
    CreateSubmenuButton("Load", function()
        self:LoadSet(setID)
        self:Print("Loaded " .. setName)
    end)
    
    -- Add to current selection
    CreateSubmenuButton("Add to current", function()
        self:AddToSet(setID)
    end)
    
    -- Remove from current selection
    CreateSubmenuButton("Remove from current", function()
        self:RemoveFromSet(setID)
    end)
    
    -- Rename (not for Default)
    if setID ~= "Default" then
        CreateSubmenuButton("Rename", function()
            self.renamingSet = setID
            StaticPopup_Show("ABSTRACTUI_ADDONMANAGER_RENAMESET", setName)
        end)
    end
    
    submenu:SetHeight(yOffset)
    self.setsMenu.submenu = submenu
    submenu:Show()
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
    mainFrame:SetFrameStrata("FULLSCREEN_DIALOG")
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
    
    -- Title bar (inset from border)
    local titleBg = mainFrame:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT", 2, -2)
    titleBg:SetPoint("TOPRIGHT", -2, -2)
    titleBg:SetHeight(40)
    titleBg:SetColorTexture(ColorPalette:GetColor("bg-secondary"))
    
    local title = FontKit:CreateFontString(mainFrame, "title", "large")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Addon Manager")
    title:SetTextColor(ColorPalette:GetColor("text-primary"))
    
    -- Close button (matching AbstractUI options style)
    local closeBtn = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -6, -6)
    closeBtn:SetSize(32, 32)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    closeBtn:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
    closeBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Close button text (X)
    closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY")
    closeBtn.text:SetFont("Fonts\\FRIZQT__.TTF", 28, "OUTLINE")
    closeBtn.text:SetText("×")
    closeBtn.text:SetPoint("CENTER", 0, 1)
    closeBtn.text:SetTextColor(0.7, 0.7, 0.7, 1)
    
    -- Hover effects
    closeBtn:SetScript("OnEnter", function(self)
        local r, g, b = ColorPalette:GetColor('accent-primary')
        if type(r) == "table" then
            g, b = r[2] or r.g or 0.0, r[3] or r.b or 0.8
            r = r[1] or r.r or 0.0
        end
        self:SetBackdropColor(r, g, b, 0.15)
        self.text:SetTextColor(1, 1, 1, 1)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
        self.text:SetTextColor(0.7, 0.7, 0.7, 1)
    end)
    closeBtn:SetScript("OnClick", function()
        mainFrame:Hide()
    end)
    
    -- Sort dropdown
    local sortLabel = FontKit:CreateFontString(mainFrame, "body", "small")
    sortLabel:SetPoint("TOPLEFT", 20, -50)
    sortLabel:SetText("Sort by:")
    sortLabel:SetTextColor(ColorPalette:GetColor("text-secondary"))
    
    local sortDropdown = FrameFactory:CreateDropdown(mainFrame, 180, 24)
    sortDropdown:SetPoint("LEFT", sortLabel, "RIGHT", 10, 0)
    sortDropdown:SetItems({
        {value = SORT_DEFAULT, text = "Default (Categories)"},
        {value = SORT_TITLES, text = "Alphabetical by Title"},
        {value = SORT_AUTHOR, text = "Group by Author"},
        {value = SORT_SEPARATE_LOD, text = "Separate Load on Demand"},
        {value = SORT_GROUP_BY_NAME, text = "Group by Name Prefix"},
    })
    sortDropdown:SetValue(currentSorter)
    sortDropdown.onChange = function(value)
        currentSorter = value
        AddonManager:ReloadAddonList()
    end
    
    -- Recursive enable checkbox
    local recurseCheck = FrameFactory:CreateCheckbox(mainFrame, 16)
    recurseCheck:SetPoint("LEFT", sortDropdown, "RIGHT", 140, 0)
    recurseCheck:SetChecked(not NoRecurse)
    recurseCheck:SetScript("OnClick", function(self)
        self:Toggle()
        NoRecurse = not self:GetChecked()
    end)
    
    local recurseLabel = FontKit:CreateFontString(mainFrame, "body", "small")
    recurseLabel:SetPoint("LEFT", recurseCheck, "RIGHT", 5, 0)
    recurseLabel:SetText("Enable Dependencies")
    recurseLabel:SetTextColor(ColorPalette:GetColor("text-secondary"))
    
    -- Scroll frame (custom, not FauxScrollFrame)
    scrollFrame = CreateFrame("Frame", "AbstractUI_AddonManager_ScrollFrame", mainFrame, "BackdropTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", -56, 70)
    
    -- Add backdrop to scroll area
    scrollFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    local r, g, b = ColorPalette:GetColor("bg-primary")
    if type(r) == "table" then
        g, b = r[2] or r.g or 0.05, r[3] or r.b or 0.05
        r = r[1] or r.r or 0.05
    end
    scrollFrame:SetBackdropColor(r * 0.7, g * 0.7, b * 0.7, 0.9)
    scrollFrame:SetBackdropBorderColor(ColorPalette:GetColor("primary"))
    
    -- Custom scrollbar
    local scrollbar = FrameFactory:CreateScrollBar(mainFrame)
    scrollbar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -20, -80)
    scrollbar:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -20, 70)
    scrollbar:SetScript("OnValueChanged", function(self, value)
        AddonManager:UpdateDisplay()
    end)
    mainFrame.scrollbar = scrollbar
    
    -- Mouse wheel support
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = scrollbar:GetValue()
        local min, max = scrollbar:GetMinMaxValues()
        local newValue = math.max(min, math.min(max, current - delta))
        scrollbar:SetValue(newValue)
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
        -- Re-enable AbstractUI and protected addons
        EnableAddOn("AbstractUI")
        for addonName, _ in pairs(protectedAddons) do
            EnableAddOn(addonName)
        end
        AddonManager:UpdateDisplay()
    end)
    
    -- Sets button
    local setsBtn = FrameFactory:CreateButton(mainFrame, 80, 25, "Sets")
    setsBtn:SetPoint("LEFT", disableAllBtn, "RIGHT", 5, 0)
    setsBtn:SetScript("OnClick", function(self)
        AddonManager:ShowSetsMenu(self)
    end)
    
    local closeBottomBtn = FrameFactory:CreateButton(mainFrame, 80, 25, "Close")
    closeBottomBtn:SetPoint("BOTTOMRIGHT", -20, buttonY)
    closeBottomBtn:SetScript("OnClick", function()
        mainFrame:Hide()
    end)
    
    local reloadBtn = FrameFactory:CreateButton(mainFrame, 100, 25, "Reload UI")
    reloadBtn:SetPoint("RIGHT", closeBottomBtn, "LEFT", -5, 0)
    reloadBtn:SetScript("OnClick", function()
        if not InCombatLockdown() then
            C_Timer.After(0.1, function()
                ReloadUI()
            end)
        else
            print("|cffff0000AbstractUI:|r Cannot reload UI while in combat.")
        end
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
    entry.checkbox = FrameFactory:CreateCheckbox(entry, 16)
    entry.checkbox:SetPoint("LEFT", 5, 0)
    
    entry.checkbox:SetScript("OnClick", function(self)
        local addonIndex = self.addonIndex
        if not addonIndex then return end
        
        if addonIndex > 0 then
            -- Check if addon is protected
            local addonName
            if addonIndex > GetNumAddOns() then
                local blizzIndex = addonIndex - GetNumAddOns()
                addonName = BLIZZARD_ADDONS[blizzIndex]
            else
                addonName = GetAddOnInfo(addonIndex)
            end
            
            if protectedAddons[addonName] then
                -- Protected addon, revert checkbox and show message
                self:SetChecked(true)
                AddonManager:Print("|cffff0000" .. addonName .. " is protected and cannot be disabled.|r")
                return
            end
            
            local shift = IsShiftKeyDown()
            local ctrl = IsControlKeyDown()
            
            self:Toggle()
            
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
    entry.collapseBtn = CreateFrame("Button", nil, entry, "BackdropTemplate")
    entry.collapseBtn:SetPoint("LEFT", 0, 0)
    entry.collapseBtn:SetSize(16, 16)
    entry.collapseBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    entry.collapseBtn:SetBackdropColor(ColorPalette:GetColor("bg-secondary"))
    entry.collapseBtn:SetBackdropBorderColor(ColorPalette:GetColor("primary"))
    entry.collapseBtn:Hide()
    
    -- Collapse icon texture (plus/minus)
    entry.collapseBtn.icon = entry.collapseBtn:CreateTexture(nil, "ARTWORK")
    entry.collapseBtn.icon:SetSize(10, 10)
    entry.collapseBtn.icon:SetPoint("CENTER")
    entry.collapseBtn.icon:SetVertexColor(ColorPalette:GetColor("text-primary"))
    
    entry.collapseBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ColorPalette:GetColor("button-hover"))
    end)
    
    entry.collapseBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ColorPalette:GetColor("bg-secondary"))
    end)
    
    entry.collapseBtn:SetScript("OnClick", function(self)
        local category = self.category
        if category then
            collapsedAddons[category] = not collapsedAddons[category]
            AddonManager:RebuildSortedAddonList()
            AddonManager:UpdateDisplay()
        end
    end)
    
    -- Title text
    entry.titleText = FontKit:CreateFontString(entry, "body", "normal")
    entry.titleText:SetPoint("LEFT", 45, 0)
    entry.titleText:SetJustifyH("LEFT")
    entry.titleText:SetWidth(335)
    
    -- Status text
    entry.statusText = FontKit:CreateFontString(entry, "body", "small")
    entry.statusText:SetPoint("LEFT", 390, 0)
    entry.statusText:SetJustifyH("LEFT")
    entry.statusText:SetWidth(200)
    
    -- Security/Protection icon button
    entry.securityBtn = CreateFrame("Button", nil, entry, "BackdropTemplate")
    entry.securityBtn:SetPoint("LEFT", 25, 0)
    entry.securityBtn:SetSize(16, 16)
    entry.securityBtn:Hide()
    
    entry.securityIcon = entry.securityBtn:CreateTexture(nil, "ARTWORK")
    entry.securityIcon:SetAllPoints()
    
    entry.securityBtn:SetScript("OnClick", function(self)
        local addonIndex = self.addonIndex
        if not addonIndex or addonIndex > GetNumAddOns() then return end
        
        local addonName = GetAddOnInfo(addonIndex)
        if not addonName then return end
        
        -- Toggle protection
        if protectedAddons[addonName] then
            protectedAddons[addonName] = nil
            AddonManager:Print("|cff00ff00" .. addonName .. " is now unlocked and can be disabled.|r")
        else
            protectedAddons[addonName] = true
            -- Ensure protected addon is enabled
            EnableAddOn(addonName)
            AddonManager:Print("|cffffaa00" .. addonName .. " is now protected and will always be loaded.|r")
        end
        
        AddonManager:UpdateDisplay()
    end)
    
    entry.securityBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local addonIndex = self.addonIndex
        if addonIndex and addonIndex <= GetNumAddOns() then
            local addonName = GetAddOnInfo(addonIndex)
            if protectedAddons[addonName] then
                GameTooltip:SetText("|cffffaa00Protected Addon|r", 1, 1, 1)
                GameTooltip:AddLine("This addon is protected and will always be loaded.", nil, nil, nil, true)
                GameTooltip:AddLine("Click to unlock.", 0.5, 1, 0.5, true)
            else
                GameTooltip:SetText("|cff00ff00Normal Addon|r", 1, 1, 1)
                GameTooltip:AddLine("This addon can be disabled.", nil, nil, nil, true)
                GameTooltip:AddLine("Click to protect and keep always loaded.", 0.5, 1, 0.5, true)
            end
        end
        GameTooltip:Show()
    end)
    
    entry.securityBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
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
    local scrollbar = mainFrame.scrollbar
    local offset = scrollbar and math.floor(scrollbar:GetValue()) or 0
    
    -- Update scrollbar range
    if scrollbar then
        local maxOffset = math.max(0, numAddons - NUM_ENTRIES)
        scrollbar:SetMinMaxValues(0, maxOffset)
        if numAddons <= NUM_ENTRIES then
            scrollbar:Hide()
            scrollFrame:SetPoint("BOTTOMRIGHT", -40, 70)
        else
            scrollbar:Show()
            scrollFrame:SetPoint("BOTTOMRIGHT", -56, 70)
        end
    end
    
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
                entry.securityBtn:Hide()
                entry.loadBtn:Hide()
                entry.statusText:SetText("")
                
                entry.titleText:SetText("|cff" .. GetHexColor(ColorPalette:GetColor("text-primary")) .. item)
                entry.addonIndex = nil
                
                -- Set icon based on collapsed/expanded state
                if collapsedAddons[item] then
                    entry.collapseBtn.icon:SetTexture("Interface\\AddOns\\AbstractUI\\Media\\plus")
                else
                    entry.collapseBtn.icon:SetTexture("Interface\\AddOns\\AbstractUI\\Media\\minus")
                end
            else
                -- Addon entry
                entry.collapseBtn:Hide()
                entry.checkbox:Show()
                entry.addonIndex = item
                entry.checkbox.addonIndex = item
                entry.loadBtn.addonIndex = item
                entry.securityBtn.addonIndex = item
                
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
                        
                        -- Keep Blizzard addons in blue to distinguish them
                        entry.titleText:SetText("|cff7f7fff" .. blizzName)
                        
                        if loaded then
                            entry.statusText:SetText("|cff00ff00Loaded")
                        else
                            entry.statusText:SetText("")
                        end
                        
                        entry.loadBtn:Hide()
                        entry.securityBtn:Hide()
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
                        -- Strip any color codes from the addon title and apply our own
                        local cleanTitle = self:StripColorCodes(title or name)
                        entry.titleText:SetText("|cff" .. color .. cleanTitle)
                        entry.statusText:SetText("|cff" .. color .. statusText)
                        
                        -- Show load button for LOD addons
                        if isondemand and not loaded and loadable then
                            entry.loadBtn:Show()
                        else
                            entry.loadBtn:Hide()
                        end
                        
                        -- Protection icon (locked/unlocked)
                        if protectedAddons[name] then
                            entry.securityIcon:SetTexture("Interface\\AddOns\\AbstractUI\\Media\\Locked")
                        else
                            entry.securityIcon:SetTexture("Interface\\AddOns\\AbstractUI\\Media\\Unlocked")
                        end
                        entry.securityIcon:SetVertexColor(ColorPalette:GetColor("text-primary"))
                        entry.securityBtn:Show()
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
-- GAME MENU HOOK
-- ============================================================================

function AddonManager:HookGameMenuButton()
    if self.gameMenuHooked then return end
    
    -- Use hooksecurefunc to hook the button click without replacing it
    local function ApplyHook()
        -- The button is created dynamically, so we need to find it
        -- Try common names first
        local addonsButton = _G["GameMenuButtonAddons"] or _G["GameMenuButtonAddOns"]
        
        -- If not found by name, search GameMenuFrame children
        if not addonsButton and GameMenuFrame then
            for i = 1, GameMenuFrame:GetNumChildren() do
                local child = select(i, GameMenuFrame:GetChildren())
                if child and child:IsObjectType("Button") then
                    -- Check button text
                    if child.GetText then
                        local text = child:GetText()
                        if text and (text == "AddOns" or text == "Addons" or text:find("Addon")) then
                            addonsButton = child
                            break
                        end
                    end
                    
                    -- Also check button name
                    local name = child:GetName()
                    if name and (name:find("Addon") or name:find("AddOn")) then
                        addonsButton = child
                        break
                    end
                end
            end
        end
        
        if addonsButton and not self.buttonHooked then
            -- Store reference to the button
            self.hookedButton = addonsButton
            
            -- Hook the OnClick script using hooksecurefunc approach
            addonsButton:HookScript("OnClick", function()
                -- Only intercept if setting is enabled
                if not AddonManager.db.profile.replaceGameMenuButton then
                    return
                end
                
                -- Hide the Game Menu
                HideUIPanel(GameMenuFrame)
                
                -- Hide the default addon list if it opens
                if AddonList and AddonList:IsShown() then
                    HideUIPanel(AddonList)
                end
                
                -- Show our addon manager
                AddonManager:Show()
            end)
            
            self.buttonHooked = true
        end
    end
    
    -- Try to apply hook when GameMenuFrame is shown
    if GameMenuFrame then
        GameMenuFrame:HookScript("OnShow", function()
            if not self.buttonHooked then
                C_Timer.After(0.1, ApplyHook)
            end
        end)
        
        self.gameMenuHooked = true
        
        -- Try immediately in case menu is already shown
        if GameMenuFrame:IsShown() then
            C_Timer.After(0.1, ApplyHook)
        end
    else
        -- Try again later if frame doesn't exist
        C_Timer.After(1, function()
            self:HookGameMenuButton()
        end)
    end
end

function AddonManager:UnhookGameMenuButton()
    if not self.gameMenuHooked then return end
    
    -- Since we used HookScript, the hooks are permanent and can't be easily removed
    -- We just set the flags to prevent re-hooking
    self.gameMenuHooked = false
    self.buttonHooked = false
    self.hookedButton = nil
    
    AbstractUI:Print("Game Menu hook disabled (takes effect after reload)")
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
            protectedAddons = {},
            replaceGameMenuButton = false,
        }
    }
    
    self.db = AbstractUI.db:RegisterNamespace("AddonManager", defaults)
    
    -- Load settings
    currentSorter = self.db.profile.sorter or SORT_DEFAULT
    NoRecurse = self.db.profile.noRecurse or false
    collapsedAddons = self.db.profile.collapsedCategories or {}
    addonSets = self.db.profile.sets or {}
    protectedAddons = self.db.profile.protectedAddons or {}
    
    -- Register static popup for renaming sets
    StaticPopupDialogs["ABSTRACTUI_ADDONMANAGER_RENAMESET"] = {
        text = "Enter the new name for %s:",
        button1 = "Okay",
        button2 = "Cancel",
        OnAccept = function(self)
            local text = self.editBox:GetText()
            if text and text ~= "" then
                AddonManager:RenameSet(AddonManager.renamingSet, text)
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local text = self:GetText()
            if text and text ~= "" then
                AddonManager:RenameSet(AddonManager.renamingSet, text)
            end
            self:GetParent():Hide()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        hasEditBox = true,
        exclusive = true,
        preferredIndex = 3,
    }
    
    -- Register slash command
    SLASH_ABSTRACTADDONMANAGER1 = "/auiaddon"
    SLASH_ABSTRACTADDONMANAGER2 = "/auiam"
    SlashCmdList["ABSTRACTADDONMANAGER"] = function()
        AddonManager:Toggle()
    end
end

function AddonManager:OnEnable()
    -- Register event to hook game menu button after world enters
    if self.db.profile.replaceGameMenuButton then
        -- Try to hook immediately
        self:HookGameMenuButton()
        
        -- Also hook after entering world to ensure it works
        self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
            C_Timer.After(1, function()
                if self.db.profile.replaceGameMenuButton and not self.gameMenuHooked then
                    self:HookGameMenuButton()
                end
            end)
        end)
    end
end

function AddonManager:OnDisable()
    -- Save settings
    if self.db then
        self.db.profile.sorter = currentSorter
        self.db.profile.noRecurse = NoRecurse
        self.db.profile.collapsedCategories = collapsedAddons
        self.db.profile.sets = addonSets
        self.db.profile.protectedAddons = protectedAddons
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

-- ============================================================================
-- OPTIONS
-- ============================================================================

function AddonManager:GetOptions()
    return {
        type = "group",
        name = "Addon Manager",
        get = function(info) return self.db.profile[info[#info]] end,
        set = function(info, value) self.db.profile[info[#info]] = value end,
        args = {
            header = {
                type = "header",
                name = "Addon Manager",
                order = 1,
            },
            description = {
                type = "description",
                name = "Manage your addons in-game with sorting and filtering options. Access the addon manager with /auiaddon or /auiam commands.",
                order = 2,
                fontSize = "medium",
            },
            openManager = {
                type = "execute",
                name = "Open Addon Manager",
                desc = "Open the addon manager window",
                order = 3,
                func = function()
                    self:Show()
                end,
            },
            spacer1 = {
                type = "description",
                name = " ",
                order = 3.5,
            },
            settingsHeader = {
                type = "header",
                name = "Settings",
                order = 4,
            },
            defaultSorter = {
                type = "select",
                name = "Default Sort Method",
                desc = "Choose the default sorting method when opening the addon manager",
                order = 5,
                values = {
                    [SORT_DEFAULT] = "Default (Categories)",
                    [SORT_TITLES] = "Alphabetical by Title",
                    [SORT_AUTHOR] = "Group by Author",
                    [SORT_SEPARATE_LOD] = "Separate Load on Demand",
                    [SORT_GROUP_BY_NAME] = "Group by Name Prefix",
                },
                get = function()
                    return self.db.profile.sorter or SORT_DEFAULT
                end,
                set = function(_, value)
                    self.db.profile.sorter = value
                    currentSorter = value
                    if mainFrame and mainFrame:IsShown() then
                        self:ReloadAddonList()
                    end
                end,
            },
            noRecurse = {
                type = "toggle",
                name = "Disable Recursive Dependencies",
                desc = "When enabled, enabling an addon will NOT automatically enable its dependencies. Hold Shift while clicking to temporarily invert this behavior.",
                order = 6,
                get = function()
                    return self.db.profile.noRecurse or false
                end,
                set = function(_, value)
                    self.db.profile.noRecurse = value
                    NoRecurse = value
                end,
            },
            replaceGameMenuButton = {
                type = "toggle",
                name = "Replace Game Menu Addons Button",
                desc = "When enabled, the Addons button in the Game Menu (ESC key) will open AbstractUI's Addon Manager instead of Blizzard's addon list. Takes effect immediately when enabled, but requires reload when disabled.",
                order = 6.5,
                get = function()
                    return self.db.profile.replaceGameMenuButton or false
                end,
                set = function(_, value)
                    self.db.profile.replaceGameMenuButton = value
                    if value then
                        self:HookGameMenuButton()
                    else
                        self:UnhookGameMenuButton()
                    end
                end,
            },
            spacer2 = {
                type = "description",
                name = " ",
                order = 6.8,
            },
            infoHeader = {
                type = "header",
                name = "Information",
                order = 7,
            },
            infoText = {
                type = "description",
                name = "The Addon Manager provides a convenient way to enable/disable addons, manage load-on-demand addons, and organize your addon list with various sorting options. Changes take effect after a UI reload.\n\n|cff00ff00Features:|r\n• Multiple sorting options\n• Load-on-demand addon support\n• Dependency auto-enabling\n• Blizzard addon management\n• Collapsible categories",
                order = 8,
                fontSize = "medium",
            },
        },
    }
end
