-- MidnightUI Token Broker
-- Displays WoW Token price and price history with manual refresh on click

if not BrokerBar then return end

local LDB = LibStub("LibDataBroker-1.1")
local tokenObj

-- Register the broker
tokenObj = LDB:NewDataObject("MidnightToken", {
    type = "data source", text = "Loading...", icon = "Interface\\Icons\\WoW_Token01", 
    OnClick = function() 
        C_WowTokenPublic.UpdateMarketPrice() -- Manual refresh on click
    end,
    OnTooltipShow = function(tip)
        local r, g, b = GetColor()
        tip:AddLine("WoW Token", r, g, b)
        local c = C_WowTokenPublic.GetCurrentMarketPrice()
        if c then 
            tip:AddDoubleLine("Current:", FormatTokenPrice(c), 1,1,1) 
        else
            tip:AddLine("Price not available", 0.8, 0.8, 0.8)
        end
        tip:AddLine(" ")
        tip:AddLine("Price History", 1, 0.82, 0)
        local h = BrokerBar.db.profile.tokenHistory or {}
        if #h > 0 then
            for _, e in ipairs(h) do 
                tip:AddDoubleLine(date("%m/%d %I:%M %p", e.time), FormatTokenPrice(e.price), 1,1,1) 
            end
        else
            tip:AddLine("No history available", 0.6, 0.6, 0.6)
        end
        tip:AddLine(" ")
        tip:AddLine("|cffaaaaaa(Click to refresh price)|r", 0.7, 0.7, 0.7)
        ApplyTooltipStyle(tip)
    end
})
