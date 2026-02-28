-- MidnightUI System Broker
-- Displays FPS and latency with color-coded tooltip showing top 60 addons by memory usage

if not BrokerBar then return end

local LDB = LibStub("LibDataBroker-1.1")
local sysObj

-- Register the broker
sysObj = LDB:NewDataObject("MidnightSystem", {
    type = "data source", text = "0 FPS", icon = "Interface\\Icons\\Trade_Engineering",
    OnTooltipShow = function(tip)
        local r, g, b = GetColor()
        UpdateAddOnMemoryUsage()
        local addons = {}
        for i = 1, C_AddOns.GetNumAddOns() do 
            local u = GetAddOnMemoryUsage(i)
            if u > 0 then 
                table.insert(addons, {n = C_AddOns.GetAddOnInfo(i), m = u}) 
            end 
        end
        table.sort(addons, function(a, b) return a.m > b.m end)
        tip:AddLine("System Performance", r, g, b)
        local _, _, _, world = GetNetStats()
        local fps = math.floor(GetFramerate())
        
        -- FPS Coloring for Tooltip (Matches Bar)
        local fr, fg, fb = 0.2, 1, 0.2 -- Green Default
        if fps < 20 then
            fr, fg, fb = 0.87, 0.09, 0.09 -- Red
        elseif fps < 40 then
            fr, fg, fb = 1, 0.49, 0.04 -- Orange
        elseif fps < 60 then
            fr, fg, fb = 1, 0.82, 0 -- Yellow
        end
        
        -- Latency Coloring for Tooltip (Matches Bar)
        local lr, lg, lb = 0.2, 1, 0.2 -- Green Default
        if world >= 200 then
            lr, lg, lb = 0.87, 0.09, 0.09 -- Red
        elseif world >= 100 then
            lr, lg, lb = 1, 0.82, 0 -- Yellow
        end
        
        tip:AddDoubleLine("FPS:", fps, 1, 1, 1, fr, fg, fb)
        tip:AddDoubleLine("Latency:", world.."ms", 1, 1, 1, lr, lg, lb)
        tip:AddLine(" ")
        tip:AddLine("Top Addon Memory", r, g, b)
        
        for i, data in ipairs(addons) do
            if i > 60 then break end
            
            -- Determine Formatting (KB vs MB)
            local memString = ""
            local val = data.m -- Raw value in KB
            if val < 1024 then
                memString = string.format("%.0f KB", val)
            else
                memString = string.format("%.2f MB", val / 1024)
            end
            
            -- Determine Coloring (Red > 10MB, Yellow > 1MB, Green < 1MB)
            local cr, cg, cb
            if val > 10240 then -- Red (0.87, 0.09, 0.09)
                cr, cg, cb = 0.87, 0.09, 0.09
            elseif val > 1024 then -- Yellow (1.0, 0.82, 0.0)
                cr, cg, cb = 1, 0.82, 0
            else -- Green (0.2, 1.0, 0.2)
                cr, cg, cb = 0.2, 1, 0.2
            end
            
            -- Apply color to BOTH Name and Value
            tip:AddDoubleLine(data.n, memString, cr, cg, cb, cr, cg, cb)
        end
        tip:Show()
        ApplyTooltipStyle(tip)
    end
})
