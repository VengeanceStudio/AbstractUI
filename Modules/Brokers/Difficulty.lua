-- AbstractUI Difficulty Broker
-- Displays current instance difficulty (e.g., N, H, M+, LFR, World)

local LDB = LibStub("LibDataBroker-1.1")
local diffObj

-- Register the broker
diffObj = LDB:NewDataObject("AbstractDiff", { 
    type = "data source", text = "World", icon = "Interface\\Icons\\inv_misc_groupneedmore" 
})
