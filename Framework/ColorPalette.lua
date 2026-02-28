-- MidnightUI Color Palette System
-- Theme color management with RGB/RGBA support

local ColorPalette = {}
_G.MidnightUI_ColorPalette = ColorPalette

-- Active theme
ColorPalette.activeTheme = "MidnightGlass"

-- Color palette storage
ColorPalette.palettes = {}

-- Theme change callbacks
ColorPalette.callbacks = {}

-- ============================================================================
-- COLOR HELPERS
-- ============================================================================

-- Convert hex color to RGB (returns 0-1 range)
function ColorPalette:HexToRGB(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    local a = 1
    if #hex == 8 then
        a = tonumber(hex:sub(7, 8), 16) / 255
    end
    return r, g, b, a
end

-- Convert RGB to hex
function ColorPalette:RGBToHex(r, g, b, a)
    r = math.floor(r * 255)
    g = math.floor(g * 255)
    b = math.floor(b * 255)
    if a then
        a = math.floor(a * 255)
        return string.format("#%02X%02X%02X%02X", r, g, b, a)
    end
    return string.format("#%02X%02X%02X", r, g, b)
end

-- Create color table from RGB
function ColorPalette:CreateColor(r, g, b, a)
    return {r = r, g = g, b = b, a = a or 1}
end

-- ============================================================================
-- PALETTE REGISTRATION
-- ============================================================================

function ColorPalette:RegisterPalette(themeName, colors)
    self.palettes[themeName] = colors
end

-- ============================================================================
-- COLOR RETRIEVAL
-- ============================================================================

-- Get color from active theme
function ColorPalette:GetColor(colorName)
    local palette = self.palettes[self.activeTheme]
    if not palette or not palette[colorName] then
        -- Fallback to white
        return 1, 1, 1, 1
    end
    
    local color = palette[colorName]
    return color.r, color.g, color.b, color.a
end

-- Get color table from active theme
function ColorPalette:GetColorTable(colorName)
    local palette = self.palettes[self.activeTheme]
    if not palette or not palette[colorName] then
        return {r = 1, g = 1, b = 1, a = 1}
    end
    
    return palette[colorName]
end

-- Get color from specific theme
function ColorPalette:GetThemeColor(themeName, colorName)
    local palette = self.palettes[themeName]
    if not palette or not palette[colorName] then
        return 1, 1, 1, 1
    end
    
    local color = palette[colorName]
    return color.r, color.g, color.b, color.a
end

-- ============================================================================
-- THEME MANAGEMENT
-- ============================================================================

function ColorPalette:SetActiveTheme(themeName)
    if self.palettes[themeName] then
        self.activeTheme = themeName
        -- Fire theme change callbacks
        for _, callback in ipairs(self.callbacks) do
            callback(themeName)
        end
        return true
    end
    return false
end

function ColorPalette:GetActiveTheme()
    return self.activeTheme
end

function ColorPalette:RegisterCallback(callback)
    table.insert(self.callbacks, callback)
end

function ColorPalette:GetAvailableThemes()
    local themes = {}
    for theme in pairs(self.palettes) do
        table.insert(themes, theme)
    end
    return themes
end

-- ============================================================================
-- COLOR OPERATIONS
-- ============================================================================

-- Lighten color by percentage (0-1)
function ColorPalette:Lighten(colorName, percent)
    local r, g, b, a = self:GetColor(colorName)
    local amount = 1 + percent
    return math.min(r * amount, 1), math.min(g * amount, 1), math.min(b * amount, 1), a
end

-- Darken color by percentage (0-1)
function ColorPalette:Darken(colorName, percent)
    local r, g, b, a = self:GetColor(colorName)
    local amount = 1 - percent
    return r * amount, g * amount, b * amount, a
end

-- Set alpha for a color
function ColorPalette:WithAlpha(colorName, alpha)
    local r, g, b = self:GetColor(colorName)
    return r, g, b, alpha
end

return ColorPalette
