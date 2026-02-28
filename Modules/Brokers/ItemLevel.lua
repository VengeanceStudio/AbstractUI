-- MidnightUI Item Level Broker
-- Displays average equipped item level with per-slot breakdown tooltip

if not BrokerBar then return end

local LDB = LibStub("LibDataBroker-1.1")
local ilvlObj

-- Register the broker
ilvlObj = LDB:NewDataObject("MidnightILvl", { 
    type = "data source", text = "0", icon = "Interface\\Icons\\INV_Helmet_03", 
    OnTooltipShow = function(tip) 
        tip:AddLine("Item Level", GetColor())
        for i=1,18 do 
            local l=GetInventoryItemLink("player",i)
            if l then 
                tip:AddDoubleLine(l, GetDetailedItemLevelInfo(l)) 
            end 
        end
        ApplyTooltipStyle(tip) 
    end 
})
