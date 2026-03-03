-- AbstractUI Gold Broker
-- Displays current character gold and provides account-wide summary tooltip

local LDB = LibStub("LibDataBroker-1.1")
local goldObj

-- Format money as separate columns (gold, silver, copper)
local function FormatMoneyTable(amount)
    if not amount then 
        amount = 0
    end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    
    -- Format gold with commas, padded to 8 characters (supports up to 9,999,999g)
    local goldStr = tostring(gold)
    while true do
        goldStr, k = goldStr:gsub("^(%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    
    -- Format as separate columns with fixed spacing
    -- Using spaces for alignment - each denomination gets its own column
    return string.format("%8s|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t  %2d|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t  %2d|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t", 
        goldStr, silver, copper)
end

-- Register the broker
goldObj = LDB:NewDataObject("AbstractGold", { 
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
            GameTooltip:AddDoubleLine(charKey:match("^(.-) %-") or charKey, FormatMoneyTable(amt), charColor.r, charColor.g, charColor.b)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total", FormatMoneyTable(total), 1, 0.82, 0)
        
        -- Apply tooltip styling first
        ApplyTooltipStyle(GameTooltip)
        
        -- Apply monospaced font to money columns for proper alignment
        for i = 1, GameTooltip:NumLines() do
            local rightText = _G["GameTooltipTextRight"..i]
            if rightText then
                local text = rightText:GetText()
                -- Only apply to lines with money icons
                if text and text:find("|T") then
                    rightText:SetFont("Interface\\AddOns\\AbstractUI\\Media\\Fonts\\FiraMono-Regular.ttf", 12)
                    rightText:SetJustifyH("RIGHT")
                end
            end
        end
        
        GameTooltip:Show()
    end,
    OnLeave = function() 
        GameTooltip:Hide() 
    end
})
