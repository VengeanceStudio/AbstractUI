-- MidnightUI Location Broker
-- Displays current zone name with coordinates and toggles world map on click

if not BrokerBar then return end

local LDB = LibStub("LibDataBroker-1.1")
local locObj

-- Register the broker
locObj = LDB:NewDataObject("MidnightLocation", { 
    type = "data source", text = "Loc", icon = "Interface\\Icons\\INV_Misc_Map02", 
    OnClick = function() ToggleWorldMap() end 
})
