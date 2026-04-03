-- AbstractUI Delves Broker
-- Displays Valeera Sanguinar's XP and level, tracking gains over the past hour

local LDB = LibStub("LibDataBroker-1.1")
local delvesObj

-- Valeera Sanguinar Perk Program ID (Delves companion)
local VALEERA_PERK_PROGRAM_ID = 1  -- Brann Bronzebeard uses ID 1, Valeera likely uses a different constant
local VALEERA_TRAIT_CONFIG_ID = nil  -- Will be discovered dynamically

-- Format number with thousands separator
local function FormatNumber(num)
    if not num then return "0" end
    local formatted = tostring(num)
    while true do
        formatted, k = formatted:gsub("^(%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- Find Valeera's trait config ID dynamically
local function FindValeeraTraitConfig()
    if not C_Traits or not C_Traits.GetConfigIDsByType then return nil end
    
    -- Type 3 is for delve companions (Brann/Valeera)
    local configIDs = C_Traits.GetConfigIDsByType(3)
    if not configIDs or #configIDs == 0 then return nil end
    
    -- Find the active config (Valeera)
    for _, configID in ipairs(configIDs) do
        local configInfo = C_Traits.GetConfigInfo(configID)
        if configInfo and configInfo.type == 3 then
            -- Check if this config has nodes (is active/available)
            local treeInfo = C_Traits.GetTreeInfo(configID)
            if treeInfo then
                return configID
            end
        end
    end
    
    return configIDs[1]  -- Fallback to first config
end

-- Get Valeera's current data using Traits/Perks system
local function GetValeeraData()
    if not C_Traits then return nil end
    
    if not VALEERA_TRAIT_CONFIG_ID then
        VALEERA_TRAIT_CONFIG_ID = FindValeeraTraitConfig()
        if not VALEERA_TRAIT_CONFIG_ID then return nil end
    end
    
    local configInfo = C_Traits.GetConfigInfo(VALEERA_TRAIT_CONFIG_ID)
    if not configInfo then return nil end
    
    local treeInfo = C_Traits.GetTreeInfo(VALEERA_TRAIT_CONFIG_ID)
    if not treeInfo then return nil end
    
    -- Get trait currency info for XP
    local traitCurrencyID = C_Traits.GetTraitCurrencyForTreeID(VALEERA_TRAIT_CONFIG_ID)
    local currencyInfo = nil
    if traitCurrencyID then
        currencyInfo = C_CurrencyInfo.GetCurrencyInfo(traitCurrencyID)
    end
    
    local currentXP = 0
    local maxXP = 1
    
    if currencyInfo then
        currentXP = currencyInfo.quantity or 0
        maxXP = currencyInfo.maxQuantity or 1
        if maxXP <= 0 then maxXP = 1 end
    end
    
    return {
        level = configInfo.activeConfigID and (treeInfo.spentAmountRequired or 0) or 0,
        currentXP = currentXP,
        maxXP = maxXP,
        isMaxLevel = false,  -- Will refine based on actual max
        name = configInfo.name or "Valeera Sanguinar"
    }
end

-- Calculate gains over the past hour
local function GetHourlyGains()
    local history = BrokerBar.db.profile.valeeraHistory or {}
    local now = time()
    local hourAgo = now - 3600
    
    -- Clean up old entries (older than 1 hour)
    local cleaned = {}
    for _, entry in ipairs(history) do
        if entry.time >= hourAgo then
            table.insert(cleaned, entry)
        end
    end
    BrokerBar.db.profile.valeeraHistory = cleaned
    
    if #cleaned == 0 then
        return 0, 0 -- No data from past hour
    end
    
    -- Get oldest entry from past hour
    local oldestEntry = cleaned[1]
    local current = GetValeeraData()
    
    if not current then
        return 0, 0
    end
    
    -- Calculate level and XP gains
    local levelGain = current.level - oldestEntry.level
    local xpGain = 0
    
    if levelGain > 0 then
        -- Leveled up - need to account for XP rollover
        -- Simplified: just show level gains
        xpGain = current.currentXP + (levelGain * oldestEntry.maxXP) - oldestEntry.xp
    else
        xpGain = current.currentXP - oldestEntry.xp
    end
    
    return levelGain, xpGain
end

-- Update historical data
local function UpdateHistory()
    if not BrokerBar or not BrokerBar.db then return end
    
    local current = GetValeeraData()
    if not current then return end
    
    local history = BrokerBar.db.profile.valeeraHistory or {}
    
    -- Add current snapshot
    table.insert(history, {
        time = time(),
        level = current.level,
        xp = current.currentXP,
        maxXP = current.maxXP
    })
    
    -- Keep only last 2 hours of data
    local twoHoursAgo = time() - 7200
    local cleaned = {}
    for _, entry in ipairs(history) do
        if entry.time >= twoHoursAgo then
            table.insert(cleaned, entry)
        end
    end
    
    BrokerBar.db.profile.valeeraHistory = cleaned
end

-- Update the broker text display
local function UpdateBrokerText()
    if not delvesObj then return end
    
    local data = GetValeeraData()
    if not data then
        delvesObj.text = "N/A"
        return
    end
    
    if data.isMaxLevel then
        delvesObj.text = string.format("Lvl %d (Max)", data.level)
    else
        local xpPercent = math.floor((data.currentXP / data.maxXP) * 100)
        delvesObj.text = string.format("Lvl %d (%d%%)", data.level, xpPercent)
    end
end

-- Register the broker
delvesObj = LDB:NewDataObject("AbstractDelves", {
    type = "data source",
    text = "...",
    icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Bronze",  -- Delves icon placeholder
    OnEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        SmartAnchor(GameTooltip, self)
        local r, g, b = GetColor()
        
        local data = GetValeeraData()
        local title = (data and data.name) or "Valeera Sanguinar"
        GameTooltip:AddLine(title, r, g, b)
        GameTooltip:AddLine(" ")
        
        if not data then
            GameTooltip:AddLine("Companion data not available", 0.8, 0.8, 0.8)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Complete the Delves intro quest", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("or visit the Delves hub to unlock", 0.6, 0.6, 0.6)
        else
            -- Current status
            GameTooltip:AddDoubleLine("Level:", tostring(data.level), 1, 1, 1, 1, 1, 1)
            
            if not data.isMaxLevel and data.maxXP > 0 then
                local xpText = string.format("%s / %s (%d%%)", 
                    FormatNumber(data.currentXP), 
                    FormatNumber(data.maxXP),
                    math.floor((data.currentXP / data.maxXP) * 100))
                GameTooltip:AddDoubleLine("Experience:", xpText, 1, 1, 1, 1, 1, 1)
            elseif data.currentXP > 0 then
                GameTooltip:AddDoubleLine("Experience:", FormatNumber(data.currentXP), 1, 1, 1, 1, 1, 1)
            end
            
            -- Hourly gains
            local levelGain, xpGain = GetHourlyGains()
            if levelGain > 0 or xpGain > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Past Hour Gains", 1, 0.82, 0)
                
                if levelGain > 0 then
                    GameTooltip:AddDoubleLine("Levels:", string.format("+%d", levelGain), 1, 1, 1, 0, 1, 0)
                end
                
                if xpGain > 0 then
                    GameTooltip:AddDoubleLine("XP:", string.format("+%s", FormatNumber(xpGain)), 1, 1, 1, 0, 1, 0)
                end
            end
        end
        
        ApplyTooltipStyle(GameTooltip)
        GameTooltip:Show()
    end,
    OnLeave = function()
        GameTooltip:Hide()
    end,
})

-- Initialize
local function Initialize()
    -- Try to find Valeera's config
    VALEERA_TRAIT_CONFIG_ID = FindValeeraTraitConfig()
    
    UpdateBrokerText()
    UpdateHistory()
end

-- Update on load (delayed to ensure BrokerBar DB is ready and player data loaded)
C_Timer.After(3, Initialize)

-- Update every 30 seconds (delve companion XP changes slowly)
C_Timer.NewTicker(30, function()
    UpdateBrokerText()
    UpdateHistory()
end)

-- Listen for trait system changes
local frame = CreateFrame("Frame")
frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
frame:RegisterEvent("TRAIT_CONFIG_CREATED")
frame:RegisterEvent("TRAIT_NODE_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, ...)
    -- Re-find config on world enter (handles zone changes, reloads)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, function()
            VALEERA_TRAIT_CONFIG_ID = FindValeeraTraitConfig()
            UpdateBrokerText()
            UpdateHistory()
        end)
    else
        UpdateBrokerText()
        UpdateHistory()
    end
end)
