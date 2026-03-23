-- AbstractUI Crests Broker
-- Displays seasonal crest currencies (Dawncrest)

local LDB = LibStub("LibDataBroker-1.1")
local crestsObj

-- Currency IDs for Dawncrest season
local CREST_IDS = {
    {id = 3383, name = "Adventurer", color = {r=0.0, g=1.0, b=0.0}},    -- Green quality
    {id = 3341, name = "Veteran", color = {r=0.0, g=0.44, b=0.87}},       -- Blue quality
    {id = 3343, name = "Champion", color = {r=0.64, g=0.21, b=0.93}},     -- Purple quality
    {id = 3345, name = "Hero", color = {r=1.0, g=0.5, b=0.0}},            -- Orange quality (was 3346)
    {id = 3347, name = "Myth", color = {r=1.0, g=0.82, b=0.0}},           -- Legendary quality (was 3348)
}

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

-- Get currency count with fallback
local function GetCurrencyCount(currencyID)
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if info then
        return info.quantity or 0
    end
    return 0
end

-- Convert RGB (0-1) to hex color code
local function RGBToHex(r, g, b)
    return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- Update the broker text display
local function UpdateBrokerText()
    if not crestsObj then return end
    
    -- Build colored string showing all crest counts: 215/10/0/20/0
    local parts = {}
    local displayIcon = nil
    local highestTierWithCrests = nil
    
    -- TEST: Show all 5 in REVERSE order to test 5-color-code limit
    local counts = {}
    for i, crest in ipairs(CREST_IDS) do
        counts[i] = GetCurrencyCount(crest.id)
    end
    
    -- Reverse order: Myth, Hero, Champion, Veteran, Adventurer
    local c1 = RGBToHex(CREST_IDS[1].color.r, CREST_IDS[1].color.g, CREST_IDS[1].color.b)
    local c2 = RGBToHex(CREST_IDS[2].color.r, CREST_IDS[2].color.g, CREST_IDS[2].color.b)
    local c3 = RGBToHex(CREST_IDS[3].color.r, CREST_IDS[3].color.g, CREST_IDS[3].color.b)
    local c4 = RGBToHex(CREST_IDS[4].color.r, CREST_IDS[4].color.g, CREST_IDS[4].color.b)
    local c5 = RGBToHex(CREST_IDS[5].color.r, CREST_IDS[5].color.g, CREST_IDS[5].color.b)
    
    crestsObj.text = string.format(
        "|cff%s%d|r/|cff%s%d|r/|cff%s%d|r/|cff%s%d|r/|cff%s%d|r",
        c5, counts[5], c4, counts[4], c3, counts[3], c2, counts[2], c1, counts[1]
    )
    
    -- Set icon to highest tier crest that player owns
    if highestTierWithCrests then
        local info = C_CurrencyInfo.GetCurrencyInfo(CREST_IDS[highestTierWithCrests].id)
        if info and info.iconFileID then
            displayIcon = info.iconFileID
        end
    else
        -- Use default icon for lowest tier when player has none
        local info = C_CurrencyInfo.GetCurrencyInfo(CREST_IDS[1].id)
        if info and info.iconFileID then
            displayIcon = info.iconFileID
        end
    end
    
    if displayIcon then
        crestsObj.icon = displayIcon
    end
end

-- Register the broker
crestsObj = LDB:NewDataObject("AbstractCrests", {
    type = "data source",
    text = "...",
    icon = 5872034,  -- Default crest/upgrade icon (numeric ID)
    OnEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        SmartAnchor(GameTooltip, self)
        local r, g, b = GetColor()
        GameTooltip:AddLine("Dawncrests", r, g, b)
        GameTooltip:AddLine(" ")
        
        -- Display all crest currencies
        for _, crest in ipairs(CREST_IDS) do
            local info = C_CurrencyInfo.GetCurrencyInfo(crest.id)
            if info then
                local count = info.quantity or 0
                local maxQuantity = info.maxQuantity or 0
                local icon = info.iconFileID or ""
                
                -- Build display string
                local displayStr = FormatNumber(count)
                if maxQuantity > 0 then
                    displayStr = displayStr .. " / " .. FormatNumber(maxQuantity)
                end
                
                -- Add icon if available
                if icon and icon ~= "" then
                    displayStr = "|T"..icon..":0:0:0:0|t " .. displayStr
                end
                
                GameTooltip:AddDoubleLine(
                    crest.name .. " Dawncrest",
                    displayStr,
                    crest.color.r, crest.color.g, crest.color.b,
                    1, 1, 1
                )
            end
        end
        
        ApplyTooltipStyle(GameTooltip)
        GameTooltip:Show()
    end,
    OnLeave = function()
        GameTooltip:Hide()
    end,
})

-- Update on load
C_Timer.After(1, UpdateBrokerText)

-- Use a repeating timer to update currency display periodically
C_Timer.NewTicker(5, UpdateBrokerText)
