-- MidnightUI Theme: Midnight Dark Glass
-- Dark, translucent glass aesthetic with subtle gradients

local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

-- ============================================================================
-- COLOR PALETTE
-- ============================================================================

ColorPalette:RegisterPalette("MidnightGlass", {
    -- Primary colors
    ["primary"] = {r = 0.0, g = 0.8, b = 1.0, a = 1.0},           -- Cyan
    ["secondary"] = {r = 0.4, g = 0.4, b = 0.5, a = 1.0},         -- Gray-blue
    ["accent"] = {r = 0.0, g = 1.0, b = 0.8, a = 1.0},            -- Teal
    
    -- Background colors
    ["bg-primary"] = {r = 0.05, g = 0.05, b = 0.1, a = 0.95},     -- Very dark blue, almost black
    ["bg-secondary"] = {r = 0.1, g = 0.1, b = 0.15, a = 0.9},     -- Slightly lighter dark blue
    ["bg-tertiary"] = {r = 0.15, g = 0.15, b = 0.2, a = 0.85},    -- Medium-dark blue
    
    -- Glass effects
    ["glass-dark"] = {r = 0.05, g = 0.05, b = 0.1, a = 0.8},      -- Dark glass
    ["glass-medium"] = {r = 0.1, g = 0.1, b = 0.15, a = 0.7},     -- Medium glass
    ["glass-light"] = {r = 0.15, g = 0.15, b = 0.2, a = 0.6},     -- Light glass
    
    -- Text colors
    ["text-primary"] = {r = 1.0, g = 1.0, b = 1.0, a = 1.0},      -- White
    ["text-secondary"] = {r = 0.7, g = 0.7, b = 0.8, a = 1.0},    -- Light gray
    ["text-muted"] = {r = 0.5, g = 0.5, b = 0.6, a = 1.0},        -- Gray
    ["text-disabled"] = {r = 0.3, g = 0.3, b = 0.4, a = 1.0},     -- Dark gray
    
    -- Component colors
    ["button-bg"] = {r = 0.1, g = 0.1, b = 0.15, a = 0.9},
    ["button-hover"] = {r = 0.15, g = 0.3, b = 0.4, a = 0.95},
    ["button-pressed"] = {r = 0.0, g = 0.6, b = 0.8, a = 1.0},
    ["button-disabled"] = {r = 0.05, g = 0.05, b = 0.1, a = 0.5},
    
    -- Toggle switch colors
    ["toggle-off-bg"] = {r = 0.02, g = 0.02, b = 0.05, a = 1.0},
    ["toggle-off-border"] = {r = 0.25, g = 0.25, b = 0.35, a = 0.8},
    
    ["panel-bg"] = {r = 0.05, g = 0.05, b = 0.1, a = 0.95},
    ["panel-border"] = {r = 0.2, g = 0.4, b = 0.6, a = 0.8},
    
    ["tab-inactive"] = {r = 0.1, g = 0.1, b = 0.15, a = 0.8},
    ["tab-active"] = {r = 0.15, g = 0.3, b = 0.4, a = 0.95},
    ["tab-selected-bg"] = {r = 0.25, g = 0.4, b = 0.5, a = 0.95},  -- Brighter blue for selected tab
    
    -- Accent colors
    ["accent-primary"] = {r = 0.1608, g = 0.5216, b = 0.5804, a = 1.0},  -- Teal accent
    
    ["scrollbar-track"] = {r = 0.05, g = 0.05, b = 0.1, a = 0.7},
    ["scrollbar-thumb"] = {r = 0.2, g = 0.4, b = 0.6, a = 0.9},
    
    ["tooltip-bg"] = {r = 0.05, g = 0.05, b = 0.1, a = 0.98},
    ["tooltip-border"] = {r = 0.0, g = 0.8, b = 1.0, a = 0.6},
    
    -- Status colors
    ["success"] = {r = 0.0, g = 1.0, b = 0.5, a = 1.0},
    ["warning"] = {r = 1.0, g = 0.8, b = 0.0, a = 1.0},
    ["error"] = {r = 1.0, g = 0.2, b = 0.2, a = 1.0},
    ["info"] = {r = 0.0, g = 0.8, b = 1.0, a = 1.0},
})

-- ============================================================================
-- FONT KIT
-- ============================================================================

FontKit:RegisterThemeFonts("MidnightGlass", {
    ["title"] = "Friz Quadrata TT",        -- Large headers
    ["heading"] = "Friz Quadrata TT",      -- Section headers
    ["body"] = "Friz Quadrata TT",         -- Body text
    ["button"] = "Friz Quadrata TT",       -- Button text
    ["tab"] = "Friz Quadrata TT",          -- Tab labels
    ["tooltip"] = "Friz Quadrata TT",      -- Tooltip text
    ["number"] = "Friz Quadrata TT",       -- Numeric displays
})

-- Theme loaded
