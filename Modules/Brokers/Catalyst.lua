-- AbstractUI Catalyst Broker
-- Displays Dawnlight Manaflux charges for Midnight Season 1 catalyst upgrades

local LDB = LibStub("LibDataBroker-1.1")
local catalystObj

-- Currency ID for Dawnlight Manaflux (Midnight Season 1 catalyst charges)
local CATALYST_CURRENCY_ID = 3378

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
    if not catalystObj then return end
    
    local count = GetCurrencyCount(CATALYST_CURRENCY_ID)
    catalystObj.text = tostring(count)
    
    -- Set icon from currency info
    local info = C_CurrencyInfo.GetCurrencyInfo(CATALYST_CURRENCY_ID)
    if info and info.iconFileID then
        catalystObj.icon = info.iconFileID
    end
end

-- Register the broker
catalystObj = LDB:NewDataObject("AbstractCatalyst", {
    type = "data source",
    text = "...",
    icon = 5872034,  -- Default upgrade icon (will be replaced with currency icon)
    OnEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        SmartAnchor(GameTooltip, self)
        local r, g, b = GetColor()
        GameTooltip:AddLine("Catalyst Charges", r, g, b)
        GameTooltip:AddLine(" ")
        
        -- Display Dawnlight Manaflux info
        local info = C_CurrencyInfo.GetCurrencyInfo(CATALYST_CURRENCY_ID)
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
                "Dawnlight Manaflux",
                displayStr,
                0.5, 0.8, 1.0,  -- Light blue color for mana-themed currency
                1, 1, 1
            )
            
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Used to upgrade gear to tier pieces", 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("Currency not available", 0.8, 0.8, 0.8)
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

-- Listen for currency changes (charges awarded weekly)
local frame = CreateFrame("Frame")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:SetScript("OnEvent", UpdateBrokerText)
