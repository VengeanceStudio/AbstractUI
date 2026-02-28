-- MidnightUI Font Kit System
-- Font management and registration

local LSM = LibStub("LibSharedMedia-3.0")
local FontKit = {}
_G.MidnightUI_FontKit = FontKit

-- Font definitions per theme
FontKit.fonts = {}
FontKit.activeTheme = "MidnightGlass"

-- Font size scale
FontKit.sizes = {
    tiny = 10,
    small = 12,
    normal = 14,
    medium = 16,
    large = 18,
    huge = 24,
    massive = 32,
}

-- ============================================================================
-- FONT REGISTRATION
-- ============================================================================

function FontKit:RegisterThemeFonts(themeName, fonts)
    self.fonts[themeName] = fonts
end

-- ============================================================================
-- FONT RETRIEVAL
-- ============================================================================

-- Get font path for theme and type
function FontKit:GetFont(fontType)
    local theme = self.fonts[self.activeTheme]
    if not theme or not theme[fontType] then
        -- Fallback to default WoW font
        return "Fonts\\FRIZQT__.TTF"
    end
    
    -- Check if it's a LSM registered font
    local fontName = theme[fontType]
    if LSM:IsValid("font", fontName) then
        return LSM:Fetch("font", fontName)
    end
    
    -- Return as path
    return fontName
end

-- Get font size
function FontKit:GetSize(sizeName)
    return self.sizes[sizeName] or self.sizes.normal
end

-- ============================================================================
-- FONT APPLICATION
-- ============================================================================

-- Apply font to fontstring
function FontKit:SetFont(fontString, fontType, sizeName, flags)
    if not fontString then return false end
    
    local path = self:GetFont(fontType)
    local size = self:GetSize(sizeName or "normal")
    local outline = flags or "OUTLINE"
    
    fontString:SetFont(path, size, outline)
    return true
end

-- Apply font with custom size
function FontKit:SetFontCustomSize(fontString, fontType, customSize, flags)
    if not fontString then return false end
    
    local path = self:GetFont(fontType)
    local outline = flags or "OUTLINE"
    
    fontString:SetFont(path, customSize, outline)
    return true
end

-- ============================================================================
-- THEME MANAGEMENT
-- ============================================================================

function FontKit:SetActiveTheme(themeName)
    if self.fonts[themeName] then
        self.activeTheme = themeName
        return true
    end
    return false
end

function FontKit:GetActiveTheme()
    return self.activeTheme
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Create a fontstring with theme font applied
function FontKit:CreateFontString(parent, fontType, sizeName, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    self:SetFont(fs, fontType, sizeName, flags)
    return fs
end

-- Get font info as table
function FontKit:GetFontInfo(fontType, sizeName)
    return {
        path = self:GetFont(fontType),
        size = self:GetSize(sizeName or "normal"),
        theme = self.activeTheme,
    }
end

return FontKit
