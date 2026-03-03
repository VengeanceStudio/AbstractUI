-- AbstractUI Gold Broker
-- Displays current character gold and provides account-wide summary tooltip

local LDB = LibStub("LibDataBroker-1.1")
local goldObj

-- Format money for display (gold, silver, copper)
local function FormatMoneyTable(amount)
    if not amount then 
        amount = 0
    end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    
    -- Format gold with commas, right-padded to consistent width
    local goldStr = tostring(gold)
    while true do
        goldStr, k = goldStr:gsub("^(%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    
    -- Pad gold to 9 characters (handles up to 9,999,999)
    goldStr = string.format("%9s", goldStr)
    
    -- Always show all three denominations with consistent formatting
    -- This ensures alignment even with proportional fonts
    return string.format("%s|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t %02d|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t %02d|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t", 
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
        
        -- Apply tooltip styling
        ApplyTooltipStyle(GameTooltip)
        
        -- Override font with monospaced after styling is applied
        C_Timer.After(0, function()
            for i = 1, GameTooltip:NumLines() do
                local rightText = _G["GameTooltipTextRight"..i]
                if rightText then
                    local text = rightText:GetText()
                    if text and text:find("|T") then
                        rightText:SetFont("Interface\\AddOns\\AbstractUI\\Media\\Fonts\\FiraMono-Regular.ttf", 12)
                        rightText:SetJustifyH("RIGHT")
                    end
                end
            end
        end)
        
        GameTooltip:Show()
    end,
    OnLeave = function() 
        GameTooltip:Hide() 
    end
})
