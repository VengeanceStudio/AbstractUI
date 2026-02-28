-- MidnightUI Friends Broker
-- Displays online friends count and provides a popup with detailed friend list

if not BrokerBar then return end

local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local LDB = LibStub("LibDataBroker-1.1")
local LSM = LibStub("LibSharedMedia-3.0")
local friendsFrame, friendTitle, friendFooter, scrollChild, listSeparator
local headerRefs = {}
local friendObj

-- Create the friends popup frame
function BrokerBar:CreateFriendsFrame()
    if friendsFrame then return end
    friendsFrame = CreateFrame("Frame", "MidnightFriendsPopup", UIParent, "BackdropTemplate")
    friendsFrame:SetSize(600, 400); friendsFrame:SetFrameStrata("DIALOG"); friendsFrame:EnableMouse(true); friendsFrame:Hide()
    -- Don't skin on creation, wait for OnShow to apply themed backdrop
    -- MidnightUI:SkinFrame(friendsFrame)

    friendTitle = friendsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    friendTitle:SetPoint("TOP", 0, -10); friendTitle:SetText("Friends List")

    friendFooter = friendsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    friendFooter:SetPoint("BOTTOM", 0, 8); friendFooter:SetText("|cff00ff00Click: Whisper • Ctrl-Click: Invite|r")

    local fScroll = CreateFrame("ScrollFrame", nil, friendsFrame, "UIPanelScrollFrameTemplate")
    fScroll:SetPoint("TOPLEFT", 10, -55); fScroll:SetPoint("BOTTOMRIGHT", -25, 25)
    scrollChild = CreateFrame("Frame"); scrollChild:SetSize(560, 1); fScroll:SetScrollChild(scrollChild)
    listSeparator = scrollChild:CreateTexture(nil, "ARTWORK"); listSeparator:SetHeight(1); listSeparator:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    local fHeader = CreateFrame("Frame", nil, friendsFrame)
    fHeader:SetPoint("TOPLEFT", 10, -30); fHeader:SetSize(560, 20)
    
    -- Create horizontal line after headers
    local headerLine = friendsFrame:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetColorTexture(0.5, 0.5, 0.5, 0.8)
    headerLine:SetPoint("TOPLEFT", 10, -50)
    headerLine:SetPoint("TOPRIGHT", -25, -50)
    
    local function CreateHeader(text, width, xPos)
        local fs = fHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetText(text); fs:SetWidth(width); fs:SetJustifyH("LEFT"); fs:SetPoint("LEFT", xPos, 0)
        table.insert(headerRefs, fs) 
    end
    -- Columns (Adjusted faction column width)
    local colW = { btag=135, char=100, lvl=30, zone=120, realm=80, fac=50 }
    local colX = { btag=5, char=145, lvl=250, zone=285, realm=410, fac=495 }
    CreateHeader("BattleTag", colW.btag, colX.btag); CreateHeader("Character", colW.char, colX.char)
    CreateHeader("Lvl", colW.lvl, colX.lvl); CreateHeader("Zone", colW.zone, colX.zone)
    CreateHeader("Realm", colW.realm, colX.realm); CreateHeader("Faction", colW.fac, colX.fac)

    -- Add OnShow script to update fonts/colors dynamically
    friendsFrame:SetScript("OnShow", function()
        -- Refresh backdrop with current theme
        MidnightUI:ApplyThemedBackdrop(friendsFrame)
        
        local db = BrokerBar.db.profile
        local FontKit = _G.MidnightUI_FontKit
        local titleFont, titleSize, bodyFont, bodySize, fontFlags
        
        if FontKit then
            titleFont = FontKit:GetFont('header')
            titleSize = FontKit:GetSize('large')
            bodyFont = FontKit:GetFont('body')
            bodySize = FontKit:GetSize('normal')
            fontFlags = "OUTLINE"
        else
            local fontPath = LSM:Fetch("font", db.font) or "Fonts\\FRIZQT__.ttf"
            titleFont, bodyFont = fontPath, fontPath
            titleSize = db.fontSize + 2
            bodySize = db.fontSize
            fontFlags = "OUTLINE"
        end
        local r, g, b = GetColor()
        
        -- Update title
        friendTitle:SetFont(titleFont, titleSize, fontFlags)
        friendTitle:SetTextColor(r, g, b)
        
        -- Update footer
        friendFooter:SetFont(bodyFont, bodySize, fontFlags)
        
        -- Update headers
        for _, fs in ipairs(headerRefs) do
            fs:SetFont(bodyFont, bodySize, fontFlags)
            fs:SetTextColor(r, g, b)
        end
    end)

    friendsFrame:SetScript("OnUpdate", function(self, elapsed)
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

function BrokerBar:UpdateFriendList()
    if not scrollChild then return end
    for _, child in ipairs({scrollChild:GetChildren()}) do 
        child:Hide() 
    end
    
    local wowFriends, bnetFriends = {}, {}
    local numBNet = BNGetNumFriends() or 0
    for i = 1, numBNet do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.gameAccountInfo and info.gameAccountInfo.isOnline then
            local g = info.gameAccountInfo
            if (g.clientProgram == BNET_CLIENT_WOW) and (g.wowProjectID == 1) then
                -- Use classID to get proper class token for coloring
                local classToken = g.className
                if g.classID then
                    local classInfo = C_CreatureInfo.GetClassInfo(g.classID)
                    if classInfo then
                        classToken = classInfo.classFile
                    end
                end
                table.insert(wowFriends, {name=g.characterName, bnet=info.battleTag, level=g.characterLevel, zone=g.areaName, realm=g.realmName, faction=g.factionName, class=classToken or g.className})
            else
                table.insert(bnetFriends, {bnet=info.battleTag, game=g.richPresence or g.clientProgram, status=(g.isWowMobile and "Mobile" or "Online")})
            end
        end
    end

    local yOffset, db, fontPath = 0, BrokerBar.db.profile, LSM:Fetch("font", BrokerBar.db.profile.font)
    local colW = { btag=135, char=100, lvl=30, zone=120, realm=80, fac=50 }
    local colX = { btag=5, char=145, lvl=250, zone=285, realm=410, fac=495 }

    local function CreateRow(data, isWoW)
        local btn = CreateFrame("Button", nil, scrollChild); btn:SetSize(560, 20); btn:SetPoint("TOPLEFT", 0, yOffset)
        local function AddText(t, w, x, c)
            local fs = btn:CreateFontString(nil, "OVERLAY"); fs:SetFont(fontPath, db.fontSize, "OUTLINE")
            local sT = tostring(t or "")
            if #sT > 20 then 
                sT = sT:sub(1, 20).."..." 
            end
            fs:SetText(sT); fs:SetWidth(w); fs:SetJustifyH("LEFT"); fs:SetPoint("LEFT", x, 0)
            if c then fs:SetTextColor(c.r, c.g, c.b) end
        end
        if isWoW then
            local cToken = classTokenLookup[data.class] or data.class
            -- Use RAID_CLASS_COLORS instead of C_ClassColor
            local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[cToken] or {r=1,g=1,b=1}
            AddText(data.bnet, colW.btag, colX.btag, {r=0.51,g=0.77,b=1}); AddText(data.name, colW.char, colX.char, color)
            AddText(data.level, colW.lvl, colX.lvl, {r=1,g=1,b=1}); AddText(data.zone, colW.zone, colX.zone, {r=1,g=0.82,b=0})
            AddText(data.realm, colW.realm, colX.realm, {r=1,g=1,b=1})
            
            -- Fixed faction icon logic with proper texture markup
            local facIcon = ""
            if data.faction == "Horde" then
                facIcon = "|TInterface\\Icons\\INV_BannerPVP_01:16:16:0:0|t"
            elseif data.faction == "Alliance" then
                facIcon = "|TInterface\\Icons\\INV_BannerPVP_02:16:16:0:0|t"
            end
            AddText(facIcon, colW.fac, colX.fac)

            btn:SetScript("OnClick", function() 
                local t = data.name
                if data.realm then 
                    t=t.."-"..data.realm:gsub("%s+","") 
                end
                if IsControlKeyDown() then 
                    C_PartyInfo.InviteUnit(t) 
                else 
                    ChatFrame_SendTell(t) 
                end 
            end)
        else
            AddText(data.bnet, colW.btag, colX.btag, {r=0.51,g=0.77,b=1}); AddText(data.game, colW.char, colX.char, {r=0.6,g=0.6,b=0.6})
            AddText(data.status, colW.zone, colX.zone, (data.status=="Mobile" and {r=0.5,g=0.5,b=0.5} or {r=0,g=1,b=0}))
            btn:SetScript("OnClick", function() 
                ChatFrame_SendTell(data.bnet) 
            end)
        end
        local hl = btn:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1,1,1,0.1)
        yOffset = yOffset - 20
    end

    for _, f in ipairs(wowFriends) do 
        CreateRow(f, true) 
    end
    if #wowFriends > 0 and #bnetFriends > 0 then
        listSeparator:ClearAllPoints()
        listSeparator:SetPoint("TOPLEFT", 5, yOffset-2)
        listSeparator:SetPoint("TOPRIGHT", -5, yOffset-2)
        listSeparator:Show()
        yOffset = yOffset - 5
    else 
        listSeparator:Hide() 
    end
    for _, f in ipairs(bnetFriends) do 
        CreateRow(f, false) 
    end
    
    -- Adjust scroll child height to fit content
    local contentHeight = math.abs(yOffset) + 10
    scrollChild:SetHeight(contentHeight)
    
    -- Adjust friends frame height dynamically (min 200, max 600)
    local frameHeight = math.min(600, math.max(200, contentHeight + 90))
    friendsFrame:SetHeight(frameHeight)
end

-- Register the broker
friendObj = LDB:NewDataObject("MidnightFriends", {
    type = "data source", text = "0", icon = "Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon",
    OnClick = function() ToggleFriendsFrame(1) end,
    OnEnter = function(self) 
        if not friendsFrame then 
            BrokerBar:CreateFriendsFrame() 
        end
        friendsFrame.owner = self
        BrokerBar:UpdateFriendList()
        SmartAnchor(friendsFrame, self)
        friendsFrame:Show() 
    end
})
