-- AbstractUI Delves Broker
-- Displays Valeera Sanguinar's XP and level, tracking gains over the past hour

local LDB = LibStub("LibDataBroker-1.1")
local delvesObj

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

-- Get active delve companion data (Brann or Valeera)
local function GetCompanionData()
    if not C_DelvesUI or not C_GossipInfo then return nil end
    
    -- Try to get active companion ID from DelvesUI
    local companionID = nil
    
    -- Check if we can get it from the Delves frame if it's open
    if EncounterJournal and EncounterJournal.encounter then
        local progressFrame = EncounterJournal.encounter.overviewScroll.child.loreDescription:GetParent():GetParent()
        if progressFrame and progressFrame.majorFactionData and progressFrame.majorFactionData.playerCompanionID then
            companionID = progressFrame.majorFactionData.playerCompanionID
        end
    end
    
    -- If we don't have companion ID from the frame, try hardcoded values
    -- Companion IDs: Brann = 1, Valeera = 2 (these are the known delve companions)
    if not companionID then
        -- Try Valeera first (ID 2), then Brann (ID 1)
        for _, testID in ipairs({2, 1}) do
            local factionID = C_DelvesUI.GetFactionForCompanion(testID)
            if factionID and factionID > 0 then
                local repInfo = C_GossipInfo.GetFriendshipReputation(factionID)
                if repInfo and repInfo.friendshipFactionID and repInfo.friendshipFactionID > 0 then
                    companionID = testID
                    break
                end
            end
        end
    end
    
    if not companionID then return nil end
    
    -- Get faction ID for the companion
    local factionID = C_DelvesUI.GetFactionForCompanion(companionID)
    if not factionID or factionID == 0 then return nil end
    
    -- Get friendship reputation data
    local rankInfo = C_GossipInfo.GetFriendshipReputationRanks(factionID)
    local repInfo = C_GossipInfo.GetFriendshipReputation(factionID)
    
    if not rankInfo or not repInfo then return nil end
    
    -- Calculate current XP progress on this level
    local currentXP = repInfo.standing - repInfo.reactionThreshold
    local maxXP = repInfo.nextThreshold - repInfo.reactionThreshold
    
    if maxXP <= 0 then maxXP = 1 end
    if currentXP < 0 then currentXP = 0 end
    
    return {
        level = rankInfo.currentLevel or 0,
        currentXP = currentXP,
        maxXP = maxXP,
        isMaxLevel = (rankInfo.currentLevel >= rankInfo.maxLevel),
        name = repInfo.name or "Delve Companion",
        companionID = companionID
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
    local current = GetCompanionData()
    
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
    
    local current = GetCompanionData()
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
    
    local data = GetCompanionData()
    if not data then
        delvesObj.text = "N/A"
        return
    end
    
    if data.isMaxLevel then
        delvesObj.text = string.format("Lvl %d (Max)", data.level)
    elseif data.maxXP > 0 then
        local xpPercent = math.floor((data.currentXP / data.maxXP) * 100)
        delvesObj.text = string.format("Lvl %d (%d%%)", data.level, xpPercent)
    else
        delvesObj.text = string.format("Lvl %d", data.level)
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
        
        local data = GetCompanionData()
        local title = (data and data.name) or "Delve Companion"
        GameTooltip:AddLine(title, r, g, b)
        GameTooltip:AddLine(" ")
        
        if not data then
            GameTooltip:AddLine("Companion data not available", 0.8, 0.8, 0.8)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Complete the Delves intro quest", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("to unlock your companion", 0.6, 0.6, 0.6)
        else
            -- Current status
            GameTooltip:AddDoubleLine("Level:", tostring(data.level), 1, 1, 1, 1, 1, 1)
            
            if data.isMaxLevel then
                GameTooltip:AddDoubleLine("Experience:", "MAX LEVEL", 1, 1, 1, 0, 1, 0)
            elseif data.maxXP > 0 then
                local xpText = string.format("%s / %s (%d%%)", 
                    FormatNumber(data.currentXP), 
                    FormatNumber(data.maxXP),
                    math.floor((data.currentXP / data.maxXP) * 100))
                GameTooltip:AddDoubleLine("Experience:", xpText, 1, 1, 1, 1, 1, 1)
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

-- Listen for reputation/friendship changes
local frame = CreateFrame("Frame")
frame:RegisterEvent("UPDATE_FACTION")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, ...)
    -- Re-check data on world enter (handles zone changes, reloads)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, function()
            UpdateBrokerText()
            UpdateHistory()
        end)
    else
        UpdateBrokerText()
        UpdateHistory()
    end
end)
