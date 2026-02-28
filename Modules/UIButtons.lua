local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local UIButtons = MidnightUI:NewModule("UIButtons", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

local uiButtons = {}
local container
local FrameFactory, ColorPalette, FontKit

function UIButtons:OnInitialize()
    self:RegisterMessage("MIDNIGHTUI_DB_READY", "OnDBReady")
end

function UIButtons:OnDBReady()
    if not MidnightUI.db or not MidnightUI.db.profile or not MidnightUI.db.profile.modules then
        return
    end
    if not MidnightUI.db.profile.modules.UIButtons then
        return 
    end
    
    -- Get framework systems
    FrameFactory = MidnightUI.FrameFactory
    ColorPalette = _G.MidnightUI_ColorPalette
    FontKit = MidnightUI.FontKit

    self.db = MidnightUI.db:RegisterNamespace("UIButtons", {
        profile = {
            enabled = true,
            scale = 1.0,
            spacing = 2,
            locked = false,
            font = "Friz Quadrata TT",
            fontSize = 16,
            position = { 
                point = "TOPLEFT", 
                x = math.floor(GetScreenWidth() * 0.75), 
                y = -math.floor(GetScreenHeight() * 0.75) 
            },
            backgroundColor = { 0.1, 0.1, 0.1, 0.8 },
            UIButtons = {
                reload = { enabled = true, order = 1 },
                exit = { enabled = true, order = 2 },
                options = { enabled = true, order = 3 },
                addons = { enabled = true, order = 4 },
                move = { enabled = true, order = 5 }
            }
        }
    })

    -- Migration: Remove old 'logout' button and ensure 'options' button exists
    local btns = self.db.profile.UIButtons
    if btns.logout then btns.logout = nil end
    if not btns.options then
        btns.options = { enabled = true, order = 3 }
    end
    
    -- Safety: Ensure all current buttons exist
    if not btns.reload then btns.reload = { enabled = true, order = 1 } end
    if not btns.exit then btns.exit = { enabled = true, order = 2 } end
    if not btns.addons then btns.addons = { enabled = true, order = 4 } end
    if not btns.move then btns.move = { enabled = true, order = 5 } end

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterMessage("MIDNIGHTUI_MOVEMODE_CHANGED", "OnMoveModeChanged")

    -- Manually call setup since PLAYER_ENTERING_WORLD already fired
    C_Timer.After(0.1, function()
        self:PLAYER_ENTERING_WORLD()
    end)
end

function UIButtons:PLAYER_ENTERING_WORLD()
    self:CreateContainer()
    self:CreateButtons()
    self:UpdateLayout()
end

function UIButtons:CreateContainer()
    if container then return end
    
    local Movable = MidnightUI:GetModule("Movable")
    
    container = CreateFrame("Frame", "MidnightUI_UIButtonsContainer", UIParent, "BackdropTemplate")
    container:SetSize(200, 36)
    
    local pos = self.db.profile.position
    container:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    container:SetScale(self.db.profile.scale)
    container:SetFrameStrata("TOOLTIP")
    container:SetFrameLevel(200)
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = nil,
        tile = false, edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    
    -- Use ColorPalette if available, fallback to database
    if ColorPalette then
        container:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
    else
        container:SetBackdropColor(unpack(self.db.profile.backgroundColor))
    end
    
    -- Use Movable for drag functionality
    Movable:MakeFrameDraggable(
        container,
        function(point, x, y)
            UIButtons.db.profile.position = { point = point, x = x, y = y }
            Movable:UpdateNudgeArrows(container)
        end,
        function() return not UIButtons.db.profile.locked end
    )
    
    container:Show()
    
    -- Create nudge arrows using Movable
    Movable:CreateNudgeArrows(container, self.db)
end

function UIButtons:CreateButtons()
    local buttonData = {
        reload = {
            name = "Reload",
            text = "R",
            tooltip = "Reload UI",
            onClick = function() ReloadUI() end
        },
        exit = {
            name = "Edit Mode",
            text = "E",
            tooltip = "Edit Mode",
            onClick = function() end
        },
        options = {
            name = "Options",
            text = "O",
            tooltip = "Open MidnightUI Options",
            onClick = function()
                -- Use custom MidnightUI options panel
                if MidnightUI and type(MidnightUI.OpenConfig) == "function" then
                    MidnightUI:OpenConfig()
                end
            end
        },
        addons = {
            name = "Addons",
            text = "A",
            tooltip = "Open Addon List"
        },
        move = {
            name = "Move",
            text = "M",
            tooltip = "Toggle Move Mode\n|cffaaaaaa(Hover over elements to reposition)|r",
            onClick = function() 
                MidnightUI:ToggleMoveMode()
            end,
            getColor = function()
                if MidnightUI.moveMode then
                    return {0, 1, 0}
                else
                    return {1, 1, 1}
                end
            end
        }
    }

    local LSM = LibStub("LibSharedMedia-3.0")
    local fontName = self.db.profile.font or "Friz Quadrata TT"
    local fontSize = self.db.profile.fontSize or 16
    local fontPath = LSM:Fetch("font", fontName) or "Fonts\\FRIZQT__.TTF"
    for key, data in pairs(buttonData) do
        local config = self.db.profile.UIButtons[key]
        if config and config.enabled then
            local btn
            
            -- For exit button, we need SecureActionButtonTemplate
            if key == "exit" then
                btn = CreateFrame("Button", "MidnightUIButton_"..key, container, "SecureActionButtonTemplate, BackdropTemplate")
                btn:SetSize(32, 32)
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", "/editmode")
                btn:RegisterForClicks("AnyUp", "AnyDown")
                
                -- Apply framework styling manually for secure button
                btn:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = nil,
                    tile = false,
                    tileSize = 16,
                    edgeSize = 0,
                    insets = { left = 0, right = 0, top = 0, bottom = 0 }
                })
                if ColorPalette then
                    -- Use same panel-bg color as container
                    btn:SetBackdropColor(ColorPalette:GetColor("panel-bg"))
                else
                    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
                end
                
                btn.text = btn:CreateFontString(nil, "OVERLAY")
                if FontKit then
                    FontKit:SetFont(btn.text, "button", "normal")
                else
                    btn.text:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
                end
                btn.text:SetPoint("CENTER")
                btn.text:SetText(data.text)
                if ColorPalette then
                    btn.text:SetTextColor(ColorPalette:GetColor("text-primary"))
                else
                    btn.text:SetTextColor(1, 1, 1, 1)
                end
            else
                -- Use framework button for non-secure buttons
                if FrameFactory then
                    btn = FrameFactory:CreateButton(container, 32, 32, data.text)
                    
                    -- Override FrameFactory styling to remove borders and darken background
                    if btn.SetBackdrop then
                        btn:SetBackdrop({
                            bgFile = "Interface\\Buttons\\WHITE8X8",
                            edgeFile = nil,
                            tile = false, edgeSize = 0,
                            insets = { left = 0, right = 0, top = 0, bottom = 0 }
                        })
                        
                        if ColorPalette then
                            -- Use same panel-bg color as container
                            btn:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
                        else
                            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                        end
                    end
                else
                    -- Fallback to basic button if framework not available
                    btn = CreateFrame("Button", "MidnightUIButton_"..key, container, "BackdropTemplate")
                    btn:SetSize(32, 32)
                    btn:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = nil,
                        tile = false, edgeSize = 0,
                        insets = { left = 0, right = 0, top = 0, bottom = 0 }
                    })
                    
                    if ColorPalette then
                        -- Use same panel-bg color as container
                        btn:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
                    else
                        btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                    end
                    
                    btn.text = btn:CreateFontString(nil, "OVERLAY")
                    if FontKit then
                        FontKit:SetFont(btn.text, "button", "normal")
                    else
                        btn.text:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
                    end
                    btn.text:SetPoint("CENTER")
                    btn.text:SetText(data.text)
                    if ColorPalette then
                        btn.text:SetTextColor(ColorPalette:GetColor("text-primary"))
                    else
                        btn.text:SetTextColor(1, 1, 1, 1)
                    end
                end
            end
            
            btn:SetFrameStrata("TOOLTIP")
            btn:SetFrameLevel(201)
            btn:EnableMouse(true)
            
            -- Special handling for addons button
            if key == "addons" then
                btn:RegisterForClicks("AnyUp")
                btn:SetScript("OnClick", function(self)
                    if not AddonList then
                        if _G.LoadAddOn then
                            local loaded, reason = _G.LoadAddOn("Blizzard_AddOnManager")
                            if not loaded then
                                UIErrorsFrame:AddMessage("Unable to load AddOn Manager: "..(reason or "unknown error"), 1, 0, 0)
                                return
                            end
                        end
                    end
                    if AddonList then
                        if AddonList:IsShown() then
                            AddonList:Hide()
                        else
                            AddonList:Show()
                        end
                    end
                    -- Reset button state after click
                    if self.normalBgColor then
                        C_Timer.After(0.05, function()
                            self:SetBackdropColor(unpack(self.normalBgColor))
                        end)
                    end
                end)
            elseif key ~= "exit" then
                -- Standard click handler for other non-secure buttons
                btn:RegisterForClicks("AnyUp")
                local originalOnClick = data.onClick
                btn:SetScript("OnClick", function(self, ...)
                    originalOnClick(...)
                    -- Reset button state after click
                    if self.normalBgColor then
                        C_Timer.After(0.05, function()
                            self:SetBackdropColor(unpack(self.normalBgColor))
                        end)
                    end
                end)
            end
            
            -- Tooltip
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_NONE")
                GameTooltip:SetText(data.tooltip)
                
                -- Manually position tooltip using Tooltips module anchor
                local Tooltips = MidnightUI:GetModule("Tooltips", true)
                if Tooltips then
                    -- Use custom anchor position
                    local pos = Tooltips.db.profile.anchorPosition
                    local scale = Tooltips.db.profile.scale or 1.0
                    GameTooltip:SetScale(scale)
                    GameTooltip:ClearAllPoints()
                    GameTooltip:SetPoint("BOTTOMLEFT", UIParent, pos.point, pos.x, pos.y)
                    
                    -- Apply styling
                    if Tooltips.StyleTooltip then
                        Tooltips:StyleTooltip(GameTooltip)
                    end
                end
                
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            
            btn.key = key
            btn.getData = data.getColor
            btn:Show()
            btn:SetAlpha(1)
            uiButtons[key] = btn
        end
    end
    self:RegisterMessage("MIDNIGHTUI_MOVEMODE_CHANGED", "OnMoveModeChanged")

    -- Store font update function for later use
    self.UpdateButtonFonts = function(this)
        local LSM = LibStub("LibSharedMedia-3.0")
        local fontName = self.db.profile.font or "Friz Quadrata TT"
        local fontSize = self.db.profile.fontSize or 16
        local fontPath = LSM:Fetch("font", fontName) or "Fonts\\FRIZQT__.TTF"
        for _, btn in pairs(uiButtons) do
            if btn.text then
                btn.text:SetFont(fontPath, fontSize, "OUTLINE")
            end
        end
    end
end

function UIButtons:OnMoveModeChanged(event, enabled)
    local Movable = MidnightUI:GetModule("Movable")
    
    -- Update move button color
    local moveBtn = uiButtons.move
    if moveBtn and moveBtn.text then
        if enabled then
            if ColorPalette then
                moveBtn.text:SetTextColor(ColorPalette:GetColor('success'))
            else
                moveBtn.text:SetTextColor(0, 1, 0)
            end
        else
            if ColorPalette then
                moveBtn.text:SetTextColor(ColorPalette:GetColor('text-primary'))
            else
                moveBtn.text:SetTextColor(1, 1, 1)
            end
        end
    end
    
    -- Update container arrows
    if container then
        Movable:UpdateNudgeArrows(container)
    end
end

function UIButtons:UpdateLayout()
    if not container then return end
    
    local sortedButtons = {}
    
    for key, btn in pairs(uiButtons) do
        local order = self.db.profile.UIButtons[key].order or 999
        table.insert(sortedButtons, {key = key, btn = btn, order = order})
    end
    
    table.sort(sortedButtons, function(a, b) return a.order < b.order end)
    
    local spacing = self.db.profile.spacing
    local buttonWidth = 32
    local totalWidth = (#sortedButtons * buttonWidth) + ((#sortedButtons - 1) * spacing) + 6
    
    container:SetSize(totalWidth, 36)
    container:SetScale(self.db.profile.scale)
    
    -- Update background color if available
    local ColorPalette = _G.MidnightUI_ColorPalette
    if ColorPalette then
        container:SetBackdropColor(ColorPalette:GetColor('panel-bg'))
    elseif self.db.profile.backgroundColor then
        container:SetBackdropColor(unpack(self.db.profile.backgroundColor))
    end
    
    -- Position buttons from left to right
    for i, data in ipairs(sortedButtons) do
        data.btn:ClearAllPoints()
        if i == 1 then
            data.btn:SetPoint("LEFT", container, "LEFT", 3, 0)
        else
            local prevBtn = sortedButtons[i-1].btn
            data.btn:SetPoint("LEFT", prevBtn, "RIGHT", spacing, 0)
        end
        data.btn:Show()
    end
    -- Update fonts in case global font changed
    if self.UpdateButtonFonts then
        self:UpdateButtonFonts()
    end
end

function UIButtons:GetOptions()
    return {
        type = "group",
        name = "UI Buttons",
        order = 10,
        args = {
            header = { type = "header", name = "Quick Access Buttons", order = 1},
            desc = { type = "description", name = "Buttons appear in a container that can be moved and customized.", order = 2 },
            locked = {
                name = "Lock Position",
                type = "toggle",
                order = 3,
                width = "full",
                get = function() return self.db.profile.locked end,
                set = function(_, v) self.db.profile.locked = v end
            },
            scale = {
                name = "Scale",
                type = "range",
                order = 4,
                min = 0.5,
                max = 2.0,
                step = 0.01,
                bigStep = 0.1,
                isPercent = false,
                get = function() return self.db.profile.scale end,
                set = function(_, v)
                    self.db.profile.scale = v
                    if container then
                        container:SetScale(v)
                    end
                    self:UpdateLayout()
                end
            },
            spacing = {
                name = "Spacing",
                type = "range",
                order = 5,
                min = 0,
                max = 20,
                step = 1,
                get = function() return self.db.profile.spacing end,
                set = function(_, v)
                    self.db.profile.spacing = v
                    self:UpdateLayout()
                end
            },
            backgroundColor = {
                name = "Background Color",
                type = "color",
                order = 6,
                hasAlpha = true,
                get = function()
                    local c = self.db.profile.backgroundColor
                    return c[1], c[2], c[3], c[4]
                end,
                set = function(_, r, g, b, a)
                    self.db.profile.backgroundColor = {r, g, b, a}
                    self:UpdateLayout()
                end
            },
            fontSpacer = {
                type = "description",
                name = "",
                order = 6.5,
                width = "full",
            },
            font = {
                name = "Font",
                type = "select",
                order = 7,
                values = function()
                    local fonts = LSM:List("font")
                    local out = {}
                    for _, font in ipairs(fonts) do out[font] = font end
                    return out
                end,
                get = function() return self.db.profile.font end,
                set = function(_, v)
                    self.db.profile.font = v
                    self:UpdateButtonFonts()
                end
            },
            fontSize = {
                name = "Font Size",
                type = "range",
                order = 8,
                min = 8,
                max = 32,
                step = 1,
                get = function() return self.db.profile.fontSize end,
                set = function(_, v)
                    self.db.profile.fontSize = v
                    self:UpdateButtonFonts()
                end
            },
            buttonsHeader = { type = "header", name = "Individual Buttons", order = 10},
            reload = {
                name = "Reload (R)", type = "toggle", order = 11,
                get = function() 
                    if not self.db.profile.UIButtons.reload then return true end
                    return self.db.profile.UIButtons.reload.enabled 
                end,
                set = function(_, v) self.db.profile.UIButtons.reload.enabled = v; ReloadUI() end
            },
            exit = {
                name = "Edit Mode (E)", type = "toggle", order = 12,
                get = function() 
                    if not self.db.profile.UIButtons.exit then return true end
                    return self.db.profile.UIButtons.exit.enabled 
                end,
                set = function(_, v) self.db.profile.UIButtons.exit.enabled = v; ReloadUI() end
            },
            options = {
                name = "Options (O)", type = "toggle", order = 13,
                get = function() 
                    if not self.db.profile.UIButtons.options then return true end
                    return self.db.profile.UIButtons.options.enabled 
                end,
                set = function(_, v) self.db.profile.UIButtons.options.enabled = v; ReloadUI() end
            },
            addons = {
                name = "Addons (A)", type = "toggle", order = 14,
                get = function() 
                    if not self.db.profile.UIButtons.addons then return true end
                    return self.db.profile.UIButtons.addons.enabled 
                end,
                set = function(_, v) self.db.profile.UIButtons.addons.enabled = v; ReloadUI() end
            },
            move = {
                name = "Move Mode (M)", type = "toggle", order = 15,
                get = function() 
                    if not self.db.profile.UIButtons.move then return true end
                    return self.db.profile.UIButtons.move.enabled 
                end,
                set = function(_, v) self.db.profile.UIButtons.move.enabled = v; ReloadUI() end
            }
        }
    }
end