local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local CastBar = MidnightUI:NewModule("CastBar", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- Get ColorPalette and FontKit from Framework
local ColorPalette = MidnightUI.ColorPalette
local FontKit = MidnightUI.FontKit

-- -----------------------------------------------------------------------------
-- DATABASE DEFAULTS
-- -----------------------------------------------------------------------------
local defaults = {
    profile = {
        enabled = true,
        locked = false,
        
        -- Position & Size
        point = "CENTER",
        x = 0,
        y = -220,
        width = 250,
        height = 24,
        
        -- Appearance
        texture = "Blizzard",
        showBorder = true,
        showBackground = true,
        showIcon = true,
        iconPosition = "LEFT", -- LEFT or RIGHT
        iconSize = 24,
        
        -- Colors
        castingColor = {0.3, 0.7, 1.0, 1.0}, -- Blue
        channelingColor = {0.3, 1.0, 0.3, 1.0}, -- Green
        notInterruptibleColor = {0.7, 0.7, 0.7, 1.0}, -- Gray
        failedColor = {1.0, 0.2, 0.2, 1.0}, -- Red
        backgroundColor = {0, 0, 0, 0.5},
        borderColor = {0, 0, 0, 1},
        
        -- Text
        showSpellName = true,
        showCastTime = true,
        font = "Friz Quadrata TT",
        fontSize = 12,
        fontOutline = "OUTLINE",
        
        -- Features
        showLatency = true,
        showShieldBorder = true, -- Show special border for non-interruptible casts
    }
}

-- -----------------------------------------------------------------------------
-- INITIALIZATION
-- -----------------------------------------------------------------------------
function CastBar:OnInitialize()
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "OnDBReady")
end

function CastBar:OnDBReady()
    if not MidnightUI.db or not MidnightUI.db.profile or not MidnightUI.db.profile.modules.castBar then
        self:Disable()
        return
    end
    
    self.db = MidnightUI.db:RegisterNamespace("CastBar", defaults)
    
    -- Register events
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_SPELLCAST_START")
    self:RegisterEvent("UNIT_SPELLCAST_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    self:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    
    -- Register for Move Mode changes
    self:RegisterMessage("MIDNIGHTUI_MOVEMODE_CHANGED", "OnMoveModeChanged")
    
    -- If player is already in world, set up immediately
    if IsPlayerInWorld and IsPlayerInWorld() then
        C_Timer.After(0.5, function()
            self:SetupCastBar()
        end)
    end
end

function CastBar:PLAYER_ENTERING_WORLD()
    C_Timer.After(0.5, function()
        if self.db and self.db.profile then
            self:SetupCastBar()
        end
    end)
end

-- -----------------------------------------------------------------------------
-- CAST BAR CREATION
-- -----------------------------------------------------------------------------
function CastBar:SetupCastBar()
    if self.castBar then return end
    
    local db = self.db.profile
    
    -- Create main frame
    local frame = CreateFrame("Frame", "MidnightUI_CastBar", UIParent, "BackdropTemplate")
    frame:SetSize(db.width, db.height)
    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    frame:SetMovable(true)
    frame:EnableMouse(false)
    frame:SetClampedToScreen(true)
    frame:Hide() -- Hidden until casting
    
    -- Backdrop
    frame:SetBackdrop({
        bgFile = db.showBackground and "Interface\\Buttons\\WHITE8X8" or nil,
        edgeFile = db.showBorder and "Interface\\Buttons\\WHITE8X8" or nil,
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    frame:SetBackdropColor(unpack(db.backgroundColor))
    frame:SetBackdropBorderColor(unpack(db.borderColor))
    
    -- Status bar
    local statusBar = CreateFrame("StatusBar", nil, frame)
    statusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    statusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    statusBar:SetStatusBarTexture(LSM:Fetch("statusbar", db.texture))
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0)
    frame.statusBar = statusBar
    
    -- Shield overlay for non-interruptible casts
    if db.showShieldBorder then
        local shield = frame:CreateTexture(nil, "OVERLAY")
        shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Arena-Shield")
        shield:SetPoint("CENTER", statusBar, "LEFT", -5, 0)
        shield:SetSize(db.height + 10, db.height + 10)
        shield:Hide()
        frame.shield = shield
    end
    
    -- Spell icon
    if db.showIcon then
        local iconFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        -- Icon size matches bar height for a square appearance
        local iconSize = db.height
        iconFrame:SetSize(iconSize, iconSize)
        
        if db.iconPosition == "LEFT" then
            iconFrame:SetPoint("RIGHT", frame, "LEFT", -4, 0)
        else
            iconFrame:SetPoint("LEFT", frame, "RIGHT", 4, 0)
        end
        
        iconFrame:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        iconFrame:SetBackdropBorderColor(0, 0, 0, 1)
        
        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        iconFrame.texture = icon
        
        -- Create green highlight overlay for icon in move mode
        iconFrame.movableHighlightFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        iconFrame.movableHighlightFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        iconFrame.movableHighlightFrame:SetFrameLevel(10000)
        iconFrame.movableHighlightFrame:SetAllPoints(iconFrame)
        iconFrame.movableHighlightFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        iconFrame.movableHighlightFrame:SetBackdropColor(0, 0.5, 0, 0.2)
        iconFrame.movableHighlightFrame:SetBackdropBorderColor(0, 1, 0, 1)
        iconFrame.movableHighlightFrame:Hide()
        
        frame.icon = iconFrame
    end
    
    -- Latency bar (shows network delay)
    if db.showLatency then
        local latency = CreateFrame("StatusBar", nil, statusBar)
        latency:SetPoint("TOPRIGHT")
        latency:SetPoint("BOTTOMRIGHT")
        latency:SetStatusBarTexture(LSM:Fetch("statusbar", db.texture))
        latency:SetStatusBarColor(1, 0, 0, 0.5)
        latency:SetMinMaxValues(0, 1)
        latency:SetValue(0)
        frame.latency = latency
    end
    
    -- Spell name text
    if db.showSpellName then
        local spellName = statusBar:CreateFontString(nil, "OVERLAY")
        spellName:SetPoint("LEFT", statusBar, "LEFT", 4, 0)
        spellName:SetPoint("RIGHT", statusBar, "CENTER", -4, 0)
        local font = LSM:Fetch("font", db.font)
        spellName:SetFont(font, db.fontSize, db.fontOutline)
        spellName:SetTextColor(1, 1, 1, 1)
        spellName:SetShadowOffset(1, -1)
        spellName:SetShadowColor(0, 0, 0, 1)
        spellName:SetJustifyH("LEFT")
        frame.spellName = spellName
    end
    
    -- Cast time text
    if db.showCastTime then
        local castTime = statusBar:CreateFontString(nil, "OVERLAY")
        castTime:SetPoint("LEFT", statusBar, "CENTER", 4, 0)
        castTime:SetPoint("RIGHT", statusBar, "RIGHT", -4, 0)
        local font = LSM:Fetch("font", db.font)
        castTime:SetFont(font, db.fontSize, db.fontOutline)
        castTime:SetTextColor(1, 1, 1, 1)
        castTime:SetShadowOffset(1, -1)
        castTime:SetShadowColor(0, 0, 0, 1)
        castTime:SetJustifyH("RIGHT")
        frame.castTime = castTime
    end
    
    self.castBar = frame
    
    -- Create green highlight overlay for move mode (parented to UIParent to avoid alpha inheritance)
    frame.movableHighlightFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame.movableHighlightFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame.movableHighlightFrame:SetFrameLevel(10000)
    frame.movableHighlightFrame:SetAllPoints(frame)
    frame.movableHighlightFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame.movableHighlightFrame:SetBackdropColor(0, 0.5, 0, 0.2)
    frame.movableHighlightFrame:SetBackdropBorderColor(0, 1, 0, 1)
    frame.movableHighlightFrame:Hide()
    
    -- Create label text on overlay frame
    frame.movableLabel = frame.movableHighlightFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.movableLabel:SetPoint("CENTER")
    frame.movableLabel:SetText("Cast Bar")
    frame.movableLabel:SetTextColor(1, 1, 1, 1)
    frame.movableLabel:SetShadowOffset(2, -2)
    frame.movableLabel:SetShadowColor(0, 0, 0, 1)
    
    -- Setup dragging
    self:SetupDragging()
    
    -- Update script
    frame:SetScript("OnUpdate", function(self, elapsed)
        CastBar:OnUpdate(elapsed)
    end)
end

-- -----------------------------------------------------------------------------
-- CAST BAR UPDATE
-- -----------------------------------------------------------------------------
function CastBar:OnUpdate(elapsed)
    local frame = self.castBar
    if not frame or not frame.casting and not frame.channeling then return end
    
    if frame.casting then
        frame.value = frame.value + elapsed
        if frame.value >= frame.maxValue then
            frame:Hide()
            frame.casting = nil
            return
        end
        frame.statusBar:SetValue(frame.value)
        
        if frame.castTime then
            local remaining = frame.maxValue - frame.value
            frame.castTime:SetFormattedText("%.1f", remaining)
        end
    elseif frame.channeling then
        frame.value = frame.value - elapsed
        if frame.value <= 0 then
            frame:Hide()
            frame.channeling = nil
            return
        end
        frame.statusBar:SetValue(frame.value)
        
        if frame.castTime then
            frame.castTime:SetFormattedText("%.1f", frame.value)
        end
    end
end

-- -----------------------------------------------------------------------------
-- EVENT HANDLERS
-- -----------------------------------------------------------------------------
function CastBar:UNIT_SPELLCAST_START(event, unit)
    if unit ~= "player" then return end
    
    local frame = self.castBar
    if not frame then return end
    
    local spell, _, texture, startTime, endTime, _, _, notInterruptible, spellID = UnitCastingInfo(unit)
    if not spell then return end
    
    frame.value = (GetTime() - (startTime / 1000))
    frame.maxValue = (endTime - startTime) / 1000
    frame.casting = true
    frame.channeling = nil
    frame.notInterruptible = notInterruptible
    
    frame.statusBar:SetMinMaxValues(0, frame.maxValue)
    frame.statusBar:SetValue(frame.value)
    
    -- Set color
    local db = self.db.profile
    if notInterruptible then
        frame.statusBar:SetStatusBarColor(unpack(db.notInterruptibleColor))
        if frame.shield then frame.shield:Show() end
    else
        frame.statusBar:SetStatusBarColor(unpack(db.castingColor))
        if frame.shield then frame.shield:Hide() end
    end
    
    -- Set icon
    if frame.icon then
        frame.icon.texture:SetTexture(texture)
    end
    
    -- Set spell name
    if frame.spellName then
        frame.spellName:SetText(spell)
    end
    
    -- Set latency
    if frame.latency then
        local _, _, lagHome, lagWorld = GetNetStats()
        local lag = (lagHome + lagWorld) / 2
        local latencyWidth = (lag / 1000) / frame.maxValue * frame.statusBar:GetWidth()
        frame.latency:SetWidth(math.min(latencyWidth, frame.statusBar:GetWidth()))
    end
    
    frame:Show()
end

function CastBar:UNIT_SPELLCAST_STOP(event, unit)
    if unit ~= "player" then return end
    
    local frame = self.castBar
    if not frame then return end
    
    if frame.casting then
        frame:Hide()
        frame.casting = nil
    end
end

function CastBar:UNIT_SPELLCAST_FAILED(event, unit)
    if unit ~= "player" then return end
    
    local frame = self.castBar
    if not frame then return end
    
    if frame.casting then
        frame.statusBar:SetStatusBarColor(unpack(self.db.profile.failedColor))
        frame.casting = nil
        
        -- Hide after brief moment
        C_Timer.After(0.3, function()
            if frame then frame:Hide() end
        end)
    end
end

function CastBar:UNIT_SPELLCAST_INTERRUPTED(event, unit)
    if unit ~= "player" then return end
    self:UNIT_SPELLCAST_FAILED(event, unit)
end

function CastBar:UNIT_SPELLCAST_DELAYED(event, unit)
    if unit ~= "player" then return end
    
    local frame = self.castBar
    if not frame or not frame.casting then return end
    
    local spell, _, texture, startTime, endTime = UnitCastingInfo(unit)
    if not spell then return end
    
    frame.value = (GetTime() - (startTime / 1000))
    frame.maxValue = (endTime - startTime) / 1000
    frame.statusBar:SetMinMaxValues(0, frame.maxValue)
end

function CastBar:UNIT_SPELLCAST_CHANNEL_START(event, unit)
    if unit ~= "player" then return end
    
    local frame = self.castBar
    if not frame then return end
    
    local spell, _, texture, startTime, endTime, _, notInterruptible, spellID = UnitChannelInfo(unit)
    if not spell then return end
    
    frame.maxValue = (endTime - startTime) / 1000
    frame.value = frame.maxValue
    frame.channeling = true
    frame.casting = nil
    frame.notInterruptible = notInterruptible
    
    frame.statusBar:SetMinMaxValues(0, frame.maxValue)
    frame.statusBar:SetValue(frame.value)
    
    -- Set color
    local db = self.db.profile
    if notInterruptible then
        frame.statusBar:SetStatusBarColor(unpack(db.notInterruptibleColor))
        if frame.shield then frame.shield:Show() end
    else
        frame.statusBar:SetStatusBarColor(unpack(db.channelingColor))
        if frame.shield then frame.shield:Hide() end
    end
    
    -- Set icon
    if frame.icon then
        frame.icon.texture:SetTexture(texture)
    end
    
    -- Set spell name
    if frame.spellName then
        frame.spellName:SetText(spell)
    end
    
    frame:Show()
end

function CastBar:UNIT_SPELLCAST_CHANNEL_STOP(event, unit)
    if unit ~= "player" then return end
    
    local frame = self.castBar
    if not frame then return end
    
    if frame.channeling then
        frame:Hide()
        frame.channeling = nil
    end
end

function CastBar:UNIT_SPELLCAST_CHANNEL_UPDATE(event, unit)
    if unit ~= "player" then return end
    
    local frame = self.castBar
    if not frame or not frame.channeling then return end
    
    local spell, _, texture, startTime, endTime = UnitChannelInfo(unit)
    if not spell then return end
    
    frame.maxValue = (endTime - startTime) / 1000
    frame.value = frame.maxValue - (GetTime() - (startTime / 1000))
    frame.statusBar:SetMinMaxValues(0, frame.maxValue)
end

function CastBar:UNIT_SPELLCAST_INTERRUPTIBLE(event, unit)
    if unit ~= "player" then return end
    
    local frame = self.castBar
    if not frame then return end
    
    frame.notInterruptible = false
    if frame.casting then
        frame.statusBar:SetStatusBarColor(unpack(self.db.profile.castingColor))
    elseif frame.channeling then
        frame.statusBar:SetStatusBarColor(unpack(self.db.profile.channelingColor))
    end
    
    if frame.shield then
        frame.shield:Hide()
    end
end

function CastBar:UNIT_SPELLCAST_NOT_INTERRUPTIBLE(event, unit)
    if unit ~= "player" then return end
    
    local frame = self.castBar
    if not frame then return end
    
    frame.notInterruptible = true
    frame.statusBar:SetStatusBarColor(unpack(self.db.profile.notInterruptibleColor))
    
    if frame.shield then
        frame.shield:Show()
    end
end

-- -----------------------------------------------------------------------------
-- DRAGGING SUPPORT
-- -----------------------------------------------------------------------------
function CastBar:SetupDragging()
    local frame = self.castBar
    if not frame then return end
    
    local Movable = MidnightUI:GetModule("Movable")
    
    Movable:MakeFrameDraggable(
        frame,
        function(point, x, y)
            CastBar.db.profile.point = point
            CastBar.db.profile.x = x
            CastBar.db.profile.y = y
        end,
        nil
    )
end

function CastBar:OnMoveModeChanged(event, enabled)
    if not self.castBar then return end
    
    if enabled then
        self.castBar:EnableMouse(true)
        self.castBar:SetAlpha(0.3)
        self.castBar:Show() -- Show in move mode even if not casting
        self.castBar.movableHighlightFrame:Show()
        
        -- Show icon overlay if icon exists
        if self.castBar.icon and self.castBar.icon.movableHighlightFrame then
            self.castBar.icon:SetAlpha(0.3)
            self.castBar.icon.movableHighlightFrame:Show()
        end
    else
        self.castBar:EnableMouse(false)
        self.castBar:SetAlpha(1.0)
        self.castBar.movableHighlightFrame:Hide()
        
        -- Hide icon overlay
        if self.castBar.icon and self.castBar.icon.movableHighlightFrame then
            self.castBar.icon:SetAlpha(1.0)
            self.castBar.icon.movableHighlightFrame:Hide()
        end
        
        -- Hide if not actually casting
        if not self.castBar.casting and not self.castBar.channeling then
            self.castBar:Hide()
        end
    end
end

-- -----------------------------------------------------------------------------
-- OPTIONS
-- -----------------------------------------------------------------------------
function CastBar:GetOptions()
    return {
        type = "group",
        name = "Cast Bar",
        order = 12,
        args = {
            header = {
                type = "header",
                name = "Player Cast Bar",
                order = 1
            },
            desc = {
                type = "description",
                name = "Display a custom cast bar for your character.\n\n",
                order = 2
            },
            
            headerPosition = { type = "header", name = "Position & Size", order = 10},
            width = {
                name = "Width",
                type = "range",
                order = 11,
                width = "half",
                min = 100,
                max = 500,
                step = 1,
                get = function() return self.db.profile.width end,
                set = function(_, v)
                    self.db.profile.width = v
                    if self.castBar then
                        self.castBar:SetWidth(v)
                    end
                end
            },
            height = {
                name = "Height",
                type = "range",
                order = 12,
                width = "half",
                min = 16,
                max = 50,
                step = 1,
                get = function() return self.db.profile.height end,
                set = function(_, v)
                    self.db.profile.height = v
                    if self.castBar then
                        self.castBar:SetHeight(v)
                        -- Resize icon to match new bar height
                        if self.castBar.icon then
                            self.castBar.icon:SetSize(v, v)
                        end
                    end
                end
            },
            
            headerAppearance = { type = "header", name = "Appearance", order = 20},
            showIcon = {
                name = "Show Spell Icon",
                type = "toggle",
                order = 21,
                get = function() return self.db.profile.showIcon end,
                set = function(_, v)
                    self.db.profile.showIcon = v
                    if self.castBar then
                        self.castBar:Hide()
                        self.castBar = nil
                        self:SetupCastBar()
                    end
                end
            },
            iconPosition = {
                name = "Icon Position",
                type = "select",
                order = 22,
                values = {
                    LEFT = "Left",
                    RIGHT = "Right"
                },
                disabled = function() return not self.db.profile.showIcon end,
                get = function() return self.db.profile.iconPosition end,
                set = function(_, v)
                    self.db.profile.iconPosition = v
                    if self.castBar then
                        self.castBar:Hide()
                        self.castBar = nil
                        self:SetupCastBar()
                    end
                end
            },
            showLatency = {
                name = "Show Latency",
                type = "toggle",
                order = 23,
                desc = "Shows your network lag as a red bar at the end of the cast",
                get = function() return self.db.profile.showLatency end,
                set = function(_, v)
                    self.db.profile.showLatency = v
                    -- Setting saved, will apply on next cast
                end
            },
            showShieldBorder = {
                name = "Show Shield for Non-Interruptible",
                type = "toggle",
                order = 24,
                desc = "Shows a shield icon when casting non-interruptible spells",
                get = function() return self.db.profile.showShieldBorder end,
                set = function(_, v)
                    self.db.profile.showShieldBorder = v
                    -- Setting saved, will apply on next cast
                end
            },
            
            headerText = { type = "header", name = "Text Display", order = 30},
            showSpellName = {
                name = "Show Spell Name",
                type = "toggle",
                order = 31,
                get = function() return self.db.profile.showSpellName end,
                set = function(_, v)
                    self.db.profile.showSpellName = v
                    if self.castBar and self.castBar.spellName then
                        if v then
                            self.castBar.spellName:Show()
                        else
                            self.castBar.spellName:Hide()
                        end
                    end
                end
            },
            showCastTime = {
                name = "Show Cast Time",
                type = "toggle",
                order = 32,
                get = function() return self.db.profile.showCastTime end,
                set = function(_, v)
                    self.db.profile.showCastTime = v
                    if self.castBar and self.castBar.castTime then
                        if v then
                            self.castBar.castTime:Show()
                        else
                            self.castBar.castTime:Hide()
                        end
                    end
                end
            },
            font = {
                name = "Font",
                type = "select",
                order = 33,
                values = LSM:HashTable("font"),
                get = function() return self.db.profile.font end,
                set = function(_, v)
                    self.db.profile.font = v
                    if self.castBar then
                        self.castBar:Hide()
                        self.castBar = nil
                        self:SetupCastBar()
                    end
                end
            },
            fontSize = {
                name = "Font Size",
                type = "range",
                order = 34,
                min = 8,
                max = 24,
                step = 1,
                get = function() return self.db.profile.fontSize end,
                set = function(_, v)
                    self.db.profile.fontSize = v
                    if self.castBar then
                        local font = LSM:Fetch("font", self.db.profile.font)
                        if self.castBar.spellName then
                            self.castBar.spellName:SetFont(font, v, self.db.profile.fontOutline)
                        end
                        if self.castBar.castTime then
                            self.castBar.castTime:SetFont(font, v, self.db.profile.fontOutline)
                        end
                    end
                end
            },
            
            headerReset = { type = "header", name = "Reset", order = 40},
            resetPosition = {
                name = "Reset Position",
                type = "execute",
                order = 41,
                func = function()
                    self.db.profile.point = "CENTER"
                    self.db.profile.x = 0
                    self.db.profile.y = -220
                    if self.castBar then
                        self.castBar:ClearAllPoints()
                        self.castBar:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
                    end
                end
            }
        }
    }
end
