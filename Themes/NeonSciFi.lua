-- MidnightUI Theme: Neon Sci-Fi
-- Bright neon accents with holographic effects and futuristic styling

local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

-- ============================================================================
-- COLOR PALETTE
-- ============================================================================

ColorPalette:RegisterPalette("NeonSciFi", {
    -- Primary neon colors
    ["primary"] = {r = 0.0, g = 1.0, b = 1.0, a = 1.0},           -- Cyan neon
    ["secondary"] = {r = 1.0, g = 0.0, b = 1.0, a = 1.0},         -- Magenta neon
    ["accent"] = {r = 0.0, g = 1.0, b = 0.5, a = 1.0},            -- Green neon
    
    -- Background colors (darker for contrast)
    ["bg-primary"] = {r = 0.0, g = 0.0, b = 0.05, a = 0.95},      -- Very dark blue
    ["bg-secondary"] = {r = 0.05, g = 0.0, b = 0.1, a = 0.9},     -- Dark purple-blue
    ["bg-tertiary"] = {r = 0.1, g = 0.05, b = 0.15, a = 0.85},    -- Medium purple
    
    -- Holographic effects
    ["holo-cyan"] = {r = 0.0, g = 1.0, b = 1.0, a = 0.3},
    ["holo-magenta"] = {r = 1.0, g = 0.0, b = 1.0, a = 0.3},
    ["holo-green"] = {r = 0.0, g = 1.0, b = 0.5, a = 0.3},
    
    -- Text colors (bright for readability)
    ["text-primary"] = {r = 0.0, g = 1.0, b = 1.0, a = 1.0},      -- Cyan
    ["text-secondary"] = {r = 0.8, g = 0.9, b = 1.0, a = 1.0},    -- Light cyan
    ["text-muted"] = {r = 0.5, g = 0.7, b = 0.8, a = 1.0},        -- Muted cyan
    ["text-disabled"] = {r = 0.3, g = 0.3, b = 0.4, a = 1.0},     -- Dark gray
    
    -- Component colors
    ["button-bg"] = {r = 0.05, g = 0.0, b = 0.1, a = 0.9},
    ["button-hover"] = {r = 0.1, g = 0.5, b = 0.6, a = 0.95},
    ["button-pressed"] = {r = 0.0, g = 0.8, b = 1.0, a = 1.0},
    ["button-disabled"] = {r = 0.02, g = 0.02, b = 0.05, a = 0.5},
    
    -- Toggle switch colors
    ["toggle-off-bg"] = {r = 0.02, g = 0.02, b = 0.08, a = 1.0},
    ["toggle-off-border"] = {r = 0.15, g = 0.40, b = 0.45, a = 0.8},
    
    ["panel-bg"] = {r = 0.0, g = 0.0, b = 0.05, a = 0.95},
    ["panel-border"] = {r = 0.0, g = 1.0, b = 1.0, a = 0.8},      -- Neon cyan border
    
    ["tab-inactive"] = {r = 0.05, g = 0.0, b = 0.1, a = 0.8},
    ["tab-active"] = {r = 0.1, g = 0.5, b = 0.6, a = 0.95},
    
    ["scrollbar-track"] = {r = 0.0, g = 0.0, b = 0.05, a = 0.7},
    ["scrollbar-thumb"] = {r = 0.0, g = 1.0, b = 1.0, a = 0.9},
    
    ["tooltip-bg"] = {r = 0.0, g = 0.0, b = 0.1, a = 0.98},
    ["tooltip-border"] = {r = 0.0, g = 1.0, b = 1.0, a = 0.9},
    
    -- Glow effects
    ["glow-cyan"] = {r = 0.0, g = 1.0, b = 1.0, a = 0.6},
    ["glow-magenta"] = {r = 1.0, g = 0.0, b = 1.0, a = 0.6},
    ["glow-green"] = {r = 0.0, g = 1.0, b = 0.5, a = 0.6},
    ["glow-white"] = {r = 1.0, g = 1.0, b = 1.0, a = 0.4},
    
    -- Status colors (extra bright for sci-fi feel)
    ["success"] = {r = 0.0, g = 1.0, b = 0.5, a = 1.0},
    ["warning"] = {r = 1.0, g = 1.0, b = 0.0, a = 1.0},
    ["error"] = {r = 1.0, g = 0.0, b = 0.5, a = 1.0},
    ["info"] = {r = 0.0, g = 1.0, b = 1.0, a = 1.0},
})

-- ============================================================================
-- FONT KIT
-- ============================================================================

FontKit:RegisterThemeFonts("NeonSciFi", {
    ["title"] = "Friz Quadrata TT",        -- Large headers
    ["heading"] = "Friz Quadrata TT",      -- Section headers
    ["body"] = "Friz Quadrata TT",         -- Body text
    ["button"] = "Friz Quadrata TT",       -- Button text
    ["tab"] = "Friz Quadrata TT",          -- Tab labels
    ["tooltip"] = "Friz Quadrata TT",      -- Tooltip text
    ["number"] = "Friz Quadrata TT",       -- Numeric displays
})

-- Theme loaded
