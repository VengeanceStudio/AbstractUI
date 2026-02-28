-- MidnightUI Clock Broker
-- Displays current time (local or realm) with tooltip showing daily/weekly resets

if not BrokerBar then return end

local LDB = LibStub("LibDataBroker-1.1")
local clockObj

-- Register the broker
clockObj = LDB:NewDataObject("MidnightClock", { 
    type = "data source", text = "00:00", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", 
    OnTooltipShow = function(tip) 
        local r,g,b = GetColor()
        local db = BrokerBar.db.profile
        tip:AddLine("Midnight Clock", r,g,b) -- UPDATED TITLE
        
        -- Local Time
        local localTime = date("*t")
        tip:AddDoubleLine("Local Time:", FormatTimeDisplay(localTime.hour, localTime.min, db.useStandardTime), 1,1,1, 1,1,1)
        
        -- Realm Time
        local realmH, realmM = GetGameTime()
        tip:AddDoubleLine("Realm Time:", FormatTimeDisplay(realmH, realmM, db.useStandardTime), 1,1,1, 1,1,1)
        
        tip:AddLine(" ")
        
        -- Resets
        tip:AddLine("Resets", r, g, b) -- ADDED TITLE
        local dailyReset = C_DateAndTime.GetSecondsUntilDailyReset()
        if dailyReset then
            tip:AddDoubleLine("Daily Reset:", FormatSeconds(dailyReset), 1,1,1, 1,1,1)
        end
        
        local weeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if weeklyReset then
            tip:AddDoubleLine("Weekly Reset:", FormatSeconds(weeklyReset), 1,1,1, 1,1,1)
        end
        
        ApplyTooltipStyle(tip) 
    end 
})
