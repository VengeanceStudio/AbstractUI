-- AbstractUI Crests Broker
-- Displays seasonal crest currencies (Dawncrest)

local LDB = LibStub("LibDataBroker-1.1")
local crestsObj

-- Currency IDs for Dawncrest season
local CREST_IDS = {
    {id = 3383, name = "Adventurer", color = {r=0.0, g=1.0, b=0.0}},    -- Green quality
    {id = 3341, name = "Veteran", color = {r=0.0, g=0.44, b=0.87}},       -- Blue quality
    {id = 3343, name = "Champion", color = {r=0.64, g=0.21, b=0.93}},     -- Purple quality
    {id = 3346, name = "Hero", color = {r=1.0, g=0.5, b=0.0}},            -- Orange quality
    {id = 3348, name = "Myth", color = {r=1.0, g=0.82, b=0.0}},           -- Legendary quality
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

-- Update the broker text display
local function UpdateBrokerText()
    if not crestsObj then return end
    
    -- Get the highest tier crest that player has
    local displayText = ""
    local displayIcon = nil
    local hasAny = false
    
    -- Check from highest to lowest
    for i = #CREST_IDS, 1, -1 do
        local crest = CREST_IDS[i]
        local count = GetCurrencyCount(crest.id)
        if count > 0 then
            displayText = FormatNumber(count)
            -- Get the icon from currency info
            local info = C_CurrencyInfo.GetCurrencyInfo(crest.id)
            if info and info.iconFileID then
                displayIcon = info.iconFileID
            end
            hasAny = true
            break
        end
    end
    
    if not hasAny then
        displayText = "0"
        -- Use default icon for lowest tier crest when player has none
        local info = C_CurrencyInfo.GetCurrencyInfo(CREST_IDS[1].id)
        if info and info.iconFileID then
            displayIcon = info.iconFileID
        end
    end
    
    crestsObj.text = displayText
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

-- Listen for currency changes
local frame = CreateFrame("Frame")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CURRENCY_DISPLAY_UPDATE" then
        UpdateBrokerText()
    end
end)
