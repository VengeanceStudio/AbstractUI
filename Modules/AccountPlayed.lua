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
    WINDOW_TITLE = "Time Played",
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
    DB_CORRUPTED = "Time Played database corrupted, resetting...",
    DEBUG_HEADER = "Time Played - Tracked Characters:",
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
    
    local ColorPalette = _G.AbstractUI_ColorPalette
    local FontKit = _G.AbstractUI_FontKit
    
    local CPANEL_W = 230
    local CPANEL_ROW_H = 22
    local CPANEL_HEADER_H = 32
    local CPANEL_PAD = 8
    
    local p = CreateFrame("Frame", "AccountPlayedCharPanel", UIParent, "BackdropTemplate")
    p:SetWidth(CPANEL_W)
    p:SetHeight(CPANEL_HEADER_H + CPANEL_PAD)
    p:SetFrameStrata("DIALOG")
    p:SetFrameLevel(110)
    p:SetClampedToScreen(true)
    
    -- AbstractUI styling
    p:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    p:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
    p:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Title
    p.titleText = FontKit:CreateFontString(p, "heading", "normal")
    p.titleText:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)
    p.titleText:SetPoint("TOPRIGHT", p, "TOPRIGHT", -32, -10)
    p.titleText:SetJustifyH("LEFT")
    
    -- Close button (AbstractUI style)
    local closeBtn = CreateFrame("Button", nil, p, "BackdropTemplate")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -4)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    closeBtn:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    closeBtn:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY")
    closeBtn.text:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    closeBtn.text:SetText("×")
    closeBtn.text:SetPoint("CENTER", 0, 1)
    closeBtn.text:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    closeBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ColorPalette:GetColor('button-hover'))
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    end)
    closeBtn:SetScript("OnClick", function()
        p:Hide()
        charPanelClass = nil
    end)
    
    -- Divider
    local div = p:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -(CPANEL_HEADER_H - 2))
    div:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -(CPANEL_HEADER_H - 2))
    div:SetColorTexture(ColorPalette:GetColor('panel-border'))
    
    -- Character rows
    p.charRows = {}
    for i = 1, 20 do
        local yOff = -(CPANEL_HEADER_H + CPANEL_PAD + (i - 1) * CPANEL_ROW_H)
        local row = CreateFrame("Frame", nil, p)
        row:SetHeight(CPANEL_ROW_H)
        row:SetPoint("TOPLEFT", p, "TOPLEFT", 8, yOff)
        row:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, yOff)
        
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0, 0, 0, 0)
        
        row.nameText = FontKit:CreateFontString(row, "body", "small")
        row.nameText:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.nameText:SetPoint("RIGHT", row, "RIGHT", -110, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetWordWrap(false)
        
        row.timeText = FontKit:CreateFontString(row, "body", "small")
        row.timeText:SetPoint("RIGHT", row, "RIGHT", -52, 0)
        row.timeText:SetWidth(72)
        row.timeText:SetJustifyH("RIGHT")
        row.timeText:SetTextColor(ColorPalette:GetColor('text-secondary'))
        
        local trashBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
        trashBtn:SetSize(44, 18)
        trashBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        trashBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = nil,
            tile = false,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        trashBtn:SetBackdropColor(0, 0, 0, 0)
        
        local trashLabel = trashBtn:CreateFontString(nil, "OVERLAY")
        trashLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        trashLabel:SetText("|cffff4040" .. DELETE .. "|r")
        trashLabel:SetPoint("CENTER")
        trashLabel:SetJustifyH("CENTER")
        
        trashBtn:SetScript("OnEnter", function()
            row.bg:SetColorTexture(0.8, 0.2, 0.2, 0.2)
            trashBtn:SetBackdropColor(0.8, 0.2, 0.2, 0.3)
            GameTooltip:SetOwner(trashBtn, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.CHAR_PANEL_REMOVE_TIP, 1, 0.35, 0.35)
            GameTooltip:Show()
        end)
        trashBtn:SetScript("OnLeave", function()
            row.bg:SetColorTexture(0, 0, 0, 0)
            trashBtn:SetBackdropColor(0, 0, 0, 0)
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
    
    local ColorPalette = _G.AbstractUI_ColorPalette
    local FontKit = _G.AbstractUI_FontKit
    
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
    f:SetClampedToScreen(true)
    
    -- AbstractUI styling
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    f:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
    f:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    -- Title
    f.title = FontKit:CreateFontString(f, "heading", "large")
    f.title:SetPoint("TOP", f, "TOP", 0, -16)
    f.title:SetText(L.WINDOW_TITLE)
    f.title:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    -- Drag area (top portion for moving window)
    f.dragArea = CreateFrame("Frame", nil, f)
    f.dragArea:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.dragArea:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, 0)
    f.dragArea:SetHeight(40)
    f.dragArea:EnableMouse(true)
    f.dragArea:RegisterForDrag("LeftButton")
    f.dragArea:SetScript("OnDragStart", function(self) f:StartMoving() end)
    f.dragArea:SetScript("OnDragStop", function(self)
        f:StopMovingOrSizing()
        local point, _, _, x, y = f:GetPoint()
        AccountPlayedPopupDB.point = point
        AccountPlayedPopupDB.x = x
        AccountPlayedPopupDB.y = y
    end)
    
    -- Close button (AbstractUI style)
    local close = CreateFrame("Button", nil, f, "BackdropTemplate")
    close:SetSize(32, 32)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    close:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    close:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    close:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    
    close.text = close:CreateFontString(nil, "OVERLAY")
    close.text:SetFont("Fonts\\FRIZQT__.TTF", 28, "OUTLINE")
    close.text:SetText("×")
    close.text:SetPoint("CENTER", 0, 1)
    close.text:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    close:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ColorPalette:GetColor('button-hover'))
    end)
    close:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ColorPalette:GetColor('button-bg'))
    end)
    close:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        f:Hide()
    end)
    
    table.insert(UISpecialFrames, "AccountPlayedPopup")
    
    f:SetScript("OnHide", function()
        if charPanel then charPanel:Hide() end
        charPanelClass = nil
    end)
    
    -- ScrollFrame container
    local scrollFrame = CreateFrame("ScrollFrame", nil, f)
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 60)
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
    
    -- Total row at bottom
    f.totalRow = FontKit:CreateFontString(f, "heading", "normal")
    f.totalRow:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 38)
    f.totalRow:SetTextColor(ColorPalette:GetColor('accent-primary'))
    
    -- Create rows
    local rowHeight = 22
    for i = 1, 20 do
        local row = self:CreateRow(content, START_W - 20, rowHeight)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        row:Hide()
        popupRows[i] = row
    end
    
    -- Format toggle checkbox (AbstractUI style)
    local checkBox = CreateFrame("Button", nil, f, "BackdropTemplate")
    checkBox:SetSize(16, 16)
    checkBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 38)
    checkBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    checkBox:SetBackdropColor(ColorPalette:GetColor('bg-secondary'))
    checkBox:SetBackdropBorderColor(ColorPalette:GetColor('primary'))
    
    checkBox.check = checkBox:CreateTexture(nil, "OVERLAY")
    checkBox.check:SetSize(10, 10)
    checkBox.check:SetPoint("CENTER")
    checkBox.check:SetColorTexture(ColorPalette:GetColor('accent-primary'))
    checkBox.check:Hide()
    
    checkBox.text = FontKit:CreateFontString(checkBox, "body", "small")
    checkBox.text:SetPoint("RIGHT", checkBox, "LEFT", -6, 0)
    checkBox.text:SetText(L.USE_YEARS_LABEL)
    checkBox.text:SetTextColor(ColorPalette:GetColor('text-primary'))
    
    checkBox:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(ColorPalette:GetColor('accent-primary'))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L.TIME_FORMAT_TITLE, 1, 1, 1)
        GameTooltip:AddLine(L.TIME_FORMAT_YEARS, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L.TIME_FORMAT_HOURS, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    checkBox:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(ColorPalette:GetColor('primary'))
        GameTooltip:Hide()
    end)
    
    checkBox:SetScript("OnClick", function(self)
        AccountPlayedPopupDB.useYears = not AccountPlayedPopupDB.useYears
        if AccountPlayedPopupDB.useYears then
            self.check:Show()
        else
            self.check:Hide()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        AccountPlayed:UpdatePopupDisplay()
    end)
    
    if AccountPlayedPopupDB.useYears then
        checkBox.check:Show()
    end
    
    f.formatCheckbox = checkBox
    
    -- Resize support
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    end
    
    -- Resize grabber (AbstractUI style)
    local br = CreateFrame("Button", nil, f, "BackdropTemplate")
    br:SetSize(20, 20)
    br:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    br:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
    })
    br:SetBackdropColor(ColorPalette:GetColor('panel-border'))
    
    -- Diagonal lines for resize indicator
    for i = 1, 3 do
        local line = br:CreateTexture(nil, "OVERLAY")
        line:SetSize(12, 1)
        line:SetColorTexture(ColorPalette:GetColor('text-secondary'))
        line:SetPoint("BOTTOMRIGHT", br, "BOTTOMRIGHT", -2 - (i * 3), 2 + (i * 3))
        line:SetRotation(math.rad(-45))
    end
    
    br:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ColorPalette:GetColor('accent-primary'))
    end)
    br:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ColorPalette:GetColor('panel-border'))
    end)
    br:SetScript("OnMouseDown", function(self) f:StartSizing("BOTTOMRIGHT") end)
    br:SetScript("OnMouseUp", function(self) f:StopMovingOrSizing() end)
    
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
    
    f:Hide()
    popupFrame = f
    return f
end

function AccountPlayed:CreateRow(parent, width, height)
    local ColorPalette = _G.AbstractUI_ColorPalette
    local FontKit = _G.AbstractUI_FontKit
    
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, height)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(ColorPalette:GetColor('button-hover'))
    row.highlight:Hide()
    
    row.classText = FontKit:CreateFontString(row, "body", "normal")
    row.classText:SetPoint("LEFT", 4, 0)
    row.classText:SetWidth(120)
    row.classText:SetJustifyH("LEFT")
    
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetPoint("LEFT", row.classText, "RIGHT", 8, 0)
    row.bar:SetPoint("RIGHT", row, "RIGHT", -140, 0)
    row.bar:SetHeight(height - 4)
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(0)
    row.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    
    row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bar.bg:SetAllPoints()
    row.bar.bg:SetColorTexture(ColorPalette:GetColor('bg-tertiary'))
    
    row.valueText = FontKit:CreateFontString(row, "body", "normal")
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
    
    if f.formatCheckbox and f.formatCheckbox.check then
        if AccountPlayedPopupDB.useYears then
            f.formatCheckbox.check:Show()
        else
            f.formatCheckbox.check:Hide()
        end
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
    local broker = LDB:NewDataObject("AbstractTimePlayed", {
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
            tooltip:AddLine("|cffffffffTime Played|r")
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
        name = "Time Played",
        order = 50,
        args = {
            header = {
                type = "header",
                name = "Time Played Tracker",
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
                desc = "Open the Time Played window",
                order = 3,
                func = function() AccountPlayed:ToggleWindow() end,
            },
        }
    }
end
