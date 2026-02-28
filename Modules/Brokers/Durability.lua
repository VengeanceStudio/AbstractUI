-- MidnightUI Durability Broker
-- Displays overall equipment durability percentage with detailed per-slot tooltip

if not BrokerBar then return end

local LDB = LibStub("LibDataBroker-1.1")
local duraObj

-- Register the broker
duraObj = LDB:NewDataObject("MidnightDura", { 
    type = "data source", text = "100%", icon = "Interface\\Icons\\Trade_BlackSmithing", 
    OnTooltipShow = function(tip) 
        tip:AddLine("Durability Details", GetColor())
        for i=1,18 do 
            local c,m=GetInventoryItemDurability(i)
            if c and m then 
                tip:AddDoubleLine(GetInventoryItemLink("player",i), math.floor((c/m)*100).."%") 
            end 
        end
        ApplyTooltipStyle(tip) 
    end 
})
