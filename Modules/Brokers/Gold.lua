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
    
    -- Build string in parts for maximum consistency
    local parts = {}
    
    -- Format gold amount (right-aligned to handle varying lengths with commas)
    local goldStr = tostring(gold)
    -- Add commas
    while true do
        goldStr, k = goldStr:gsub("^(%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    
    -- Build final string piece by piece with consistent spacing
    -- Format: "GGGGGGGGG|icon SS|icon CC|icon"
    return string.format("%9s|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t %02d|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t %02d|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t", 
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
        
        -- Apply monospaced font to right-side text (money amounts)  
        for i = startLine, GameTooltip:NumLines() do
            local rightText = _G["GameTooltipTextRight"..i]
            if rightText and rightText:GetText() and rightText:GetText():find("|T") then
                -- Use WoW's actual monospaced font
                rightText:SetFont("Fonts\\skurri.ttf", 11)
                rightText:SetJustifyH("RIGHT")
                rightText:SetSpacing(0)
            end
        end
        
        ApplyTooltipStyle(GameTooltip)
        GameTooltip:Show()
    end,
    OnLeave = function() 
        GameTooltip:Hide() 
    end
})
