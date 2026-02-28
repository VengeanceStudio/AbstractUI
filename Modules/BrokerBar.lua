
local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local BrokerBar = MidnightUI:NewModule("BrokerBar", "AceEvent-3.0")
local LDB = LibStub("LibDataBroker-1.1")
local LSM = LibStub("LibSharedMedia-3.0")
local Masque = LibStub("Masque", true)

-- Framework integration - use global reference for ColorPalette
local FrameFactory, FontKit
local ColorPalette = _G.MidnightUI_ColorPalette

-- Make BrokerBar globally accessible for broker files
_G.BrokerBar = BrokerBar

-- Update all bar widgets' fonts when the global font changes
function BrokerBar:UpdateAllFonts()
    for barID, bar in pairs(bars) do
        self:UpdateBarLayout(barID)
    end
end

-- ============================================================================
-- 1. LOCAL VARIABLES & DATA CACHES
-- ============================================================================
local bars = {}         
local widgets = {}      
local masqueGroup = nil 

-- Layout Cache
local layoutCache = { 
    LEFT = {}, 
    CENTER = {}, 
    RIGHT = {} 
}

-- Interactive Frame References
local friendsFrame, guildFrame, volFrame
local scrollChild, gScrollChild
local guildMotD, listSeparator
local friendTitle, friendFooter, guildTitle, guildFooter
local headerRefs, guildHeaderRefs = {}, {}

-- Module Object References
local friendObj, guildObj, diffObj, clockObj, sysObj, goldObj, bagObj, duraObj, locObj, tokenObj, volObj, ilvlObj

-- Data Cache
local lastState = { 
    timeH = -1, timeM = -1, fps = -1, ms = -1, 
    bagFree = -1, bagTotal = -1, gold = -1, dura = -1, 
    friends = -1, guild = -1, zone = "", diffID = -1, 
    diffPlayers = -1, vol = -1, token = -1, ilvl = -1
}

-- Mappings
local LABEL_MAP_FULL = { 
    MidnightDiff = "Difficulty", MidnightVolume = "Volume", MidnightDura = "Durability", 
    MidnightClock = "Clock", MidnightBags = "Bags", MidnightFriends = "Friends", 
    MidnightGold = "Gold", MidnightGuild = "Guild", MidnightLocation = "Location", 
    MidnightSystem = "System", MidnightToken = "Token", MidnightILvl = "Item Level"
}

local LABEL_MAP_SHORT = { 
    MidnightDiff = "Diff", MidnightVolume = "Vol", MidnightDura = "Dura", 
    MidnightClock = "Time", MidnightBags = "Bags", MidnightFriends = "Frnd", 
    MidnightGold = "Gold", MidnightGuild = "Gld", MidnightLocation = "Loc", 
    MidnightSystem = "Sys", MidnightToken = "Tok", MidnightILvl = "iLvL" 
}

local SHORTEN_REPLACEMENTS = {
    ["Heroic"] = "H", ["Mythic"] = "M", ["Normal"] = "N", ["Finder"] = "LFR", 
    ["Player"] = "P", ["Timewalking"] = "TW", ["Follower"] = "F", ["Tier"] = "T", 
    ["Story"] = "S", ["Delve"] = "D", ["Keystone"] = "+", ["%("] = "", ["%)"] = "",
}

classTokenLookup = {}
if _G.FillLocalizedClassList then
    local temp = {}
    FillLocalizedClassList(temp, false) 
    for token, name in pairs(temp) do 
        classTokenLookup[name] = token 
    end
    wipe(temp)
    FillLocalizedClassList(temp, true) 
    for token, name in pairs(temp) do 
        classTokenLookup[name] = token 
    end
end

-- SKINS DEFINITIONS
local SKINS = {
    ["Midnight"] = { 
        backdrop = { 
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground", 
            edgeFile = nil, 
            tile = false, tileSize = 0, edgeSize = 0, 
            insets = { left = 0, right = 0, top = 0, bottom = 0 } 
        }, 
        borderAlpha = 0 
    },
    ["Blizzard"] = { 
        backdrop = { 
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", 
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", 
            tile = true, tileSize = 16, edgeSize = 16, 
            insets = { left = 4, right = 4, top = 4, bottom = 4 } 
        }, 
        borderAlpha = 1 
    },
    ["Glass"] = { 
        backdrop = { 
            bgFile = "Interface\\Buttons\\WHITE8X8", 
            edgeFile = "Interface\\Buttons\\WHITE8X8", 
            tile = false, tileSize = 0, edgeSize = 1, 
            insets = { left = 1, right = 1, top = 1, bottom = 1 } 
        }, 
        borderAlpha = 0.4 
    },
    ["Flat"] = { 
        backdrop = { 
            bgFile = "Interface\\Buttons\\WHITE8X8", 
            edgeFile = "Interface\\Buttons\\WHITE8X8", 
            tile = false, tileSize = 0, edgeSize = 1, 
            insets = { left = 0, right = 0, top = 0, bottom = 0 } 
        }, 
        borderAlpha = 1 
    },
    ["Transparent"] = { 
        backdrop = { 
            bgFile = nil, 
            edgeFile = nil, 
            tile = false, tileSize = 0, edgeSize = 0, 
            insets = { left = 0, right = 0, top = 0, bottom = 0 } 
        }, 
        borderAlpha = 0 
    },
    ["Outline"] = { 
        backdrop = { 
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", 
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", 
            tile = true, tileSize = 16, edgeSize = 12, 
            insets = { left = 3, right = 3, top = 3, bottom = 3 } 
        }, 
        borderAlpha = 1 
    },
    ["Tooltip"] = { 
        backdrop = { 
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", 
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", 
            tile = true, tileSize = 16, edgeSize = 16, 
            insets = { left = 4, right = 4, top = 4, bottom = 4 } 
        }, 
        borderAlpha = 1 
    }
}

-- ============================================================================
-- 2. DATABASE DEFAULTS
-- ============================================================================
local defaults = {
    profile = {
        locked = false,
        font = "Friz Quadrata TT",
        fontSize = 12,
        fontColor = {r = 1, g = 1, b = 1},
        useClassColor = false,
        useStandardTime = true,
        spacing = 15,
        goldData = {},      
        tokenHistory = {},
        brokers = {}, -- Initialize empty brokers table
        lastVolume = 1, -- PERSISTENT VOLUME STORAGE
        barSkin = "Midnight", 
        bars = { 
            ["MainBar"] = { 
                enabled = true, 
                fullWidth = true, 
                width = 600, 
                height = 24, 
                scale = 1.0,
                alpha = 0.6,
                useThemeColor = true,
                color = {r = 0.1, g = 0.1, b = 0.1}, 
                texture = "Blizzard", 
                skin = "Midnight",    
                padding = 10, 
                point = "TOP", 
                x = 0, y = 0,
                font = "Friz Quadrata TT",
            },
        },
    }
}

local function ShortenValue(text)
    if not text or text == "" then 
        return "" 
    end
    if tostring(text):find("|TInterface") then 
        return text 
    end
    local short = tostring(text)
    for k, v in pairs(SHORTEN_REPLACEMENTS) do 
        short = short:gsub(k, v) 
    end
    if strlenutf8(short) > 60 then 
        short = short:sub(1, 60) 
    end
    return short
end

-- Make helper functions global for broker files
function GetColor()
    -- FIX: Ensure DB is loaded if Helper is called early
    if not BrokerBar.db then return 1, 1, 1 end
    
    -- Use theme colors if available
    if ColorPalette then
        return ColorPalette:GetColor('text-primary')
    end
    
    local db = BrokerBar.db.profile
    if db.useClassColor then
        local _, class = UnitClass("player")
        local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        return color.r, color.g, color.b
    end
    return db.fontColor.r, db.fontColor.g, db.fontColor.b
end

function FormatTimeDisplay(h, m, standard)
    if standard then
        local suffix = (h >= 12) and " PM" or " AM"
        local hour = h % 12
        if hour == 0 then 
            hour = 12 
        end
        return string.format("%d:%02d%s", hour, m, suffix)
    else
        return string.format("%02d:%02d", h, m)
    end
end

function FormatSeconds(seconds)
    if not seconds or seconds <= 0 then 
        return "Now" 
    end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    if days > 0 then 
        return string.format("%dd %dh %dm", days, hours, mins)
    else 
        return string.format("%dh %dm", hours, mins) 
    end
end

-- Helper to format numbers with commas (e.g., 1,234,567)
function FormatWithCommas(amount)
    local formatted = tostring(amount)
    while true do
        formatted, k = formatted:gsub("^(%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

function FormatMoney(amount)
    if not amount then 
        return "0c" 
    end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    local str = ""
    if gold > 0 then 
        str = str .. string.format("%s|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t ", FormatWithCommas(gold)) 
    end
    if silver > 0 or gold > 0 then 
        str = str .. string.format("%02d|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t ", silver) 
    end
    str = str .. string.format("%02d|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t ", copper)
    return str
end

function FormatTokenPrice(amount)
    if not amount then 
        return "N/A" 
    end
    local gold = math.floor(amount / 10000)
    return string.format("%s|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t", FormatWithCommas(gold))
end

function ApplyTooltipStyle(tip)
    if not tip then return end
    
    -- Don't style tooltips with embedded content to avoid taint
    if tip.ItemTooltip and tip.ItemTooltip:IsShown() then
        return
    end
    
    -- Hide default Blizzard tooltip borders
    if tip.NineSlice then
        tip.NineSlice:SetAlpha(0)
    end
    if tip.TopOverlay then
        tip.TopOverlay:SetAlpha(0)
    end
    if tip.BottomOverlay then
        tip.BottomOverlay:SetAlpha(0)
    end
    
    -- Apply themed backdrop
    local ColorPalette = _G.MidnightUI_ColorPalette
    if ColorPalette and tip.SetBackdrop then
        tip:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        -- Use tooltip-bg if it exists in theme, otherwise fallback to panel-bg
        local bgColor = ColorPalette:GetColorTable('tooltip-bg')
        if not bgColor or (bgColor.r == 1 and bgColor.g == 1 and bgColor.b == 1) then
            -- tooltip-bg not defined or is the white fallback, use panel-bg instead
            bgColor = ColorPalette:GetColorTable('panel-bg')
        end
        tip:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
        tip:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    end
    
    -- Use pcall to safely apply styling without causing taint
    local success = pcall(function()
        local db = BrokerBar.db.profile
        local fontPath, fontSize, fontFlags
        
        -- Use framework fonts if available
        if FontKit then
            fontPath = FontKit:GetFont('body')
            fontSize = FontKit:GetSize('normal') + 2  -- Slightly larger for tooltip header
            fontFlags = "OUTLINE"
        else
            fontPath = LSM:Fetch("font", db.font) or "Fonts\\FRIZQT__.ttf"
            fontSize = db.fontSize + 2
            fontFlags = "OUTLINE"
        end
        
        local name = tip:GetName()
        
        if not name then return end
        
        if _G[name.."TextLeft1"] then
            _G[name.."TextLeft1"]:SetFont(fontPath, fontSize, fontFlags or "OUTLINE")
        end
        if _G[name.."TextRight1"] then
            _G[name.."TextRight1"]:SetFont(fontPath, fontSize, fontFlags or "OUTLINE")
        end
        
        -- Use framework fonts for body if available
        if FontKit then
            fontPath = FontKit:GetFont('body')
            fontSize = FontKit:GetSize('normal')
            fontFlags = "OUTLINE"
        else
            fontSize = db.fontSize
        end
        
        local numLines = tip:NumLines()
        if numLines then
            for i = 2, numLines do
                local l, r = _G[name.."TextLeft"..i], _G[name.."TextRight"..i]
                if l then 
                    l:SetFont(fontPath, fontSize, fontFlags or "OUTLINE") 
                end
                if r then 
                    r:SetFont(fontPath, fontSize, fontFlags or "OUTLINE") 
                end
            end
        end
    end)
    
    -- Silently fail if styling causes issues (e.g., with embedded item tooltips)
end

function SmartAnchor(tooltip, owner)
    tooltip:ClearAllPoints()
    local bottom = owner:GetBottom()
    local sH, sW = GetScreenHeight(), GetScreenWidth()
    
    local vP, rP, yO
    if bottom and bottom > sH/2 then
        vP, rP, yO = "TOP", "BOTTOM", -2
    else
        vP, rP, yO = "BOTTOM", "TOP", 2
    end
    
    tooltip:SetPoint(vP, owner, rP, 0, yO)
    
    local tW = tooltip:GetWidth() or 200
    local oC = owner:GetCenter() or sW/2
    
    if (oC + tW/2) > sW then 
        tooltip:SetPoint(vP.."RIGHT", owner, rP.."RIGHT", 0, yO)
    elseif (oC - tW/2) < 0 then 
        tooltip:SetPoint(vP.."LEFT", owner, rP.."LEFT", 0, yO) 
    end
end

-- HELPER: DIFFICULTY STRING LOGIC
function GetDifficultyLabel()
    local _, instanceType, difficultyID, _, _, _, _, _, instanceGroupSize = GetInstanceInfo()
    
    if instanceType == "none" then return "World" end
    if instanceType == "pvp" or instanceType == "arena" then return "BG" end
    
    -- Dungeons & Raids
    -- Timewalking (24 = Dungeon, 33 = Raid)
    if difficultyID == 24 or difficultyID == 33 then return "TW" end
    
    -- Legacy Raids
    if difficultyID == 3 then return "N10" end
    if difficultyID == 4 then return "N25" end
    if difficultyID == 5 then return "H10" end
    if difficultyID == 6 then return "H25" end
    
    -- Standard Dungeons
    if difficultyID == 1 then return "N" end
    if difficultyID == 2 then return "H" end
    if difficultyID == 23 then return "M0" end
    if difficultyID == 8 then return "M+" end
    
    -- Follower Dungeons (Check ID or Fallback Name)
    if difficultyID == 205 then return "F" end
    
    -- Raids
    if difficultyID == 7 or difficultyID == 17 then return "LFR" end
    if difficultyID == 16 then return "M20" end -- Mythic Raid fixed
    
    -- Flex Raids (Normal 14, Heroic 15)
    if difficultyID == 14 then 
        local num = GetNumGroupMembers()
        if num == 0 then num = 1 end 
        return "N"..num
    end
    if difficultyID == 15 then 
        local num = GetNumGroupMembers()
        if num == 0 then num = 1 end
        return "H"..num
    end
    
    -- Fallback for Delves (Check Name)
    local diffName = select(4, GetInstanceInfo())
    if diffName then
        if diffName:find("Delve") then return "D" end
        if diffName:find("Follower") then return "F" end
    end
    
    return diffName or ""
end

-- ============================================================================
-- 4. INTERACTIVE FRAMES (Friends, Guild, Volume)
-- ============================================================================
-- NOTE: These functions have been moved to individual broker files in Modules/Brokers/
-- The broker files now handle their own frame creation and update logic

-- ============================================================================
-- 5. BROKER OBJECTS (LDB)
-- ============================================================================

function BrokerBar:InitializeBrokers()
    -- Brokers are now loaded from separate files in Modules/Brokers/
    -- Get references to the data objects created by those files
    friendObj = LDB:GetDataObjectByName("MidnightFriends")
    guildObj = LDB:GetDataObjectByName("MidnightGuild")
    goldObj = LDB:GetDataObjectByName("MidnightGold")
    sysObj = LDB:GetDataObjectByName("MidnightSystem")
    bagObj = LDB:GetDataObjectByName("MidnightBags")
    tokenObj = LDB:GetDataObjectByName("MidnightToken")
    volObj = LDB:GetDataObjectByName("MidnightVolume")
    duraObj = LDB:GetDataObjectByName("MidnightDura")
    locObj = LDB:GetDataObjectByName("MidnightLocation")
    diffObj = LDB:GetDataObjectByName("MidnightDiff")
    ilvlObj = LDB:GetDataObjectByName("MidnightILvl")
    clockObj = LDB:GetDataObjectByName("MidnightClock")
end

-- ============================================================================
-- 6. UPDATE ENGINE
-- ============================================================================

function BrokerBar:UpdateAllModules()
    -- CLOCK
    local h, m = tonumber(date("%H")), tonumber(date("%M"))
    if h ~= lastState.timeH or m ~= lastState.timeM then
        lastState.timeH, lastState.timeM = h, m
        clockObj.text = FormatTimeDisplay(h, m, self.db.profile.useStandardTime)
    end

    -- SYSTEM (FPS/MS) - Color Logic for Bar Text
    local _, _, _, world = GetNetStats()
    local fps = math.floor(GetFramerate())
    if fps ~= lastState.fps or world ~= lastState.ms then
        lastState.fps, lastState.ms = fps, world
        
        -- Custom FPS Colors: Red < 20, Orange < 40, Yellow < 60, Green >= 60
        local color = "ff33ff33" -- Green (Default)
        if fps < 20 then color = "ffde1818"      -- Red
        elseif fps < 40 then color = "ffff7d0a"  -- Orange
        elseif fps < 60 then color = "ffffd200"  -- Yellow
        end
        
        -- Custom MS Colors: Green < 100, Yellow < 200, Red >= 200
        local msColor = "ff33ff33" -- Green (Default)
        if world >= 200 then msColor = "ffde1818"     -- Red
        elseif world >= 100 then msColor = "ffffd200" -- Yellow
        end
        
        sysObj.text = string.format("FPS: |c%s%d|r MS: |c%s%d|r", color, fps, msColor, world)
    end

    -- BAGS
    local free, total = 0, 0
    for i = 0, 5 do 
        local s = C_Container.GetContainerNumSlots(i)
        if s > 0 then 
            free = free + C_Container.GetContainerNumFreeSlots(i)
            total = total + s 
        end 
    end
    if free ~= lastState.bagFree or total ~= lastState.bagTotal then 
        lastState.bagFree, lastState.bagTotal = free, total
        bagObj.text = (total-free).."/"..total 
    end

    -- GOLD & TOKEN
    local money = GetMoney()
    if money ~= lastState.gold then 
        lastState.gold = money
        goldObj.text = FormatMoney(money) 
    end
    
    local price = C_WowTokenPublic.GetCurrentMarketPrice()
    if price and price ~= lastState.token then 
        lastState.token = price
        tokenObj.text = FormatTokenPrice(price) 
    end

    -- COUNTS
    local _, online = GetNumGuildMembers()
    if online ~= lastState.guild then 
        lastState.guild = online
        guildObj.text = tostring(online or 0) 
    end
    
    -- FIXED FRIENDS COUNT: Count only online WoW Retail friends
    local wowOnline = 0
    local numBNet = BNGetNumFriends() or 0
    for i = 1, numBNet do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.gameAccountInfo and info.gameAccountInfo.isOnline then
            local g = info.gameAccountInfo
            if (g.clientProgram == BNET_CLIENT_WOW) and (g.wowProjectID == 1) then
                wowOnline = wowOnline + 1
            end
        end
    end
    if wowOnline ~= lastState.friends then 
        lastState.friends = wowOnline
        friendObj.text = tostring(wowOnline) 
    end
    
    -- DURABILITY
    local low = 100
    for i = 1, 18 do 
        local c, m = GetInventoryItemDurability(i)
        if c and m then 
            local p = (c/m)*100
            if p < low then low = p end 
        end 
    end
    low = math.floor(low)
    if low ~= lastState.dura then 
        lastState.dura = low
        duraObj.text = low.."%" 
    end
    
    -- LOCATION
    local z = GetZoneText() or "Unknown"
    if z ~= lastState.zone then 
        lastState.zone = z
        locObj.text = z 
    end
    
    -- DIFFICULTY & FLEX
    local diff = GetDifficultyLabel()
    local num = GetNumGroupMembers()
    if diff ~= lastState.diffID or num ~= lastState.diffPlayers then
        lastState.diffID = diff
        lastState.diffPlayers = num
        diffObj.text = diff
    end
    
    -- ITEM LEVEL
    local avgIlvl, equippedIlvl = GetAverageItemLevel()
    equippedIlvl = math.floor(equippedIlvl or 0)
    if equippedIlvl ~= lastState.ilvl then
        lastState.ilvl = equippedIlvl
        ilvlObj.text = tostring(equippedIlvl)
    end
    
    -- VOLUME - FIXED: Always Whole Number Formatting
    local v = math.floor((tonumber(GetCVar("Sound_MasterVolume")) or 0) * 100)
    if v ~= lastState.vol then 
        lastState.vol = v
        volObj.text = string.format("%d%%", v) -- Force integer display
    end
end

-- ============================================================================
-- 7. FRAME & LAYOUT LOGIC
-- ============================================================================

local function SortByOrder(a, b) 
    local db = BrokerBar.db.profile.brokers
    if not db then return false end
    return (db[a] and db[a].order or 0) < (db[b] and db[b].order or 0) 
end

function BrokerBar:GetSafeConfig(name)
    -- Ensure brokers table exists
    if not self.db.profile.brokers then
        self.db.profile.brokers = {}
    end
    
    if not self.db.profile.brokers[name] then
        -- Default enabled brokers (only these are shown by default)
        local defaultEnabledBrokers = {
            ["MidnightVolume"] = true,
            ["MidnightLocation"] = true,
            ["MidnightGold"] = true,
            ["MidnightDiff"] = true,
            ["MidnightSystem"] = true,
            ["MidnightClock"] = true,
        }
        
        -- Default alignments for each broker
        local defaultAlignments = {
            ["MidnightVolume"] = "RIGHT",
            ["MidnightLocation"] = "RIGHT",
            ["MidnightDiff"] = "RIGHT",
            ["MidnightSystem"] = "LEFT",
            ["MidnightGold"] = "LEFT",
            ["MidnightClock"] = "CENTER",
        }
        
        -- Default order values for positioning (lower = leftmost in their alignment group)
        local defaultOrders = {
            ["MidnightSystem"] = 10,    -- LEFT side, first
            ["MidnightGold"] = 20,      -- LEFT side, second
            ["MidnightClock"] = 30,     -- CENTER
            ["MidnightDiff"] = 60,      -- RIGHT side, first (leftmost)
            ["MidnightLocation"] = 50,  -- RIGHT side, second
            ["MidnightVolume"] = 40,    -- RIGHT side, third (rightmost)
        }
        
        -- Check if this broker should be enabled by default
        local defaultBar = defaultEnabledBrokers[name] and "MainBar" or "None"
        local defaultAlign = defaultAlignments[name] or "CENTER"
        local defaultOrder = defaultOrders[name] or 100
        
        -- Special case: Location should show coordinates by default
        local defaultShowCoords = (name == "MidnightLocation")
        
        -- Special case: Volume should default to 5% step size
        local defaultVolumeStep = (name == "MidnightVolume") and 0.05 or nil
        
        self.db.profile.brokers[name] = { 
            bar = defaultBar, 
            align = defaultAlign, 
            order = defaultOrder, 
            showIcon = true, 
            showText = true, 
            showLabel = false, 
            showCoords = defaultShowCoords,
            volumeStep = defaultVolumeStep
        } 
    end
    return self.db.profile.brokers[name]
end

function BrokerBar:UpdateBarLayout(barID)
    local bar = bars[barID]
    local db = self.db.profile.bars[barID]
    if not bar or not db then return end
    
    -- Ensure bar has proper size before positioning widgets
    local barWidth, barHeight = bar:GetSize()
    if barWidth == 0 or barHeight == 0 then
        -- Bar hasn't been sized yet, apply settings first
        self:ApplyBarSettings(barID)
        return  -- ApplyBarSettings will call UpdateBarLayout again
    end
    
    wipe(layoutCache.LEFT)
    wipe(layoutCache.CENTER)
    wipe(layoutCache.RIGHT)
    
    local brokersForThisBar = {}
    
    for name, w in pairs(widgets) do
        local config = self:GetSafeConfig(name)
        if config and config.bar == barID then 
            table.insert(layoutCache[config.align or "CENTER"], name)
            table.insert(brokersForThisBar, name)
            w:Show()
        elseif config and config.bar == "None" then
            -- Only hide widgets explicitly set to "None", don't hide widgets assigned to other bars
            w:Hide() 
        end
    end
    
    local fontPath, fontSize, fontFlags
    if FontKit then
        fontPath = FontKit:GetFont('body')
        fontSize = FontKit:GetSize('normal')
        fontFlags = "OUTLINE"
    else
        fontPath = LSM:Fetch("font", self.db.profile.font) or "Fonts\\FRIZQT__.ttf"
        fontSize = self.db.profile.fontSize
        fontFlags = "OUTLINE"
    end
    local r, g, b = GetColor()
    
    for align, list in pairs(layoutCache) do
        table.sort(list, SortByOrder)
        local lastWidget = nil
        local first = true
        local totalW = 0
        
        -- Center Calculation
        if align == "CENTER" then
            for _, name in ipairs(list) do
                local w = widgets[name]
                local obj = LDB:GetDataObjectByName(name)
                
                -- FIXED TEXT CONSTRUCTION FOR WIDTH CALC
                local bCfg = self:GetSafeConfig(name)
                local map = bCfg.useShortLabel and LABEL_MAP_SHORT or LABEL_MAP_FULL
                local labelPart = bCfg.showLabel and (map[name] or obj.label or name) or ""
                local rawText = tostring(obj.text or "")
                
                local textValue = rawText
                if name ~= "MidnightLocation" then
                    textValue = ShortenValue(rawText)
                end
                
                if name == "MidnightLocation" and bCfg.showCoords then
                    textValue = textValue .. " (00, 00)" -- Placeholder for sizing
                end
                
                local displayString = (labelPart ~= "" and labelPart .. ": " or "") .. (bCfg.showText and textValue or "")
                
                w.text:SetFont(fontPath, fontSize, fontFlags or "OUTLINE")
                w.text:SetText(displayString)
                
                local iconSize = (db.height or 24) * 0.85
                totalW = totalW + w.text:GetStringWidth() + (bCfg.showIcon and (iconSize + 4) or 4) + self.db.profile.spacing
            end
            totalW = totalW - self.db.profile.spacing
        end

        for _, name in ipairs(list) do
            local w, obj, bCfg = widgets[name], LDB:GetDataObjectByName(name), self:GetSafeConfig(name)
            w:SetParent(bar)
            w:SetFrameLevel(bar:GetFrameLevel() + 1)  -- Ensure widgets are above the bar's background
            w:ClearAllPoints()
            w.text:SetTextColor(r,g,b)
            
            local rawText = tostring(obj.text or "")
            local map = bCfg.useShortLabel and LABEL_MAP_SHORT or LABEL_MAP_FULL
            local labelPart = bCfg.showLabel and (map[name] or obj.label or name) or ""
            
            local textValue = rawText
            
            -- LOCATION LOGIC (DECIMALS & TRUNCATION BYPASS)
            if name == "MidnightLocation" then
                if bCfg.showCoords then 
                    local m = C_Map.GetBestMapForUnit("player")
                    if m then 
                        local p = C_Map.GetPlayerMapPosition(m, "player")
                        if p then 
                            local decimals = bCfg.coordDecimals or 0
                            if decimals == 0 then
                                textValue = textValue .. string.format(" (%d, %d)", p.x*100, p.y*100)
                            elseif decimals == 1 then
                                textValue = textValue .. string.format(" (%.1f, %.1f)", p.x*100, p.y*100)
                            else -- 2 decimals
                                textValue = textValue .. string.format(" (%.2f, %.2f)", p.x*100, p.y*100)
                            end
                        end 
                    end 
                end
                -- No ShortenValue() call for location, showing full zone name
            else
                textValue = ShortenValue(rawText)
            end
            
            local displayString = (labelPart ~= "" and labelPart .. ": " or "") .. (bCfg.showText and textValue or "")
            w.text:SetText(displayString)

            -- FORCE GLOBAL FONT FOR ALL WIDGETS
            w.text:SetFont(fontPath, fontSize, fontFlags or "OUTLINE")

            local iconSize = (db.height or 24) * 0.85
            if bCfg.showIcon and obj.icon then 
                w.icon:SetTexture(obj.icon)
                w.icon:SetSize(iconSize, iconSize)
                w.icon:Show()
                w.icon:SetPoint("LEFT", w, "LEFT", 2, 0)
                w.text:SetPoint("LEFT", w.icon, "RIGHT", 4, 0) 
            else 
                w.icon:Hide()
                w.text:SetPoint("LEFT", w, "LEFT", 2, 0) 
            end
            
            local contentWidth = w.text:GetStringWidth() + (bCfg.showIcon and (iconSize + 4) or 4)
            w:SetSize(contentWidth, db.height)
            
            if align == "LEFT" then 
                w:SetPoint("LEFT", lastWidget or bar, lastWidget and "RIGHT" or "LEFT", lastWidget and self.db.profile.spacing or 10, 0)
            elseif align == "RIGHT" then 
                w:SetPoint("RIGHT", lastWidget or bar, lastWidget and "LEFT" or "RIGHT", lastWidget and -self.db.profile.spacing or -10, 0)
            else 
                if first then 
                    w:SetPoint("LEFT", bar, "CENTER", -(totalW/2), 0) 
                else 
                    w:SetPoint("LEFT", lastWidget, "RIGHT", self.db.profile.spacing, 0) 
                end 
            end
            
            lastWidget = w
            first = false
        end
    end
end

function BrokerBar:CreateBarFrame(id)
    local Movable = MidnightUI:GetModule("Movable")
    
    local f = CreateFrame("Frame", "MidnightBar_"..id, UIParent, "BackdropTemplate")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    
    -- Use Movable for drag functionality
    Movable:MakeFrameDraggable(
        f,
        function(point, x, y)
            local db = BrokerBar.db.profile.bars[id]
            if db then
                db.point = point or "CENTER"
                db.x = x or 0
                db.y = y or 0
            end
        end,
        function() return not BrokerBar.db.profile.locked end
    )
    
    -- Create compact arrow controls for this bar (like UIButtons)
    local nudgeFrame = Movable:CreateNudgeArrows(
        f,
        { offsetX = 0, offsetY = 0 },
        function()
            local db = BrokerBar.db.profile.bars[id]
            local nudgeDB = nudgeFrame.db
            
            -- Apply nudge offset to saved position
            db.x = (db.x or 0) + (nudgeDB.offsetX or 0)
            db.y = (db.y or 0) + (nudgeDB.offsetY or 0)
            
            -- Reset nudge offset
            nudgeDB.offsetX = 0
            nudgeDB.offsetY = 0
            
            -- Update bar position
            f:ClearAllPoints()
            if db.fullWidth then
                f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, db.y)
                f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, db.y)
            else
                f:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x, db.y)
            end
            
            Movable:UpdateNudgeDisplay(nudgeFrame, nudgeDB)
        end,
        nil
    )
    
    f.nudgeFrame = nudgeFrame
    
    -- Register nudge frame
    if nudgeFrame then
        Movable:RegisterNudgeFrame(nudgeFrame, f)
    end
    
    bars[id] = f
end

function BrokerBar:ApplyBarSettings(barID)
    local f, db = bars[barID], self.db.profile.bars[barID]
    if not f or not db then return end
    
    local skin = SKINS[db.skin == "Global" and self.db.profile.barSkin or db.skin] or SKINS["Midnight"]
    f:SetScale(db.scale or 1.0)
    f:ClearAllPoints()
    
    if db.fullWidth then 
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, db.y or 0)
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, db.y or 0)
    else 
        f:SetSize(db.width or 400, db.height or 24)
        f:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or 0)
    end
    
    f:SetHeight(db.height or 24)
    f.bg:SetTexture(LSM:Fetch("statusbar", db.texture or "Flat"))
    
    -- Use theme color if useThemeColor flag is set, otherwise use saved color
    local r, g, b, alpha
    if db.useThemeColor and ColorPalette then
        r, g, b, alpha = ColorPalette:GetColor("panel-bg")
        -- Fallback if ColorPalette returns nil (shouldn't happen but safety check)
        if not r then
            r, g, b = db.color.r, db.color.g, db.color.b
            alpha = db.alpha or 0.6
        end
    else
        r, g, b = db.color.r, db.color.g, db.color.b
        alpha = db.alpha or 0.6
    end
    f.bg:SetVertexColor(r, g, b, alpha)
    
    -- Use theme colors for backdrop if available
    if ColorPalette then
        f:SetBackdropColor(ColorPalette:GetColor("bg-primary"))
        f:SetBackdropBorderColor(ColorPalette:GetColor("panel-border"))
    else
        f:SetBackdropColor(0, 0, 0, 0)
        f:SetBackdropBorderColor(1, 1, 1, skin.borderAlpha)
    end
    f:SetBackdrop(skin.backdrop)
    
    if db.enabled then 
        f:Show()
    else 
        f:Hide()
    end
    self:UpdateBarLayout(barID)
end

function BrokerBar:CreateWidget(name, obj)
    local btn = widgets[name]
    if not btn then
        btn = CreateFrame("Button", nil, UIParent)
        btn:RegisterForClicks("AnyUp") -- CRITICAL FIX: ENABLE RIGHT CLICK
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if masqueGroup then 
            masqueGroup:AddButton(btn, { Icon = btn.icon }) 
        end
        widgets[name] = btn
    end
    btn:SetScript("OnEnter", function(self) 
        if obj.OnEnter then 
            obj.OnEnter(self) 
        elseif obj.OnTooltipShow then 
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            SmartAnchor(GameTooltip, self)
            obj.OnTooltipShow(GameTooltip)
            -- FORCE STYLE FOR ALL TOOLTIPS
            ApplyTooltipStyle(GameTooltip)
            GameTooltip:Show() 
        end 
        -- Fallback check for addons that use weird tooltip methods
        if GameTooltip:IsShown() and GameTooltip:GetOwner() == self then
             ApplyTooltipStyle(GameTooltip)
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(self, button) 
        if name == "MidnightLocation" then 
            ToggleWorldMap() 
        elseif obj.OnClick then 
            obj.OnClick(self, button) 
        end 
    end)
    btn:EnableMouseWheel(true)
    btn:SetScript("OnMouseWheel", function(self, delta) 
        if obj.OnMouseWheel then 
            obj.OnMouseWheel(obj, delta) 
        end 
    end)
    LDB.RegisterCallback(self, "LibDataBroker_AttributeChanged_"..name, function() 
        local config = BrokerBar:GetSafeConfig(name)
        if config and config.bar and config.bar ~= "None" then
            BrokerBar:UpdateBarLayout(config.bar)
        end
    end)
end

-- ============================================================================
-- 8. INITIALIZATION & EVENTS
-- ============================================================================

function BrokerBar:OnInitialize()
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "OnDBReady")
end

function BrokerBar:OnDBReady()
    if not MidnightUI.db.profile.modules.bar then return end
    
    -- Get framework systems (ColorPalette already set at top of file)
    FrameFactory = MidnightUI.FrameFactory
    FontKit = MidnightUI.FontKit
    
    -- Keep namespace as "Bar" for backwards compatibility with saved settings
    self.db = MidnightUI.db:RegisterNamespace("Bar", defaults)
    
    -- Ensure MainBar has useThemeColor flag set (migration for existing profiles)
    if self.db.profile.bars["MainBar"] and self.db.profile.bars["MainBar"].useThemeColor == nil then
        self.db.profile.bars["MainBar"].useThemeColor = true
    end
    
    if Masque then 
        masqueGroup = Masque:Group("Midnight Bar") 
    end

    for id in pairs(self.db.profile.bars) do 
        self:CreateBarFrame(id) 
    end
    
    LDB.RegisterCallback(self, "LibDataBroker_DataObjectCreated", function(_, name, obj) 
        self:CreateWidget(name, obj) 
    end)
    
    self:InitializeBrokers()
    
    for name, obj in LDB:DataObjectIterator() do 
        self:CreateWidget(name, obj) 
    end
    
    -- REMOVED: self:RegisterEvent("PLAYER_LOGIN") - Not needed, no handler exists
    self:RegisterEvent("PLAYER_MONEY", "UpdateGoldData")
    self:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED", "UpdateTokenHistory")
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAllModules")
    self:RegisterEvent("BAG_UPDATE", "UpdateAllModules")
    self:RegisterEvent("ZONE_CHANGED", "UpdateAllModules")
    
    self:UpdateGoldData()
    
    -- Request initial WoW Token price
    C_Timer.After(2, function()
        C_WowTokenPublic.UpdateMarketPrice()
    end)
    
    C_Timer.NewTicker(1.0, function() self:UpdateAllModules() end)
    
    C_Timer.After(1.0, function() 
        for id in pairs(bars) do 
            BrokerBar:ApplyBarSettings(id) 
        end 
    end)
end

function BrokerBar:PLAYER_ENTERING_WORLD()
    -- Just update modules, initialization already done
    self:UpdateAllModules()
end

function BrokerBar:UpdateGoldData()
    local key = UnitName("player") .. " - " .. GetRealmName()
    self.db.profile.goldData[key] = { amount = GetMoney(), class = select(2, UnitClass("player")) }
end

function BrokerBar:UpdateTokenHistory()
    local price = C_WowTokenPublic.GetCurrentMarketPrice()
    if not price then return end
    
    local h = self.db.profile.tokenHistory
    
    -- Check if this price is different from the most recent entry
    if #h > 0 and h[1].price == price then
        return -- Don't add duplicate prices
    end
    
    -- Add new entry at the beginning
    table.insert(h, 1, { price = price, time = time() })
    
    -- Keep only the 5 most recent entries
    while #h > 5 do 
        table.remove(h) 
    end
    
    -- Update the display immediately
    tokenObj.text = FormatTokenPrice(price)
    self:UpdateBarLayout("MainBar")
end

function BrokerBar:GUILD_ROSTER_UPDATE() 
    if guildFrame and guildFrame:IsShown() then 
        self:UpdateGuildList() 
    end
    self:UpdateAllModules() 
end

-- ============================================================================
-- 9. OPTIONS
-- ============================================================================

function BrokerBar:MoveBroker(name, direction)
    local config = self:GetSafeConfig(name)
    if not config or config.bar == "None" then 
        return 
    end
    
    -- Ensure brokers table exists
    if not self.db.profile.brokers then
        self.db.profile.brokers = {}
    end
    
    -- For RIGHT-aligned brokers, reverse the direction since they're laid out right-to-left
    -- (higher order values appear further left visually)
    if config.align == "RIGHT" then
        direction = -direction
    end
    
    -- Build list of brokers in same bar/align
    local list = {}
    for n, c in pairs(self.db.profile.brokers) do 
        if c.bar == config.bar and c.align == config.align then 
            table.insert(list, {name=n, order=c.order or 10}) 
        end 
    end
    table.sort(list, function(a, b) 
        if a.order == b.order then
            return a.name < b.name  -- Secondary sort by name for consistency
        end
        return a.order < b.order 
    end)
    
    -- First, ensure all brokers have unique sequential order values
    for i, d in ipairs(list) do
        self.db.profile.brokers[d.name].order = i * 10
        list[i].order = i * 10  -- Update the list entry too
    end
    
    -- Find current index
    local idx
    for i, d in ipairs(list) do 
        if d.name == name then idx = i end 
    end
    
    if not idx then
        return
    end
    
    local target = idx + direction
    
    -- Check if move is valid
    if target < 1 or target > #list then 
        return
    end
    
    -- Swap only the order values of these two brokers
    local currentBrokerName = list[idx].name
    local targetBrokerName = list[target].name
    
    self.db.profile.brokers[currentBrokerName].order, self.db.profile.brokers[targetBrokerName].order = 
        self.db.profile.brokers[targetBrokerName].order, self.db.profile.brokers[currentBrokerName].order
    
    self:UpdateBarLayout(config.bar)
end

function BrokerBar:GetPluginOptions()
    local options = { 
        name = "Brokers", 
        type = "group", 
        childGroups = "tree",
        order = 3,
        args = {} 
    }
    
    local barList = { ["None"] = "None" }; 
    for bID in pairs(self.db.profile.bars) do 
        barList[bID] = bID 
    end
    
    local nameMap = { 
        MidnightDura = "Midnight Durability", 
        MidnightClock = "Midnight Clock", 
        MidnightBags = "Midnight Bags", 
        MidnightFriends = "Midnight Friends", 
        MidnightGold = "Midnight Gold", 
        MidnightGuild = "Midnight Guild", 
        MidnightLocation = "Midnight Location", 
        MidnightSystem = "Midnight System", 
        MidnightDiff = "Midnight Difficulty", 
        MidnightToken = "Midnight Token", 
        MidnightVolume = "Midnight Volume", 
        MidnightILvl = "Midnight Item Level" 
    }

    for name in pairs(widgets) do
        self:GetSafeConfig(name)
        local displayName = nameMap[name] or name
        local isLoc = (name == "MidnightLocation")
        local isVol = (name == "MidnightVolume")
        local isGold = (name == "MidnightGold")

        options.args[name:gsub("%s", "_")] = {
            name = (self.db.profile.brokers[name].bar ~= "None") and displayName or "|cff808080"..displayName.."|r", 
            type = "group", 
            order = 1,
            args = {
                enable = { 
                    name = "Enable", 
                    type = "toggle", 
                    order = 1, 
                    width = "normal", 
                    get = function() return self.db.profile.brokers[name].bar ~= "None" end, 
                    set = function(_, v) self.db.profile.brokers[name].bar = v and "MainBar" or "None"; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
                },
                moveL = { 
                    name = "Move Left", 
                    type = "execute", 
                    order = 1.1, 
                    width = "half", 
                    func = function() self:MoveBroker(name, -1) end 
                },
                moveR = { 
                    name = "Move Right", 
                    type = "execute", 
                    order = 1.2, 
                    width = "half", 
                    func = function() self:MoveBroker(name, 1) end 
                },

                -- Row 2: Bar and Align (now order 4 and 4.1)
                bar = { 
                    name = "Bar", 
                    type = "select", 
                    order = 4, 
                    width = "half",
                    values = barList, 
                    get = function() return self.db.profile.brokers[name].bar end, 
                    set = function(_, v) self.db.profile.brokers[name].bar = v; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
                },
                align = { 
                    name = "Align", 
                    type = "select", 
                    order = 4.1, 
                    width = "half",
                    values = {LEFT="Left", CENTER="Center", RIGHT="Right"}, 
                    get = function() return self.db.profile.brokers[name].align end, 
                    set = function(_, v) self.db.profile.brokers[name].align = v; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
                },

                -- Row 3: Checkboxes and toggles (start at order 5)
                showIcon = { 
                    name = "Show Icon", 
                    type = "toggle", 
                    order = 5, 
                    get = function() return self.db.profile.brokers[name].showIcon end, 
                    set = function(_, v) self.db.profile.brokers[name].showIcon = v; self:UpdateBarLayout(self.db.profile.brokers[name].bar) end 
                },
                showText = { 
                    name = "Show Value", 
                    type = "toggle", 
                    order = 6, 
                    get = function() return self.db.profile.brokers[name].showText end, 
                    set = function(_, v) self.db.profile.brokers[name].showText = v; self:UpdateBarLayout(self.db.profile.brokers[name].bar) end 
                },
                showLabel = { 
                    name = "Show Label", 
                    type = "toggle", 
                    order = 7, 
                    get = function() return self.db.profile.brokers[name].showLabel end, 
                    set = function(_, v) self.db.profile.brokers[name].showLabel = v; self:UpdateBarLayout(self.db.profile.brokers[name].bar) end 
                },
                useShortLabel = { 
                    name = "Use Short Label", 
                    type = "toggle", 
                    order = 8, 
                    disabled = function() return not self.db.profile.brokers[name].showLabel end, 
                    get = function() return self.db.profile.brokers[name].useShortLabel end, 
                    set = function(_, v) self.db.profile.brokers[name].useShortLabel = v; self:UpdateBarLayout(self.db.profile.brokers[name].bar) end 
                },
                
                showCoords = isLoc and { 
                    name = "Show Coords", 
                    type = "toggle", 
                    order = 10, 
                    get = function() return self.db.profile.brokers[name].showCoords end, 
                    set = function(_, v) self.db.profile.brokers[name].showCoords = v; self:UpdateBarLayout(self.db.profile.brokers[name].bar) end 
                } or nil,
                coordDecimals = isLoc and { 
                    name = "Decimal Places", 
                    type = "select", 
                    order = 11, 
                    values = { [0] = "None (60, 45)", [1] = "One (60.5, 45.3)", [2] = "Two (60.52, 45.37)" },
                    get = function() return self.db.profile.brokers[name].coordDecimals or 0 end, 
                    set = function(_, v) self.db.profile.brokers[name].coordDecimals = v; self:UpdateBarLayout(self.db.profile.brokers[name].bar) end 
                } or nil,
                volumeStep = isVol and {
                    name = "Step Size",
                    type = "select",
                    order = 12,
                    values = { [0.01] = "1%", [0.05] = "5%" },
                    get = function() return self.db.profile.brokers[name].volumeStep or 0.01 end,
                    set = function(_, v) self.db.profile.brokers[name].volumeStep = v end
                } or nil,
                deleteChar = isGold and { 
                    name = "Delete Character Data", 
                    type = "select", 
                    order = 13, 
                    values = function() local t = {}; for k in pairs(self.db.profile.goldData) do t[k] = k end; return t end, 
                    set = function(_, v) self.db.profile.goldData[v] = nil end, confirm = true 
                } or nil
            }
        }
    end
    return options
end

function BrokerBar:GetOptions()
    -- SAFETY CHECK: Ensure DB is loaded if GetOptions is called before OnInitialize
    if not self.db then
        -- Keep namespace as "Bar" for backwards compatibility with saved settings
        self.db = MidnightUI.db:RegisterNamespace("Bar", defaults)
    end

    local function GetSkinList() 
        local list = { ["Global"] = "Global (Use General Setting)" }
        for k in pairs(SKINS) do list[k] = k end
        return list 
    end
    
    local screenWidth = math.floor(GetScreenWidth())
    local options = { 
        type = "group", 
        name = "Data Brokers", 
        childGroups = "tab", 
        args = {
            settings = {
                name = "Settings",
                type = "group",
                order = 1,
                args = {
                    font = { 
                        name = "Global Font", 
                        type = "select", 
                        order = 1, 
                        values = function()
                            local fonts = LSM:List("font")
                            local out = {}
                            for _, font in ipairs(fonts) do out[font] = font end
                            return out
                        end,
                        get = function() return self.db.profile.font end, 
                        set = function(_, v) self.db.profile.font = v; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
                    },
                    fontSize = { 
                        name = "Font Size", 
                        type = "range", 
                        min = 6, 
                        max = 32, 
                        step = 1, 
                        order = 2,
                        width = "half",
                        get = function() return self.db.profile.fontSize end, 
                        set = function(_, v) self.db.profile.fontSize = v; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
                    },
                    spacing = { 
                        name = "Spacing", 
                        type = "range", 
                        min = 0, 
                        max = 50, 
                        step = 1, 
                        order = 3,
                        width = "half",
                        get = function() return self.db.profile.spacing end, 
                        set = function(_, v) self.db.profile.spacing = v; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
                    },
                    useClassColor = { 
                        name = "Use Class Color", 
                        type = "toggle", 
                        order = 4,
                        get = function() return self.db.profile.useClassColor end, 
                        set = function(_, v) self.db.profile.useClassColor = v; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
                    },
                    color = { 
                        name = "Custom Font Color", 
                        type = "color", 
                        order = 5,
                        disabled = function() return self.db.profile.useClassColor end, 
                        get = function() local c = self.db.profile.fontColor; return c.r, c.g, c.b end, 
                        set = function(_, r, g, b) self.db.profile.fontColor = {r=r, g=g, b=b}; for id in pairs(bars) do self:UpdateBarLayout(id) end end 
                    },
                    useStandardTime = { 
                        name = "Use 24-Hour Time", 
                        type = "toggle", 
                        order = 6,
                        get = function() return self.db.profile.useStandardTime end, 
                        set = function(_, v) self.db.profile.useStandardTime = v; self:UpdateAllModules() end 
                    },
                    lock = { 
                        name = "Lock", 
                        type = "toggle", 
                        order = 7,
                        get = function() return self.db.profile.locked end, 
                        set = function(_, v) self.db.profile.locked = v; for id in pairs(bars) do self:ApplyBarSettings(id) end end 
                    },
                }
            },
            bars = { 
                name = "Bars", 
                type = "group",
                childGroups = "tree",
                order = 2,
                args = {} 
            },
            brokers = self:GetPluginOptions()
        }
    }
    local sortedBars = {}; for id in pairs(self.db.profile.bars) do table.insert(sortedBars, id) end; table.sort(sortedBars)
    
    -- Add "Create New Bar" as first item in tree
    options.args.bars.args["_create"] = {
        name = "Create New Bar",
        type = "group",
        order = 1,
        args = {
            create = {
                name = "Bar Name",
                type = "input",
                order = 1,
                set = function(_, v) 
                    if v ~= "" and not self.db.profile.bars[v] then 
                        local r, g, b, a = ColorPalette:GetColor('panel-bg')
                        self.db.profile.bars[v] = { 
                            enabled = true, 
                            fullWidth = false, 
                            width = 400, 
                            height = 24, 
                            scale = 1.0, 
                            alpha = a or 0.6, 
                            color = {r = r or 0.1, g = g or 0.1, b = b or 0.1},
                            useThemeColor = true,
                            texture = "Blizzard", 
                            skin = "Global", 
                            padding = 5, 
                            point = "CENTER", 
                            x = 0, 
                            y = 0 
                        }
                        self:CreateBarFrame(v)
                        self:ApplyBarSettings(v)
                        -- Refresh options to show new bar
                        
                    end 
                end 
            }
        }
    }
    
    for i, id in ipairs(sortedBars) do
        options.args.bars.args[id] = { 
            name = id, 
            type = "group", 
            order = 2 + i, 
            args = {
                enabled = { 
                    name = "Enabled", 
                    type = "toggle", 
                    order = 1,
                    get = function() return self.db.profile.bars[id].enabled end, 
                    set = function(_, v) self.db.profile.bars[id].enabled = v; self:ApplyBarSettings(id) end 
                },
                fullWidth = { 
                    name = "Full Width", 
                    type = "toggle", 
                    order = 2,
                    get = function() return self.db.profile.bars[id].fullWidth end, 
                    set = function(_, v) self.db.profile.bars[id].fullWidth = v; self:ApplyBarSettings(id) end 
                },
                width = { 
                    name = "Width", 
                    type = "range", 
                    order = 3, 
                    min = 50, 
                    max = screenWidth, 
                    step = 1,
                    width = "half",
                    disabled = function() return self.db.profile.brokers[id] and self.db.profile.brokers[id].fullWidth or false end, 
                    get = function() return self.db.profile.bars[id].width end, 
                    set = function(_, v) self.db.profile.bars[id].width = v; self:ApplyBarSettings(id) end 
                },
                height = { 
                    name = "Height", 
                    type = "range", 
                    order = 4, 
                    min = 10, 
                    max = 100, 
                    step = 1,
                    width = "half",
                    get = function() return self.db.profile.bars[id].height end, 
                    set = function(_, v) self.db.profile.bars[id].height = v; self:ApplyBarSettings(id) end 
                },
                scale = { 
                    name = "Scale", 
                    type = "range", 
                    order = 4.5, 
                    min = 0.5, 
                    max = 3.0, 
                    step = 0.1,
                    width = "half",
                    get = function() return self.db.profile.bars[id].scale or 1.0 end, 
                    set = function(_, v) self.db.profile.bars[id].scale = v; self:ApplyBarSettings(id) end 
                },
                skin = { 
                    name = "Skin", 
                    type = "select", 
                    order = 5,
                    hidden = function() return self.db.profile.bars[id].useThemeColor end,
                    values = GetSkinList, 
                    get = function() return self.db.profile.bars[id].skin or "Global" end, 
                    set = function(_, v) self.db.profile.bars[id].skin = v; self:ApplyBarSettings(id) end 
                },
                texture = { 
                    name = "Texture", 
                    type = "select", 
                    order = 6,
                    hidden = function() return self.db.profile.bars[id].useThemeColor end,
                    values = function()
                        local textures = LSM:List("statusbar")
                        local out = {}
                        for _, tex in ipairs(textures) do out[tex] = tex end
                        return out
                    end,
                    get = function() return self.db.profile.bars[id].texture end, 
                    set = function(_, v) self.db.profile.bars[id].texture = v; self:ApplyBarSettings(id) end 
                },
                useThemeColor = {
                    name = "Use Theme Color",
                    type = "toggle",
                    order = 6.5,
                    get = function() return self.db.profile.bars[id].useThemeColor end,
                    set = function(_, v)
                        self.db.profile.bars[id].useThemeColor = v
                        if v then
                            -- Set to Transparent skin and Solid texture when using theme color
                            self.db.profile.bars[id].skin = "Transparent"
                            self.db.profile.bars[id].texture = "Solid"
                        end
                        self:ApplyBarSettings(id)
                    end
                },
                color = { 
                    name = "Color", 
                    type = "color", 
                    hasAlpha = true, 
                    order = 7,
                    hidden = function() return self.db.profile.bars[id].useThemeColor end,
                    get = function() local c = self.db.profile.bars[id].color; return c.r, c.g, c.b, self.db.profile.bars[id].alpha end, 
                    set = function(_, r, g, b, a) 
                        self.db.profile.bars[id].useThemeColor = false
                        self.db.profile.bars[id].color = {r=r, g=g, b=b}
                        self.db.profile.bars[id].alpha = a
                        self:ApplyBarSettings(id) 
                    end 
                },
                delete = {
                    name = "Delete Bar",
                    type = "execute",
                    order = 99,
                    confirm = function() return string.format("Are you sure you want to delete %s?", id) end,
                    disabled = function() return id == "MainBar" end,
                    func = function()
                        self.db.profile.bars[id] = nil
                        if bars[id] then bars[id]:Hide(); bars[id] = nil end
                        if self.db.profile.brokers then
                            for name, config in pairs(self.db.profile.brokers) do if config.bar == id then config.bar = "None" end end
                        end
                        MidnightUI:OpenConfig()
                    end
                },
        }}
    end
    return options
end

function BrokerBar:ScheduleLayout() 
    BrokerBar.layoutQueued = true
    C_Timer.After(0.05, function() 
        BrokerBar.layoutQueued = false
        for id in pairs(bars) do 
            BrokerBar:UpdateBarLayout(id) 
        end 
    end) 
end