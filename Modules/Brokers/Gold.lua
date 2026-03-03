-- AbstractUI Gold Broker
-- Displays current character gold and provides account-wide summary tooltip

local LDB = LibStub("LibDataBroker-1.1")
local goldObj

-- Format money for aligned display in tooltips (always shows all denominations)
local function FormatMoneyAligned(amount)
    if not amount then 
        amount = 0
    end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    
    -- Format gold with commas
    local goldStr = tostring(gold)
    while true do
        goldStr, k = goldStr:gsub("^(%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    
    -- Don't pad - let monospaced font handle alignment
    -- Always show all three denominations
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
        local startLine = GameTooltip:NumLines() + 1  -- Track starting line for font changes
        for charKey, data in pairs(BrokerBar.db.profile.goldData) do
            local charColor = {r=1, g=1, b=1}
            if type(data) == "table" and data.class then 
                local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[data.class]
                if c then charColor = c end 
            end
            local amt = type(data) == "table" and data.amount or data
            total = total + amt
            GameTooltip:AddDoubleLine(charKey:match("^(.-) %-") or charKey, FormatMoneyAligned(amt), charColor.r, charColor.g, charColor.b)
        end
        GameTooltip:AddLine(" ")
        local totalLine = GameTooltip:NumLines() + 1
        GameTooltip:AddDoubleLine("Total", FormatMoneyAligned(total), 1, 0.82, 0)
        
        -- Apply tooltip styling first
        ApplyTooltipStyle(GameTooltip)
        
        -- Then apply monospaced font to right-side text (money amounts) AFTER styling
        -- This ensures our font changes aren't overridden
        for i = startLine, GameTooltip:NumLines() do
            local rightText = _G["GameTooltipTextRight"..i]
            if rightText then
                local text = rightText:GetText()
                -- Only apply to lines with money icons
                if text and text:find("|T") then
                    -- Use ARIALN.TTF - a true monospaced font that's less likely to be replaced
                    rightText:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
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
