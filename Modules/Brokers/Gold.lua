-- MidnightUI Gold Broker
-- Displays current character gold and provides account-wide summary tooltip

if not BrokerBar then return end

local LDB = LibStub("LibDataBroker-1.1")
local goldObj

-- Register the broker
goldObj = LDB:NewDataObject("MidnightGold", { 
    type = "data source", text = "0g", icon = "Interface\\Icons\\INV_Misc_Coin_01",
    OnEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        SmartAnchor(GameTooltip, self)
        local r, g, b = GetColor()
        GameTooltip:AddLine("Account Gold Summary", r, g, b)
        GameTooltip:AddLine(" ")
        local total = 0
        for charKey, data in pairs(BrokerBar.db.profile.goldData) do
            local charColor = {r=1, g=1, b=1}
            if type(data) == "table" and data.class then 
                local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[data.class]
                if c then charColor = c end 
            end
            local amt = type(data) == "table" and data.amount or data
            total = total + amt
            GameTooltip:AddDoubleLine(charKey:match("^(.-) %-") or charKey, FormatMoney(amt), charColor.r, charColor.g, charColor.b)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total", FormatMoney(total), 1, 0.82, 0)
        ApplyTooltipStyle(GameTooltip)
        GameTooltip:Show()
    end,
    OnLeave = function() 
        GameTooltip:Hide() 
    end
})
