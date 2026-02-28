-- MidnightUI Bags Broker
-- Displays bag space usage and provides detailed tooltip with per-bag breakdown

if not BrokerBar then return end

local LDB = LibStub("LibDataBroker-1.1")
local bagObj

-- Register the broker
bagObj = LDB:NewDataObject("MidnightBags", {
    type = "data source", text = "0/0", icon = "Interface\\Icons\\INV_Misc_Bag_08", OnClick = function() ToggleAllBags() end,
    OnTooltipShow = function(tip)
        local r, g, b = GetColor()
        tip:AddLine("Bag Storage", r, g, b)
        for i = 0, 4 do
            local s = C_Container.GetContainerNumSlots(i)
            if s > 0 then
                local f = C_Container.GetContainerNumFreeSlots(i)
                local name = (i==0) and "Backpack" or "Bag "..i
                local br, bg, bb = 1, 1, 1
                if i > 0 then
                    local link = GetInventoryItemLink("player", C_Container.ContainerIDToInventoryID(i))
                    if link then 
                        local _, _, q = C_Item.GetItemInfo(link)
                        if q then 
                            br, bg, bb = C_Item.GetItemQualityColor(q) 
                        end
                        name = GetItemInfo(link) 
                    end
                end
                tip:AddDoubleLine(name, (s-f).."/"..s, br, bg, bb, 1, 1, 1)
            end
        end
        ApplyTooltipStyle(tip)
    end
})
