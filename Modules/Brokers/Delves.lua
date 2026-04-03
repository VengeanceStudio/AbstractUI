-- AbstractUI Delves Broker
-- Displays Valeera Sanguinar's XP and level, tracking gains over the past hour

local LDB = LibStub("LibDataBroker-1.1")
local delvesObj

-- Valeera Sanguinar Faction ID (Delves companion)
local VALEERA_FACTION_ID = 2641

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

-- Get Valeera's current data
local function GetValeeraData()
    if not C_MajorFactions then return nil end
    
    local factionData = C_MajorFactions.GetMajorFactionData(VALEERA_FACTION_ID)
    if not factionData then return nil end
    
    return {
        level = factionData.renownLevel or 0,
        currentXP = factionData.renownReputationEarned or 0,
        maxXP = factionData.renownLevelThreshold or 1,
        isMaxLevel = factionData.renownLevel >= (C_MajorFactions.GetMaximumRenownLevel(VALEERA_FACTION_ID) or 999)
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
    icon = 5926728,  -- Delves/Valeera icon (will be updated)
    OnEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        SmartAnchor(GameTooltip, self)
        local r, g, b = GetColor()
        GameTooltip:AddLine("Valeera Sanguinar", r, g, b)
        GameTooltip:AddLine(" ")
        
        local data = GetValeeraData()
        if not data then
            GameTooltip:AddLine("Companion data not available", 0.8, 0.8, 0.8)
        else
            -- Current status
            GameTooltip:AddDoubleLine("Level:", tostring(data.level), 1, 1, 1, 1, 1, 1)
            
            if not data.isMaxLevel then
                local xpText = string.format("%s / %s (%d%%)", 
                    FormatNumber(data.currentXP), 
                    FormatNumber(data.maxXP),
                    math.floor((data.currentXP / data.maxXP) * 100))
                GameTooltip:AddDoubleLine("Experience:", xpText, 1, 1, 1, 1, 1, 1)
            else
                GameTooltip:AddDoubleLine("Experience:", "MAX LEVEL", 1, 1, 1, 0, 1, 0)
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
    -- Set proper icon if available
    if C_MajorFactions then
        local factionData = C_MajorFactions.GetMajorFactionData(VALEERA_FACTION_ID)
        if factionData and factionData.textureKit then
            -- Use the faction's icon if available
            local atlasName = "MajorFactions_Icons_" .. factionData.textureKit .. "64"
            if C_Texture and C_Texture.GetAtlasID then
                local atlasID = C_Texture.GetAtlasID(atlasName)
                if atlasID then
                    delvesObj.icon = atlasID
                end
            end
        end
    end
    
    UpdateBrokerText()
    UpdateHistory()
end

-- Update on load (delayed to ensure BrokerBar DB is ready)
C_Timer.After(2, Initialize)

-- Update every 30 seconds (delve companion XP changes slowly)
C_Timer.NewTicker(30, function()
    UpdateBrokerText()
    UpdateHistory()
end)

-- Listen for major faction renown changes
local frame = CreateFrame("Frame")
frame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
frame:RegisterEvent("MAJOR_FACTION_UNLOCKED")
frame:SetScript("OnEvent", function(self, event, factionID)
    if factionID == VALEERA_FACTION_ID or not factionID then
        UpdateBrokerText()
        UpdateHistory()
    end
end)
