--[[
================================================================================
MidnightUI - UnitFrames Module
================================================================================
Custom unit frame implementation for player, target, focus, pet, and boss frames.

FILE ORGANIZATION:
  1. UI Helper Functions (lines 2-200)
     - ShowTagHelp(): Tag documentation window
     - FormatHealthText(): Health text formatting with abbreviation
  
  2. Module Declaration & Dependencies (lines 205-212)
     - LibStub initialization
     - AceAddon module creation
  
  3. Core Utility Functions (lines 214-632)
     - SanitizeColorTable(): Color validation
     - GetHealthPct(), GetPowerPct(): Unit stat calculations
     - ParseTemplate(), GetTagValue(): Text template parsing
     - UpdateTextSegments(): Dynamic text rendering
     - ProcessTags_OLD(): Legacy tag processor (deprecated)
  
  4. Frame Management (lines 836-890)
     - frames: Frame storage table
     - SetBlizzardFramesHidden(): Hide default Blizzard frames
     - HookBlizzardPlayerFrame(): Hook Blizzard player frame
  
  5. Configuration/Options (lines 893-1430)
     - GenerateFrameOptions(): Frame config generator
     - GetBarOptions(): Bar config options
     - GetOptions(): Main options table
     - GetPlayerOptions(), GetPetOptions_Real(), GetBossOptions_Real()
  
  6. Event Handlers (lines 1430-1520)
     - PLAYER_ENTERING_WORLD: Initial frame creation
     - PLAYER_REGEN_ENABLED: Combat exit cleanup
     - PLAYER_TARGET_CHANGED, PLAYER_FOCUS_CHANGED: Target changes
     - INSTANCE_ENCOUNTER_ENGAGE_UNIT: Boss frame updates
     - UNIT_HEALTH, UNIT_POWER_UPDATE, UNIT_DISPLAYPOWER: Stat updates
     - UNIT_TARGET, UNIT_PET: Secondary unit updates
  
  7. Default Configuration (lines 1520-1780)
     - defaults: Default profile settings
     - MigrateInfoBarText(): Settings migration
  
  8. Frame Creation (lines 1780-2480)
     - CreateBar(): Status bar creation
     - CreateUnitFrame(): Main frame factory
     - Create*Frame(): Individual frame constructors
  
  9. Frame Update Logic (lines 2480-3040)
     - UpdateUnitFrame(): Main update function (handles all stat/text updates)
  
  10. Module Initialization (lines 3040-end)
      - Event handlers (duplicates removed)
      - OnInitialize(), OnDBReady()
      - GetPlayerOptions(), GetTargetOptions(), GetTargetTargetOptions()

PERFORMANCE NOTES:
  - OnUpdate scripts removed (event-driven updates only)
  - SetBlizzardFramesHidden() called ONLY on zone changes (not per-frame-update)
  - Event handler deduplication prevents memory leaks
  
CRITICAL: Do NOT call SetBlizzardFramesHidden() in high-frequency event handlers!
================================================================================
--]]

-- Creates and shows a popup window with tag documentation
local function ShowTagHelp()
    -- Check if the frame already exists
    if _G.MidnightUI_TagHelpFrame then
        _G.MidnightUI_TagHelpFrame:Show()
        return
    end
    
    -- Create the help frame
    local frame = CreateFrame("Frame", "MidnightUI_TagHelpFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(500, 500)
    local screenWidth = UIParent:GetWidth()
    frame:SetPoint("CENTER", UIParent, "LEFT", screenWidth * 0.825, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText("Text Display Tags")
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    -- Content frame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(450, 750)
    scrollFrame:SetScrollChild(content)
    
    -- Add text content
    local yOffset = -10
    local function AddHeader(text)
        local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", 10, yOffset)
        header:SetText(text)
        header:SetTextColor(1, 0.82, 0)
        yOffset = yOffset - 25
        return header
    end
    
    local function AddTag(tag, description)
        local tagText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        tagText:SetPoint("TOPLEFT", 20, yOffset)
        tagText:SetText("|cff00ff00" .. tag .. "|r")
        tagText:SetJustifyH("LEFT")
        
        local descText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        descText:SetPoint("TOPLEFT", 120, yOffset)
        descText:SetPoint("RIGHT", -10, 0)
        descText:SetText(description)
        descText:SetJustifyH("LEFT")
        descText:SetWordWrap(true)
        
        yOffset = yOffset - 30
        return tagText, descText
    end
    
    local function AddExample(text)
        local example = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        example:SetPoint("TOPLEFT", 20, yOffset)
        example:SetPoint("RIGHT", -10, 0)
        example:SetText("|cffaaaaaa" .. text .. "|r")
        example:SetJustifyH("LEFT")
        example:SetWordWrap(true)
        yOffset = yOffset - 20
        return example
    end
    
    -- Health Tags
    AddHeader("Health Tags")
    AddTag("[curhp]", "Current health (abbreviated)")
    AddTag("[maxhp]", "Maximum health (abbreviated)")
    AddTag("[perhp]", "Health percentage")
    yOffset = yOffset - 5
    
    -- Power Tags
    AddHeader("Power Tags")
    AddTag("[curpp]", "Current power/mana/energy/rage")
    AddTag("[maxpp]", "Maximum power")
    AddTag("[perpp]", "Power percentage")
    yOffset = yOffset - 5
    
    -- Unit Info Tags
    AddHeader("Unit Info Tags")
    AddTag("[name]", "Unit name")
    AddTag("[level]", "Unit level")
    yOffset = yOffset - 5
    
    -- Examples
    AddHeader("Example Templates")
    AddExample("HP: [curhp] / [maxhp]")
    AddExample("[curhp] / [maxhp] ([perhp]%)")
    AddExample("[perhp]%")
    AddExample("[name] - Level [level]")
    AddExample("[name] ([perhp]% HP)")
    
    frame:Show()
end

-- Helper: Robust health text formatter (handles secret values, abbreviates, supports styles)
local function FormatHealthText(hp, hpPct, style, divider, maxHp)
    style = style or "both"
    divider = divider or " | "

    -- Use pcall to handle secret values from UnitHealth()
    -- Prefer AbbreviateNumbers (Midnight API) over AbbreviateLargeNumbers (legacy)
    local hpStr = ""
    local success = pcall(function()
        local abbr = AbbreviateNumbers or AbbreviateLargeNumbers
        local val = hp
        -- Ensure hp is usable
        if type(val) == "number" then
            hpStr = abbr and abbr(val) or tostring(val)
        elseif val ~= nil then
            -- Try to convert to string in case it's a secret value
            local ok, str = pcall(tostring, val)
            hpStr = ok and str or ""
        end
    end)
    if not success then hpStr = "" end

    if style == "percent" then
        -- Percent Only: [perhp]%
        if hpPct and type(hpPct) == "number" then
            local success, result = pcall(function() return string.format("%d%%", hpPct) end)
            return success and result or ""
        end
        return ""
    elseif style == "absolute" then
        -- Current Only: [curhp]
        return hpStr or ""
    elseif style == "both" then
        -- Current/Max (Percent): [curhp] / [maxhp] ([perhp]%)
        if hpPct and type(hpPct) == "number" then
            local maxStr = ""
            pcall(function()
                local abbr = AbbreviateNumbers or AbbreviateLargeNumbers
                if type(maxHp) == "number" then
                    maxStr = abbr and abbr(maxHp) or tostring(maxHp)
                elseif maxHp ~= nil then
                    local ok, str = pcall(tostring, maxHp)
                    maxStr = ok and str or ""
                end
            end)
            local success, result = pcall(function() 
                return string.format("%s%s%s (%d%%)", hpStr or "", divider, maxStr, hpPct) 
            end)
            return success and result or (hpStr or "")
        end
        return hpStr or ""
    elseif style == "current_percent" then
        -- Current (Percent): [curhp] ([perhp]%)
        if hpPct and type(hpPct) == "number" then
            local success, result = pcall(function() 
                return string.format("%s (%d%%)", hpStr or "", hpPct) 
            end)
            return success and result or (hpStr or "")
        end
        return hpStr or ""
    elseif style == "both_reverse" then
        -- Percent Current: [perhp]% [curhp]
        if hpPct and type(hpPct) == "number" then
            local success, result = pcall(function() return string.format("%d%%%s%s", hpPct, divider, hpStr or "") end)
            return success and result or hpStr or ""
        end
        return hpStr or ""
    elseif style == "missing_percent" then
        if hpPct and type(hpPct) == "number" then
            local success, missing = pcall(function() return 100 - hpPct end)
            if not success then return "" end
            if missing > 0 then
                return string.format("-%d%%", missing)
            end
            return "0%"
        end
        return ""
    elseif style == "missing_value" then
        -- Handle secret values in subtraction
        local success, missing = pcall(function() 
            if type(maxHp) == "number" and type(hp) == "number" then
                return maxHp - hp
            end
            return nil
        end)
        if success and missing and missing > 0 then
            local ok, missingStr = pcall(function()
                local abbr = AbbreviateNumbers or AbbreviateLargeNumbers
                return abbr and abbr(missing) or tostring(missing)
            end)
            return ok and ("-" .. missingStr) or ""
        elseif success and missing == 0 then
            return "0"
        end
        return ""
    end

    return hpStr or ""
end
if not LibStub then return end
local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local UnitFrames = MidnightUI and MidnightUI:NewModule("UnitFrames", "AceEvent-3.0", "AceHook-3.0")
if not UnitFrames then return end
_G.UnitFrames = UnitFrames
local LSM = LibStub("LibSharedMedia-3.0")

-- Utility: Sanitize a color table to ensure all values are plain numbers (not secret values)
local function SanitizeColorTable(color, fallback)
    fallback = fallback or {1, 1, 1, 1}
    if type(color) ~= "table" then return fallback end
    local r = tonumber(color[1]) or fallback[1] or 1
    local g = tonumber(color[2]) or fallback[2] or 1
    local b = tonumber(color[3]) or fallback[3] or 1
    local a = tonumber(color[4]) or fallback[4] or 1
    return {r, g, b, a}
end
-- Helper: Health percent with 12.0+ API compatibility
local tocVersion = tonumber((select(4, GetBuildInfo()))) or 0
local function GetHealthPct(unit, usePredicted)
    if tocVersion >= 120000 and type(UnitHealthPercent) == "function" then
        local ok, pct
        if CurveConstants and CurveConstants.ScaleTo100 then
            ok, pct = pcall(UnitHealthPercent, unit, usePredicted, CurveConstants.ScaleTo100)
        end
        if not ok or pct == nil then
            ok, pct = pcall(UnitHealthPercent, unit, usePredicted)
        end
        if ok and pct ~= nil then
            return pct
        end
    end
    if UnitHealth and UnitHealthMax then
        local cur = UnitHealth(unit)
        local max = UnitHealthMax(unit)
        if cur and max and max > 0 then
            local ok, pct = pcall(function() return (cur / max) * 100 end)
            if ok then return pct end
        end
    end
    return nil
end

-- Helper: Power percent with 12.0+ API compatibility
local function GetPowerPct(unit, powerType, usePredicted)
    if tocVersion >= 120000 and type(UnitPowerPercent) == "function" then
        local ok, pct
        if CurveConstants and CurveConstants.ScaleTo100 then
            ok, pct = pcall(UnitPowerPercent, unit, powerType, usePredicted, CurveConstants.ScaleTo100)
        end
        if not ok or pct == nil then
            ok, pct = pcall(UnitPowerPercent, unit, powerType, usePredicted)
        end
        if ok and pct ~= nil then
            return pct
        end
    end
    local cur = UnitPower and UnitPower(unit, powerType) or 0
    local max = UnitPowerMax and UnitPowerMax(unit, powerType) or 0
    local calcOk, result = pcall(function()
        if cur and max and max > 0 then
            return (cur / max) * 100
        end
        return nil
    end)
    if calcOk and result then
        return result
    end
    return nil
end


-- Blizzard power type colors
local POWER_TYPE_COLORS = {
    MANA = {0.00, 0.44, 0.87, 1},
    RAGE = {0.78, 0.21, 0.21, 1},
    FOCUS = {1.00, 0.50, 0.25, 1},
    ENERGY = {1.00, 0.85, 0.10, 1},
    RUNIC_POWER = {0.00, 0.82, 1.00, 1},
    FURY = {0.788, 0.259, 0.992, 1},
    PAIN = {1.00, 0.61, 0.00, 1},
}

local function GetPowerTypeColor(unit)
    local powerType, powerToken = UnitPowerType(unit)
    if powerToken and POWER_TYPE_COLORS[powerToken] then
        return POWER_TYPE_COLORS[powerToken]
    end
    return {0.2, 0.4, 0.8, 1} -- fallback (blue)
end

-- Template parser: splits template into segments of text and tags
-- Returns array of {type="text"|"tag", value="..."} 
local function ParseTemplate(template)
    if not template or template == "" then
        return {}
    end
    
    local segments = {}
    local pos = 1
    
    while pos <= #template do
        -- Find next tag
        local tagStart, tagEnd = template:find("%[%w+%]", pos)
        
        if tagStart then
            -- Add any text before the tag
            if tagStart > pos then
                local text = template:sub(pos, tagStart - 1)
                table.insert(segments, {type = "text", value = text})
            end
            
            -- Add the tag (without brackets)
            local tag = template:sub(tagStart + 1, tagEnd - 1)
            table.insert(segments, {type = "tag", value = tag})
            
            pos = tagEnd + 1
        else
            -- No more tags, add remaining text
            local text = template:sub(pos)
            if text ~= "" then
                table.insert(segments, {type = "text", value = text})
            end
            break
        end
    end
    
    return segments
end

-- Get raw value for a tag (may be secret value - caller must use SetText directly)
local function GetTagValue(tagName, unit)
    if tagName == "name" then
        return UnitName(unit) or ""
    elseif tagName == "level" then
        return UnitLevel(unit) or ""
    elseif tagName == "curhp" then
        local val = UnitHealth(unit)
        if val then
            -- Try to abbreviate if possible
            local num = tonumber(val)
            if num and type(num) == "number" then
                local abbr = AbbreviateNumbers or AbbreviateLargeNumbers
                if abbr then
                    local ok, result = pcall(abbr, num)
                    if ok and result then return result end
                end
                return num
            end
        end
        return val or "?"
    elseif tagName == "maxhp" then
        local val = UnitHealthMax(unit)
        if val then
            local num = tonumber(val)
            if num and type(num) == "number" then
                local abbr = AbbreviateNumbers or AbbreviateLargeNumbers
                if abbr then
                    local ok, result = pcall(abbr, num)
                    if ok and result then return result end
                end
                return num
            end
        end
        return val or "?"
    elseif tagName == "perhp" then
        -- Try WoW 12.0+ UnitHealthPercent API with proper scaling
        if tocVersion >= 120000 and UnitHealthPercent then
            local ok, pct
            -- Try with ScaleTo100 first for proper 0-100 range
            if CurveConstants and CurveConstants.ScaleTo100 then
                ok, pct = pcall(UnitHealthPercent, unit, false, CurveConstants.ScaleTo100)
            end
            -- Fallback without scaling parameter
            if not ok or pct == nil then
                ok, pct = pcall(UnitHealthPercent, unit, false)
            end
            
            if ok and pct ~= nil then
                -- Format to whole number (%.0f handles secret values properly)
                return string.format("%.0f", pct)
            end
        end
        
        -- Fallback: try to calculate from values
        local ok1, hp = pcall(UnitHealth, unit)
        local ok2, maxHp = pcall(UnitHealthMax, unit)
        
        if ok1 and ok2 and hp and maxHp then
            local hpNum = tonumber(hp)
            local maxNum = tonumber(maxHp)
            
            if hpNum and maxNum and type(hpNum) == "number" and type(maxNum) == "number" and maxNum > 0 then
                local ok, pct = pcall(function() return math.floor((hpNum / maxNum) * 100) end)
                if ok and pct and type(pct) == "number" then
                    return tostring(pct)
                end
            end
        end
        
        return "?"
    elseif tagName == "curpp" then
        local val = UnitPower(unit)
        if val then
            local num = tonumber(val)
            if num and type(num) == "number" then
                local abbr = AbbreviateNumbers or AbbreviateLargeNumbers
                if abbr then
                    local ok, result = pcall(abbr, num)
                    if ok and result then return result end
                end
                return num
            end
        end
        return val or "?"
    elseif tagName == "maxpp" then
        local val = UnitPowerMax(unit)
        if val then
            local num = tonumber(val)
            if num and type(num) == "number" then
                local abbr = AbbreviateNumbers or AbbreviateLargeNumbers
                if abbr then
                    local ok, result = pcall(abbr, num)
                    if ok and result then return result end
                end
                return num
            end
        end
        return val or "?"
    elseif tagName == "perpp" then
        -- Try WoW 12.0+ UnitPowerPercent API with proper scaling
        if tocVersion >= 120000 and UnitPowerPercent then
            local ok, pct
            -- Try with ScaleTo100 first for proper 0-100 range
            if CurveConstants and CurveConstants.ScaleTo100 then
                ok, pct = pcall(UnitPowerPercent, unit, 0, false, CurveConstants.ScaleTo100)
            end
            -- Fallback without scaling parameter
            if not ok or pct == nil then
                ok, pct = pcall(UnitPowerPercent, unit, 0, false)
            end
            
            if ok and pct ~= nil then
                -- Format as whole number percentage (without % symbol - user can add it in template)
                local formatted = string.format("%.0f", pct)
                return formatted
            end
        end
        
        -- Fallback: try to calculate from values
        local ok1, pp = pcall(UnitPower, unit)
        local ok2, maxPp = pcall(UnitPowerMax, unit)
        
        if ok1 and ok2 and pp and maxPp then
            local ppNum = tonumber(pp)
            local maxNum = tonumber(maxPp)
            
            if ppNum and maxNum and type(ppNum) == "number" and type(maxNum) == "number" and maxNum > 0 then
                local ok, pct = pcall(function() return math.floor((ppNum / maxNum) * 100) end)
                if ok and pct and type(pct) == "number" then
                    return string.format("%.0f", pct)
                end
            end
        end
        
        return "?"
    end
    
    return "?"
end

-- Create or update text segments on a frame based on a template
-- This creates individual FontStrings for each piece so secret values can be set directly
local function UpdateTextSegments(parentFrame, template, unit, position, font, fontSize, fontOutline, color)
    position = position or "LEFT" -- LEFT, CENTER, or RIGHT
    
    -- Parse the template into segments
    local segments = ParseTemplate(template)
    
    -- Ensure we have a container for segment FontStrings
    if not parentFrame.textSegments then
        parentFrame.textSegments = {}
    end
    if not parentFrame.textSegments[position] then
        parentFrame.textSegments[position] = {}
    end
    
    local container = parentFrame.textSegments[position]
    
    -- Remove old segments if count doesn't match
    if #container ~= #segments then
        for i = 1, #container do
            if container[i] and container[i].Hide then
                container[i]:Hide()
                container[i]:SetParent(nil)
            end
        end
        container = {}
        parentFrame.textSegments[position] = container
    end
    
    -- For CENTER, create a wrapper frame to hold all segments
    if position == "CENTER" and #segments > 1 then
        if not parentFrame.centerWrapper then
            parentFrame.centerWrapper = CreateFrame("Frame", nil, parentFrame)
            parentFrame.centerWrapper:SetSize(1, 1)
        end
        parentFrame.centerWrapper:ClearAllPoints()
        parentFrame.centerWrapper:SetPoint("CENTER", parentFrame, "CENTER", 0, 0)
        parentFrame.centerWrapper:Show()
    end
    
    -- Create or update each segment
    for i, segment in ipairs(segments) do
        -- Create FontString if needed
        if not container[i] then
            if position == "CENTER" and #segments > 1 then
                container[i] = parentFrame.centerWrapper:CreateFontString(nil, "OVERLAY")
            else
                container[i] = parentFrame:CreateFontString(nil, "OVERLAY")
            end
        end
        
        local fs = container[i]
        
        -- Set font
        if font and fontSize and fontOutline then
            pcall(function() fs:SetFont(font, fontSize, fontOutline) end)
        end
        
        -- Set color
        if color and #color >= 3 then
            pcall(function() fs:SetTextColor(color[1], color[2], color[3], color[4] or 1) end)
        end
        
        -- Get and set the value
        if segment.type == "text" then
            -- Plain text - safe to set directly
            pcall(function() fs:SetText(segment.value) end)
        elseif segment.type == "tag" then
            -- Tag - get raw value (may be secret) and set directly
            local value = GetTagValue(segment.value, unit)
            pcall(function() fs:SetText(value) end)
        end
        
        -- Position based on layout
        fs:ClearAllPoints()
        if position == "LEFT" then
            if i == 1 then
                fs:SetPoint("LEFT", parentFrame, "LEFT", 4, 0)
            else
                fs:SetPoint("LEFT", container[i-1], "RIGHT", 0, 0)
            end
            fs:SetJustifyH("LEFT")
        elseif position == "CENTER" then
            if #segments == 1 then
                fs:SetPoint("CENTER", parentFrame, "CENTER", 0, 0)
                fs:SetJustifyH("CENTER")
            else
                -- Calculate middle index for centering
                local middleIndex = math.ceil(#segments / 2)
                
                if i == middleIndex then
                    -- Middle segment - center it
                    fs:SetPoint("CENTER", parentFrame, "CENTER", 0, 0)
                elseif i < middleIndex then
                    -- Before middle - build right-to-left
                    if i == middleIndex - 1 then
                        fs:SetPoint("RIGHT", container[middleIndex], "LEFT", 0, 0)
                    else
                        fs:SetPoint("RIGHT", container[i+1], "LEFT", 0, 0)
                    end
                else
                    -- After middle - build left-to-right
                    fs:SetPoint("LEFT", container[i-1], "RIGHT", 0, 0)
                end
                fs:SetJustifyH("CENTER")
            end
        elseif position == "RIGHT" then
            if i == #segments then
                fs:SetPoint("RIGHT", parentFrame, "RIGHT", -4, 0)
            elseif i == 1 then
                -- Build right-to-left, so start from the right
                local totalSegments = #segments
                local reverseIndex = totalSegments - i + 1
                if reverseIndex == totalSegments then
                    fs:SetPoint("RIGHT", parentFrame, "RIGHT", -4, 0)
                end
            else
                fs:SetPoint("RIGHT", container[i-1], "LEFT", 0, 0)
            end
            fs:SetJustifyH("RIGHT")
        end
        
        fs:Show()
    end
end

-- Old ProcessTags function - keeping for reference, will remove later
local function ProcessTags_OLD(template, unit, safeCurhp, safeMaxhp, hpPct, safeCurpp, safeMaxpp, ppPct)
    if not template or template == "" then
        return ""
    end
    
    -- Get basic unit info
    local name = UnitName and UnitName(unit) or ""
    local level = UnitLevel and UnitLevel(unit) or ""
    
    -- Build a table of tag values with safe string conversion
    local tagValues = {}
    
    -- Name and level are always safe
    tagValues["name"] = tostring(name)
    tagValues["level"] = tostring(level)
    
    -- Use the passed in values, but also try to get fresh ones
    local freshHp, freshMaxHp, freshHpPct
    
    -- Try max HP first
    local maxNum = tonumber(safeMaxhp)
    if maxNum and type(maxNum) == "number" then
        freshMaxHp = maxNum
    end
    
    -- Try current HP
    local hpNum = tonumber(safeCurhp)
    if hpNum and type(hpNum) == "number" then
        freshHp = hpNum
    end
    
    -- Try percentage from parameter
    local pctNum = tonumber(hpPct)
    if pctNum and type(pctNum) == "number" then
        freshHpPct = pctNum
    end
    
    -- If we don't have current HP but have percentage and max, calculate it
    if not freshHp and freshHpPct and freshMaxHp and freshMaxHp > 0 then
        local ok, calculated = pcall(function() return math.floor((freshHpPct / 100) * freshMaxHp) end)
        if ok and calculated and type(calculated) == "number" then
            freshHp = calculated
        end
    end
    
    -- If we don't have percentage but have both values, calculate it
    if not freshHpPct and freshHp and freshMaxHp and freshMaxHp > 0 then
        local ok, calculated = pcall(function() return (freshHp / freshMaxHp) * 100 end)
        if ok and calculated and type(calculated) == "number" then
            freshHpPct = calculated
        end
    end
    
    -- Health percentage
    if freshHpPct and type(freshHpPct) == "number" then
        local ok, pctStr = pcall(function() return tostring(math.floor(freshHpPct)) end)
        tagValues["perhp"] = (ok and type(pctStr) == "string") and pctStr or "?"
    else
        tagValues["perhp"] = "?"
    end
    
    -- Current HP
    tagValues["curhp"] = "0"
    if freshHp and type(freshHp) == "number" then
        local ok, result = pcall(function()
            local abbr = AbbreviateNumbers or AbbreviateLargeNumbers
            if abbr then
                local okAbbr, abbrVal = pcall(abbr, freshHp)
                if okAbbr and abbrVal then
                    return tostring(abbrVal)
                end
            end
            return tostring(freshHp)
        end)
        if ok and result and type(result) == "string" then
            tagValues["curhp"] = result
        end
    end
    
    -- Max HP
    tagValues["maxhp"] = "0"
    if freshMaxHp and type(freshMaxHp) == "number" then
        local ok, result = pcall(function()
            local abbr = AbbreviateNumbers or AbbreviateLargeNumbers
            if abbr then
                local okAbbr, abbrVal = pcall(abbr, freshMaxHp)
                if okAbbr and abbrVal then
                    return tostring(abbrVal)
                end
            end
            return tostring(freshMaxHp)
        end)
        if ok and result and type(result) == "string" then
            tagValues["maxhp"] = result
        end
    end
    
    -- Get fresh power values directly from API
    local freshPp, freshMaxPp, freshPpPct
    
    -- Try to get max power (usually not secret)
    local ok, maxPp = pcall(UnitPowerMax, unit)
    if ok and maxPp then
        local maxNum = tonumber(maxPp)
        if maxNum and type(maxNum) == "number" then
            freshMaxPp = maxNum
        end
    end
    
    -- Try to get current power
    local ok, pp = pcall(UnitPower, unit)
    if ok and pp then
        local ppNum = tonumber(pp)
        if ppNum and type(ppNum) == "number" then
            freshPp = ppNum
        end
    end
    
    -- Try to get percentage (works best with WoW 12.0+ API)
    if tocVersion >= 120000 and UnitPowerPercent then
        local ok, pct = pcall(UnitPowerPercent, unit, 0)
        if ok and pct then
            local pctNum = tonumber(pct)
            if pctNum and type(pctNum) == "number" then
                freshPpPct = pctNum
                -- Calculate current power from percentage if we don't have it
                if not freshPp and freshMaxPp and freshMaxPp > 0 then
                    freshPp = math.floor((pctNum / 100) * freshMaxPp)
                end
            end
        end
    end
    
    -- If we still don't have percentage but have both values, calculate it
    if not freshPpPct and freshPp and freshMaxPp and freshMaxPp > 0 then
        freshPpPct = (freshPp / freshMaxPp) * 100
    end
    
    -- Power percentage
    if freshPpPct and type(freshPpPct) == "number" then
        local ok, pctStr = pcall(function() return tostring(math.floor(freshPpPct)) end)
        tagValues["perpp"] = (ok and type(pctStr) == "string") and pctStr or "0"
    else
        tagValues["perpp"] = "0"
    end
    
    -- Current PP
    tagValues["curpp"] = "0"
    if freshPp and type(freshPp) == "number" then
        local ok, result = pcall(function()
            local abbr = AbbreviateNumbers or AbbreviateLargeNumbers
            if abbr then
                local okAbbr, abbrVal = pcall(abbr, freshPp)
                if okAbbr and abbrVal then
                    return tostring(abbrVal)
                end
            end
            return tostring(freshPp)
        end)
        if ok and result and type(result) == "string" then
            tagValues["curpp"] = result
        end
    end
    
    -- Max PP
    tagValues["maxpp"] = "0"
    if freshMaxPp and type(freshMaxPp) == "number" then
        local ok, result = pcall(function()
            local abbr = AbbreviateNumbers or AbbreviateLargeNumbers
            if abbr then
                local okAbbr, abbrVal = pcall(abbr, freshMaxPp)
                if okAbbr and abbrVal then
                    return tostring(abbrVal)
                end
            end
            return tostring(freshMaxPp)
        end)
        if ok and result and type(result) == "string" then
            tagValues["maxpp"] = result
        end
    end
    
    -- Replace all tags in the template
    local result = template
    for tag, value in pairs(tagValues) do
        -- Only replace if value is actually a string (not a secret value)
        if type(value) == "string" then
            local ok = pcall(function()
                result = result:gsub("%[" .. tag .. "%]", value)
            end)
            -- If gsub fails, skip this tag
            if not ok then
                result = result:gsub("%[" .. tag .. "%]", "?")
            end
        else
            -- If value is not a string (secret value), replace with placeholder
            result = result:gsub("%[" .. tag .. "%]", "?")
        end
    end
    
    return result
end


local frames = {}

-- Move HookBlizzardPlayerFrame definition above its first use

local function SetBlizzardFramesHidden(self)
    if InCombatLockdown() then return end
    
    if self.db.profile.showPlayer and PlayerFrame then
        UnregisterStateDriver(PlayerFrame, "visibility")
        RegisterStateDriver(PlayerFrame, "visibility", "hide")
        PlayerFrame:UnregisterAllEvents()
    end
    if self.db.profile.showTarget and TargetFrame then
        UnregisterStateDriver(TargetFrame, "visibility")
        RegisterStateDriver(TargetFrame, "visibility", "hide")
        TargetFrame:UnregisterAllEvents()
    end
    -- Do not forcibly hide TargetFrame here; let the secure driver in CreateTargetFrame control its visibility
    if self.db.profile.showTargetTarget and TargetFrameToT then
        UnregisterStateDriver(TargetFrameToT, "visibility")
        RegisterStateDriver(TargetFrameToT, "visibility", "hide")
        TargetFrameToT:UnregisterAllEvents()
    end
    if self.db.profile.showPet and PetFrame then
        UnregisterStateDriver(PetFrame, "visibility")
        RegisterStateDriver(PetFrame, "visibility", "hide")
        PetFrame:UnregisterAllEvents()
    end
    if self.db.profile.showFocus and FocusFrame then
        UnregisterStateDriver(FocusFrame, "visibility")
        RegisterStateDriver(FocusFrame, "visibility", "hide")
        FocusFrame:UnregisterAllEvents()
    end
    if self.db.profile.showBoss then
        for i = 1, 5 do
            local bossFrame = _G["Boss" .. i .. "TargetFrame"]
            if bossFrame then
                UnregisterStateDriver(bossFrame, "visibility")
                RegisterStateDriver(bossFrame, "visibility", "hide")
                bossFrame:UnregisterAllEvents()
            end
        end
    end
end

local function HookBlizzardPlayerFrame(self)
    if PlayerFrame and not PlayerFrame._MidnightUIHooked then
        hooksecurefunc(PlayerFrame, "Show", function()
            if self.db and self.db.profile and self.db.profile.showPlayer then PlayerFrame:Hide() end
        end)
        PlayerFrame._MidnightUIHooked = true
    end
end

-- ...existing code...

-- Helper function to generate frame options with independent databases
function UnitFrames:GenerateFrameOptions(frameName, frameKey, createFunc, frameGlobal)
    local db = self.db and self.db.profile and self.db.profile[frameKey] or {}
    local function update()
        if _G[frameGlobal] then _G[frameGlobal]:Hide(); _G[frameGlobal]:SetParent(nil) end
        if self and self[createFunc] then self[createFunc](self) end
    end
    
    return {
        type = "group",
        name = frameName,
        args = {
            header = { type = "header", name = frameName .. " Bars", order = 0},
            spacing = {
                type = "range",
                name = "Bar Spacing",
                desc = "Vertical space between bars.",
                min = 0, max = 32, step = 1,
                order = 0.9,
                get = function() return self.db and self.db.profile and self.db.profile.spacing or 2 end,
                set = function(_, v) if self.db and self.db.profile then self.db.profile.spacing = v; update() end end,
            },
            bossSpacing = frameKey == "boss" and {
                type = "range",
                name = "Boss Frame Spacing",
                desc = "Vertical space between each boss frame.",
                min = 40, max = 200, step = 1,
                order = 0.91,
                get = function() return self.db and self.db.profile and self.db.profile.boss and self.db.profile.boss.spacing or 80 end,
                set = function(_, v) 
                    if self.db and self.db.profile and self.db.profile.boss then 
                        self.db.profile.boss.spacing = v
                        update() 
                    end 
                end,
            } or nil,
            copyFrom = {
                type = "select",
                name = "Copy From",
                desc = "Copy all settings from another frame to this frame.",
                order = 0.91,
                values = function()
                    local frames = {
                        [""] = "-- Select Frame --",
                        player = "Player",
                        target = "Target",
                        targettarget = "Target of Target",
                        focus = "Focus",
                    }
                    -- Remove current frame from options
                    frames[frameKey] = nil
                    return frames
                end,
                get = function() return "" end,
                set = function(_, sourceKey)
                    if not self.db or not self.db.profile or sourceKey == "" or sourceKey == frameKey then return end
                    
                    local source = self.db.profile[sourceKey]
                    if not source then return end
                    
                    -- Deep copy function
                    local function deepCopy(orig)
                        local copy
                        if type(orig) == 'table' then
                            copy = {}
                            for k, v in pairs(orig) do
                                copy[k] = deepCopy(v)
                            end
                        else
                            copy = orig
                        end
                        return copy
                    end
                    
                    -- Copy all bar settings
                    if source.health then
                        self.db.profile[frameKey].health = deepCopy(source.health)
                    end
                    if source.power then
                        self.db.profile[frameKey].power = deepCopy(source.power)
                    end
                    if source.info then
                        self.db.profile[frameKey].info = deepCopy(source.info)
                    end
                    
                    update()
                end,
            },
            raidTargetIconSize = {
                type = "range",
                name = "Raid Target Icon Size",
                desc = "Size of the raid target marker icon.",
                min = 16, max = 64, step = 1,
                order = 0.92,
                get = function() return db.raidTargetIconSize or 32 end,
                set = function(_, v) db.raidTargetIconSize = v; update() end,
            },
            raidTargetIconOffsetX = {
                type = "range",
                name = "Raid Target Icon X Offset",
                desc = "Horizontal offset of the raid target icon from center-top of frame.",
                min = -100, max = 100, step = 1,
                order = 0.93,
                get = function() return db.raidTargetIconOffsetX or 0 end,
                set = function(_, v) db.raidTargetIconOffsetX = v; update() end,
            },
            raidTargetIconOffsetY = {
                type = "range",
                name = "Raid Target Icon Y Offset",
                desc = "Vertical offset of the raid target icon. Positive = up, negative = down.",
                min = -100, max = 100, step = 1,
                order = 0.94,
                get = function() return db.raidTargetIconOffsetY or 0 end,
                set = function(_, v) db.raidTargetIconOffsetY = v; update() end,
            },
            health = {
                type = "group",
                name = "Health Bar",
                order = 1,
                inline = true,
                args = self:GetBarOptions("health", db, update),
            },
            power = {
                type = "group",
                name = "Power Bar",
                order = 2,
                inline = true,
                args = self:GetBarOptions("power", db, update),
            },
            info = {
                type = "group",
                name = "Info Bar",
                order = 3,
                inline = true,
                args = self:GetBarOptions("info", db, update),
            },
        },
    }
end

-- Helper function to generate bar-specific options
function UnitFrames:GetBarOptions(barType, db, update)
    local options = {
        enabled = {
            type = "toggle",
            name = "Show",
            order = 1,
            get = function() return db[barType] and db[barType].enabled end,
            set = function(_, v) db[barType].enabled = v; update() end,
        },
        width = {
            type = "range",
            name = "Width",
            min = 50, max = 600, step = 1,
            order = 2,
            get = function() return db[barType] and db[barType].width or 220 end,
            set = function(_, v) db[barType].width = v; update() end,
        },
        height = {
            type = "range",
            name = "Height",
            min = 5, max = 100, step = 1,
            order = 3,
            get = function() 
                local defaults = {health = 24, power = 12, info = 10}
                return db[barType] and db[barType].height or defaults[barType] or 20
            end,
            set = function(_, v) db[barType].height = v; update() end,
        },
    }
    
    -- Add text format options for all bars
    options.textFormat = {
        type = "group",
        name = "Display Text",
        order = 3.5,
        inline = true,
        args = {
            tagHelp = {
                type = "execute",
                name = "Show Tag Help",
                desc = "Opens a window showing all available tags and examples",
                order = 0.5,
                func = function()
                    if UnitFrames and UnitFrames.ShowTagHelp then
                        UnitFrames:ShowTagHelp()
                    end
                end,
            },
            description = {
                type = "description",
                name = barType == "health" and "Use tags like [curhp], [maxhp], [perhp], [name], [level]. Mix with plain text: 'HP: [curhp]/[maxhp]'" or
                      barType == "power" and "Use tags like [curpp], [maxpp], [perpp]. Mix with plain text: 'Mana: [curpp]'" or
                      "Use tags like [name], [level]. Mix with plain text: '[name] Lvl [level]'",
                order = 1,
            },
            textLeft = {
                type = "input",
                name = "Left Text",
                desc = "Text to display on the left side of the " .. barType .. " bar.",
                order = 2,
                width = "full",
                get = function() 
                    local defaults = {health = "", power = "", info = "[name]"}
                    return db[barType] and db[barType].textLeft or defaults[barType] or ""
                end,
                set = function(_, v) db[barType].textLeft = v; update() end,
            },
            textCenter = {
                type = "input",
                name = "Center Text",
                desc = "Text to display in the center of the " .. barType .. " bar.",
                order = 3,
                width = "full",
                get = function() 
                    local defaults = {health = "[curhp] / [maxhp] ([perhp]%)", power = "", info = "[level]"}
                    return db[barType] and db[barType].textCenter or defaults[barType] or ""
                end,
                set = function(_, v) db[barType].textCenter = v; update() end,
            },
            textRight = {
                type = "input",
                name = "Right Text",
                desc = "Text to display on the right side of the " .. barType .. " bar.",
                order = 4,
                width = "full",
                get = function() return db[barType] and db[barType].textRight or "" end,
                set = function(_, v) db[barType].textRight = v; update() end,
            },
        },
    }
    
    -- Add attachTo for power and info bars
    if barType ~= "health" then
        options.attachTo = {
            type = "select",
            name = "Attach To",
            desc = "Attach the " .. barType:gsub("^%l", string.upper) .. " Bar to another bar.",
            order = 1.5,
            values = { health = "Health Bar", power = "Power Bar", info = "Info Bar", none = "None" },
            get = function() return db[barType] and db[barType].attachTo or "health" end,
            set = function(_, v) db[barType].attachTo = v; update() end,
        }
    end
    
    -- Add styling options
    options.classColor = {
        type = "toggle",
        name = "Class Colored Bar",
        desc = "Use class color for the " .. barType .. " bar.",
        order = 3.9,
        get = function() return db[barType] and db[barType].classColor end,
        set = function(_, v) db[barType].classColor = v; update() end,
    }
    
    -- Add hostility color option for health bars
    if barType == "health" then
        options.hostilityColor = {
            type = "toggle",
            name = "Hostility Colored Bar",
            desc = "Use reaction colors (green=friendly, yellow=neutral, red=hostile) for the " .. barType .. " bar.",
            order = 3.91,
            get = function() return db[barType] and db[barType].hostilityColor end,
            set = function(_, v) db[barType].hostilityColor = v; update() end,
        }
    end
    
    options.color = {
        type = "color",
        name = "Bar Color",
        hasAlpha = true,
        order = 4,
        get = function() 
            local defaults = {health = {0.2,0.8,0.2,1}, power = {0.2,0.4,0.8,1}, info = {0.8,0.8,0.2,1}}
            return unpack(db[barType] and db[barType].color or defaults[barType] or {1,1,1,1})
        end,
        set = function(_, r,g,b,a) db[barType].color = {r,g,b,a}; update() end,
    }
    
    options.alpha = {
        type = "range",
        name = "Bar Transparency",
        desc = "Set the transparency of the " .. barType .. " bar.",
        min = 0, max = 100, step = 1, order = 4.1,
        get = function() return math.floor(100 * (db[barType] and db[barType].alpha or (db[barType] and db[barType].color and db[barType].color[4]) or 1) + 0.5) end,
        set = function(_, v)
            local alpha = v / 100
            db[barType].alpha = alpha
            if db[barType] and db[barType].color then
                db[barType].color[4] = alpha
            else
                local defaults = {health = {0.2,0.8,0.2,alpha}, power = {0.2,0.4,0.8,alpha}, info = {0.8,0.8,0.2,alpha}}
                db[barType].color = defaults[barType] or {1,1,1,alpha}
            end
            update()
        end,
        bigStep = 5,
    }
    
    options.fontClassColor = {
        type = "toggle",
        name = "Class Colored Font",
        desc = "Use class color for the " .. barType .. " bar text.",
        order = 9.5,
        get = function() return db[barType] and db[barType].fontClassColor end,
        set = function(_, v) db[barType].fontClassColor = v; update() end,
    }
    
    options.bgColor = {
        type = "color",
        name = "Background Color",
        hasAlpha = true,
        order = 5,
        get = function() return unpack(db[barType] and db[barType].bgColor or {0,0,0,0.5}) end,
        set = function(_, r,g,b,a) db[barType].bgColor = {r,g,b,a}; update() end,
    }
    
    options.font = {
        type = "select",
        name = "Font",
        order = 6,
        values = function()
            local fonts = self.LSM and self.LSM:List("font") or (LibStub and LibStub("LibSharedMedia-3.0"):List("font")) or {}
            local out = {}
            for _, font in ipairs(fonts) do out[font] = font end
            return out
        end,
        get = function() return db[barType] and db[barType].font or "Friz Quadrata TT" end,
        set = function(_, v) db[barType].font = v; update() end,
    }
    
    options.fontSize = {
        type = "range",
        name = "Font Size",
        min = 6, max = 32, step = 1,
        order = 7,
        get = function() 
            local defaults = {health = 14, power = 12, info = 10}
            return db[barType] and db[barType].fontSize or defaults[barType] or 12
        end,
        set = function(_, v) db[barType].fontSize = v; update() end,
    }
    
    options.fontOutline = {
        type = "select",
        name = "Font Outline",
        order = 8,
        values = { NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" },
        get = function() return db[barType] and db[barType].fontOutline or "OUTLINE" end,
        set = function(_, v) db[barType].fontOutline = v; update() end,
    }
    
    options.fontColor = {
        type = "color",
        name = "Font Color",
        hasAlpha = true,
        order = 9,
        get = function() return unpack(db[barType] and db[barType].fontColor or {1,1,1,1}) end,
        set = function(_, r,g,b,a) db[barType].fontColor = {r,g,b,a}; update() end,
    }
    
    options.textPos = {
        type = "select",
        name = "Text Position",
        order = 11,
        values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" },
        get = function() return db[barType] and db[barType].textPos or "CENTER" end,
        set = function(_, v) db[barType].textPos = v; update() end,
    }
    
    options.texture = {
        type = "select",
        name = "Texture",
        order = 12,
        values = function()
            local LSM = self.LSM or (LibStub and LibStub("LibSharedMedia-3.0"))
            local textures = LSM and LSM:List("statusbar") or {}
            local out = {}
            for _, tex in ipairs(textures) do out[tex] = tex end
            return out
        end,
        get = function() return db[barType] and db[barType].texture or "Blizzard Raid Bar" end,
        set = function(_, v) db[barType].texture = v; update() end,
    }
    
    return options
end

function UnitFrames:GetOptions()
    return {
        name = "Unit Frames",
        type = "group",
        childGroups = "tab",
        args = {
            player = {
                name = "Player",
                type = "group",
                order = 1,
                args = self.GetPlayerOptions_Real and self:GetPlayerOptions_Real().args or {},
            },
            target = {
                name = "Target",
                type = "group",
                order = 2,
                args = self.GetTargetOptions_Real and self:GetTargetOptions_Real().args or {},
            },
            targettarget = {
                name = "Target of Target",
                type = "group",
                order = 3,
                args = self.GetTargetTargetOptions_Real and self:GetTargetTargetOptions_Real().args or {},
            },
            pet = {
                name = "Pet",
                type = "group",
                order = 4,
                args = self.GetPetOptions_Real and self:GetPetOptions_Real().args or {},
            },
            focus = {
                name = "Focus",
                type = "group",
                order = 5,
                args = self.GetFocusOptions_Real and self:GetFocusOptions_Real().args or {},
            },
            boss = {
                name = "Boss Frames",
                type = "group",
                order = 6,
                args = self.GetBossOptions_Real and self:GetBossOptions_Real().args or {},
            },
            partyRaid = {
                name = "Party/Raid",
                type = "group",
                order = 7,
                args = {
                    header = {
                        type = "header",
                        name = "MidnightUI Does Not Support Party/Raid Frames",
                        order = 1,
                    },
                    description1 = {
                        type = "description",
                        name = "With the release of WoW: Midnight (12.0), Blizzard introduced major changes to the unitframe API and the new Secure Party/Raid Frame system. Because these frames are now fully controlled by the client and no longer expose the hooks or layout controls that addons previously relied on, MidnightUI will not include support for modifying or replacing Party Frames or Raid Frames.",
                        order = 2,
                        fontSize = "medium",
                    },
                    spacer1 = {
                        type = "description",
                        name = " ",
                        order = 3,
                    },
                    description2 = {
                        type = "description",
                        name = "Players who want customizable group frames still have excellent options available. Please look on your favorite addon download site for addons like the following:",
                        order = 4,
                        fontSize = "medium",
                    },
                    addonList = {
                        type = "description",
                        name = "• Danders Frames\n• Grid2\n• VuhDo\n• Cell (hopefully)",
                        order = 5,
                        fontSize = "medium",
                    },
                    spacer2 = {
                        type = "description",
                        name = " ",
                        order = 6,
                    },
                    description3 = {
                        type = "description",
                        name = "These and many others provide full-featured, Midnight-compatible Party and Raid frame replacements.",
                        order = 7,
                        fontSize = "medium",
                    },
                    spacer3 = {
                        type = "description",
                        name = " ",
                        order = 8,
                    },
                    description4 = {
                        type = "description",
                        name = "MidnightUI will continue to focus on delivering a clean, modern experience for the parts of the interface that remain customizable under the updated WoW 12.0 API restrictions. Boss Frames are now supported - see the Boss Frames tab to configure them.",
                        order = 9,
                        fontSize = "medium",
                    },
                },
            },
        },
    }
end

function UnitFrames:GetPlayerOptions()
    if self.GetPlayerOptions_Real then
        return self:GetPlayerOptions_Real()
    end
    return nil
end

function UnitFrames:GetPetOptions_Real()
    return self:GenerateFrameOptions("Pet", "pet", "CreatePetFrame", "MidnightUI_PetFrame")
end

function UnitFrames:GetBossOptions_Real()
    local options = self:GenerateFrameOptions("Boss Frames", "boss", "CreateBossFrames", "MidnightUI_Boss1Frame")
    
    -- Add boss-specific options at the top
    options.args.enable = {
        type = "toggle",
        name = "Show Boss Frames",
        desc = "Enable custom boss frames",
        order = 0.5,
        get = function() return self.db and self.db.profile and self.db.profile.showBoss end,
        set = function(_, v)
            if not self.db or not self.db.profile then return end
            self.db.profile.showBoss = v
            if v then
                self:CreateBossFrames()
            else
                for i = 1, 5 do
                    local frame = _G["MidnightUI_Boss" .. i .. "Frame"]
                    if frame then
                        frame:Hide()
                        frame:SetParent(nil)
                    end
                end
            end
        end,
    }
    
    options.args.description = {
        type = "description",
        name = "Settings below apply to all 5 boss frames.",
        order = 0.6,
    }
    
    return options
end

    function UnitFrames:PLAYER_ENTERING_WORLD()
        if not self.db or not self.db.profile then
            return
        end
        
        HookBlizzardPlayerFrame(self)
        -- Only create frames if they don't already exist to prevent recreation on every zone change
        if self.db.profile.showPlayer and not _G["MidnightUI_PlayerFrame"] then self:CreatePlayerFrame() end
        if self.db.profile.showTarget and not _G["MidnightUI_TargetFrame"] then self:CreateTargetFrame() end
        if self.db.profile.showTargetTarget and not _G["MidnightUI_TargetTargetFrame"] then self:CreateTargetTargetFrame() end
        if self.db.profile.showPet and not _G["MidnightUI_PetFrame"] then self:CreatePetFrame() end
        if self.db.profile.showFocus and not _G["MidnightUI_FocusFrame"] then self:CreateFocusFrame() end
        if self.db.profile.showBoss and not _G["MidnightUI_Boss1Frame"] then self:CreateBossFrames() end
        
        -- Only hide Blizzard frames once - state drivers persist across zone changes
        if not self.blizzardFramesHidden then
            SetBlizzardFramesHidden(self)
            self.blizzardFramesHidden = true
        end
    end

    function UnitFrames:PLAYER_REGEN_ENABLED()
        -- Re-register state drivers when leaving combat to fix any visibility issues
        if not self.db or not self.db.profile then return end
        
        -- Update player frame to hide combat icon
        local playerFrame = _G["MidnightUI_PlayerFrame"]
        if playerFrame then
            self:UpdateUnitFrame("PlayerFrame", "player")
        end
        
        local targetFrame = _G["MidnightUI_TargetFrame"]
        if targetFrame and self.db.profile.showTarget then
            UnregisterStateDriver(targetFrame, "visibility")
            RegisterStateDriver(targetFrame, "visibility", "[@target,exists] show; hide")
        end
        
        local targetTargetFrame = _G["MidnightUI_TargetTargetFrame"]
        if targetTargetFrame and self.db.profile.showTargetTarget then
            UnregisterStateDriver(targetTargetFrame, "visibility")
            RegisterStateDriver(targetTargetFrame, "visibility", "[@targettarget,exists] show; hide")
        end
        
        local petFrame = _G["MidnightUI_PetFrame"]
        if petFrame and self.db.profile.showPet then
            UnregisterStateDriver(petFrame, "visibility")
            RegisterStateDriver(petFrame, "visibility", "[@pet,exists] show; hide")
        end
        
        local focusFrame = _G["MidnightUI_FocusFrame"]
        if focusFrame and self.db.profile.showFocus then
            UnregisterStateDriver(focusFrame, "visibility")
            RegisterStateDriver(focusFrame, "visibility", "[@focus,exists] show; hide")
        end
        
        -- Re-register boss frame state drivers
        if self.db.profile.showBoss then
            for i = 1, 5 do
                local bossFrame = _G["MidnightUI_Boss" .. i .. "Frame"]
                if bossFrame then
                    UnregisterStateDriver(bossFrame, "visibility")
                    RegisterStateDriver(bossFrame, "visibility", "[@boss" .. i .. ",exists] show; hide")
                end
            end
        end
    end

    function UnitFrames:PLAYER_REGEN_DISABLED()
        -- Update player frame to show combat icon when entering combat
        if not self.db or not self.db.profile then return end
        
        local playerFrame = _G["MidnightUI_PlayerFrame"]
        if playerFrame then
            self:UpdateUnitFrame("PlayerFrame", "player")
        end
    end

    function UnitFrames:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
        -- Update all boss frames when boss encounter starts/updates
        if self.db and self.db.profile and self.db.profile.showBoss then
            for i = 1, 5 do
                if UnitExists("boss" .. i) then
                    self:UpdateUnitFrame("Boss" .. i .. "Frame", "boss" .. i)
                end
            end
        end
    end

    function UnitFrames:UNIT_TARGET(event, unit)
        if unit == "target" and self.db.profile.showTargetTarget then
            self:UpdateUnitFrame("TargetTargetFrame", "targettarget")
        end
        if unit == "player" and self.db.profile.showPet then
            self:UpdateUnitFrame("PetFrame", "pet")
        end
        if unit == "focus" and self.db.profile.showFocus then
            self:UpdateUnitFrame("FocusFrame", "focus")
        end
    end
    
    local defaults = {
        profile = {
            enabled = true,
            showPlayer = true,
            showTarget = true,
            showTargetTarget = true,
            showPet = true,
            showBoss = true,
            spacing = 4,
            player = {
                position = { point = "CENTER", x = 0, y = -200 },
                health = {
                    enabled = true,
                    width = 220, height = 24,
                    color = {0.2, 0.8, 0.2, 1},
                    bgColor = {0, 0, 0, 0},
                    font = "Friz Quadrata TT", fontSize = 14, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    text = "[curhp] / [maxhp] ([perhp]%)", textPos = "CENTER",
                    textPresets = {
                        { name = "Current / Max (Percent)", value = "[curhp] / [maxhp] ([perhp]%)" },
                        { name = "Current Only", value = "[curhp]" },
                        { name = "Max Only", value = "[maxhp]" },
                        { name = "Percent Only", value = "[perhp]%" },
                    },
                    texture = "Blizzard Raid Bar"
                },
                power = {
                    enabled = true,
                    width = 220, height = 12,
                    color = {0.2, 0.4, 0.8, 1},
                    bgColor = {0.2, 0.4, 0.8, 0.2},
                    classColor = false,
                    font = "Friz Quadrata TT", fontSize = 12, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    text = "[curpp] / [maxpp]", textPos = "CENTER",
                    texture = "Blizzard Raid Bar"
                },
                info = {
                    enabled = true, width = 220, height = 10,
                    color = {0.8, 0.8, 0.2, 1},
                    bgColor = {0, 0, 0, 1},
                    font = "Friz Quadrata TT", fontSize = 10, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    text = nil, textPos = nil, -- migrated to textCenter
                    textLeft = nil,
                    textCenter = "[name] [level] [class]",
                    textRight = nil,
                    texture = "Blizzard Raid Bar"
                }
            },
            target = {
                position = { point = "TOPLEFT", x = 320, y = 0 },
                health = {
                    enabled = true,
                    width = 220, height = 24,
                    color = {0.2, 0.8, 0.2, 1},
                    bgColor = {0, 0, 0, 0.5},
                    font = "Friz Quadrata TT", fontSize = 14, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    text = "[curhp] / [maxhp] ([perhp]%)", textPos = "CENTER",
                    textPresets = {
                        { name = "Current / Max (Percent)", value = "[curhp] / [maxhp] ([perhp]%)" },
                        { name = "Current Only", value = "[curhp]" },
                        { name = "Max Only", value = "[maxhp]" },
                        { name = "Percent Only", value = "[perhp]%" },
                    },
                    texture = "Flat"
                },
                power = {
                    enabled = true,
                    width = 220, height = 12,
                    color = {0.2, 0.4, 0.8, 1},
                    bgColor = {0, 0, 0, 0.5},
                    font = "Friz Quadrata TT", fontSize = 12, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    text = "[curpp] / [maxpp]", textPos = "CENTER",
                    texture = "Flat"
                },
                info = {
                    enabled = true, width = 220, height = 10,
                    color = {0.8, 0.8, 0.2, 1},
                    bgColor = {0, 0, 0, 0.5},
                    font = "Friz Quadrata TT", fontSize = 10, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    text = nil, textPos = nil, -- migrated to textCenter
                    textLeft = nil,
                    textCenter = "[name] [level] [class]",
                    textRight = nil,
                    texture = "Flat"
                }
            },
            targettarget = {
                position = { point = "TOP", x = 0, y = -20 },
                health = {
                    enabled = true,
                    width = 220, height = 24,
                    color = {0.2, 0.8, 0.2, 1},
                    bgColor = {0, 0, 0, 0.5},
                    font = "Friz Quadrata TT", fontSize = 14, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    text = "[curhp] / [maxhp] ([perhp]%)", textPos = "CENTER",
                    textPresets = {
                        { name = "Current / Max (Percent)", value = "[curhp] / [maxhp] ([perhp]%)" },
                        { name = "Current Only", value = "[curhp]" },
                        { name = "Max Only", value = "[maxhp]" },
                        { name = "Percent Only", value = "[perhp]%" },
                    },
                    texture = "Flat"
                },
                power = {
                    enabled = true,
                    width = 220, height = 12,
                    color = {0.2, 0.4, 0.8, 1},
                    bgColor = {0, 0, 0, 0.5},
                    font = "Friz Quadrata TT", fontSize = 12, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    text = "[curpp] / [maxpp]", textPos = "CENTER",
                    texture = "Flat"
                },
                info = {
                    enabled = true, width = 220, height = 10,
                    color = {0.8, 0.8, 0.2, 1},
                    bgColor = {0, 0, 0, 0.5},
                    font = "Friz Quadrata TT", fontSize = 10, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    text = nil, textPos = nil, -- migrated to textCenter
                    textLeft = nil,
                    textCenter = "[name] [level] [class]",
                    textRight = nil,
                    texture = "Flat"
                }
            },
            pet = {
                position = { point = "CENTER", x = -200, y = -100 },
                health = {
                    enabled = true,
                    width = 220, height = 24,
                    color = {0.2, 0.8, 0.2, 1},
                    bgColor = {0, 0, 0, 0.5},
                    font = "Friz Quadrata TT", fontSize = 14, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    textLeft = "", textCenter = "[curhp] / [maxhp] ([perhp]%)", textRight = "",
                    texture = "Flat"
                },
                power = {
                    enabled = true,
                    width = 220, height = 12,
                    color = {0.2, 0.4, 0.8, 1},
                    bgColor = {0, 0, 0, 0.5},
                    font = "Friz Quadrata TT", fontSize = 12, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    textLeft = "", textCenter = "", textRight = "",
                    texture = "Flat"
                },
                info = {
                    enabled = true, width = 220, height = 10,
                    color = {0.8, 0.8, 0.2, 1},
                    bgColor = {0, 0, 0, 1},
                    font = "Friz Quadrata TT", fontSize = 10, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    textLeft = "[name]", textCenter = "[level]", textRight = "",
                    texture = "Flat"
                }
            },
            focus = {
                position = { point = "CENTER", x = 0, y = -100 },
                health = {
                    enabled = true,
                    width = 220, height = 24,
                    color = {0.2, 0.8, 0.2, 1},
                    bgColor = {0, 0, 0, 0},
                    font = "Friz Quadrata TT", fontSize = 14, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    text = "[curhp] / [maxhp] ([perhp]%)", textPos = "CENTER",
                    textPresets = {
                        { name = "Current / Max (Percent)", value = "[curhp] / [maxhp] ([perhp]%)" },
                        { name = "Current Only", value = "[curhp]" },
                        { name = "Max Only", value = "[maxhp]" },
                        { name = "Percent Only", value = "[perhp]%" },
                    },
                    texture = "Blizzard Raid Bar"
                },
                power = {
                    enabled = true,
                    width = 220, height = 12,
                    color = {0.2, 0.4, 0.8, 1},
                    bgColor = {0.2, 0.4, 0.8, 0.2},
                    classColor = false,
                    font = "Friz Quadrata TT", fontSize = 12, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    text = "[curpp] / [maxpp]", textPos = "CENTER",
                    texture = "Blizzard Raid Bar"
                },
                info = {
                    enabled = true, width = 220, height = 10,
                    color = {0.8, 0.8, 0.2, 1},
                    bgColor = {0, 0, 0, 1},
                    font = "Friz Quadrata TT", fontSize = 10, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    text = nil, textPos = nil, -- migrated to textCenter
                    textLeft = nil,
                    textCenter = "[name] [level] [class]",
                    textRight = nil,
                    texture = "Blizzard Raid Bar"
                }
            },
            boss = {
                basePosition = { point = "TOPRIGHT", x = -100, y = -200 },
                spacing = 80,
                raidTargetIconSize = 32,
                raidTargetIconOffsetX = 0,
                raidTargetIconOffsetY = 0,
                health = {
                    enabled = true,
                    width = 220, height = 24,
                    color = {0.8, 0.2, 0.2, 1},
                    hostilityColor = true,
                    bgColor = {0, 0, 0, 0.5},
                    font = "Friz Quadrata TT", fontSize = 14, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    textLeft = "", textCenter = "[curhp] / [maxhp] ([perhp]%)", textRight = "",
                    texture = "Blizzard Raid Bar"
                },
                power = {
                    enabled = true,
                    width = 220, height = 12,
                    color = {0.2, 0.4, 0.8, 1},
                    bgColor = {0, 0, 0, 0.5},
                    attachTo = "health",
                    font = "Friz Quadrata TT", fontSize = 12, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    textLeft = "", textCenter = "", textRight = "",
                    texture = "Blizzard Raid Bar"
                },
                info = {
                    enabled = true, width = 220, height = 10,
                    color = {0.8, 0.8, 0.2, 1},
                    bgColor = {0, 0, 0, 1},
                    attachTo = "health",
                    font = "Friz Quadrata TT", fontSize = 10, fontOutline = "OUTLINE", fontColor = {1,1,1,1},
                    textLeft = "[name]", textCenter = "[level]", textRight = "",
                    texture = "Blizzard Raid Bar"
                }
            }
        }
    }

UnitFrames.defaults = defaults

-- Migrate legacy info bar text to new left/center/right fields for backward compatibility

local function MigrateInfoBarText(opts)
    if opts and opts.info then
        -- Migrate legacy text field
        if opts.info.text and not (opts.info.textLeft or opts.info.textCenter or opts.info.textRight) then
            opts.info.textCenter = opts.info.text
            opts.info.text = nil
        end
        if opts.info.textPos then opts.info.textPos = nil end
        -- Ensure left/center/right fields are always strings
        if opts.info.textLeft == nil then opts.info.textLeft = "" end
        if opts.info.textCenter == nil then opts.info.textCenter = "" end
        if opts.info.textRight == nil then opts.info.textRight = "" end
    end
end

-- Call migration for all default unit frame options
do
    local defaults = UnitFrames and UnitFrames.defaults or nil
    if defaults and defaults.profile then
        MigrateInfoBarText(defaults.profile.player)
        MigrateInfoBarText(defaults.profile.target)
        MigrateInfoBarText(defaults.profile.targettarget)
        MigrateInfoBarText(defaults.profile.pet)
        MigrateInfoBarText(defaults.profile.focus)
        MigrateInfoBarText(defaults.profile.boss)
    end
end

                local function CreateBar(parent, opts, yOffset)
                    local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
                    bar:SetStatusBarTexture(LSM:Fetch("statusbar", opts.texture or "Flat"))
                    local safeColor = SanitizeColorTable(opts.color, {0.2, 0.8, 0.2, 1})
                    bar:SetStatusBarColor(unpack(safeColor))
                    bar:SetHeight(opts.height)
                    bar:SetWidth(opts.width)
                    bar:SetPoint("LEFT", 0, 0)
                    bar:SetPoint("RIGHT", 0, 0)
                    bar:SetPoint("TOP", 0, yOffset)
                    
                    -- Hide bars for target/targettarget/pet/focus/boss by default (state driver will show parent, UpdateUnitFrame shows bars)
                    local parentName = parent and parent:GetName() or ""
                    if parentName == "MidnightUI_TargetFrame" or parentName == "MidnightUI_TargetTargetFrame" or parentName == "MidnightUI_PetFrame" or parentName == "MidnightUI_FocusFrame" or (parentName and parentName:match("^MidnightUI_Boss%dFrame$")) then
                        bar:Hide()
                    end
                    
                    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
                    bar.bg:SetAllPoints()
                    bar.bg:SetDrawLayer("BACKGROUND", 0)  -- Ensure it's on the background layer
                    -- Use Bar settings for InfoBar background if this is the InfoBar
                    if opts._infoBar then
                        -- Use only the options provided via settings (dropdowns), not Bar module
                        local parentFrame = parent and parent.GetName and parent:GetName() or ""
                        local bg = opts.bgColor or {0,0,0,0.5}
                        local alpha = bg[4] ~= nil and bg[4] or 0.5
                        
                        -- For target/targettarget/focus frames, enforce minimum alpha since there's no parent frame background
                        if parentFrame == "MidnightUI_TargetFrame" or parentFrame == "MidnightUI_TargetTargetFrame" or parentFrame == "MidnightUI_FocusFrame" then
                            alpha = math.max(alpha, 0.5)
                        end
                        
                        bar.bg:SetColorTexture(bg[1], bg[2], bg[3], alpha)
                        bar.bg:SetAlpha(alpha)  -- Explicitly set the texture's alpha
                        bar.bg:Show()  -- Explicitly show the background texture
                    else
                        -- Always use solid black for health bar background
                        -- For power bar, use foreground color with 20% alpha for background
                        if opts and opts.bgColor and opts.bgColor[4] == 0.2 then
                            local fg = SanitizeColorTable(opts.color, {0.2, 0.4, 0.8, 1})
                            bar.bg:SetColorTexture(fg[1], fg[2], fg[3], 0.2)
                        elseif opts and opts.bgColor and opts.bgColor[1] == 0 and opts.bgColor[2] == 0 and opts.bgColor[3] == 0 then
                            local safeBG = SanitizeColorTable(opts.bgColor, {0, 0, 0, 0})
                            bar.bg:SetColorTexture(safeBG[1], safeBG[2], safeBG[3], safeBG[4])
                        else
                            local safeBG = SanitizeColorTable(opts.bgColor, {0,0,0,0.5})
                            bar.bg:SetColorTexture(safeBG[1], safeBG[2], safeBG[3], safeBG[4])
                        end
                    end
                    -- Info bar: create three FontStrings for left, center, right
                    if opts._infoBar then
                        bar.textLeft = bar:CreateFontString(nil, "OVERLAY")
                        bar.textLeft:SetPoint("LEFT", 4, 0)
                        bar.textLeft:SetJustifyH("LEFT")
                        bar.textCenter = bar:CreateFontString(nil, "OVERLAY")
                        bar.textCenter:SetPoint("CENTER", 0, 0)
                        bar.textCenter:SetJustifyH("CENTER")
                        bar.textRight = bar:CreateFontString(nil, "OVERLAY")
                        bar.textRight:SetPoint("RIGHT", -4, 0)
                        bar.textRight:SetJustifyH("RIGHT")
                    else
                        bar.text = bar:CreateFontString(nil, "OVERLAY")
                        bar.text:SetFont(LSM:Fetch("font", opts.font), opts.fontSize, opts.fontOutline)
                        bar.text:SetTextColor(unpack(opts.fontColor or {1,1,1,1}))
                        if opts.textPos == "LEFT" then
                            bar.text:SetPoint("LEFT", 4, 0)
                            bar.text:SetJustifyH("LEFT")
                        elseif opts.textPos == "RIGHT" then
                            bar.text:SetPoint("RIGHT", -4, 0)
                            bar.text:SetJustifyH("RIGHT")
                        else
                            bar.text:SetPoint("CENTER")
                            bar.text:SetJustifyH("CENTER")
                        end
                    end
                    return bar
                end


                -- ============================================================================
                -- 7. UNIT FRAME CREATION (Module Method for use by frame modules)
                -- ============================================================================
                
                function UnitFrames:CreateUnitFrame(key, unit, anchor, anchorTo, anchorPoint, x, y)
                                        -- ...existing code...
                    if frames[key] then
                        -- Critical: Stop OnUpdate script to prevent memory leaks
                        frames[key]:SetScript("OnUpdate", nil)
                        frames[key]:Hide()
                        frames[key]:SetParent(nil)
                        frames[key] = nil
                    end
                    local db = self.db.profile
                    local spacing = db.spacing
                    local frameKey = (key == "PlayerFrame" and "player") or (key == "TargetFrame" and "target") or (key == "TargetTargetFrame" and "targettarget") or (key == "PetFrame" and "pet") or (key == "FocusFrame" and "focus") or (key:match("^Boss(%d)Frame$") and "boss")
                    local frameDB = db[frameKey]
                    local h, p, i = frameDB.health, frameDB.power, frameDB.info
                    local totalHeight = (h.enabled and h.height or 0) + (p.enabled and p.height or 0) + (i.enabled and i.height or 0) + spacing * ((h.enabled and p.enabled and i.enabled) and 2 or (h.enabled and p.enabled) and 1 or 0)
                    local width = math.max(h.enabled and h.width or 0, p.enabled and p.width or 0, i.enabled and i.width or 0)

                    local frameType = "Button"
                    local template = "SecureUnitButtonTemplate,BackdropTemplate"
                    local frame = CreateFrame(frameType, "MidnightUI_"..key, UIParent, template)
                    frame:SetSize(width, totalHeight)

                    -- Use saved anchor/relative points if present, else fallback to CENTER
                    local myPoint = frameDB.anchorPoint or (anchorPoint or (frameDB.position and frameDB.position.point) or "CENTER")
                    local relPoint = frameDB.relativePoint or (anchorPoint or (frameDB.position and frameDB.position.point) or "CENTER")
                    local px = frameDB.posX or (frameDB.position and frameDB.position.x) or 0
                    local py = frameDB.posY or (frameDB.position and frameDB.position.y) or 0
                    local relTo = (type(anchorTo) == "table" and anchorTo) or UIParent
                    frame:SetPoint(myPoint, relTo, relPoint, px, py)
                    frame:SetFrameStrata("MEDIUM")
                    -- Only show player frame immediately; target/targettarget/focus visibility is controlled by state drivers
                    if unit == "player" then
                        frame:Show()
                    end

                    -- Enable drag-and-drop movement for unit frames (skip boss frames - they use a shared overlay)
                    local Movable = MidnightUI:GetModule("Movable", true)
                    if Movable and (key == "PlayerFrame" or key == "TargetFrame" or key == "TargetTargetFrame" or key == "PetFrame" or key == "FocusFrame") then
                        -- Remove any old highlight
                        if frame.movableHighlightFrame then
                            frame.movableHighlightFrame:Hide()
                            frame.movableHighlightFrame:SetParent(nil)
                            frame.movableHighlightFrame = nil
                        end
                        -- Create a dedicated child frame above all content
                        frame.movableHighlightFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
                        frame.movableHighlightFrame:SetFrameStrata("FULLSCREEN_DIALOG")
                        frame.movableHighlightFrame:SetFrameLevel(10000)
                        frame.movableHighlightFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                        frame.movableHighlightFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                        -- Keep highlight frame in sync with player frame position/size (but not visibility)
                        frame:HookScript("OnHide", function()
                            frame.movableHighlightFrame:Hide()
                        end)
                        frame:HookScript("OnSizeChanged", function()
                            frame.movableHighlightFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                            frame.movableHighlightFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                        end)
                        -- Green highlight (hidden by default)
                        frame.movableHighlightFrame:SetBackdrop({
                            bgFile = "Interface\\Buttons\\WHITE8X8",
                            edgeFile = "Interface\\Buttons\\WHITE8X8",
                            tile = false,
                            edgeSize = 2,
                            insets = { left = 0, right = 0, top = 0, bottom = 0 }
                        })
                        frame.movableHighlightFrame:SetBackdropColor(0, 0.5, 0, 0.2)  -- Semi-transparent green
                        frame.movableHighlightFrame:SetBackdropBorderColor(0, 1, 0, 1) -- Bright green border
                        -- Add a centered label with the frame name, styled like action bars
                        if not frame.movableHighlightLabel then
                            frame.movableHighlightLabel = frame.movableHighlightFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
                            frame.movableHighlightLabel:SetPoint("CENTER")
                            frame.movableHighlightLabel:SetText(key)
                            frame.movableHighlightLabel:SetTextColor(1, 1, 1, 1)
                            frame.movableHighlightLabel:SetShadowOffset(2, -2)
                            frame.movableHighlightLabel:SetShadowColor(0, 0, 0, 1)
                        end
                        frame.movableHighlightFrame:Hide() -- Hide by default

                        -- Enable the actual secure frame to be movable (required for StartMoving/StopMovingOrSizing)
                        frame:SetMovable(true)
                        frame:SetClampedToScreen(true)
                        
                        -- Make the highlight frame draggable (not the secure frame itself)
                        -- This allows dragging without interfering with secure frame click handlers
                        frame.movableHighlightFrame:SetMovable(true)
                        frame.movableHighlightFrame:EnableMouse(true)
                        frame.movableHighlightFrame:RegisterForDrag("LeftButton")
                        frame.movableHighlightFrame:SetClampedToScreen(true)
                        
                        local isDragging = false
                        frame.movableHighlightFrame:SetScript("OnDragStart", function(self)
                            if MidnightUI.moveMode then
                                isDragging = true
                                frame:StartMoving()
                            end
                        end)
                        
                        frame.movableHighlightFrame:SetScript("OnDragStop", function(self)
                            if not isDragging then return end
                            frame:StopMovingOrSizing()
                            isDragging = false
                            
                            local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
                            frameDB.anchorPoint = point or "CENTER"
                            frameDB.relativePoint = relativePoint or "CENTER"
                            frameDB.posX = xOfs or 0
                            frameDB.posY = yOfs or 0
                        end)
                        
                        -- Store reference to parent frame and register the highlight frame
                        frame.movableHighlightFrame.parentFrame = frame
                        frame.movableHighlightFrame.movableHighlight = frame.movableHighlightFrame -- Self-reference for Movable compatibility
                        frame.movableHighlightFrame.movableHighlightLabel = frame.movableHighlightLabel
                        table.insert(Movable.registeredFrames, frame.movableHighlightFrame)
                        -- Add compact <^Rv> nudge arrows
                        Movable:CreateNudgeArrows(frame, frameDB, function()
                            -- Reset callback: center the frame
                            frameDB.anchorPoint = "CENTER"
                            frameDB.relativePoint = "CENTER"
                            frameDB.posX = 0
                            frameDB.posY = 0
                            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                        end)
                        
                        -- For non-player frames, also hook the movableHighlightFrame to show arrows
                        -- This allows arrows to appear even when the unit frame is hidden
                        if key ~= "player" and frame.movableHighlightFrame and frame.arrows then
                            frame.movableHighlightFrame:HookScript("OnEnter", function()
                                if MidnightUI.moveMode and frame.arrows then
                                    -- Cancel any pending hide timer
                                    if frame.arrowHideTimer then
                                        frame.arrowHideTimer:Cancel()
                                        frame.arrowHideTimer = nil
                                    end
                                    Movable:UpdateNudgeArrows(frame)
                                end
                            end)
                            
                            frame.movableHighlightFrame:HookScript("OnLeave", function()
                                -- Delay hiding to allow mouse to move to arrows
                                frame.arrowHideTimer = C_Timer.NewTimer(0.3, function()
                                    if not MouseIsOver(frame.movableHighlightFrame) then
                                        -- Check if mouse is over any arrow button
                                        local overArrow = false
                                        for _, arrow in pairs(frame.arrows or {}) do
                                            if MouseIsOver(arrow) then
                                                overArrow = true
                                                break
                                            end
                                        end
                                        
                                        if not overArrow then
                                            Movable:HideNudgeArrows(frame)
                                        end
                                    end
                                    frame.arrowHideTimer = nil
                                end)
                            end)
                        end
                    end
                    -- ...existing code...


                    -- Remove legacy drag logic; handled by Movable:MakeFrameDraggable

                    -- Bar attachment logic
                    local yOffset = 0
                    local barRefs = {}
                    if h.enabled then
                        local healthBar = CreateBar(frame, h, yOffset)
                        healthBar:SetPoint("TOP", frame, "TOP", 0, yOffset)
                        frame.healthBar = healthBar
                        barRefs.health = healthBar
                        yOffset = yOffset - h.height - spacing
                    end
                    if p.enabled then
                        local attachTo = (p.attachTo or "health")
                        local attachBar = (attachTo ~= "none" and barRefs[attachTo]) or frame
                        local powerBar = CreateBar(frame, p, 0)
                        if attachBar and attachBar ~= frame then
                            powerBar:SetPoint("TOP", attachBar, "BOTTOM", 0, -spacing)
                        else
                            powerBar:SetPoint("TOP", frame, "TOP", 0, yOffset)
                            yOffset = yOffset - p.height - spacing
                        end
                        frame.powerBar = powerBar
                        barRefs.power = powerBar
                    end
                    if i.enabled then
                        local attachTo = (i.attachTo or "health")
                        local attachBar = (attachTo ~= "none" and barRefs[attachTo]) or frame
                        i._infoBar = true -- flag for CreateBar
                        local infoBar = CreateBar(frame, i, 0)
                        i._infoBar = nil
                        if attachBar and attachBar ~= frame then
                            infoBar:SetPoint("TOP", attachBar, "BOTTOM", 0, -spacing)
                        else
                            infoBar:SetPoint("TOP", frame, "TOP", 0, yOffset)
                        end
                        frame.infoBar = infoBar
                        barRefs.info = infoBar
                    end

                    -- Create status icons
                    -- AFK text (only for player)
                    if key == "PlayerFrame" then
                        if not frame.afkTextFrame then
                            -- Create a frame to hold the text so we can control frame level
                            frame.afkTextFrame = CreateFrame("Frame", nil, frame)
                            frame.afkTextFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
                            frame.afkTextFrame:SetSize(30, 14)
                            frame.afkTextFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
                            
                            frame.afkText = frame.afkTextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                            frame.afkText:SetPoint("CENTER", frame.afkTextFrame, "CENTER")
                            frame.afkText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
                            frame.afkText:SetText("AFK")
                            frame.afkText:SetTextColor(1, 1, 1, 1) -- White
                            frame.afkTextFrame:Hide()
                        end
                        
                        -- Combat icon (only for player)
                        if not frame.combatIconFrame then
                            -- Create a frame to hold the icon so we can control frame level
                            frame.combatIconFrame = CreateFrame("Frame", nil, frame)
                            frame.combatIconFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
                            frame.combatIconFrame:SetSize(16, 16)
                            frame.combatIconFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -6)
                            
                            frame.combatIcon = frame.combatIconFrame:CreateTexture(nil, "OVERLAY")
                            frame.combatIcon:SetAllPoints(frame.combatIconFrame)
                            frame.combatIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
                            frame.combatIcon:SetTexCoord(0.5, 1, 0, 0.5) -- Combat (crossed swords)
                            frame.combatIconFrame:Hide()
                        end
                        
                        -- Resting icon (only for player)
                        if not frame.restingIconFrame then
                            -- Create a frame to hold the icon so we can control frame level
                            frame.restingIconFrame = CreateFrame("Frame", nil, frame)
                            frame.restingIconFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
                            frame.restingIconFrame:SetSize(24, 24)
                            frame.restingIconFrame:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 2, -6)
                            
                            frame.restingIcon = frame.restingIconFrame:CreateTexture(nil, "OVERLAY")
                            frame.restingIcon:SetAllPoints(frame.restingIconFrame)
                            frame.restingIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
                            frame.restingIcon:SetTexCoord(0, 0.5, 0, 0.5) -- Resting icon
                            frame.restingIconFrame:Hide()
                        end
                        
                        -- Dead indicator (only for player)
                        if not frame.deadTextFrame then
                            -- Create a frame to hold the texture so we can control frame level
                            frame.deadTextFrame = CreateFrame("Frame", nil, frame)
                            frame.deadTextFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
                            frame.deadTextFrame:SetSize(64, 64)
                            frame.deadTextFrame:SetPoint("CENTER", frame, "CENTER")
                            
                            frame.deadTexture = frame.deadTextFrame:CreateTexture(nil, "OVERLAY")
                            frame.deadTexture:SetAllPoints(frame.deadTextFrame)
                            frame.deadTexture:SetTexture("Interface\\AddOns\\MidnightUI\\Media\\Skull")
                            frame.deadTexture:SetBlendMode("BLEND") -- Enable alpha blending for transparency
                            frame.deadTextFrame:Hide()
                        end
                    end
                    
                    -- Raid target icon (for all frames)
                    if not frame.raidTargetIconFrame then
                        -- Create a frame to hold the icon so we can control frame level
                        frame.raidTargetIconFrame = CreateFrame("Frame", nil, frame)
                        frame.raidTargetIconFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
                        
                        -- Create the texture inside the frame
                        frame.raidTargetIcon = frame.raidTargetIconFrame:CreateTexture(nil, "OVERLAY")
                        local iconSize = frameDB.raidTargetIconSize or 32
                        local offsetX = frameDB.raidTargetIconOffsetX or 0
                        local offsetY = frameDB.raidTargetIconOffsetY or 0
                        frame.raidTargetIconFrame:SetSize(iconSize, iconSize)
                        frame.raidTargetIconFrame:SetPoint("CENTER", frame, "TOP", offsetX, (iconSize / 2) + offsetY)
                        frame.raidTargetIcon:SetAllPoints(frame.raidTargetIconFrame)
                        frame.raidTargetIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
                        frame.raidTargetIconFrame:Hide()
                    end

                    if key == "PlayerFrame" then
                        frame:SetAttribute("unit", "player")
                        frame:SetAttribute("type", "target")
                        frame:SetAttribute("*type2", "togglemenu")
                        frame:RegisterForClicks("AnyUp")
                    elseif key == "TargetFrame" then
                        frame:SetAttribute("unit", "target")
                        frame:SetAttribute("type", "target")
                        frame:SetAttribute("*type2", "togglemenu")
                        frame:RegisterForClicks("AnyUp")
                    elseif key == "TargetTargetFrame" then
                        frame:SetAttribute("unit", "targettarget")
                        frame:SetAttribute("type", "target")
                        frame:SetAttribute("*type2", "togglemenu")
                        frame:RegisterForClicks("AnyUp")
                    elseif key == "PetFrame" then
                        frame:SetAttribute("unit", "pet")
                        frame:SetAttribute("type", "target")
                        frame:SetAttribute("*type2", "togglemenu")
                        frame:RegisterForClicks("AnyUp")
                    elseif key == "FocusFrame" then
                        frame:SetAttribute("unit", "focus")
                        frame:SetAttribute("type", "target")
                        frame:SetAttribute("*type2", "togglemenu")
                        frame:RegisterForClicks("AnyUp")
                    elseif key:match("^Boss(%d)Frame$") then
                        local bossNum = key:match("^Boss(%d)Frame$")
                        frame:SetAttribute("unit", "boss" .. bossNum)
                        frame:SetAttribute("type", "target")
                        frame:SetAttribute("*type2", "togglemenu")
                        frame:RegisterForClicks("AnyUp")
                    end

                    frames[key] = frame
                    
                    -- Register with click-to-cast addons (Clique, etc.)
                    if not ClickCastFrames then
                        ClickCastFrames = {}
                    end
                    ClickCastFrames[frame] = true
                    
                    -- Event-driven updates are already handled by UNIT_HEALTH, UNIT_POWER_UPDATE, etc.
                    -- No OnUpdate needed - reduces CPU usage significantly
                    
                    self:UpdateUnitFrame(key, unit)
                end

                -- Reset position function for PlayerFrame
                function UnitFrames:ResetUnitFramePosition(key)
                    local db = self.db.profile
                    local frameKey = (key == "PlayerFrame" and "player") or (key == "TargetFrame" and "target") or (key == "TargetTargetFrame" and "targettarget") or (key == "FocusFrame" and "focus") or (key:match("^Boss(%d)Frame$") and "boss" .. key:match("^Boss(%d)Frame$"))
                    if not db[frameKey] then return end
                    db[frameKey].posX = 0
                    db[frameKey].posY = 0
                    if frames[key] then
                        frames[key]:ClearAllPoints()
                        frames[key]:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                    end
                    self:UpdateUnitFrame(key, frameKey)
                end

                -- ============================================================================
                -- FRAME CREATION (MOVED TO INDIVIDUAL FILES)
                -- ============================================================================
                -- CreatePlayerFrame -> Modules/Frames/Player.lua
                -- CreateTargetFrame -> Modules/Frames/Target.lua
                -- CreateTargetTargetFrame -> Modules/Frames/TargetTarget.lua
                -- CreatePetFrame -> Modules/Frames/Pet.lua
                -- CreateFocusFrame -> Modules/Frames/Focus.lua
                -- CreateBossFrames -> Modules/Frames/Boss.lua

                function UnitFrames:UpdateUnitFrame(key, unit)
                    local db = self.db.profile
                    local frameKey = (key == "PlayerFrame" and "player") or (key == "TargetFrame" and "target") or (key == "TargetTargetFrame" and "targettarget") or (key == "PetFrame" and "pet") or (key == "FocusFrame" and "focus") or (key:match("^Boss(%d)Frame$") and "boss")
                    local frameDB = db[frameKey]
                    if not frameDB then return end
                    local h, p, i = frameDB.health, frameDB.power, frameDB.info
                    local frame = frames[key]
                    if not frame then return end
                    
                    -- Don't update frames for units that don't exist (let state drivers handle visibility)
                    if unit == "target" and not UnitExists("target") then
                        -- Let state driver handle frame visibility (don't call Hide() on secure frames)
                        return
                    end
                    
                    if unit == "targettarget" and not UnitExists("targettarget") then
                        -- Let state driver handle frame visibility (don't call Hide() on secure frames)
                        return
                    end
                    
                    if unit == "pet" and not UnitExists("pet") then
                        -- Let state driver handle frame visibility (don't call Hide() on secure frames)
                        return
                    end
                    
                    if unit == "focus" and not UnitExists("focus") then
                        -- Let state driver handle frame visibility (don't call Hide() on secure frames)
                        return
                    end
                    
                    if unit and unit:match("^boss%d$") and not UnitExists(unit) then
                        -- Let state driver handle frame visibility for boss frames
                        return
                    end
                    
                    -- For target/targettarget/pet/focus/boss, child bars visibility follows parent (state driver handles parent)
                    if (unit == "target" or unit == "targettarget" or unit == "pet" or unit == "focus" or (unit and unit:match("^boss%d$"))) and UnitExists(unit) then
                        -- State driver handles parent frame visibility - only manage child bars
                        if frame:IsShown() then
                            if frame.healthBar then frame.healthBar:Show() end
                            if frame.powerBar then frame.powerBar:Show() end
                            if frame.infoBar then frame.infoBar:Show() end
                        end
                    end
                    
                    -- Defensive: ensure safeCurhp and safeMaxhp are set before using, and use them everywhere
                    local safeCurhp = 0
                    if UnitHealth then
                        local ok, val = pcall(UnitHealth, unit)
                        if ok and val ~= nil then safeCurhp = val else safeCurhp = 0 end
                    end
                    local safeMaxhp = 0
                    if UnitHealthMax then
                        local ok, val = pcall(UnitHealthMax, unit)
                        if ok and val ~= nil then safeMaxhp = val else safeMaxhp = 0 end
                    end
                    -- Set health bar value and range so the bar length reflects current health
                    if frame.healthBar then
                        local min = 0
                        local max = 100  -- Use percentage scale to avoid secret value issues
                        local cur = 0
                        
                        -- Try to get health percentage using the newer API if available
                        local healthPct = GetHealthPct(unit, false)
                        
                        if healthPct and type(healthPct) == "number" then
                            -- Use percentage-based display (0-100 scale)
                            cur = healthPct
                            frame.healthBar:SetMinMaxValues(min, max)
                            frame.healthBar:SetValue(cur)
                        else
                            -- Fallback: Try direct health values (may fail with secret values)
                            local okMax, maxVal = pcall(tonumber, safeMaxhp)
                            if okMax and maxVal and type(maxVal) == "number" then
                                max = maxVal
                            else
                                max = 100
                            end
                            
                            local okCur, curVal = pcall(tonumber, safeCurhp)
                            if okCur and curVal and type(curVal) == "number" then
                                cur = curVal
                            else
                                cur = 0
                            end
                            
                            if max <= 0 then max = 100 end
                            
                            -- Try to set values with pcall protection
                            pcall(function()
                                if cur < 0 then cur = 0 end
                                if cur > max then cur = max end
                                frame.healthBar:SetMinMaxValues(min, max)
                                frame.healthBar:SetValue(cur)
                            end)
                        end
                    end

                    -- Calculate health percent robustly using GetHealthPct (handles secret values)
                    local hpPct = GetHealthPct(unit, false)
                    
                    -- Check if we got a usable number (not a secret value)
                    local safePct = nil
                    if hpPct then
                        local okNum, numVal = pcall(tonumber, hpPct)
                        if okNum and numVal and type(numVal) == "number" then
                            safePct = numVal
                        end
                    end
                    
                    -- Fallback: try manual calculation if we don't have a usable percentage
                    if not safePct then
                        -- Try to get values fresh and convert immediately
                        local cur, max
                        
                        local okHealth, healthVal = pcall(UnitHealth, unit)
                        if okHealth and healthVal then
                            local okNum, numVal = pcall(tonumber, healthVal)
                            if okNum and numVal and type(numVal) == "number" then
                                cur = numVal
                            end
                        end
                        
                        local okMax, maxVal = pcall(UnitHealthMax, unit)
                        if okMax and maxVal then
                            local okNum, numVal = pcall(tonumber, maxVal)
                            if okNum and numVal and type(numVal) == "number" then
                                max = numVal
                            end
                        end
                        
                        if cur and max and max > 0 then
                            local okDiv, result = pcall(function() return (cur / max) * 100 end)
                            if okDiv and type(result) == "number" then
                                safePct = result
                            end
                        end
                    end
                    
                    hpPct = safePct

                    -- Calculate power percent robustly
                    local ppPct = GetPowerPct(unit)
                    if ppPct then
                        local ok, floored = pcall(math.floor, ppPct)
                        if ok and floored then
                            ppPct = floored
                        else
                            ppPct = nil
                        end
                    else
                        ppPct = nil
                    end

                    -- Defensive: ensure all variables used in gsub are strings or numbers, never nil
                    local name = UnitName and UnitName(unit) or ""
                    local level = UnitLevel and UnitLevel(unit) or ""
                    local className = (UnitClass and select(1, UnitClass(unit))) or ""
                    local classToken = (UnitClass and select(2, UnitClass(unit))) or ""
                    -- safeCurhp and safeMaxhp already declared above, don't redeclare
                    local safeCurpp = 0
                    if UnitPower then
                        local ok, val = pcall(UnitPower, unit)
                        if ok and val ~= nil then 
                            -- Try to convert to number if it's a secret value
                            local okNum, numVal = pcall(tonumber, val)
                            if okNum and numVal and type(numVal) == "number" then
                                safeCurpp = numVal
                            else
                                safeCurpp = 0
                            end
                        else 
                            safeCurpp = 0 
                        end
                    end
                    local safeMaxpp = 0
                    if UnitPowerMax then
                        local ok, val = pcall(UnitPowerMax, unit)
                        if ok and val ~= nil then 
                            -- Try to convert to number if it's a secret value
                            local okNum, numVal = pcall(tonumber, val)
                            if okNum and numVal and type(numVal) == "number" then
                                safeMaxpp = numVal
                            else
                                safeMaxpp = 0
                            end
                        else 
                            safeMaxpp = 0 
                        end
                    end
                    if hpPct == nil then hpPct = 0 end
                    if ppPct == nil then ppPct = 0 end

                    -- Set health bar text using new segment system
                    if frame.healthBar then
                        local textLeft = (h and h.textLeft) or ""
                        local textCenter = (h and h.textCenter) or "[curhp] / [maxhp] ([perhp]%)"
                        local textRight = (h and h.textRight) or ""
                        
                        -- Ensure strings (convert nil/false to empty string)
                        if type(textLeft) ~= "string" then textLeft = "" end
                        if type(textCenter) ~= "string" then textCenter = "" end
                        if type(textRight) ~= "string" then textRight = "" end
                        
                        -- Get font settings
                        local font = LSM and LSM:Fetch("font", h.fontFace or "Arial Narrow") or "Fonts\\FRIZQT__.TTF"
                        local fontSize = h.fontSize or 12
                        local fontOutline = h.fontOutline or "OUTLINE"
                        local color
                        if h.fontClassColor then
                            local _, classToken = UnitClass(unit)
                            if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
                                local classColorValue = RAID_CLASS_COLORS[classToken]
                                color = {classColorValue.r, classColorValue.g, classColorValue.b, 1}
                            else
                                color = h.fontColor or {1, 1, 1, 1}
                            end
                        else
                            color = h.fontColor or {1, 1, 1, 1}
                        end
                        
                        -- Update text segments for each position
                        if textLeft ~= "" then
                            UpdateTextSegments(frame.healthBar, textLeft, unit, "LEFT", font, fontSize, fontOutline, color)
                        end
                        if textCenter ~= "" then
                            UpdateTextSegments(frame.healthBar, textCenter, unit, "CENTER", font, fontSize, fontOutline, color)
                        end
                        if textRight ~= "" then
                            UpdateTextSegments(frame.healthBar, textRight, unit, "RIGHT", font, fontSize, fontOutline, color)
                        end
                    end

                    -- Update status icons
                    -- Update AFK text (only for player)
                    if unit == "player" and frame.afkTextFrame then
                        if UnitIsAFK("player") then
                            frame.afkTextFrame:Show()
                        else
                            frame.afkTextFrame:Hide()
                        end
                    end
                    
                    -- Update Combat icon (only for player)
                    if unit == "player" and frame.combatIconFrame then
                        if UnitAffectingCombat("player") then
                            frame.combatIconFrame:Show()
                        else
                            frame.combatIconFrame:Hide()
                        end
                    end
                    
                    -- Update Resting icon (only for player)
                    if unit == "player" and frame.restingIconFrame then
                        if IsResting() then
                            frame.restingIconFrame:Show()
                        else
                            frame.restingIconFrame:Hide()
                        end
                    end
                    
                    -- Update Dead indicator (only for player)
                    if unit == "player" and frame.deadTextFrame then
                        if UnitIsDead("player") then
                            frame.deadTextFrame:Show()
                        else
                            frame.deadTextFrame:Hide()
                        end
                    end
                    
                    -- Update raid target icon (for all frames)
                    if frame.raidTargetIconFrame and frame.raidTargetIcon then
                        -- Update icon size and position from settings
                        local iconSize = frameDB.raidTargetIconSize or 32
                        local offsetX = frameDB.raidTargetIconOffsetX or 0
                        local offsetY = frameDB.raidTargetIconOffsetY or 0
                        frame.raidTargetIconFrame:SetSize(iconSize, iconSize)
                        frame.raidTargetIconFrame:ClearAllPoints()
                        frame.raidTargetIconFrame:SetPoint("CENTER", frame, "TOP", offsetX, (iconSize / 2) + offsetY)
                        
                        local raidTargetIndex = GetRaidTargetIndex(unit)
                        if raidTargetIndex then
                            frame.raidTargetIconFrame:Show()
                            SetRaidTargetIconTexture(frame.raidTargetIcon, raidTargetIndex)
                        else
                            frame.raidTargetIconFrame:Hide()
                        end
                    end

                    -- Set health bar color: class color if enabled, else hostility color, else custom/static color (no gradient, no arithmetic)
                    local colorSet = false
                    if h.classColor then
                        local _, classToken = UnitClass(unit)
                        if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
                            local classColorValue = RAID_CLASS_COLORS[classToken]
                            frame.healthBar:SetStatusBarColor(
                                tonumber(classColorValue.r) or 1,
                                tonumber(classColorValue.g) or 1,
                                tonumber(classColorValue.b) or 1,
                                1)
                            colorSet = true
                        end
                    elseif h.hostilityColor or (unit == "target" or unit == "targettarget" or unit == "focus" or (unit and unit:match("^boss%d$"))) then
                        -- Use hostility color if enabled OR if it's a target/targettarget/focus/boss frame (default behavior)
                        local reaction = UnitReaction(unit, "player")
                        if reaction then
                            if reaction >= 5 then
                                frame.healthBar:SetStatusBarColor(0.2, 0.8, 0.2, 1) -- Friendly (green)
                            elseif reaction == 4 then
                                frame.healthBar:SetStatusBarColor(1, 1, 0.2, 1) -- Neutral (yellow)
                            else
                                frame.healthBar:SetStatusBarColor(0.8, 0.2, 0.2, 1) -- Hostile (red)
                            end
                            colorSet = true
                        end
                    end
                    if not colorSet then
                        local fallback = {0.2, 0.8, 0.2, 1} -- bright green fallback
                        local c = SanitizeColorTable(h.color, fallback)
                        if not c or not c[1] or not c[2] or not c[3] then
                            print("[MidnightUI] Health bar fallback color used! h.color:", h.color)
                            c = fallback
                        end
                        -- Always set a visible, non-gray color
                        if c[1] == c[2] and c[2] == c[3] then
                            c = fallback
                        end
                        frame.healthBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
                        -- Set background from bgColor settings
                        if frame.healthBar.bg and frame.healthBar.bg.SetColorTexture then
                            local safeBgColor = SanitizeColorTable(h.bgColor, {0, 0, 0, 0.2})
                            frame.healthBar.bg:SetColorTexture(safeBgColor[1], safeBgColor[2], safeBgColor[3], safeBgColor[4] or 0.2)
                        end
                    end

                    -- Power Bar
                    local curpp = safeCurpp or 0
                    local maxpp = safeMaxpp or 0
                    if frame.powerBar then
                        frame.powerBar:SetMinMaxValues(0, maxpp)
                        frame.powerBar:SetValue(curpp)
                        frame.powerBar.text:SetFont(LSM:Fetch("font", p.font), p.fontSize, p.fontOutline)
                        if p.fontClassColor then
                            local _, classToken = UnitClass(unit)
                            if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
                                local classColorValue = RAID_CLASS_COLORS[classToken]
                                frame.powerBar.text:SetTextColor(classColorValue.r, classColorValue.g, classColorValue.b, 1)
                            else
                                frame.powerBar.text:SetTextColor(unpack(p.fontColor or {1,1,1,1}))
                            end
                        else
                            frame.powerBar.text:SetTextColor(unpack(p.fontColor or {1,1,1,1}))
                        end
                        -- Use Blizzard default color if not overridden
                        local powerColor = p.color
                        local useClassColor = p.classColor
                        local safePowerColor
                        if useClassColor then
                            local _, classToken = UnitClass(unit)
                            if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
                                local classColorValue = RAID_CLASS_COLORS[classToken]
                                safePowerColor = {
                                    tonumber(classColorValue.r) or 1,
                                    tonumber(classColorValue.g) or 1,
                                    tonumber(classColorValue.b) or 1,
                                    0.6
                                }
                                frame.powerBar:SetStatusBarColor(safePowerColor[1], safePowerColor[2], safePowerColor[3], safePowerColor[4])
                            else
                                safePowerColor = SanitizeColorTable(powerColor, {0.2,0.4,0.8,1})
                                frame.powerBar:SetStatusBarColor(safePowerColor[1], safePowerColor[2], safePowerColor[3], safePowerColor[4])
                            end
                        else
                            if not p._userSetColor and (not p.color or (p.color[1] == 0.2 and p.color[2] == 0.4 and p.color[3] == 0.8)) then
                                powerColor = GetPowerTypeColor(unit)
                            end
                            safePowerColor = SanitizeColorTable(powerColor, {0.2,0.4,0.8,1})
                            frame.powerBar:SetStatusBarColor(safePowerColor[1], safePowerColor[2], safePowerColor[3], safePowerColor[4])
                        end
                        
                        -- Set power bar background from bgColor settings
                        if frame.powerBar.bg and frame.powerBar.bg.SetColorTexture then
                            local safeBgColor = SanitizeColorTable(p.bgColor, {0, 0, 0, 0.2})
                            frame.powerBar.bg:SetColorTexture(safeBgColor[1], safeBgColor[2], safeBgColor[3], safeBgColor[4] or 0.2)
                        end
                        
                        -- Set power bar text using new segment system
                        local textLeft = p and p.textLeft or ""
                        local textCenter = p and p.textCenter or ""
                        local textRight = p and p.textRight or ""
                        
                        -- Get font settings
                        local font = LSM and LSM:Fetch("font", p.fontFace or "Arial Narrow") or "Fonts\\FRIZQT__.TTF"
                        local fontSize = p.fontSize or 12
                        local fontOutline = p.fontOutline or "OUTLINE"
                        local color
                        if p.fontClassColor then
                            local _, classToken = UnitClass(unit)
                            if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
                                local classColorValue = RAID_CLASS_COLORS[classToken]
                                color = {classColorValue.r, classColorValue.g, classColorValue.b, 1}
                            else
                                color = p.fontColor or {1, 1, 1, 1}
                            end
                        else
                            color = p.fontColor or {1, 1, 1, 1}
                        end
                        
                        -- Update text segments for each position
                        if textLeft ~= "" then
                            UpdateTextSegments(frame.powerBar, textLeft, unit, "LEFT", font, fontSize, fontOutline, color)
                        end
                        if textCenter ~= "" then
                            UpdateTextSegments(frame.powerBar, textCenter, unit, "CENTER", font, fontSize, fontOutline, color)
                        end
                        if textRight ~= "" then
                            UpdateTextSegments(frame.powerBar, textRight, unit, "RIGHT", font, fontSize, fontOutline, color)
                        end
                    end

                    -- Set static info bar text: character name and level
                    if frame.infoBar then
                        local infoBar = frame.infoBar
                        local font, fontSize, fontOutline = LSM:Fetch("font", i.font), i.fontSize, i.fontOutline
                        local color
                        if i.fontClassColor then
                            local _, classToken = UnitClass("player")
                            if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
                                local classColorValue = RAID_CLASS_COLORS[classToken]
                                color = {classColorValue.r, classColorValue.g, classColorValue.b, 1}
                            else
                                color = (i.fontColor or {1,1,1,1})
                            end
                        else
                            color = (i.fontColor or {1,1,1,1})
                        end
                        -- Set info bar bar color to class color if classColor is enabled (only for PlayerFrame)
                        if key == "PlayerFrame" and i.classColor then
                            local _, classToken = UnitClass("player")
                            if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
                                local classColorValue = RAID_CLASS_COLORS[classToken]
                                local barAlpha = (i.color and i.color[4]) or 0.6
                                -- Set the main bar color with bar alpha
                                infoBar:SetStatusBarColor(classColorValue.r, classColorValue.g, classColorValue.b, barAlpha)
                                -- Set the background from bgColor settings, not bar color
                                if infoBar.bg then
                                    if infoBar.bg.SetTexture then infoBar.bg:SetTexture(nil) end
                                    if infoBar.bg.SetColorTexture then
                                        local safeBgColor = SanitizeColorTable(i.bgColor, {0, 0, 0, 0.5})
                                        infoBar.bg:SetColorTexture(safeBgColor[1], safeBgColor[2], safeBgColor[3], safeBgColor[4] or 0.5)
                                        infoBar.bg:SetAlpha(safeBgColor[4] or 0.5)  -- Explicitly set texture alpha
                                        infoBar.bg:Show()  -- Explicitly show the background
                                    end
                                end
                            end
                        else
                            -- fallback to configured color
                            local safeColor = SanitizeColorTable(i.color, {0.8, 0.8, 0.2, 1})
                            infoBar:SetStatusBarColor(safeColor[1], safeColor[2], safeColor[3], safeColor[4] or 1)
                            if infoBar.bg and infoBar.bg.SetColorTexture then
                                -- Use bgColor from settings for background, not bar color
                                local safeBgColor = SanitizeColorTable(i.bgColor, {0, 0, 0, 0.5})
                                -- For target/targettarget/focus, enforce minimum 0.5 alpha
                                if unit == "target" or unit == "targettarget" or unit == "focus" then
                                    local bgAlpha = math.max(safeBgColor[4] or 0.5, 0.5)
                                    infoBar.bg:SetColorTexture(safeBgColor[1], safeBgColor[2], safeBgColor[3], bgAlpha)
                                    infoBar.bg:SetAlpha(bgAlpha)  -- Explicitly set texture alpha
                                else
                                    -- For player/pet/boss, use bgColor as-is
                                    infoBar.bg:SetColorTexture(safeBgColor[1], safeBgColor[2], safeBgColor[3], safeBgColor[4] or 0.5)
                                    infoBar.bg:SetAlpha(safeBgColor[4] or 0.5)  -- Explicitly set texture alpha
                                end
                                infoBar.bg:Show()  -- Explicitly show the background
                            end
                        end
                        
                        -- Set info bar text using new segment system
                        local textLeft = i and i.textLeft or "[name]"
                        local textCenter = i and i.textCenter or "[level]"
                        local textRight = i and i.textRight or ""
                        
                        -- Update text segments for each position
                        if textLeft ~= "" then
                            UpdateTextSegments(infoBar, textLeft, unit, "LEFT", font, fontSize, fontOutline, color)
                        end
                        if textCenter ~= "" then
                            UpdateTextSegments(infoBar, textCenter, unit, "CENTER", font, fontSize, fontOutline, color)
                        end
                        if textRight ~= "" then
                            UpdateTextSegments(infoBar, textRight, unit, "RIGHT", font, fontSize, fontOutline, color)
                        end
                    end
                end



                function UnitFrames:PLAYER_TARGET_CHANGED()
                    if self.db.profile.showTarget then 
                        -- Force show target frame if target exists (fixes self-targeting after login)
                        -- Skip Show() calls in combat to prevent taint
                        if not InCombatLockdown() then
                            local targetFrame = _G["MidnightUI_TargetFrame"]
                            if targetFrame then
                                local hasTarget = pcall(UnitExists, "target")
                                if hasTarget then
                                    targetFrame:Show()
                                    if targetFrame.healthBar then targetFrame.healthBar:Show() end
                                    if targetFrame.powerBar then targetFrame.powerBar:Show() end
                                    if targetFrame.infoBar then targetFrame.infoBar:Show() end
                                end
                            end
                        end
                        -- Delay update slightly to allow unit data to populate
                        C_Timer.After(0.05, function()
                            local hasTarget = pcall(UnitExists, "target")
                            if hasTarget then
                                self:UpdateUnitFrame("TargetFrame", "target")
                            end
                        end)
                    end
                    if self.db.profile.showTargetTarget then 
                        C_Timer.After(0.05, function()
                            local hasTarget = pcall(UnitExists, "targettarget")
                            if hasTarget then
                                self:UpdateUnitFrame("TargetTargetFrame", "targettarget")
                            end
                        end)
                    end
                    if self.db.profile.showFocus then 
                        C_Timer.After(0.05, function()
                            if UnitExists("focus") then
                                self:UpdateUnitFrame("FocusFrame", "focus")
                            end
                        end)
                    end
                end

                function UnitFrames:UNIT_HEALTH(event, unit)
                    if unit == "player" and self.db.profile.showPlayer then self:UpdateUnitFrame("PlayerFrame", "player") end
                    if unit == "target" and self.db.profile.showTarget then self:UpdateUnitFrame("TargetFrame", "target") end
                    if unit == "targettarget" and self.db.profile.showTargetTarget then self:UpdateUnitFrame("TargetTargetFrame", "targettarget") end
                    if unit == "pet" and self.db.profile.showPet then self:UpdateUnitFrame("PetFrame", "pet") end
                    if unit == "focus" and self.db.profile.showFocus then self:UpdateUnitFrame("FocusFrame", "focus") end
                    -- Handle boss frames
                    if self.db.profile.showBoss and unit and unit:match("^boss%d$") then
                        local bossNum = unit:match("^boss(%d)$")
                        if bossNum then
                            self:UpdateUnitFrame("Boss" .. bossNum .. "Frame", unit)
                        end
                    end
                    -- Do NOT call SetBlizzardFramesHidden - causes catastrophic state driver accumulation
                end

                function UnitFrames:UNIT_MAXHEALTH(event, unit)
                    -- Update when max health changes
                    self:UNIT_HEALTH(event, unit)
                end

                function UnitFrames:UNIT_POWER_UPDATE(event, unit)
                    if unit == "player" and self.db.profile.showPlayer then self:UpdateUnitFrame("PlayerFrame", "player") end
                    if unit == "target" and self.db.profile.showTarget then self:UpdateUnitFrame("TargetFrame", "target") end
                    if unit == "targettarget" and self.db.profile.showTargetTarget then self:UpdateUnitFrame("TargetTargetFrame", "targettarget") end
                    if unit == "focus" and self.db.profile.showFocus then self:UpdateUnitFrame("FocusFrame", "focus") end
                    -- Handle boss frames
                    if self.db.profile.showBoss and unit and unit:match("^boss%d$") then
                        local bossNum = unit:match("^boss(%d)$")
                        if bossNum then
                            self:UpdateUnitFrame("Boss" .. bossNum .. "Frame", unit)
                        end
                    end
                    -- Do NOT call SetBlizzardFramesHidden - causes catastrophic state driver accumulation
                end

                function UnitFrames:UNIT_DISPLAYPOWER(event, unit)
                    if unit == "player" and self.db.profile.showPlayer then self:UpdateUnitFrame("PlayerFrame", "player") end
                    if unit == "target" and self.db.profile.showTarget then self:UpdateUnitFrame("TargetFrame", "target") end
                    if unit == "targettarget" and self.db.profile.showTargetTarget then self:UpdateUnitFrame("TargetTargetFrame", "targettarget") end
                    if unit == "focus" and self.db.profile.showFocus then self:UpdateUnitFrame("FocusFrame", "focus") end
                    -- Handle boss frames
                    if self.db.profile.showBoss and unit and unit:match("^boss%d$") then
                        local bossNum = unit:match("^boss(%d)$")
                        if bossNum then
                            self:UpdateUnitFrame("Boss" .. bossNum .. "Frame", unit)
                        end
                    end
                    -- Do NOT call SetBlizzardFramesHidden - causes catastrophic state driver accumulation
                end

                function UnitFrames:OnInitialize()
                    self:RegisterMessage("MIDNIGHTUI_DB_READY", "OnDBReady")
                    self:RegisterEvent("PLAYER_ENTERING_WORLD")
                end

                -- Public method to show tag help window
                function UnitFrames:ShowTagHelp()
                    ShowTagHelp()
                end

                function UnitFrames:OnDBReady()
                    if not MidnightUI.db.profile.modules.unitframes then return end
                    self.db = MidnightUI.db:RegisterNamespace("UnitFrames", defaults)
                    
                    -- CRITICAL: Unregister events first to prevent duplicate handlers on reload
                    self:UnregisterEvent("UNIT_HEALTH")
                    self:UnregisterEvent("UNIT_MAXHEALTH")
                    self:UnregisterEvent("UNIT_POWER_UPDATE")
                    self:UnregisterEvent("UNIT_DISPLAYPOWER")
                    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
                    self:UnregisterEvent("PLAYER_FOCUS_CHANGED")
                    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
                    self:UnregisterEvent("UNIT_TARGET")
                    self:UnregisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
                    self:UnregisterEvent("PLAYER_FLAGS_CHANGED")
                    self:UnregisterEvent("PLAYER_UPDATE_RESTING")
                    
                    -- Now register them cleanly
                    self:RegisterEvent("UNIT_HEALTH")
                    self:RegisterEvent("UNIT_MAXHEALTH")
                    self:RegisterEvent("UNIT_POWER_UPDATE")
                    self:RegisterEvent("UNIT_DISPLAYPOWER")
                    self:RegisterEvent("PLAYER_TARGET_CHANGED")
                    self:RegisterEvent("PLAYER_FOCUS_CHANGED")
                    self:RegisterEvent("PLAYER_REGEN_ENABLED")
                    self:RegisterEvent("PLAYER_REGEN_DISABLED")
                    self:RegisterEvent("UNIT_TARGET")
                    self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
                    self:RegisterEvent("PLAYER_FLAGS_CHANGED")
                    self:RegisterEvent("PLAYER_UPDATE_RESTING")
                    self:PLAYER_ENTERING_WORLD()
                end

                function UnitFrames:GetTargetOptions()
                    if self.GetTargetOptions_Real then
                        return self:GetTargetOptions_Real()
                    end
                    return nil
                end

                function UnitFrames:GetTargetTargetOptions()
                    if self.GetTargetTargetOptions_Real then
                        return self:GetTargetTargetOptions_Real()
                    end
                    return nil
                end