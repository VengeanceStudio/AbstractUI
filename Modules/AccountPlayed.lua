local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local AccountPlayed = AbstractUI:NewModule("AccountPlayed", "AceEvent-3.0")
local LDB = LibStub("LibDataBroker-1.1")

-- SavedVariables
AccountPlayedDB = AccountPlayedDB or {}
AccountPlayedPopupDB = AccountPlayedPopupDB or {
    width = 520,
    height = 300,
    point = "CENTER",
    x = 0,
    y = 0,
    useYears = false,
}

-- Module state
local lastPlayedRequest = 0
local popupFrame = nil
local popupRows = {}
local charPanel = nil
local charPanelClass = nil

-- Database defaults
local defaults = {
    profile = {
        enabled = true,
    }
}

-- Localization (basic English)
local L = {
    WINDOW_TITLE = "Account Played",
    TOTAL = "Total: ",
    NO_DATA = "No data available",
    TIME_UNIT_YEAR = "y",
    TIME_UNIT_DAY = "d",
    TIME_UNIT_HOUR = "h",
    TIME_UNIT_MINUTE = "m",
    UNKNOWN = "Unknown",
    CLICK_TO_PRINT = "Left-Click: Print to chat",
    CHAR_PANEL_RIGHT_CLICK = "Right-Click: Show characters",
    CHAR_PANEL_REMOVE_TIP = "Remove this character from tracking",
    USE_YEARS_LABEL = "Use Days/Years",
    TIME_FORMAT_TITLE = "Time Format",
    TIME_FORMAT_YEARS = "Checked: Show days and years",
    TIME_FORMAT_HOURS = "Unchecked: Show hours and minutes",
    CMD_DELETE_CONFIRM = "Delete time tracking for %s?",
    CMD_DELETE_SUCCESS = "Deleted: %s",
    CMD_DELETE_NOT_FOUND = "Character not found: %s",
    CMD_DELETE_USAGE = "Usage: /apdelete CharacterName-RealmName",
    DB_CORRUPTED = "AccountPlayed database corrupted, resetting...",
    DEBUG_HEADER = "Account Played - Tracked Characters:",
}

-- -----------------------------------------------------------------------------
-- Initialization
-- -----------------------------------------------------------------------------

function AccountPlayed:OnInitialize()
    self:RegisterMessage("AbstractUI_DB_READY", "OnDBReady")
end

function AccountPlayed:OnDBReady()
    if not AbstractUI.db or not AbstractUI.db.profile or not AbstractUI.db.profile.modules then
        self:Disable()
        return
    end
    
    if not AbstractUI.db.profile.modules.accountPlayed then 
        self:Disable()
        return 
    end
    
    self.db = AbstractUI.db:RegisterNamespace("AccountPlayed", defaults)
    
    -- Validate database
    if type(AccountPlayedDB) ~= "table" then
        print("|cffff0000" .. L.DB_CORRUPTED .. "|r")
        AccountPlayedDB = {}
    end
    
    self:MigrateOldData()
    
    -- Register events
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("TIME_PLAYED_MSG")
    
    -- Register broker
    self:RegisterBroker()
    
    -- Register slash commands
    self:RegisterCommands()
end

function AccountPlayed:MigrateOldData()
    for charKey, data in pairs(AccountPlayedDB) do
        if type(data) == "number" then
            AccountPlayedDB[charKey] = { time = data, class = "UNKNOWN" }
        end
    end
end

-- -----------------------------------------------------------------------------
-- Events
-- -----------------------------------------------------------------------------

function AccountPlayed:PLAYER_LOGIN()
    self:SafeRequestTimePlayed()
end

function AccountPlayed:TIME_PLAYED_MSG(event, totalTimePlayed)
    local realm, name = self:GetCharInfo()
    local charKey = self:GetCharKey(realm, name)
    local _, classFile = UnitClass("player")
    classFile = classFile or "UNKNOWN"
    
    local existing = AccountPlayedDB[charKey]
    if not existing or not existing.time or totalTimePlayed > existing.time then
        AccountPlayedDB[charKey] = {
            time = totalTimePlayed,
            class = classFile,
        }
    end
end

-- -----------------------------------------------------------------------------
-- Helper Functions
-- -----------------------------------------------------------------------------

function AccountPlayed:GetCharInfo()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
    return realm, name
end

function AccountPlayed:GetCharKey(realm, name)
    return realm .. "-" .. name
end

function AccountPlayed:GetLocalizedClass(classFile)
    if not classFile or classFile == "UNKNOWN" then 
        return L.UNKNOWN
    end
    return LOCALIZED_CLASS_NAMES_MALE[classFile] or classFile
end

function AccountPlayed:SafeRequestTimePlayed()
    local now = GetTime()
    if now - lastPlayedRequest >= 10 then
        RequestTimePlayed()
        lastPlayedRequest = now
        return true
    end
    return false
end

-- -----------------------------------------------------------------------------
-- Time Formatting
-- -----------------------------------------------------------------------------

function AccountPlayed:FormatTimeSmart(seconds, useYears)
    seconds = tonumber(seconds) or 0
    local hours = seconds / 3600
    
    if useYears then
        local totalHours = math.floor(hours)
        local days = math.floor(totalHours / 24)
        return days > 0 and string.format("%d%s", days, L.TIME_UNIT_DAY) or string.format("%d%s", totalHours, L.TIME_UNIT_HOUR)
    else
        return string.format("%d%s", math.floor(hours), L.TIME_UNIT_HOUR)
    end
end

function AccountPlayed:FormatTimeDetailed(seconds, useYears)
    seconds = tonumber(seconds) or 0
    local hours = seconds / 3600
    
    if useYears then
        local totalHours = math.floor(hours)
        local days = math.floor(totalHours / 24)
        local remHours = totalHours % 24
        return days > 0 and string.format("%d%s %d%s", days, L.TIME_UNIT_DAY, remHours, L.TIME_UNIT_HOUR) or string.format("%d%s", totalHours, L.TIME_UNIT_HOUR)
    else
        local h = math.floor(hours)
        local m = math.floor((seconds % 3600) / 60)
        return string.format("%d%s %d%s", h, L.TIME_UNIT_HOUR, m, L.TIME_UNIT_MINUTE)
    end
end

function AccountPlayed:FormatTimeTotal(seconds, useYears)
    seconds = tonumber(seconds) or 0
    local hours = seconds / 3600
    
    if useYears and hours >= 9000 then
        local days = math.floor(hours / 24)
        local years = math.floor(days / 365)
        local remDays = days % 365
        return years > 0 and string.format("%d%s %d%s", years, L.TIME_UNIT_YEAR, remDays, L.TIME_UNIT_DAY) or string.format("%d%s", days, L.TIME_UNIT_DAY)
    end
    return self:FormatTimeSmart(seconds, useYears)
end

-- -----------------------------------------------------------------------------
-- Data Aggregation
-- -----------------------------------------------------------------------------

function AccountPlayed:GetAccountTotal()
    local total = 0
    for _, data in pairs(AccountPlayedDB) do
        if type(data) == "table" and data.time then
            total = total + data.time
        end
    end
    return total
end

function AccountPlayed:GetClassTotals()
    local totals, accountTotal = {}, 0
    for _, data in pairs(AccountPlayedDB) do
        if type(data) == "table" and data.time and data.class then
            totals[data.class] = (totals[data.class] or 0) + data.time
            accountTotal = accountTotal + data.time
        end
    end
    return totals, accountTotal
end

function AccountPlayed:GetCharactersByClass(className)
    local chars = {}
    for charKey, data in pairs(AccountPlayedDB) do
        if type(data) == "table" and data.class == className and data.time then
            table.insert(chars, { key = charKey, time = data.time, class = data.class })
        end
    end
    table.sort(chars, function(a, b) return a.time > b.time end)
    return chars
end

-- -----------------------------------------------------------------------------
-- Character Delete Confirmation
-- -----------------------------------------------------------------------------

StaticPopupDialogs["ACCOUNTPLAYED_CONFIRM_DELETE"] = {
    text = "",
    button1 = DELETE,
    button2 = CANCEL,
    OnAccept = function(self, data)
        if not data or not data.foundKey then return end
        AccountPlayedDB[data.foundKey] = nil
        print("|cff00ff00" .. string.format(L.CMD_DELETE_SUCCESS, data.foundKey) .. "|r")
        if popupFrame and popupFrame:IsShown() then
            AccountPlayed:UpdatePopupDisplay()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function AccountPlayed:ConfirmDeleteKey(foundKey)
    StaticPopupDialogs["ACCOUNTPLAYED_CONFIRM_DELETE"].text = string.format(L.CMD_DELETE_CONFIRM, foundKey)
    StaticPopup_Show("ACCOUNTPLAYED_CONFIRM_DELETE", nil, nil, { foundKey = foundKey })
end

-- -----------------------------------------------------------------------------
-- Character Panel (flyout)
-- -----------------------------------------------------------------------------

function AccountPlayed:CreateCharPanel()
    if charPanel then return charPanel end
    
    local CPANEL_W = 230
    local CPANEL_ROW_H = 22
    local CPANEL_HEADER_H = 28
    local CPANEL_PAD = 6
    
    local p = CreateFrame("Frame", "AccountPlayedCharPanel", UIParent, "BackdropTemplate")
    p:SetWidth(CPANEL_W)
    p:SetHeight(CPANEL_HEADER_H + CPANEL_PAD)
    p:SetFrameStrata("DIALOG")
    p:SetFrameLevel(110)
    p:SetClampedToScreen(true)
    
    p:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    p:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    
    -- Title
    p.titleText = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.titleText:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)
    p.titleText:SetPoint("TOPRIGHT", p, "TOPRIGHT", -26, -10)
    p.titleText:SetJustifyH("LEFT")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        p:Hide()
        charPanelClass = nil
    end)
    
    -- Divider
    local div = p:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -(CPANEL_HEADER_H - 2))
    div:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, -(CPANEL_HEADER_H - 2))
    div:SetColorTexture(0.4, 0.4, 0.4, 0.8)
    
    -- Character rows
    p.charRows = {}
    for i = 1, 20 do
        local yOff = -(CPANEL_HEADER_H + CPANEL_PAD + (i - 1) * CPANEL_ROW_H)
        local row = CreateFrame("Frame", nil, p)
        row:SetHeight(CPANEL_ROW_H)
        row:SetPoint("TOPLEFT", p, "TOPLEFT", 10, yOff)
        row:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, yOff)
        
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0)
        
        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameText:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.nameText:SetPoint("RIGHT", row, "RIGHT", -110, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetWordWrap(false)
        
        row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.timeText:SetPoint("RIGHT", row, "RIGHT", -52, 0)
        row.timeText:SetWidth(72)
        row.timeText:SetJustifyH("RIGHT")
        row.timeText:SetTextColor(0.75, 0.75, 0.75)
        
        local trashBtn = CreateFrame("Button", nil, row)
        trashBtn:SetSize(44, 18)
        trashBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        
        local trashLabel = trashBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        trashLabel:SetAllPoints()
        trashLabel:SetText("|cffff4040" .. DELETE .. "|r")
        trashLabel:SetJustifyH("CENTER")
        trashBtn:SetWidth(trashLabel:GetStringWidth() + 8)
        
        trashBtn:SetScript("OnEnter", function()
            row.bg:SetColorTexture(1, 0.25, 0.25, 0.15)
            GameTooltip:SetOwner(trashBtn, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.CHAR_PANEL_REMOVE_TIP, 1, 0.35, 0.35)
            GameTooltip:Show()
        end)
        trashBtn:SetScript("OnLeave", function()
            row.bg:SetColorTexture(1, 1, 1, 0)
            GameTooltip:Hide()
        end)
        trashBtn:SetScript("OnClick", function()
            if row.charKey then
                AccountPlayed:ConfirmDeleteKey(row.charKey)
            end
        end)
        
        row.trashBtn = trashBtn
        row:Hide()
        p.charRows[i] = row
    end
    
    p:Hide()
    charPanel = p
    table.insert(UISpecialFrames, "AccountPlayedCharPanel")
    return p
end

function AccountPlayed:ShowCharPanel(className, forceShow, anchorRow)
    local p = self:CreateCharPanel()
    
    if not forceShow and charPanelClass == className and p:IsShown() then
        p:Hide()
        charPanelClass = nil
        return
    end
    
    local chars = self:GetCharactersByClass(className)
    if #chars == 0 then
        p:Hide()
        charPanelClass = nil
        return
    end
    
    charPanelClass = className
    
    if anchorRow then
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", anchorRow, "TOPRIGHT", 6, 0)
    elseif not p:IsShown() then
        p:ClearAllPoints()
        if popupFrame and popupFrame:IsShown() then
            p:SetPoint("TOPLEFT", popupFrame, "TOPRIGHT", 4, 0)
        else
            p:SetPoint("CENTER")
        end
    end
    
    local color = RAID_CLASS_COLORS[className] or { r = 1, g = 1, b = 1 }
    p.titleText:SetText(self:GetLocalizedClass(className))
    p.titleText:SetTextColor(color.r, color.g, color.b)
    
    for i, row in ipairs(p.charRows) do
        local char = chars[i]
        if char then
            local name = char.key:match("%-(.+)$") or char.key
            local timeStr = self:FormatTimeDetailed(char.time, AccountPlayedPopupDB.useYears)
            row.nameText:SetText(name)
            row.nameText:SetTextColor(color.r, color.g, color.b)
            row.timeText:SetText(timeStr)
            row.charKey = char.key
            row:Show()
        else
            row.charKey = nil
            row:Hide()
        end
    end
    
    local CPANEL_HEADER_H = 28
    local CPANEL_PAD = 6
    local CPANEL_ROW_H = 22
    p:SetHeight(CPANEL_HEADER_H + CPANEL_PAD + #chars * CPANEL_ROW_H + CPANEL_PAD)
    p:Show()
end

-- -----------------------------------------------------------------------------
-- Main Popup Window
-- -----------------------------------------------------------------------------

function AccountPlayed:CreatePopup()
    if popupFrame then return popupFrame end
    
    local START_W = AccountPlayedPopupDB.width or 540
    local START_H = AccountPlayedPopupDB.height or 300
    local MIN_W, MIN_H = 420, 200
    local MAX_W, MAX_H = 720, 400
    
    local f = CreateFrame("Frame", "AccountPlayedPopup", UIParent, "BackdropTemplate")
    f:SetSize(START_W, START_H)
    
    if AccountPlayedPopupDB.point then
        f:SetPoint(AccountPlayedPopupDB.point, UIParent, AccountPlayedPopupDB.point, 
                   AccountPlayedPopupDB.x or 0, AccountPlayedPopupDB.y or 0)
    else
        f:SetPoint("CENTER")
    end
    
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        AccountPlayedPopupDB.point = point
        AccountPlayedPopupDB.x = x
        AccountPlayedPopupDB.y = y
    end)
    
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    end
    f:SetClampedToScreen(true)
    
    -- Resize grabber
    local br = CreateFrame("Button", nil, f)
    br:SetSize(16, 16)
    br:SetPoint("BOTTOMRIGHT", -6, 6)
    br:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    br:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    br:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    br:SetScript("OnMouseDown", function(self) self:GetParent():StartSizing("BOTTOMRIGHT") end)
    br:SetScript("OnMouseUp", function(self) self:GetParent():StopMovingOrSizing() end)
    
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetBackdropColor(0, 0, 0, 0.5)
    
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.title:SetPoint("TOP", f, "TOP", 0, -12)
    f.title:SetText(L.WINDOW_TITLE)
    
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        f:Hide()
    end)
    
    table.insert(UISpecialFrames, "AccountPlayedPopup")
    
    f:SetScript("OnHide", function()
        if charPanel then charPanel:Hide() end
        charPanelClass = nil
    end)
    
    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)
    f.scrollFrame = scrollFrame
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    f.content = content
    
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local step = 20
        local new = self:GetVerticalScroll() - delta * step
        new = math.max(0, math.min(new, self:GetVerticalScrollRange()))
        self:SetVerticalScroll(new)
    end)
    
    f.totalRow = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.totalRow:SetPoint("BOTTOMLEFT", 15, 18)
    f.totalRow:SetTextColor(1, 0.82, 0)
    
    -- Create rows
    local rowHeight = 22
    for i = 1, 20 do
        local row = self:CreateRow(content, START_W - 60, rowHeight)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        row:Hide()
        popupRows[i] = row
    end
    
    f:SetScript("OnSizeChanged", function(self, w, h)
        if w < MIN_W then self:SetWidth(MIN_W) end
        if h < MIN_H then self:SetHeight(MIN_H) end
        if w > MAX_W then self:SetWidth(MAX_W) end
        if h > MAX_H then self:SetHeight(MAX_H) end
        
        AccountPlayedPopupDB.width = self:GetWidth()
        AccountPlayedPopupDB.height = self:GetHeight()
        
        local cw = self.scrollFrame:GetWidth()
        self.content:SetWidth(cw)
        for _, row in ipairs(popupRows) do
            row:SetWidth(cw)
        end
        
        AccountPlayed:UpdateScrollBarVisibility(self)
    end)
    
    -- Format toggle checkbox
    local checkBox = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    checkBox:SetSize(24, 24)
    checkBox:SetPoint("BOTTOMRIGHT", -28, 20)
    checkBox:SetChecked(AccountPlayedPopupDB.useYears)
    
    checkBox.text = checkBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkBox.text:SetPoint("RIGHT", checkBox, "LEFT", -4, 0)
    checkBox.text:SetText(L.USE_YEARS_LABEL)
    checkBox.text:SetTextColor(0.9, 0.9, 0.9)
    
    checkBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L.TIME_FORMAT_TITLE, 1, 1, 1)
        GameTooltip:AddLine(L.TIME_FORMAT_YEARS, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L.TIME_FORMAT_HOURS, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    checkBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    checkBox:SetScript("OnClick", function(self)
        AccountPlayedPopupDB.useYears = self:GetChecked()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        AccountPlayed:UpdatePopupDisplay()
    end)
    
    f.formatCheckbox = checkBox
    f:Hide()
    popupFrame = f
    return f
end

function AccountPlayed:CreateRow(parent, width, height)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, height)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.1)
    row.highlight:Hide()
    
    row.classText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.classText:SetPoint("LEFT", 0, 0)
    row.classText:SetWidth(120)
    row.classText:SetJustifyH("LEFT")
    
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetPoint("LEFT", row.classText, "RIGHT", 8, 0)
    row.bar:SetPoint("RIGHT", row, "RIGHT", -140, 0)
    row.bar:SetHeight(height - 4)
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(0)
    row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    
    row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bar.bg:SetAllPoints()
    row.bar.bg:SetColorTexture(0, 0, 0, 0.4)
    
    row.valueText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.valueText:SetPoint("LEFT", row.bar, "RIGHT", 8, 0)
    row.valueText:SetWidth(170)
    row.valueText:SetJustifyH("LEFT")
    
    row:SetScript("OnEnter", function(self)
        self.highlight:Show()
        if self.className then
            local chars = AccountPlayed:GetCharactersByClass(self.className)
            if #chars > 0 then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local localizedName = AccountPlayed:GetLocalizedClass(self.className)
                GameTooltip:AddLine(localizedName, 1, 1, 1)
                GameTooltip:AddLine(" ")
                for _, char in ipairs(chars) do
                    local name = char.key:match("%-(.+)$") or char.key
                    local timeStr = AccountPlayed:FormatTimeDetailed(char.time, AccountPlayedPopupDB.useYears)
                    local color = RAID_CLASS_COLORS[char.class] or { r = 1, g = 1, b = 1 }
                    GameTooltip:AddDoubleLine(name, timeStr, color.r, color.g, color.b, 1, 1, 1)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L.CLICK_TO_PRINT, 0.5, 0.5, 0.5)
                GameTooltip:AddLine(L.CHAR_PANEL_RIGHT_CLICK, 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end
        end
    end)
    
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)
    
    row:SetScript("OnClick", function(self, button)
        if not self.className then return end
        
        if button == "RightButton" then
            GameTooltip:Hide()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            AccountPlayed:ShowCharPanel(self.className, false, self)
        else
            local chars = AccountPlayed:GetCharactersByClass(self.className)
            if #chars > 0 then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                local localizedName = AccountPlayed:GetLocalizedClass(self.className)
                print("|cff00ff00" .. localizedName .. ":|r")
                for _, char in ipairs(chars) do
                    local name = char.key:match("%-(.+)$") or char.key
                    local timeStr = AccountPlayed:FormatTimeDetailed(char.time, AccountPlayedPopupDB.useYears)
                    local color = RAID_CLASS_COLORS[char.class] or { r = 1, g = 1, b = 1 }
                    print(string.format("  |cff%02x%02x%02x%s|r - %s",
                        color.r * 255, color.g * 255, color.b * 255, name, timeStr))
                end
            end
        end
    end)
    
    return row
end

function AccountPlayed:UpdateScrollBarVisibility(frame)
    local sf = frame.scrollFrame
    local sb = sf and (sf.ScrollBar or sf.scrollBar)
    if not sb then return end
    
    if sf:GetVerticalScrollRange() > 0 then
        sb:Show()
    else
        sb:Hide()
        sf:SetVerticalScroll(0)
    end
end

function AccountPlayed:UpdatePopupDisplay()
    local f = self:CreatePopup()
    local totals = self:GetClassTotals()
    local accountTotal = self:GetAccountTotal()
    
    if f.formatCheckbox then
        f.formatCheckbox:SetChecked(AccountPlayedPopupDB.useYears)
    end
    
    if accountTotal == 0 then
        popupRows[1].classText:SetText(L.NO_DATA)
        popupRows[1].bar:SetValue(0)
        popupRows[1].valueText:SetText("")
        popupRows[1]:Show()
        f.totalRow:SetText(L.TOTAL .. self:FormatTimeTotal(0, AccountPlayedPopupDB.useYears))
        return
    end
    
    local sorted = {}
    for class, time in pairs(totals) do
        table.insert(sorted, { class = class, time = time })
    end
    table.sort(sorted, function(a, b) return a.time > b.time end)
    
    local topTime = sorted[1].time
    
    for i, row in ipairs(popupRows) do
        local entry = sorted[i]
        if entry then
            local percent = entry.time / accountTotal
            local barPercent = entry.time / topTime
            local color = RAID_CLASS_COLORS[entry.class] or { r = 1, g = 1, b = 1 }
            
            row.className = entry.class
            row.classText:SetText(self:GetLocalizedClass(entry.class))
            row.classText:SetTextColor(color.r, color.g, color.b)
            row.bar:SetValue(barPercent)
            row.bar:SetStatusBarColor(color.r, color.g, color.b)
            row.valueText:SetText(string.format("%5.1f%% - %s", percent * 100, 
                self:FormatTimeSmart(entry.time, AccountPlayedPopupDB.useYears)))
            row:Show()
        else
            row.className = nil
            row:Hide()
        end
    end
    
    f.content:SetHeight(#sorted * 22)
    self:UpdateScrollBarVisibility(f)
    f.totalRow:SetText(L.TOTAL .. self:FormatTimeTotal(accountTotal, AccountPlayedPopupDB.useYears))
    
    if charPanel and charPanel:IsShown() and charPanelClass then
        self:ShowCharPanel(charPanelClass, true)
    end
end

function AccountPlayed:ToggleWindow()
    local f = self:CreatePopup()
    if f:IsShown() then
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        f:Hide()
    else
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        self:UpdatePopupDisplay()
        f:Show()
    end
end

-- -----------------------------------------------------------------------------
-- LibDataBroker
-- -----------------------------------------------------------------------------

function AccountPlayed:RegisterBroker()
    local broker = LDB:NewDataObject("AbstractAccountPlayed", {
        type = "data source",
        text = "0h",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        OnClick = function(_, button)
            if button == "LeftButton" then
                AccountPlayed:ToggleWindow()
            end
        end,
        OnTooltipShow = function(tooltip)
            local total = AccountPlayed:GetAccountTotal()
            tooltip:AddLine("|cffffffffAccount Played|r")
            tooltip:AddLine(" ")
            tooltip:AddDoubleLine("Total Time:", AccountPlayed:FormatTimeTotal(total, AccountPlayedPopupDB.useYears), 1, 1, 1, 1, 1, 1)
            tooltip:AddLine(" ")
            tooltip:AddLine("Click to toggle window", 0.5, 0.5, 0.5)
        end,
    })
    
    -- Update text
    C_Timer.NewTicker(60, function()
        local total = AccountPlayed:GetAccountTotal()
        broker.text = AccountPlayed:FormatTimeSmart(total, AccountPlayedPopupDB.useYears)
    end)
    
    -- Initial update
    local total = self:GetAccountTotal()
    broker.text = self:FormatTimeSmart(total, AccountPlayedPopupDB.useYears)
end

-- -----------------------------------------------------------------------------
-- Slash Commands
-- -----------------------------------------------------------------------------

function AccountPlayed:RegisterCommands()
    SLASH_ACCOUNTPLAYED1 = "/aplayed"
    SlashCmdList.ACCOUNTPLAYED = function(input)
        AccountPlayed:ToggleWindow()
    end
    
    SLASH_ACCOUNTPLAYEDDEBUG1 = "/apdebug"
    SlashCmdList.ACCOUNTPLAYEDDEBUG = function()
        print("|cffff0000" .. L.DEBUG_HEADER .. "|r")
        for charKey, data in pairs(AccountPlayedDB) do
            local time, class
            if type(data) == "table" then
                time, class = data.time or 0, data.class or "UNKNOWN"
            else
                time, class = data, "UNKNOWN"
            end
            local displayName = AccountPlayed:GetLocalizedClass(class)
            print(string.format(" |cffffff00 - %s : %s (%s)|r", charKey, AccountPlayed:FormatTimeSmart(time, false), class))
        end
    end
    
    SLASH_ACCOUNTPLAYEDDELETE1 = "/apdelete"
    SlashCmdList.ACCOUNTPLAYEDDELETE = function(input)
        input = input and input:match("^%s*(.-)%s*$") or ""
        
        if input == "" then
            print("|cffff9900" .. L.CMD_DELETE_USAGE .. "|r")
            return
        end
        
        local charName, realmName = input:match("^([^%-]+)%-(.+)$")
        if not charName or not realmName then
            print("|cffff9900" .. L.CMD_DELETE_USAGE .. "|r")
            return
        end
        
        local targetKey = realmName .. "-" .. charName
        local foundKey = nil
        local lowerTarget = targetKey:lower()
        for dbKey in pairs(AccountPlayedDB) do
            if dbKey:lower() == lowerTarget then
                foundKey = dbKey
                break
            end
        end
        
        if not foundKey then
            print("|cffff0000" .. string.format(L.CMD_DELETE_NOT_FOUND, input) .. "|r")
            return
        end
        
        AccountPlayed:ConfirmDeleteKey(foundKey)
    end
end

-- -----------------------------------------------------------------------------
-- Options
-- -----------------------------------------------------------------------------

function AccountPlayed:GetOptions()
    return {
        type = "group",
        name = "Account Played",
        order = 50,
        args = {
            header = {
                type = "header",
                name = "Account Played Time Tracker",
                order = 1,
            },
            desc = {
                type = "description",
                name = "Tracks play time across all characters on your account. Shows a breakdown by class with a detailed character list.\n\n|cff00ff00Commands:|r\n• /aplayed - Toggle window\n• /apdebug - List all tracked characters\n• /apdelete CharName-RealmName - Remove a character",
                order = 2,
                fontSize = "medium",
            },
            showWindow = {
                type = "execute",
                name = "Show Window",
                desc = "Open the Account Played window",
                order = 3,
                func = function() AccountPlayed:ToggleWindow() end,
            },
        }
    }
end
