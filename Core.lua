local MidnightUI = LibStub("AceAddon-3.0"):NewAddon("MidnightUI", "AceConsole-3.0", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

MidnightUI.version = "1.0.0"

-- Define reload confirmation dialog
StaticPopupDialogs["MIDNIGHTUI_RELOAD_CONFIRM"] = {
    text = "This action requires a UI reload. Reload now?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        if not InCombatLockdown() then
            C_UI.Reload()
        else
            print("|cffff0000MidnightUI:|r Cannot reload UI while in combat. Please leave combat and run /reload.")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ============================================================================
-- 1. DATABASE DEFAULTS
-- ============================================================================
local defaults = {
    profile = {
        theme = {
            active = "MidnightTransparent",  -- Active framework theme
            font = "Friz Quadrata TT",
            fontSize = 12,
            bgColor = {0.1, 0.1, 0.1, 0.8},
            borderColor = {0, 0, 0, 1},
            customThemes = {},  -- User-created themes
        },
        modules = {
            skins = true,
            bar = true,
            UIButtons = true,
            tooltips = true,
            mailbox = true,
            maps = true,
            actionbars = true,
            unitframes = true,
            cooldowns = true,
            resourceBars = true,
            castBar = true,
            tweaks = true,
            setup = true
        }
    }
}

-- ============================================================================
-- 2. INITIALIZATION
-- ============================================================================
function MidnightUI:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MidnightUIDB", defaults, true)
    
    -- Register slash commands
    self:RegisterChatCommand("mui", "SlashCommand")
    self:RegisterChatCommand("midnightui", "SlashCommand")
    self:RegisterChatCommand("muimove", "ToggleMoveMode")
    self:RegisterChatCommand("demo", "OpenDemo")
end

function MidnightUI:OnEnable()
    -- Load custom themes FIRST before validating
    self:LoadCustomThemes()
    
    -- Validate and migrate theme setting
    local ColorPalette = _G.MidnightUI_ColorPalette
    if ColorPalette and self.db.profile.theme.active then
        local currentTheme = self.db.profile.theme.active
        -- Check if the current theme exists in the palette
        if not ColorPalette.palettes[currentTheme] then
            -- Theme doesn't exist, fall back to MidnightUIDefault
            self.db.profile.theme.active = "MidnightUIDefault"
            self:Print("Previous theme not found. Switched to MidnightUI Default theme.")
        end
        -- Set the active theme in ColorPalette
        ColorPalette:SetActiveTheme(self.db.profile.theme.active)
    end
    
    -- Send the message after all modules have registered
    C_Timer.After(0.1, function()
        self:SendMessage("MIDNIGHTUI_DB_READY")
    end)
    
    -- Register options after modules load
    -- NOTE: No longer using AceConfig/AceConfigDialog - we have our own custom framework now!
    -- Options panel is opened via MidnightUI:OpenConfig() which uses Framework/MidnightOptionsPanel.lua
    
    -- C_Timer.After(0.2, function()
    --     AceConfig:RegisterOptionsTable("MidnightUI", function() return self:GetOptions() end)
    --     AceConfigDialog:AddToBlizOptions("MidnightUI", "Midnight UI")
    --     ... (commented out old AceGUI code)
    -- end)
    
    -- Initialize Framework
    if _G.MidnightUI_FrameFactory then
        _G.MidnightUI_FrameFactory:Initialize(self)
        
        -- Apply saved theme
        local savedTheme = self.db.profile.theme.active
        if self.FrameFactory and savedTheme then
            self.FrameFactory:SetTheme(savedTheme)
        end
    end
    
    -- Load Focus Frame if present
    if UnitFrames and UnitFrames.CreateFocusFrame then
        UnitFrames:CreateFocusFrame()
    end
end

function MidnightUI:SlashCommand(input)
    if not input or input:trim() == "" then
        self:OpenConfig()
    elseif input:lower() == "move" then
        self:ToggleMoveMode()
    else
        self:OpenConfig()
    end
end

function MidnightUI:OpenDemo()
    local demo = self:GetModule("FrameworkDemo", true)
    if demo then
        demo:Toggle()
    else
        self:Print("Framework Demo module not loaded.")
    end
end

-- ============================================================================
-- 3. UTILITY FUNCTIONS
-- ============================================================================

-- Reference resolution for default layouts (effective UI resolution at 2560x1440 with auto-scaling)
MidnightUI.REFERENCE_WIDTH = 2133
MidnightUI.REFERENCE_HEIGHT = 1200

-- Scale position from reference resolution to current resolution
function MidnightUI:ScalePosition(x, y)
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    
    local scaleX = screenWidth / self.REFERENCE_WIDTH
    local scaleY = screenHeight / self.REFERENCE_HEIGHT
    
    return x * scaleX, y * scaleY
end

-- Scale all movable frames to current resolution
function MidnightUI:ScaleLayoutToResolution()
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    
    local scaleX = screenWidth / self.REFERENCE_WIDTH
    local scaleY = screenHeight / self.REFERENCE_HEIGHT
    
    print("|cff00ff00MidnightUI:|r Scaling layout from " .. self.REFERENCE_WIDTH .. "x" .. self.REFERENCE_HEIGHT .. " to " .. math.floor(screenWidth) .. "x" .. math.floor(screenHeight))
    print("|cff00ff00Scale factors:|r X=" .. string.format("%.2f", scaleX) .. " Y=" .. string.format("%.2f", scaleY))
    
    -- Scale Bar module positions
    if _G.Bar and _G.Bar.db and _G.Bar.db.profile and _G.Bar.db.profile.bars then
        for barID, barData in pairs(_G.Bar.db.profile.bars) do
            if barData.x and barData.y then
                barData.x = math.floor(barData.x * scaleX)
                barData.y = math.floor(barData.y * scaleY)
            end
        end
    end
    
    -- Scale UIButtons position
    if _G.UIButtons and _G.UIButtons.db and _G.UIButtons.db.profile and _G.UIButtons.db.profile.position then
        local pos = _G.UIButtons.db.profile.position
        if pos.x and pos.y then
            pos.x = math.floor(pos.x * scaleX)
            pos.y = math.floor(pos.y * scaleY)
        end
    end
    
    -- Scale UnitFrames positions
    if _G.UnitFrames and _G.UnitFrames.db and _G.UnitFrames.db.profile then
        local uf = _G.UnitFrames.db.profile
        for _, frame in pairs({"player", "target", "targettarget", "focus", "pet"}) do
            if uf[frame] and uf[frame].position then
                local pos = uf[frame].position
                if pos.x and pos.y then
                    pos.x = math.floor(pos.x * scaleX)
                    pos.y = math.floor(pos.y * scaleY)
                end
            end
        end
    end
    
    -- Scale CooldownManager position
    if _G.CooldownManager and _G.CooldownManager.db and _G.CooldownManager.db.profile then
        local cd = _G.CooldownManager.db.profile
        if cd.essential and cd.essential.position then
            cd.essential.position.x = math.floor(cd.essential.position.x * scaleX)
            cd.essential.position.y = math.floor(cd.essential.position.y * scaleY)
        end
        if cd.utility and cd.utility.position then
            cd.utility.position.x = math.floor(cd.utility.position.x * scaleX)
            cd.utility.position.y = math.floor(cd.utility.position.y * scaleY)
        end
    end
    
    -- Scale Maps position
    if _G.Maps and _G.Maps.db and _G.Maps.db.profile then
        local maps = _G.Maps.db.profile
        if maps.minimap and maps.minimap.position then
            local pos = maps.minimap.position
            if pos.x and pos.y then
                pos.x = math.floor(pos.x * scaleX)
                pos.y = math.floor(pos.y * scaleY)
            end
        end
    end
    
    print("|cff00ff00MidnightUI:|r Layout scaled to your resolution!")
    StaticPopup_Show("MIDNIGHTUI_RELOAD_CONFIRM")
end

function MidnightUI:OpenConfig()
    -- Use custom MidnightUI Options Panel (zero AceGUI dependency)
    local optionsPanel = _G.MidnightUI_OptionsPanel
    if optionsPanel then
        local success, err = pcall(function()
            optionsPanel:Toggle(self)
        end)
        if not success then
            self:Print("|cffff0000Error opening options panel:|r " .. tostring(err))
        end
    else
        self:Print("Options panel not loaded yet. Please try again in a moment.")
    end
end

-- Apply themed backdrop to a frame using ColorPalette
function MidnightUI:ApplyThemedBackdrop(frame)
    if not frame then return end
    
    -- Clear any backdrop on the parent frame itself
    if frame.SetBackdrop then
        frame:SetBackdrop(nil)
    end
    
    -- Force recreation of backdrop to apply new settings
    if frame.muiBackdrop then
        frame.muiBackdrop:Hide()
        frame.muiBackdrop:SetParent(nil)
        frame.muiBackdrop = nil
    end
    
    -- Create new backdrop with correct settings
    frame.muiBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.muiBackdrop:SetAllPoints()
    local level = frame:GetFrameLevel()
    frame.muiBackdrop:SetFrameLevel(level > 0 and level - 1 or 0)
    
    -- Set backdrop parameters
    frame.muiBackdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    
    -- Use framework colors if available
    local ColorPalette = _G.MidnightUI_ColorPalette
    if ColorPalette then
        local r, g, b, a = ColorPalette:GetColor('panel-bg')
        frame.muiBackdrop:SetBackdropColor(r, g, b, a)
        frame.muiBackdrop:SetBackdropBorderColor(ColorPalette:GetColor('panel-border'))
    else
        -- Fallback to database colors
        local cfg = self.db.profile.theme
        frame.muiBackdrop:SetBackdropColor(unpack(cfg.bgColor))
        frame.muiBackdrop:SetBackdropBorderColor(unpack(cfg.borderColor))
    end
    
    frame.muiBackdrop:Show()
end

-- ============================================================================
-- 4. OPTIONS TABLE
-- ============================================================================
function MidnightUI:GetThemeOptions()
    local ColorPalette = _G.MidnightUI_ColorPalette
    if not ColorPalette then
        return {
            header = {
                type = "header",
                name = "Theme System Not Loaded",
                order = 1,
            },
            desc = {
                type = "description",
                name = "The theme system is not yet initialized. Please /reload and try again.",
                order = 2,
            },
        }
    end
    
    -- Get available themes
    local availableThemes = {}
    -- Get all registered themes from ColorPalette
    for themeName, _ in pairs(ColorPalette.palettes) do
        table.insert(availableThemes, themeName)
    end
    -- Add custom themes
    local customThemes = self.db.profile.theme.customThemes or {}
    for themeName, _ in pairs(customThemes) do
        if not ColorPalette.palettes[themeName] then
            table.insert(availableThemes, themeName)
        end
    end
    
    -- Function to convert theme names to readable format
    local function GetDisplayName(themeName)
        -- Add spaces before capital letters (except first)
        local display = themeName:gsub("(%u)", " %1"):gsub("^ ", "")
        return display
    end
    
    -- Sort alphabetically by display name
    table.sort(availableThemes, function(a, b)
        return GetDisplayName(a) < GetDisplayName(b)
    end)
    
    -- Build theme selection dropdown values
    local themeValues = {}
    for _, name in ipairs(availableThemes) do
        themeValues[name] = GetDisplayName(name)
    end
    
    local options = {
        header = {
            type = "header",
            name = "Theme Management",
            order = 1
        },
        description = {
            type = "description",
            name = "Select an existing theme or create your own custom theme by adjusting the colors below.",
            order = 2,
            fontSize = "medium",
        },
        activeTheme = {
            type = "select",
            name = "Active Theme",
            desc = "Select which theme to use for the MidnightUI framework.",
            order = 3,
            values = themeValues,
            get = function() return self.db.profile.theme.active end,
            set = function(_, value)
                -- If it's a custom theme, reload it from the database first
                if self.db.profile.theme.customThemes and self.db.profile.theme.customThemes[value] then
                    local themeData = self.db.profile.theme.customThemes[value]
                    if ColorPalette then
                        ColorPalette:RegisterPalette(value, themeData)
                    end
                end
                
                self.db.profile.theme.active = value
                if self.FrameFactory then
                    self.FrameFactory:SetTheme(value)
                end
                if ColorPalette then
                    ColorPalette:SetActiveTheme(value)
                end
                if self.FontKit then
                    self.FontKit:SetActiveTheme(value)
                end
                
                -- Clear temp colors when switching themes
                self.tempThemeColors = nil
                
                -- Update color swatches to show new theme colors
                self:UpdateThemeColorSwatches()
                
                -- Notify modules that theme has changed
                self:SendMessage("MIDNIGHTUI_THEME_CHANGED", value)
                
                self:Print("Theme changed to " .. value .. ". Some changes may require a /reload to take full effect.")
                
                -- Refresh options to show current theme colors
                
            end,
        },
        spacer1 = {
            type = "description",
            name = " ",
            order = 3.5,
        },
        customThemeHeader = {
            type = "header",
            name = "Custom Theme Editor",
            order = 4
        },
        customThemeDesc = {
            type = "description",
            name = "Create a custom theme by adjusting the colors below. These colors are shown from the currently selected theme. To create a custom theme, adjust the colors and then save with a new name.",
            order = 5,
            fontSize = "medium",
        },
        customThemeName = {
            type = "input",
            name = "New Theme Name",
            desc = "Enter a name for your custom theme before saving.",
            order = 6,
            width = "full",
            get = function() return self.customThemeName or "" end,
            set = function(_, v) self.customThemeName = v end,
        },
        saveCustomTheme = {
            type = "execute",
            name = "Save Custom Theme",
            desc = "Save current color settings as a new custom theme.",
            order = 7,
            func = function()
                self:SaveCustomTheme()
            end,
        },
        deleteCustomTheme = {
            type = "execute",
            name = "Delete Custom Theme",
            desc = "Delete the currently selected custom theme (built-in themes cannot be deleted).",
            order = 8,
            disabled = function()
                local active = self.db.profile.theme.active
                local builtInThemes = {
                    "MidnightUIDefault", "MidnightGlass", "MidnightGreen",
                    "MidnightTransparent", "MidnightTransparentGold",
                    "MidnightDeathKnight", "MidnightDemonHunter", "MidnightDruid",
                    "MidnightEvoker", "MidnightHunter", "MidnightMage",
                    "MidnightMonk", "MidnightPaladin", "MidnightPriest",
                    "MidnightRogue", "MidnightShaman", "MidnightWarlock",
                    "MidnightWarrior", "NeonSciFi"
                }
                for _, themeName in ipairs(builtInThemes) do
                    if active == themeName then
                        return true
                    end
                end
                return false
            end,
            func = function()
                self:DeleteCustomTheme()
            end,
            confirm = function()
                return "Are you sure you want to delete the theme '" .. self.db.profile.theme.active .. "'?"
            end,
        },
        spacer2 = {
            type = "description",
            name = " ",
            order = 8.5,
        },
        colorsHeader = {
            type = "header",
            name = "Theme Colors",
            order = 9
        },
        colorsDesc = {
            type = "description",
            name = "Click any color rectangle below to change its color.",
            order = 10,
        },
        spacer3 = {
            type = "description",
            name = " ",
            order = 12,
        },
        spacer4 = {
            type = "description",
            name = " ",
            order = 13,
        },
        spacer5 = {
            type = "description",
            name = " ",
            order = 14,
        },
        spacer6 = {
            type = "description",
            name = " ",
            order = 15,
        },
        spacer7 = {
            type = "description",
            name = " ",
            order = 16,
        },
        spacer2 = {
            type = "description",
            name = " ",
            order = 19,
        },
        resetThemeColors = {
            type = "execute",
            name = "Reset to Theme Defaults",
            desc = "Reset all color changes back to the original theme defaults",
            order = 19.5,
            func = function()
                -- Clear temp colors
                self.tempThemeColors = nil
                
                -- Reload the original palette for the active theme
                local ColorPalette = _G.MidnightUI_ColorPalette
                if ColorPalette then
                    local activeTheme = self.db.profile.theme.active
                    -- Force re-registration from the theme file
                    self:LoadTheme(activeTheme)
                    self:UpdateThemeColorSwatches()
                end
                
                self:Print("Theme colors reset to defaults")
            end,
        },
        spacer8 = {
            type = "description",
            name = " ",
            order = 19.75,
        },        
        openColorEditor = {
            type = "execute",
            name = "Open Theme Editor",
            desc = "Opens a visual mockup window where you can click on elements to edit their colors",
            order = 20,
            func = function()
                self:OpenColorEditorFrame()
            end,
        },
    }
    
    return options
end

function MidnightUI:OpenColorPickerForThemeColor(colorKey, colorName)
    local ColorPalette = _G.MidnightUI_ColorPalette
    if not ColorPalette then
        self:Print("Color system not initialized.")
        return
    end
    
    local r, g, b, a = ColorPalette:GetColor(colorKey)
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b,
        opacity = a,
        hasOpacity = true,
        swatchFunc = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local na = ColorPickerFrame:GetColorAlpha()
            
            -- Store in temp colors
            if not self.tempThemeColors then
                self.tempThemeColors = {}
            end
            self.tempThemeColors[colorKey] = {r = nr, g = ng, b = nb, a = na}
            
            -- Apply the color immediately to preview
            local activeTheme = self.db.profile.theme.active
            local fullPalette = ColorPalette.palettes[activeTheme]
            if fullPalette then
                -- Create a copy and update with temp colors
                local updatedPalette = {}
                for k, v in pairs(fullPalette) do
                    updatedPalette[k] = v
                end
                for tempKey, tempColor in pairs(self.tempThemeColors) do
                    updatedPalette[tempKey] = tempColor
                end
                -- Re-register the theme with updated colors
                ColorPalette:RegisterPalette(activeTheme, updatedPalette)
            end
            
            -- Update color swatch frames if they exist
            self:UpdateThemeColorSwatches()
        end,
        cancelFunc = function()
            -- Restore original color
            if not self.tempThemeColors then
                self.tempThemeColors = {}
            end
            self.tempThemeColors[colorKey] = {r = r, g = g, b = b, a = a}
            
            local activeTheme = self.db.profile.theme.active
            local fullPalette = ColorPalette.palettes[activeTheme]
            if fullPalette then
                ColorPalette:RegisterPalette(activeTheme, fullPalette)
            end
            
            self:UpdateThemeColorSwatches()
        end,
    })
end

function MidnightUI:UpdateThemeColorSwatches()
    -- This will update the color swatch frames when they're created
    if self.themeColorSwatches then
        local ColorPalette = _G.MidnightUI_ColorPalette
        if not ColorPalette then return end
        
        for colorKey, swatchData in pairs(self.themeColorSwatches) do
            if swatchData and swatchData.texture then
                -- Check if there's a temp color for this key (unsaved changes)
                local r, g, b, a
                if self.tempThemeColors and self.tempThemeColors[colorKey] then
                    local tempColor = self.tempThemeColors[colorKey]
                    r, g, b, a = tempColor.r, tempColor.g, tempColor.b, tempColor.a
                else
                    -- Use the color from the active theme
                    r, g, b, a = ColorPalette:GetColor(colorKey)
                end
                swatchData.texture:SetColorTexture(r, g, b, a)
            end
        end
    end
end

function MidnightUI:OpenColorEditorFrame()
    -- Create or show the color editor frame
    if self.colorEditorFrame then
        self.colorEditorFrame:Show()
        return
    end
    
    local ColorPalette = _G.MidnightUI_ColorPalette
    local FontKit = _G.MidnightUI_FontKit
    if not ColorPalette or not FontKit then
        self:Print("Framework not initialized.")
        return
    end
    
    -- Create main frame styled like a real MidnightUI window
    local frame = CreateFrame("Frame", "MidnightUI_ColorEditorFrame", UIParent, "BackdropTemplate")
    frame:SetSize(800, 600)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    
    -- Function to get current color
    local function GetCurrentColor(key)
        local color = self.tempThemeColors and self.tempThemeColors[key]
        if color then
            return color.r, color.g, color.b, color.a
        end
        return ColorPalette:GetColor(key)
    end
    
    -- Function to update frame colors
    local function UpdateFrameColors()
        -- Update main frame
        frame:SetBackdropColor(GetCurrentColor("panel-bg"))
        frame:SetBackdropBorderColor(GetCurrentColor("panel-border"))
        
        -- Update title bar
        if frame.titleBg then
            frame.titleBg:SetColorTexture(GetCurrentColor("panel-bg"))
        end
        
        -- Update inner panel
        if frame.innerPanel then
            frame.innerPanel:SetBackdropColor(GetCurrentColor("panel-bg"))
            frame.innerPanel:SetBackdropBorderColor(GetCurrentColor("accent-primary"))
        end
        
        -- Update buttons
        for _, btn in ipairs(frame.mockButtons or {}) do
            btn:SetBackdropColor(GetCurrentColor("button-bg"))
            btn:SetBackdropBorderColor(GetCurrentColor("accent-primary"))
        end
        
        -- Update tabs
        for i, tab in ipairs(frame.mockTabs or {}) do
            if i == 2 then
                tab:SetBackdropColor(GetCurrentColor("tab-active"))
            else
                tab:SetBackdropColor(GetCurrentColor("button-bg"))
            end
            tab:SetBackdropBorderColor(GetCurrentColor("accent-primary"))
        end
        
        -- Update text
        if frame.titleText then
            frame.titleText:SetTextColor(GetCurrentColor("text-primary"))
        end
        if frame.headerText then
            frame.headerText:SetTextColor(GetCurrentColor("text-primary"))
        end
        if frame.descText then
            frame.descText:SetTextColor(GetCurrentColor("text-secondary"))
        end
        for _, btn in ipairs(frame.mockButtons or {}) do
            if btn.text then
                btn.text:SetTextColor(GetCurrentColor("text-primary"))
            end
        end
        for _, tab in ipairs(frame.mockTabs or {}) do
            if tab.text then
                tab.text:SetTextColor(GetCurrentColor("text-primary"))
            end
        end
    end
    
    -- Apply backdrop styled like settings window
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    
    -- Title bar background (used for dragging, not clickable for color)
    local titleBg = frame:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT", 0, 0)
    titleBg:SetPoint("TOPRIGHT", 0, 0)
    titleBg:SetHeight(60)
    frame.titleBg = titleBg
    
    -- Make title bar draggable (not clickable for color picker)
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(60)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)
    
    -- Title text
    local title = FontKit:CreateFontString(frame, "title", "large")
    title:SetPoint("TOPLEFT", 20, -12)
    title:SetText("Theme Editor")
    frame.titleText = title
    
    -- Instructions in title area
    local instructions = FontKit:CreateFontString(frame, "body", "small")
    instructions:SetPoint("TOPLEFT", 20, -38)
    instructions:SetText("Click on any element below to change its color • Drag title bar to move")
    frame.descText = instructions
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("TOPRIGHT", -12, -12)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    closeBtn:SetBackdropColor(GetCurrentColor("button-bg"))
    closeBtn:SetBackdropBorderColor(GetCurrentColor("panel-border"))
    closeBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    closeTxt:SetFont("Fonts\\FRIZQT__.TTF", 26, "OUTLINE")
    closeTxt:SetText("×")
    closeTxt:SetPoint("CENTER", 0, 0)
    closeTxt:SetTextColor(GetCurrentColor("text-primary"))
    closeBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(GetCurrentColor("button-hover"))
        self:SetBackdropBorderColor(GetCurrentColor("accent-primary"))
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(GetCurrentColor("button-bg"))
        self:SetBackdropBorderColor(GetCurrentColor("panel-border"))
    end)
    closeBtn:SetScript("OnClick", function()
        -- Check if there are any color changes
        if MidnightUI.tempThemeColors and next(MidnightUI.tempThemeColors) ~= nil then
            StaticPopupDialogs["MIDNIGHTUI_THEME_CLOSE_CONFIRM"] = {
                text = "You have unsaved color changes that will be lost. Close anyway?",
                button1 = "Close",
                button2 = "Cancel",
                OnAccept = function()
                    -- Discard changes and close
                    MidnightUI.tempThemeColors = nil
                    frame:Hide()
                end,
                OnCancel = function()
                    -- Cancel - keep window open
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("MIDNIGHTUI_THEME_CLOSE_CONFIRM")
        else
            -- No changes, just close
            frame:Hide()
        end
    end)
    
    -- Background click area (behind everything else) for panel-bg and panel-border colors
    local bgClickArea = CreateFrame("Frame", nil, frame)
    bgClickArea:SetAllPoints(frame)
    bgClickArea:SetFrameLevel(frame:GetFrameLevel() + 1)
    bgClickArea:EnableMouse(true)
    bgClickArea:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        
        -- Get mouse position relative to frame
        local scale = frame:GetEffectiveScale()
        local frameLeft = frame:GetLeft() * scale
        local frameRight = frame:GetRight() * scale
        local frameTop = frame:GetTop() * scale
        local frameBottom = frame:GetBottom() * scale
        local mouseX, mouseY = GetCursorPosition()
        
        -- Check if click is within 20px of any edge
        local edgeThreshold = 20 * scale
        local nearLeftEdge = (mouseX - frameLeft) < edgeThreshold
        local nearRightEdge = (frameRight - mouseX) < edgeThreshold
        local nearTopEdge = (frameTop - mouseY) < edgeThreshold
        local nearBottomEdge = (mouseY - frameBottom) < edgeThreshold
        
        if nearLeftEdge or nearRightEdge or nearTopEdge or nearBottomEdge then
            -- Click near border - change panel-border color
            local r, g, b, a = GetCurrentColor("panel-border")
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                opacity = a,
                hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = ColorPickerFrame:GetColorAlpha()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors["panel-border"] = {r = nr, g = ng, b = nb, a = na}
                    UpdateFrameColors()
                end,
                cancelFunc = function()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors["panel-border"] = {r = r, g = g, b = b, a = a}
                    UpdateFrameColors()
                end,
            })
        else
            -- Click in center - change panel-bg color
            local r, g, b, a = GetCurrentColor("panel-bg")
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                opacity = a,
                hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = ColorPickerFrame:GetColorAlpha()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors["panel-bg"] = {r = nr, g = ng, b = nb, a = na}
                    UpdateFrameColors()
                end,
                cancelFunc = function()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors["panel-bg"] = {r = r, g = g, b = b, a = a}
                    UpdateFrameColors()
                end,
            })
        end
    end)
    bgClickArea:SetScript("OnEnter", function()
        -- Show tooltip based on mouse position
        local scale = frame:GetEffectiveScale()
        local frameLeft = frame:GetLeft() * scale
        local frameRight = frame:GetRight() * scale
        local frameTop = frame:GetTop() * scale
        local frameBottom = frame:GetBottom() * scale
        local mouseX, mouseY = GetCursorPosition()
        
        local edgeThreshold = 20 * scale
        local nearLeftEdge = (mouseX - frameLeft) < edgeThreshold
        local nearRightEdge = (frameRight - mouseX) < edgeThreshold
        local nearTopEdge = (frameTop - mouseY) < edgeThreshold
        local nearBottomEdge = (mouseY - frameBottom) < edgeThreshold
        
        GameTooltip:SetOwner(bgClickArea, "ANCHOR_CURSOR")
        if nearLeftEdge or nearRightEdge or nearTopEdge or nearBottomEdge then
            GameTooltip:SetText("Panel Border", 1, 1, 1)
            GameTooltip:AddLine("Border color for all panels and frames", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Click near edge to change color", 0.0, 1.0, 0.5)
        else
            GameTooltip:SetText("Panel Background", 1, 1, 1)
            GameTooltip:AddLine("Main background color for windows and panels", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Click center area to change color", 0.0, 1.0, 0.5)
        end
        GameTooltip:Show()
    end)
    bgClickArea:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Create inner panel to demonstrate panel border (accent-primary)
    -- This panel is non-interactive so clicks pass through to bgClickArea for proper edge detection
    local innerPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    innerPanel:SetSize(760, 450)
    innerPanel:SetPoint("TOP", 0, -75)
    innerPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    innerPanel:SetFrameLevel(frame:GetFrameLevel() + 2)
    innerPanel:EnableMouse(false)  -- Don't intercept clicks - let them pass through to bgClickArea
    frame.innerPanel = innerPanel
    
    -- Create clickable border areas for accent-primary color editing
    local borderThickness = 8  -- Make borders easier to click
    
    -- Top border
    local topBorder = CreateFrame("Frame", nil, innerPanel)
    topBorder:SetPoint("TOPLEFT", innerPanel, "TOPLEFT", 0, 0)
    topBorder:SetPoint("TOPRIGHT", innerPanel, "TOPRIGHT", 0, 0)
    topBorder:SetHeight(borderThickness)
    topBorder:SetFrameLevel(innerPanel:GetFrameLevel() + 1)
    topBorder:EnableMouse(true)
    
    -- Bottom border
    local bottomBorder = CreateFrame("Frame", nil, innerPanel)
    bottomBorder:SetPoint("BOTTOMLEFT", innerPanel, "BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", innerPanel, "BOTTOMRIGHT", 0, 0)
    bottomBorder:SetHeight(borderThickness)
    bottomBorder:SetFrameLevel(innerPanel:GetFrameLevel() + 1)
    bottomBorder:EnableMouse(true)
    
    -- Left border
    local leftBorder = CreateFrame("Frame", nil, innerPanel)
    leftBorder:SetPoint("TOPLEFT", innerPanel, "TOPLEFT", 0, -borderThickness)
    leftBorder:SetPoint("BOTTOMLEFT", innerPanel, "BOTTOMLEFT", 0, borderThickness)
    leftBorder:SetWidth(borderThickness)
    leftBorder:SetFrameLevel(innerPanel:GetFrameLevel() + 1)
    leftBorder:EnableMouse(true)
    
    -- Right border
    local rightBorder = CreateFrame("Frame", nil, innerPanel)
    rightBorder:SetPoint("TOPRIGHT", innerPanel, "TOPRIGHT", 0, -borderThickness)
    rightBorder:SetPoint("BOTTOMRIGHT", innerPanel, "BOTTOMRIGHT", 0, borderThickness)
    rightBorder:SetWidth(borderThickness)
    rightBorder:SetFrameLevel(innerPanel:GetFrameLevel() + 1)
    rightBorder:EnableMouse(true)
    
    -- Add scripts to all border frames
    local borderFrames = {topBorder, bottomBorder, leftBorder, rightBorder}
    for _, border in ipairs(borderFrames) do
        border:SetScript("OnEnter", function()
            GameTooltip:SetOwner(border, "ANCHOR_CURSOR")
            GameTooltip:SetText("Panel Border (Accent)", 1, 1, 1)
            GameTooltip:AddLine("Highlighted border color for panels and minimap", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Click to change color", 0.0, 1.0, 0.5)
            GameTooltip:Show()
        end)
        border:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        border:SetScript("OnMouseDown", function()
            local r, g, b, a = GetCurrentColor("accent-primary")
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                opacity = a,
                hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = ColorPickerFrame:GetColorAlpha()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors["accent-primary"] = {r = nr, g = ng, b = nb, a = na}
                    UpdateFrameColors()
                end,
                cancelFunc = function()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors["accent-primary"] = {r = r, g = g, b = b, a = a}
                    UpdateFrameColors()
                end,
            })
        end)
    end
    
    -- Header text in panel
    local headerText = FontKit:CreateFontString(innerPanel, "heading", "medium")
    headerText:SetPoint("TOPLEFT", 20, -20)
    headerText:SetText("Sample UI Elements")
    frame.headerText = headerText
    
    -- Tab group mockup
    local tabs = {}
    local tabNames = {"General", "Settings", "Advanced"}
    for i, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", nil, innerPanel, "BackdropTemplate")
        tab:SetSize(120, 32)
        if i == 1 then
            tab:SetPoint("TOPLEFT", 20, -50)
        else
            tab:SetPoint("LEFT", tabs[i-1], "RIGHT", 5, 0)
        end
        tab:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        tab:SetFrameLevel(innerPanel:GetFrameLevel() + 5)
        tab.text = tab:CreateFontString(nil, "OVERLAY")
        tab.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        tab.text:SetText(name)
        tab.text:SetPoint("CENTER")
        tab:EnableMouse(true)
        
        -- Click handler for tab color
        local colorKey = i == 2 and "tab-active" or "button-bg"
        tab:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(i == 2 and "Active Tab" or "Inactive Tab", 1, 1, 1)
            GameTooltip:AddLine(i == 2 and "Background color for the currently selected tab" or "Background color for inactive tabs", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Click to change " .. (i == 2 and "active tab" or "button") .. " color", 0.0, 1.0, 0.5)
            GameTooltip:Show()
        end)
        tab:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        tab:SetScript("OnMouseDown", function()
            local r, g, b, a = GetCurrentColor(colorKey)
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                opacity = a,
                hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = ColorPickerFrame:GetColorAlpha()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors[colorKey] = {r = nr, g = ng, b = nb, a = na}
                    UpdateFrameColors()
                end,
                cancelFunc = function()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors[colorKey] = {r = r, g = g, b = b, a = a}
                    UpdateFrameColors()
                end,
            })
        end)
        
        table.insert(tabs, tab)
    end
    frame.mockTabs = tabs
    
    -- Text samples
    local textLabel1 = FontKit:CreateFontString(innerPanel, "body", "normal")
    textLabel1:SetPoint("TOPLEFT", 20, -100)
    textLabel1:SetText("Primary Text: Main labels and headers")
    textLabel1:EnableMouse(true)
    
    local textClick1 = CreateFrame("Frame", nil, innerPanel)
    textClick1:SetAllPoints(textLabel1)
    textClick1:SetFrameLevel(innerPanel:GetFrameLevel() + 5)
    textClick1:EnableMouse(true)
    textClick1:SetScript("OnEnter", function()
        GameTooltip:SetOwner(textClick1, "ANCHOR_TOP")
        GameTooltip:SetText("Primary Text", 1, 1, 1)
        GameTooltip:AddLine("Main text color for labels and headers", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Click to change color", 0.0, 1.0, 0.5)
        GameTooltip:Show()
    end)
    textClick1:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    textClick1:SetScript("OnMouseDown", function()
        local r, g, b, a = GetCurrentColor("text-primary")
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            opacity = a,
            hasOpacity = true,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = ColorPickerFrame:GetColorAlpha()
                if not MidnightUI.tempThemeColors then
                    MidnightUI.tempThemeColors = {}
                end
                MidnightUI.tempThemeColors["text-primary"] = {r = nr, g = ng, b = nb, a = na}
                UpdateFrameColors()
            end,
            cancelFunc = function()
                if not MidnightUI.tempThemeColors then
                    MidnightUI.tempThemeColors = {}
                end
                MidnightUI.tempThemeColors["text-primary"] = {r = r, g = g, b = b, a = a}
                UpdateFrameColors()
            end,
        })
    end)
    
    local textLabel2 = FontKit:CreateFontString(innerPanel, "body", "normal")
    textLabel2:SetPoint("TOPLEFT", 20, -125)
    textLabel2:SetText("Secondary Text: Descriptions and hints")
    textLabel2:EnableMouse(true)
    
    local textClick2 = CreateFrame("Frame", nil, innerPanel)
    textClick2:SetAllPoints(textLabel2)
    textClick2:SetFrameLevel(innerPanel:GetFrameLevel() + 5)
    textClick2:EnableMouse(true)
    textClick2:SetScript("OnEnter", function()
        GameTooltip:SetOwner(textClick2, "ANCHOR_TOP")
        GameTooltip:SetText("Secondary Text", 1, 1, 1)
        GameTooltip:AddLine("Text color for descriptions and supporting information", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Click to change color", 0.0, 1.0, 0.5)
        GameTooltip:Show()
    end)
    textClick2:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    textClick2:SetScript("OnMouseDown", function()
        local r, g, b, a = GetCurrentColor("text-secondary")
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            opacity = a,
            hasOpacity = true,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = ColorPickerFrame:GetColorAlpha()
                if not MidnightUI.tempThemeColors then
                    MidnightUI.tempThemeColors = {}
                end
                MidnightUI.tempThemeColors["text-secondary"] = {r = nr, g = ng, b = nb, a = na}
                UpdateFrameColors()
            end,
            cancelFunc = function()
                if not MidnightUI.tempThemeColors then
                    MidnightUI.tempThemeColors = {}
                end
                MidnightUI.tempThemeColors["text-secondary"] = {r = r, g = g, b = b, a = a}
                UpdateFrameColors()
            end,
        })
    end)
    
    -- Button mockups
    local buttons = {}
    local buttonNames = {"Button Background", "Button Hover"}
    local buttonKeys = {"button-bg", "button-hover"}
    for i, name in ipairs(buttonNames) do
        local btn = CreateFrame("Button", nil, innerPanel, "BackdropTemplate")
        btn:SetSize(180, 36)
        if i == 1 then
            btn:SetPoint("TOPLEFT", 20, -170)
        else
            btn:SetPoint("LEFT", buttons[i-1], "RIGHT", 20, 0)
        end
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        btn:SetFrameLevel(innerPanel:GetFrameLevel() + 5)
        btn.text = btn:CreateFontString(nil, "OVERLAY")
        btn.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        btn.text:SetText(name)
        btn.text:SetPoint("CENTER")
        btn:EnableMouse(true)
        
        local colorKey = buttonKeys[i]
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(i == 1 and "Background color for all buttons" or "Button color when hovering with mouse", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Click to change color", 0.0, 1.0, 0.5)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        btn:SetScript("OnMouseDown", function()
            local r, g, b, a = GetCurrentColor(colorKey)
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                opacity = a,
                hasOpacity = true,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = ColorPickerFrame:GetColorAlpha()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors[colorKey] = {r = nr, g = ng, b = nb, a = na}
                    UpdateFrameColors()
                end,
                cancelFunc = function()
                    if not MidnightUI.tempThemeColors then
                        MidnightUI.tempThemeColors = {}
                    end
                    MidnightUI.tempThemeColors[colorKey] = {r = r, g = g, b = b, a = a}
                    UpdateFrameColors()
                end,
            })
        end)
        
        table.insert(buttons, btn)
    end
    frame.mockButtons = buttons
    
    -- Bottom buttons
    local saveBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    saveBtn:SetSize(200, 36)
    saveBtn:SetPoint("BOTTOMLEFT", 20, 15)
    saveBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    saveBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
    saveBtn:SetBackdropColor(GetCurrentColor("button-bg"))
    saveBtn:SetBackdropBorderColor(GetCurrentColor("accent-primary"))
    local saveTxt = saveBtn:CreateFontString(nil, "OVERLAY")
    saveTxt:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    saveTxt:SetText("Save & Apply")
    saveTxt:SetPoint("CENTER")
    saveTxt:SetTextColor(GetCurrentColor("text-primary"))
    saveBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(GetCurrentColor("button-hover"))
    end)
    saveBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(GetCurrentColor("button-bg"))
    end)
    saveBtn:SetScript("OnClick", function()
        -- Check if there are any color changes
        if not MidnightUI.tempThemeColors or next(MidnightUI.tempThemeColors) == nil then
            MidnightUI:Print("|cffff8800Warning:|r No color changes detected. Please modify at least one color first.")
            return
        end
        
        -- Show save dialog
        StaticPopupDialogs["MIDNIGHTUI_THEME_SAVE_CONFIRM"] = {
            text = "Ready to save your custom theme. The editor will close and the Themes settings page will open where you can enter a name and save.",
            button1 = "Continue",
            button2 = "Cancel",
            OnAccept = function()
                -- Open settings to Themes page so user can enter a name and save
                frame:Hide()
                if MidnightUI and type(MidnightUI.OpenConfig) == "function" then
                    MidnightUI:OpenConfig()
                    -- TODO: Navigate to Themes section in custom panel
                    -- For now, user will need to click Themes in the tree
                end
                MidnightUI:Print("Click 'Themes' in the options panel, then enter a theme name and click 'Save Custom Theme' to save your changes.")
            end,
            OnCancel = function()
                -- Cancel - keep window open
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("MIDNIGHTUI_THEME_SAVE_CONFIRM")
    end)
    
    -- Reset button at bottom
    local resetBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    resetBtn:SetSize(200, 36)
    resetBtn:SetPoint("BOTTOMRIGHT", -20, 15)
    resetBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    resetBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
    resetBtn:SetBackdropColor(GetCurrentColor("button-bg"))
    resetBtn:SetBackdropBorderColor(GetCurrentColor("accent-primary"))
    local resetTxt = resetBtn:CreateFontString(nil, "OVERLAY")
    resetTxt:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    resetTxt:SetText("Reset to Theme Defaults")
    resetTxt:SetPoint("CENTER")
    resetTxt:SetTextColor(GetCurrentColor("text-primary"))
    resetBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(GetCurrentColor("button-hover"))
    end)
    resetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(GetCurrentColor("button-bg"))
    end)
    resetBtn:SetScript("OnClick", function()
        MidnightUI.tempThemeColors = nil
        UpdateFrameColors()
        MidnightUI:Print("Colors reset to theme defaults.")
    end)
    
    UpdateFrameColors()
    self.colorEditorFrame = frame
    frame:Show()
end

function MidnightUI:SaveCustomTheme()
    local themeName = self.customThemeName
    if not themeName or themeName == "" then
        self:Print("|cffff0000Error:|r Please enter a name for your custom theme.")
        return
    end
    
    -- Don't allow overwriting built-in themes
    local builtInThemes = {
        "MidnightUIDefault",
        "MidnightGlass",
        "MidnightGreen",
        "MidnightTransparent",
        "MidnightTransparentGold",
        "MidnightDeathKnight",
        "MidnightDemonHunter",
        "MidnightDruid",
        "MidnightEvoker",
        "MidnightHunter",
        "MidnightMage",
        "MidnightMonk",
        "MidnightPaladin",
        "MidnightPriest",
        "MidnightRogue",
        "MidnightShaman",
        "MidnightWarlock",
        "MidnightWarrior",
        "NeonSciFi"
    }
    for _, builtInName in ipairs(builtInThemes) do
        if themeName == builtInName then
            self:Print("|cffff0000Error:|r Cannot overwrite built-in themes.")
            return
        end
    end
    
    -- Check if theme already exists
    local isOverwrite = false
    if self.db.profile.theme.customThemes and self.db.profile.theme.customThemes[themeName] then
        isOverwrite = true
    end
    
    -- Only require color changes for NEW themes, allow overwrites without changes
    if not isOverwrite and (not self.tempThemeColors or next(self.tempThemeColors) == nil) then
        self:Print("|cffff0000Error:|r No color changes detected. Please modify at least one color before saving a new theme.")
        return
    end
    
    -- Get full theme palette from current theme as base
    local ColorPalette = _G.MidnightUI_ColorPalette
    local fullTheme = {}
    
    -- Copy all colors from current active theme
    local currentTheme = self.db.profile.theme.active
    local palette = ColorPalette.palettes[currentTheme]
    if palette then
        for key, color in pairs(palette) do
            fullTheme[key] = {r = color.r, g = color.g, b = color.b, a = color.a}
        end
    end
    
    -- Override with custom changes (if any)
    if self.tempThemeColors then
        for key, color in pairs(self.tempThemeColors) do
            fullTheme[key] = color
        end
    end
    
    -- Save theme to database
    if not self.db.profile.theme.customThemes then
        self.db.profile.theme.customThemes = {}
    end
    
    self.db.profile.theme.customThemes[themeName] = fullTheme
    
    -- Register the theme with ColorPalette
    if ColorPalette then
        ColorPalette:RegisterPalette(themeName, fullTheme)
        -- Switch to the newly saved custom theme
        ColorPalette:SetActiveTheme(themeName)
    end
    
    -- Switch the active theme to the newly created theme
    self.db.profile.theme.active = themeName
    if self.FrameFactory then
        self.FrameFactory:SetTheme(themeName)
    end
    if self.FontKit then
        self.FontKit:SetActiveTheme(themeName)
    end
    
    if isOverwrite then
        self:Print("|cff00ff00Success:|r Custom theme '" .. themeName .. "' updated and activated!")
    else
        self:Print("|cff00ff00Success:|r Custom theme '" .. themeName .. "' created and activated!")
    end
    
    -- Clear temporary storage and name
    self.tempThemeColors = nil
    self.customThemeName = ""
    
    -- Update the color swatches to show the new theme colors
    self:UpdateThemeColorSwatches()
    
    -- Refresh options
    
end

function MidnightUI:DeleteCustomTheme()
    local themeName = self.db.profile.theme.active
    
    if not self.db.profile.theme.customThemes or not self.db.profile.theme.customThemes[themeName] then
        self:Print("|cffff0000Error:|r Theme not found or is not a custom theme.")
        return
    end
    
    -- Remove from database
    self.db.profile.theme.customThemes[themeName] = nil
    
    -- Switch to default theme
    self.db.profile.theme.active = "MidnightTransparent"
    local ColorPalette = _G.MidnightUI_ColorPalette
    if ColorPalette then
        ColorPalette:SetActiveTheme("MidnightTransparent")
    end
    if self.FrameFactory then
        self.FrameFactory:SetTheme("MidnightTransparent")
    end
    if self.FontKit then
        self.FontKit:SetActiveTheme("MidnightTransparent")
    end
    
    self:Print("|cff00ff00Success:|r Theme '" .. themeName .. "' deleted. Switched to Midnight Transparent.")
    
    -- Refresh options
    
end

function MidnightUI:LoadCustomThemes()
    local ColorPalette = _G.MidnightUI_ColorPalette
    if not ColorPalette then return end
    
    local customThemes = self.db.profile.theme.customThemes
    if not customThemes then return end
    
    for themeName, themeColors in pairs(customThemes) do
        ColorPalette:RegisterPalette(themeName, themeColors)
    end
end

function MidnightUI:GetOptions()
    -- Note: Using custom MidnightOptionsPanel now, no AceConfig dependency
    -- Cleanup theme color swatch container if needed
    if self.colorSwatchContainer and not self.colorSwatchContainer:IsShown() then
        self.colorSwatchContainer:SetParent(nil)
        self.colorSwatchContainer = nil
        self.themeColorSwatches = nil
    end
    
    local options = {
        name = "Midnight UI",
        type = "group",
        childGroups = "tree",
        args = {
            general = {
                name = "General",
                type = "group",
                order = 1,
                args = {
                    versionInfo = {
                        type = "description",
                        name = function()
                            return "|cff00ccff MidnightUI|r version |cffffaa00" .. (C_AddOns.GetAddOnMetadata("MidnightUI", "Version") or "Unknown") .. "|r"
                        end,
                        order = 0.5,
                        fontSize = "large",
                    },
                    resolutionHeader = {
                        type = "header",
                        name = "Resolution Scaling",
                        order = 1.0
                    },
                    resolutionDesc = {
                        type = "description",
                        name = function()
                            local screenWidth = math.floor(GetScreenWidth())
                            local screenHeight = math.floor(GetScreenHeight())
                            local physicalWidth = math.floor(GetScreenWidth() * UIParent:GetEffectiveScale())
                            local physicalHeight = math.floor(GetScreenHeight() * UIParent:GetEffectiveScale())
                            local uiScale = UIParent:GetEffectiveScale()
                            local refWidth = MidnightUI.REFERENCE_WIDTH
                            local refHeight = MidnightUI.REFERENCE_HEIGHT
                            
                            local resInfo = "UI Resolution (effective): |cffffaa00" .. screenWidth .. "x" .. screenHeight .. "|r\n"
                            if physicalWidth ~= screenWidth or physicalHeight ~= screenHeight then
                                resInfo = resInfo .. "UI Scale: |cffcccccc" .. string.format("%.1f%%", uiScale * 100) .. "|r\n\n"
                            end
                            
                            if screenWidth == refWidth and screenHeight == refHeight then
                                return resInfo .. "|cff00ff00Your UI resolution matches the default layout resolution (" .. refWidth .. "x" .. refHeight .. ").|r\n" ..
                                       "|cffccccccThis is the standard effective resolution when your game is set to 2560x1440 with 'Use UI Scale' OFF.|r\n" ..
                                       "No scaling needed!"
                            else
                                return resInfo .. "Default layout resolution: " .. refWidth .. "x" .. refHeight .. "\n" ..
                                       "|cffcccccc(Standard for 2560x1440 with 'Use UI Scale' OFF)|r\n\n" ..
                                       "|cffaaaaIf you imported a profile from someone using " .. refWidth .. "x" .. refHeight .. ", use the button below to automatically scale all element positions to your UI resolution.|r"
                            end
                        end,
                        order = 1.01,
                        fontSize = "medium",
                    },
                    scaleToResolution = {
                        type = "execute",
                        name = "Scale Layout Resolution",
                        desc = "Automatically adjusts all element positions from 2133x1200 to your current resolution",
                        order = 1.02,
                        func = function()
                            MidnightUI:ScaleLayoutToResolution()
                        end,
                        confirm = function()
                            local screenWidth = math.floor(GetScreenWidth())
                            local screenHeight = math.floor(GetScreenHeight())
                            return "This will scale all UI element positions from " .. MidnightUI.REFERENCE_WIDTH .. "x" .. MidnightUI.REFERENCE_HEIGHT .. " to " .. screenWidth .. "x" .. screenHeight .. " and reload your UI. Continue?"
                        end,
                    },
                    fontHeaderSpacer = {
                        type = "description",
                        name = " ",
                        order = 1.095,
                    },
                    fontHeader = {
                        type = "header",
                        name = "Global Font",
                        order = 1.1
                    },
                    globalFont = {
                        type = "select",
                        name = "Global Font",
                        desc = "Select a font to apply to all MidnightUI elements.",
                        order = 1.11,
                        values = function()
                            local fonts = LSM:List("font")
                            local out = {}
                            for _, font in ipairs(fonts) do out[font] = font end
                            return out
                        end,
                        get = function() return self.db.profile.theme.font or "Friz Quadrata TT" end,
                        set = function(_, v) self.db.profile.theme.font = v end,
                    },
                    applyGlobalFont = {
                        type = "execute",
                        name = "Apply to All",
                        desc = "Apply the selected global font to all MidnightUI modules and bars.",
                        order = 1.12,
                        func = function()
                            local font = MidnightUI.db.profile.theme.font or "Friz Quadrata TT"
                            -- UnitFrames
                            if _G.UnitFrames and _G.UnitFrames.db and _G.UnitFrames.db.profile then
                                local uf = _G.UnitFrames.db.profile
                                for _, frame in pairs({"player", "target", "targettarget"}) do
                                    for _, bar in pairs({"health", "power", "info"}) do
                                        if uf[frame] and uf[frame][bar] then
                                            uf[frame][bar].font = font
                                        end
                                    end
                                end
                            end
                            -- Bar module: set all bar fonts to global and update
                            if _G.Bar and _G.Bar.db and _G.Bar.db.profile and _G.Bar.db.profile.bars then
                                for barID, barData in pairs(_G.Bar.db.profile.bars) do
                                    barData.font = font
                                end
                                if _G.Bar.UpdateAllFonts then
                                    _G.Bar:UpdateAllFonts()
                                end
                            end
                            -- CooldownManager module
                            if _G.CooldownManager and _G.CooldownManager.db and _G.CooldownManager.db.profile then
                                _G.CooldownManager.db.profile.font = font
                                _G.CooldownManager.db.profile.essential.font = font
                                _G.CooldownManager.db.profile.utility.font = font
                            end
                            -- Maps module
                            if _G.Maps and _G.Maps.db and _G.Maps.db.profile then
                                _G.Maps.db.profile.font = font
                            end
                            -- ActionBars module
                            if _G.ActionBars and _G.ActionBars.db and _G.ActionBars.db.profile then
                                _G.ActionBars.db.profile.font = font
                            end
                            -- UIButtons module
                            if _G.UIButtons and _G.UIButtons.db and _G.UIButtons.db.profile then
                                _G.UIButtons.db.profile.font = font
                            end
                            -- Tweaks module
                            if _G.Tweaks and _G.Tweaks.db and _G.Tweaks.db.profile then
                                _G.Tweaks.db.profile.font = font
                            end
                            -- Skins module
                            if _G.Skins and _G.Skins.db and _G.Skins.db.profile then
                                _G.Skins.db.profile.font = font
                            end
                            -- Movable module
                            if _G.Movable and _G.Movable.db and _G.Movable.db.profile then
                                _G.Movable.db.profile.font = font
                            end
                            -- Force UI update for UnitFrames
                            if _G.UnitFrames and _G.UnitFrames.UpdateUnitFrame then
                                _G.UnitFrames:UpdateUnitFrame("PlayerFrame", "player")
                                _G.UnitFrames:UpdateUnitFrame("TargetFrame", "target")
                                _G.UnitFrames:UpdateUnitFrame("TargetTargetFrame", "targettarget")
                            end
                            -- Add update calls for other modules as needed
                        end,
                    },
                    modulesHeaderSpacer = {
                        type = "description",
                        name = " ",
                        order = 1.995,
                    },
                    modulesHeader = { type = "header", order = 2.0, name = "Modules"},
                    modulesDesc = { type = "description", order = 2.01, name = "Toggle modules. Requires Reload." },
                    bar = { name = "Data Brokers", type = "toggle", order = 2.1, width = "full",
                        get = function() return self.db.profile.modules.bar end,
                        set = function(_, v) self.db.profile.modules.bar = v; C_UI.Reload() end },
                    UIButtons = { name = "UI Buttons", type = "toggle", order = 2.2, width = "full",
                        get = function() return self.db.profile.modules.UIButtons end,
                        set = function(_, v) self.db.profile.modules.UIButtons = v; C_UI.Reload() end },
                    tooltips = { name = "Tooltips", type = "toggle", order = 2.25, width = "full",
                        get = function() return self.db.profile.modules.tooltips end,
                        set = function(_, v) self.db.profile.modules.tooltips = v; C_UI.Reload() end },
                    mailbox = { name = "Mailbox", type = "toggle", order = 2.27, width = "full",
                        get = function() return self.db.profile.modules.mailbox end,
                        set = function(_, v) self.db.profile.modules.mailbox = v; C_UI.Reload() end },
                    chatcopy = { name = "Chat Copy", type = "toggle", order = 2.3, width = "full",
                        get = function() return self.db.profile.modules.chatcopy ~= false end,
                        set = function(_, v) self.db.profile.modules.chatcopy = v; C_UI.Reload() end },
                    maps = { name = "Maps", type = "toggle", order = 2.4, width = "full",
                        get = function() return self.db.profile.modules.maps end,
                        set = function(_, v) self.db.profile.modules.maps = v; C_UI.Reload() end },
                    actionbars = { name = "Action Bars", type = "toggle", order = 2.5, width = "full",
                        get = function() return self.db.profile.modules.actionbars end,
                        set = function(_, v) self.db.profile.modules.actionbars = v; C_UI.Reload() end },
                    unitframes = { name = "Unit Frames", type = "toggle", order = 2.6, width = "full",
                        get = function() return self.db.profile.modules.unitframes end,
                        set = function(_, v) self.db.profile.modules.unitframes = v; C_UI.Reload() end },
                    cooldowns = { name = "Cooldown Manager", type = "toggle", order = 2.7, width = "full",
                        desc = "Skins and enhances Blizzard's cooldown display manager.",
                        get = function() return self.db.profile.modules.cooldowns end,
                        set = function(_, v) 
                            self.db.profile.modules.cooldowns = v
                            C_UI.Reload()
                        end },
                    resourceBars = { name = "Resource Bars", type = "toggle", order = 2.71, width = "full",
                        desc = "Display primary and secondary resource bars (mana, energy, combo points, etc.)",
                        get = function() return self.db.profile.modules.resourceBars end,
                        set = function(_, v) self.db.profile.modules.resourceBars = v; C_UI.Reload() end },
                    castBar = { name = "Cast Bar", type = "toggle", order = 2.72, width = "full",
                        desc = "Display a custom player cast bar",
                        get = function() return self.db.profile.modules.castBar end,
                        set = function(_, v) self.db.profile.modules.castBar = v; C_UI.Reload() end },
                    tweaks = { name = "Tweaks", type = "toggle", order = 9, width = "full",
                        get = function() return self.db.profile.modules.tweaks end,
                        set = function(_, v) self.db.profile.modules.tweaks = v; C_UI.Reload() end }
                }  -- closes args table for general
            },  -- closes general group
            themes = {
                name = "Themes",
                type = "group",
                order = 40,
                args = self:GetThemeOptions(),
            },  -- closes themes group
            export = {
                name = "Export",
                type = "group",
                order = 50,
                args = {
                    header = {
                        type = "header",
                        name = "Export Profile",
                        order = 1
                    },
                    description = {
                        type = "description",
                        name = "Export your entire MidnightUI configuration to a string that can be shared with others or saved as a backup.",
                        order = 2,
                        fontSize = "medium",
                    },
                    exportButton = {
                        type = "execute",
                        name = "Generate Export String",
                        desc = "Creates an export string of your current profile",
                        order = 3,
                        func = function()
                            MidnightUI:ExportProfile()
                        end,
                    },
                    spacer = {
                        type = "description",
                        name = " ",
                        order = 3.5,
                    },
                    exportString = {
                        type = "input",
                        name = "Export String (Ctrl+A to select all, Ctrl+C to copy)",
                        desc = "Copy this entire string to share your profile",
                        order = 4,
                        width = "full",
                        multiline = 25,
                        get = function() 
                            return MidnightUI.exportString or ""
                        end,
                        set = function() end,
                    },
                },
            },
            import = {
                name = "Import",
                type = "group",
                order = 51,
                args = {
                    header = {
                        type = "header",
                        name = "Import Profile",
                        order = 1
                    },
                    description = {
                        type = "description",
                        name = "Import a MidnightUI configuration string.",
                        order = 2,
                        fontSize = "medium",
                    },
                    newProfileName = {
                        type = "input",
                        name = "New Profile Name (Optional)",
                        desc = "Leave empty to overwrite current profile, or enter a name to create a new profile",
                        order = 3,
                        width = "full",
                        get = function() 
                            -- Store in both places to prevent clearing
                            if not MidnightUI.importNewProfileName then
                                MidnightUI.importNewProfileName = ""
                            end
                            return MidnightUI.importNewProfileName 
                        end,
                        set = function(_, v) 
                            MidnightUI.importNewProfileName = v 
                        end,
                    },
                    warning = {
                        type = "description",
                        name = function()
                            local name = MidnightUI.importNewProfileName
                            if name and name ~= "" then
                                return "|cff00ff00Profile will be imported as: '|r" .. name .. "|cff00ff00'|r"
                            else
                                local currentProfile = MidnightUI.db and MidnightUI.db:GetCurrentProfile() or "Default"
                                return "|cffff8800WARNING: This will overwrite your current profile '|r" .. currentProfile .. "|cffff8800'|r"
                            end
                        end,
                        order = 3.5,
                        fontSize = "medium",
                    },
                    importString = {
                        type = "input",
                        name = "Import String",
                        desc = "Paste the export string here (Ctrl+V to paste)\n|cffaaaaaa" .. (MidnightUI.importString and "Current length: " .. #MidnightUI.importString .. " characters" or "") .. "|r",
                        order = 4,
                        width = "full",
                        multiline = 20,
                        get = function() 
                            if not MidnightUI.importString then
                                MidnightUI.importString = ""
                            end
                            return MidnightUI.importString 
                        end,
                        set = function(_, v) 
                            -- Store the full string value
                            MidnightUI.importString = v
                            -- Delayed refresh to avoid interrupting the input
                            C_Timer.After(0.1, function()
                                
                            end)
                        end,
                    },
                    stringInfo = {
                        type = "description",
                        name = function()
                            local str = MidnightUI.importString
                            if str and #str > 0 then
                                return "|cffaaaaaa" .. #str .. " characters stored|r"
                            else
                                return ""
                            end
                        end,
                        order = 4.5,
                        fontSize = "small",
                    },
                    importButton = {
                        type = "execute",
                        name = "Import Profile",
                        desc = "Import the profile from the string above. Requires UI reload.",
                        order = 5,
                        func = function()
                            MidnightUI:ImportProfile()
                        end,
                    },
                },
            },
            -- Note: Profile management disabled - using custom options panel
            -- profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
        }  -- closes main args table
    }  -- closes options table
    
    -- options.args.profiles.order = 100
    
    -- Inject Module Options
    for name, module in self:IterateModules() do
        -- Map module names to their database keys
        local dbKey = name
        if name == "UIButtons" then 
            dbKey = "UIButtons"
        elseif name == "Skin" then
            dbKey = "skins"
        elseif name == "BrokerBar" then
            dbKey = "bar"
        elseif name == "Maps" then
            dbKey = "maps"
        elseif name == "ActionBars" then
            dbKey = "actionbars"
        elseif name == "UnitFrames" then
            dbKey = "unitframes"
        elseif name == "CooldownManager" then
            dbKey = "cooldowns"
        elseif name == "Tweaks" then
            dbKey = "tweaks"
        elseif name == "Setup" then
            dbKey = "setup"
        elseif name == "ResourceBars" then
            dbKey = "resourceBars"
        elseif name == "CastBar" then
            dbKey = "castBar"
        else
            dbKey = string.lower(name)
        end
        
        if module.GetOptions and self.db.profile.modules[dbKey] then
            local displayName = name
            if name == "UIButtons" then 
                displayName = "UI Buttons"
            elseif name == "Skin" then
                displayName = "Skinning"
            elseif name == "BrokerBar" then 
                displayName = "Data Brokers"
            elseif name == "CooldownManager" then
                displayName = "Cooldown Manager"
            end
            if name == "UnitFrames" then
                options.args.unitframes = module:GetOptions()
                options.args.unitframes.name = "Unit Frames"
                options.args.unitframes.order = 8
            elseif name == "Setup" then
                options.args[name] = module:GetOptions()
                options.args[name].name = displayName
                options.args[name].order = 45
            else
                options.args[name] = module:GetOptions()
                options.args[name].name = displayName
                options.args[name].order = 10
            end
        end
    end
    
    return options
end

-- Add Move Mode property
MidnightUI.moveMode = false

-- Add Move Mode toggle function
function MidnightUI:ToggleMoveMode()
    self.moveMode = not self.moveMode
    
    if self.moveMode then
        print("|cff00ff00MidnightUI:|r Move Mode |cff00ff00ENABLED|r - Hover over elements to move them")
    else
        print("|cff00ff00MidnightUI:|r Move Mode |cffff0000DISABLED|r")
    end
    
    -- Use AceEvent's SendMessage (already loaded)
    self:SendMessage("MIDNIGHTUI_MOVEMODE_CHANGED", self.moveMode)
    -- Directly call Movable:OnMoveModeChanged for reliability
    local Movable
    if self.GetModule then
        Movable = self:GetModule("Movable", true)
    end
    if Movable and Movable.OnMoveModeChanged then
        Movable:OnMoveModeChanged("MIDNIGHTUI_MOVEMODE_CHANGED", self.moveMode)
    end
    
end

-- ============================================================================
-- 5. IMPORT/EXPORT FUNCTIONS
-- ============================================================================

-- Hex encoding functions (safe for copy/paste)
local function EncodeHex(str)
    return (str:gsub('.', function(c)
        return string.format('%02X', string.byte(c))
    end))
end

local function DecodeHex(hex)
    return (hex:gsub('..', function(cc)
        return string.char(tonumber(cc, 16))
    end))
end

-- Export Profile
function MidnightUI:ExportProfile()
    local AceSerializer = LibStub("AceSerializer-3.0")
    local LibCompress = LibStub("LibCompress")
    
    if not AceSerializer or not LibCompress then
        print("|cffff0000MidnightUI Error:|r Required libraries not found for export.")
        return
    end
    
    -- Get the entire database including all namespaces
    local exportData = {
        main = self.db.profile,
        namespaces = {}
    }
    
    -- Export all registered namespaces
    -- Use the children table which contains the actual namespace objects
    if self.db.children then
        local namespaceCount = 0
        
        for namespaceName, namespaceDB in pairs(self.db.children) do
            if namespaceDB and namespaceDB.profile then
                exportData.namespaces[namespaceName] = namespaceDB.profile
                namespaceCount = namespaceCount + 1
                print("|cff00ff00MidnightUI:|r   - Exporting: " .. namespaceName)
            end
        end
        print("|cff00ff00MidnightUI:|r Exported " .. namespaceCount .. " module namespaces")
    else
        print("|cffff8800MidnightUI Warning:|r No namespace objects found to export")
    end
    
    -- Serialize the data
    local serialized = AceSerializer:Serialize(exportData)
    
    -- Compress the serialized data
    local compressed = LibCompress:Compress(serialized)
    if not compressed then
        print("|cffff0000MidnightUI Error:|r Failed to compress export data.")
        return
    end
    
    -- Encode to hex (safe for copy/paste)
    local encoded = EncodeHex(compressed)
    
    -- Add version header
    local exportString = "MUIV2:" .. encoded
    
    -- Store for display
    self.exportString = exportString
    MidnightUI.exportString = exportString
    
    print("|cff00ff00MidnightUI:|r Export string generated!")
    print("|cff00ff00MidnightUI:|r String length: " .. #exportString .. " characters")
    print("|cff00ff00MidnightUI:|r Use Ctrl+A to select all, then Ctrl+C to copy.")
    
    -- Refresh the options UI
    
end

-- Import Profile
function MidnightUI:ImportProfile()
    local AceSerializer = LibStub("AceSerializer-3.0")
    local LibCompress = LibStub("LibCompress")
    
    if not AceSerializer or not LibCompress then
        print("|cffff0000MidnightUI Error:|r Required libraries not found for import.")
        return
    end
    
    local importString = self.importString
    
    if not importString or importString == "" then
        print("|cffff0000MidnightUI Error:|r No import string provided.")
        return
    end
    
    -- Show length for debugging
    print("|cff00ff00MidnightUI:|r Processing import string (" .. #importString .. " characters)")
    
    -- Check if user wants to create a new profile
    local newProfileName = self.importNewProfileName
    if newProfileName and newProfileName ~= "" then
        -- Trim whitespace
        newProfileName = newProfileName:match("^%s*(.-)%s*$")
    end
    
    if not newProfileName or newProfileName == "" then
        -- Show confirmation dialog before overwriting current profile
        local currentProfileName = self.db:GetCurrentProfile()
        StaticPopupDialogs["MIDNIGHTUI_IMPORT_CONFIRM"] = {
            text = "This will OVERWRITE your current profile '" .. currentProfileName .. "'!\n\nAre you sure you want to continue?",
            button1 = "Yes, Import",
            button2 = "Cancel",
            OnAccept = function()
                MidnightUI:DoImport(importString, nil)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("MIDNIGHTUI_IMPORT_CONFIRM")
    else
        -- Creating new profile - show confirmation with profile name
        StaticPopupDialogs["MIDNIGHTUI_IMPORT_NEW"] = {
            text = "This will create a new profile '" .. newProfileName .. "' and switch to it.\n\nAre you sure you want to continue?",
            button1 = "Yes, Import",
            button2 = "Cancel",
            OnAccept = function()
                MidnightUI:DoImport(importString, newProfileName)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("MIDNIGHTUI_IMPORT_NEW")
    end
end

-- Actually perform the import
function MidnightUI:DoImport(importString, newProfileName, suppressDialog)
    local AceSerializer = LibStub("AceSerializer-3.0")
    local LibCompress = LibStub("LibCompress")
    
    if not AceSerializer or not LibCompress then
        print("|cffff0000MidnightUI Error:|r Required libraries not found for import.")
        return
    end
    
    -- Check for version header
    if not importString:match("^MUIV2:") then
        print("|cffff0000MidnightUI Error:|r Invalid import string format.")
        return
    end
    
    -- Remove version header
    local encoded = importString:sub(7) -- Remove "MUIV2:"
    
    -- Decode from hex
    local success, compressed = pcall(DecodeHex, encoded)
    if not success or not compressed then
        print("|cffff0000MidnightUI Error:|r Failed to decode import string.")
        return
    end
    
    -- Decompress
    local serialized, err = LibCompress:Decompress(compressed)
    if not serialized then
        print("|cffff0000MidnightUI Error:|r Failed to decompress import data: " .. tostring(err or "unknown error"))
        return
    end
    
    -- Deserialize
    local success, exportData = AceSerializer:Deserialize(serialized)
    if not success or not exportData then
        print("|cffff0000MidnightUI Error:|r Failed to deserialize import data.")
        return
    end
    
    -- Handle old format (direct profile data) or new format (structured with namespaces)
    local profileData = exportData.main or exportData
    local namespaceData = exportData.namespaces or {}
    
    local namespaceCount = 0
    for _ in pairs(namespaceData) do
        namespaceCount = namespaceCount + 1
    end
    print("|cff00ff00MidnightUI:|r Import contains " .. namespaceCount .. " module namespaces")
    
    -- Check if user wants to create a new profile
    if newProfileName and newProfileName ~= "" then
        -- Create new profile with the imported data
        self.db:SetProfile(newProfileName)
        
        -- Apply the imported main profile data
        for key, value in pairs(profileData) do
            self.db.profile[key] = value
        end
        
        -- Apply namespace data by getting or creating namespace objects
        if self.db.children then
            local appliedCount = 0
            for namespaceName, data in pairs(namespaceData) do
                local namespace = self.db:GetNamespace(namespaceName, true)
                if namespace then
                    -- Copy all data to the namespace profile
                    for key, value in pairs(data) do
                        namespace.profile[key] = value
                    end
                    appliedCount = appliedCount + 1
                    print("|cff00ff00MidnightUI:|r   - Applied: " .. namespaceName)
                end
            end
            print("|cff00ff00MidnightUI:|r Applied " .. appliedCount .. " module namespaces")
        end
        
        print("|cff00ff00MidnightUI:|r Profile imported as '" .. newProfileName .. "'!")
    else
        -- Overwrite current profile
        local currentProfileName = self.db:GetCurrentProfile()
        
        -- Apply the imported main profile data
        for key, value in pairs(profileData) do
            self.db.profile[key] = value
        end
        
        -- Apply namespace data by getting namespace objects
        if self.db.children then
            local appliedCount = 0
            for namespaceName, data in pairs(namespaceData) do
                local namespace = self.db:GetNamespace(namespaceName, true)
                if namespace then
                    -- Copy all data to the namespace profile
                    for key, value in pairs(data) do
                        namespace.profile[key] = value
                    end
                    appliedCount = appliedCount + 1
                    print("|cff00ff00MidnightUI:|r   - Applied: " .. namespaceName)
                end
            end
            print("|cff00ff00MidnightUI:|r Applied " .. appliedCount .. " module namespaces")
        end
        
        print("|cff00ff00MidnightUI:|r Profile '" .. currentProfileName .. "' updated!")
    end
    
    -- Show reload dialog (unless suppressed by caller)
    if not suppressDialog then
        StaticPopupDialogs["MIDNIGHTUI_IMPORT_RELOAD"] = {
            text = "Profile imported successfully!\n\nReload UI now to apply changes?",
            button1 = "Reload Now",
            button2 = "Later",
            OnAccept = function()
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("MIDNIGHTUI_IMPORT_RELOAD")
    end
end

