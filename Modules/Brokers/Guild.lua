-- MidnightUI Guild Broker
-- Displays online guild members count and provides a popup with detailed member list

if not BrokerBar then return end

local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local LDB = LibStub("LibDataBroker-1.1")
local LSM = LibStub("LibSharedMedia-3.0")
local guildFrame, guildTitle, guildMotD, guildFooter, gScrollChild
local guildHeaderRefs = {}
local guildObj

-- Create the guild popup frame
function BrokerBar:CreateGuildFrame()
    if guildFrame then return end
    guildFrame = CreateFrame("Frame", "MidnightGuildPopup", UIParent, "BackdropTemplate")
    guildFrame:SetSize(600, 450); guildFrame:SetFrameStrata("DIALOG"); guildFrame:EnableMouse(true); guildFrame:Hide()
    -- Don't skin on creation, wait for OnShow to apply themed backdrop
    -- MidnightUI:SkinFrame(guildFrame)
    
    guildTitle = guildFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    guildTitle:SetPoint("TOP", 0, -10); guildTitle:SetText("Guild List")

    guildMotD = guildFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    guildMotD:SetPoint("TOP", 0, -35); guildMotD:SetWidth(560); guildMotD:SetTextColor(0, 1, 0)

    guildFooter = guildFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    guildFooter:SetPoint("BOTTOM", 0, 8); guildFooter:SetText("|cff00ff00Click: Whisper • Ctrl-Click: Invite|r")

    local gScroll = CreateFrame("ScrollFrame", nil, guildFrame, "UIPanelScrollFrameTemplate")
    gScroll:SetPoint("TOPLEFT", 10, -90); gScroll:SetPoint("BOTTOMRIGHT", -25, 25)
    gScrollChild = CreateFrame("Frame"); gScrollChild:SetSize(560, 1); gScroll:SetScrollChild(gScrollChild)

    local gHeader = CreateFrame("Frame", nil, guildFrame)
    gHeader:SetPoint("TOPLEFT", 10, -65); gHeader:SetSize(560, 20)
    
    -- Create horizontal line after headers
    local headerLine = guildFrame:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetColorTexture(0.5, 0.5, 0.5, 0.8)
    headerLine:SetPoint("TOPLEFT", 10, -85)
    headerLine:SetPoint("TOPRIGHT", -25, -85)
    
    local function CreateGHeader(t, w, x)
        local fs = gHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetText(t); fs:SetWidth(w); fs:SetJustifyH("LEFT"); fs:SetPoint("LEFT", x, 0)
        table.insert(guildHeaderRefs, fs)
    end
    -- Columns
    local gW = { name=100, lvl=30, zone=120, rank=100, note=200 }
    local gX = { name=5, lvl=110, zone=145, rank=270, note=375 }
    CreateGHeader("Name", gW.name, gX.name); CreateGHeader("Lvl", gW.lvl, gX.lvl)
    CreateGHeader("Zone", gW.zone, gX.zone); CreateGHeader("Rank", gW.rank, gX.rank); CreateGHeader("Note", gW.note, gX.note)

    -- Add OnShow script to update fonts/colors dynamically
    guildFrame:SetScript("OnShow", function()
        -- Refresh backdrop with current theme
        MidnightUI:ApplyThemedBackdrop(guildFrame)
        
        local db = BrokerBar.db.profile
        local FontKit = _G.MidnightUI_FontKit
        local titleFont, titleSize, bodyFont, bodySize, motdSize, fontFlags
        
        if FontKit then
            titleFont = FontKit:GetFont('header')
            titleSize = FontKit:GetSize('large')
            bodyFont = FontKit:GetFont('body')
            bodySize = FontKit:GetSize('normal')
            motdSize = FontKit:GetSize('medium')
            fontFlags = "OUTLINE"
        else
            local fontPath = LSM:Fetch("font", db.font) or "Fonts\\FRIZQT__.ttf"
            titleFont, bodyFont = fontPath, fontPath
            titleSize = db.fontSize + 2
            bodySize = db.fontSize
            motdSize = db.fontSize + 1
            fontFlags = "OUTLINE"
        end
        local r, g, b = GetColor()
        
        -- Update title
        guildTitle:SetFont(titleFont, titleSize, fontFlags)
        guildTitle:SetTextColor(r, g, b)
        
        -- Update MotD with larger font
        guildMotD:SetFont(bodyFont, motdSize, fontFlags)
        
        -- Update footer
        guildFooter:SetFont(bodyFont, bodySize, fontFlags)
        
        -- Update headers
        for _, fs in ipairs(guildHeaderRefs) do
            fs:SetFont(bodyFont, bodySize, fontFlags)
            fs:SetTextColor(r, g, b)
        end
    end)

    guildFrame:SetScript("OnUpdate", function(self, elapsed)
        if MouseIsOver(self) or (self.owner and MouseIsOver(self.owner)) then 
            self.timer = 0
        else 
            self.timer = (self.timer or 0) + elapsed
            if self.timer > 0.2 then 
                self:Hide() 
            end 
        end
    end)
end

function BrokerBar:UpdateGuildList()
    if not gScrollChild then return end
    for _, child in ipairs({gScrollChild:GetChildren()}) do 
        child:Hide() 
    end
    local members = {}; local num = GetNumGuildMembers(); guildMotD:SetText(GetGuildRosterMOTD() or "No Message")
    for i = 1, num do
        local name, rank, rankIndex, level, _, zone, note, _, online, _, class = GetGuildRosterInfo(i)
        if online then 
            table.insert(members, {name=name, rank=rank, rIdx=rankIndex, level=level, zone=zone, note=note, class=class}) 
        end
    end
    table.sort(members, function(a, b) return (a.rIdx == b.rIdx) and (a.name < b.name) or (a.rIdx < b.rIdx) end)
    
    local yOffset, db, fontPath = 0, BrokerBar.db.profile, LSM:Fetch("font", BrokerBar.db.profile.font)
    local gW = { name=100, lvl=30, zone=120, rank=100, note=200 }
    local gX = { name=5, lvl=110, zone=145, rank=270, note=375 }

    for _, m in ipairs(members) do
        local btn = CreateFrame("Button", nil, gScrollChild); btn:SetSize(560, 20); btn:SetPoint("TOPLEFT", 0, yOffset)
        local function AddTxt(t, w, x, c, lim)
            local fs = btn:CreateFontString(nil, "OVERLAY"); fs:SetFont(fontPath, db.fontSize, "OUTLINE")
            local sT = tostring(t or "")
            if lim and #sT > lim then 
                sT = sT:sub(1, lim).."..." 
            end
            fs:SetText(sT); fs:SetWidth(w); fs:SetJustifyH("LEFT"); fs:SetPoint("LEFT", x, 0)
            if c then fs:SetTextColor(c.r, c.g, c.b) end
        end
        -- Use RAID_CLASS_COLORS instead of C_ClassColor
        local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[m.class] or {r=1,g=1,b=1}
        AddTxt(m.name:gsub("%-.+", ""), gW.name, gX.name, color, 12); AddTxt(m.level, gW.lvl, gX.lvl, {r=1,g=1,b=1})
        AddTxt(m.zone, gW.zone, gX.zone, {r=1,g=0.82,b=0}); AddTxt(m.rank, gW.rank, gX.rank, {r=1,g=1,b=1})
        AddTxt(m.note, gW.note, gX.note, {r=0.8,g=0.8,b=0.8})
        btn:SetScript("OnClick", function() 
            if IsControlKeyDown() then 
                C_PartyInfo.InviteUnit(m.name) 
            else 
                ChatFrame_SendTell(m.name) 
            end 
        end)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1,1,1,0.1)
        yOffset = yOffset - 20
    end
    
    -- Adjust scroll child height to fit content
    local contentHeight = math.abs(yOffset) + 10
    gScrollChild:SetHeight(contentHeight)
    
    -- Adjust guild frame height dynamically (min 200, max 600)
    local frameHeight = math.min(600, math.max(200, contentHeight + 140))
    guildFrame:SetHeight(frameHeight)
end

-- Register the broker
guildObj = LDB:NewDataObject("MidnightGuild", {
    type = "data source", text = "0", icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
    OnClick = function() ToggleGuildFrame() end,
    OnEnter = function(self) 
        if IsInGuild() then 
            C_GuildInfo.GuildRoster()
            if not guildFrame then 
                BrokerBar:CreateGuildFrame() 
            end
            guildFrame.owner = self
            BrokerBar:UpdateGuildList()
            SmartAnchor(guildFrame, self)
            guildFrame:Show() 
        end 
    end
})
