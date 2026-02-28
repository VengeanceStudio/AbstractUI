-- MidnightUI Theme: MidnightUI Default
-- Based on the iconic MidnightUI logo gradient colors

local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

-- ============================================================================
-- COLOR PALETTE
-- ============================================================================

ColorPalette:RegisterPalette("MidnightUIDefault", {
    -- Core UI Colors (8 main colors for theme editor)
    ["panel-bg"] = {r = 0.10, g = 0.10, b = 0.18, a = 0.95},      -- Deep navy background
    ["panel-border"] = {r = 0.0, g = 0.83, b = 1.0, a = 0.9},     -- Cyan blue accent
    ["accent-primary"] = {r = 1.0, g = 0.0, b = 0.6, a = 1.0},    -- Hot pink/magenta
    ["button-bg"] = {r = 0.15, g = 0.15, b = 0.25, a = 0.9},      -- Slightly lighter navy
    ["button-hover"] = {r = 0.42, g = 0.31, b = 0.88, a = 0.95},  -- Purple-blue
    ["text-primary"] = {r = 1.0, g = 1.0, b = 1.0, a = 1.0},      -- White
    ["text-secondary"] = {r = 0.75, g = 0.75, b = 0.85, a = 1.0}, -- Light gray
    ["tab-active"] = {r = 0.42, g = 0.31, b = 0.88, a = 0.95},    -- Purple-blue
    
    -- Extended colors for full UI coverage
    ["primary"] = {r = 1.0, g = 0.0, b = 0.6, a = 1.0},           -- Hot pink (signature)
    ["secondary"] = {r = 0.42, g = 0.31, b = 0.88, a = 1.0},      -- Purple-blue
    ["accent"] = {r = 0.0, g = 0.83, b = 1.0, a = 1.0},           -- Cyan
    
    -- Background colors
    ["bg-primary"] = {r = 0.10, g = 0.10, b = 0.18, a = 0.95},
    ["bg-secondary"] = {r = 0.12, g = 0.12, b = 0.20, a = 0.9},
    ["bg-tertiary"] = {r = 0.15, g = 0.15, b = 0.25, a = 0.85},
    
    -- Text colors
    ["text-muted"] = {r = 0.55, g = 0.55, b = 0.65, a = 1.0},
    ["text-disabled"] = {r = 0.35, g = 0.35, b = 0.45, a = 1.0},
    
    -- Component colors
    ["button-pressed"] = {r = 1.0, g = 0.0, b = 0.6, a = 1.0},    -- Pink when pressed
    ["button-disabled"] = {r = 0.08, g = 0.08, b = 0.15, a = 0.5},
    
    -- Toggle switch colors
    ["toggle-off-bg"] = {r = 0.03, g = 0.03, b = 0.08, a = 1.0},
    ["toggle-off-border"] = {r = 0.28, g = 0.28, b = 0.38, a = 0.8},
    
    ["tab-inactive"] = {r = 0.12, g = 0.12, b = 0.20, a = 0.8},
    ["tab-selected-bg"] = {r = 0.42, g = 0.31, b = 0.88, a = 0.95},
    
    -- Gradient accents (for special highlights)
    ["gradient-start"] = {r = 1.0, g = 0.0, b = 0.6, a = 1.0},    -- Pink
    ["gradient-mid"] = {r = 0.42, g = 0.31, b = 0.88, a = 1.0},   -- Purple
    ["gradient-end"] = {r = 0.0, g = 0.83, b = 1.0, a = 1.0},     -- Cyan
    
    -- Status colors
    ["success"] = {r = 0.0, g = 0.83, b = 1.0, a = 1.0},
    ["warning"] = {r = 1.0, g = 0.65, b = 0.0, a = 1.0},
    ["error"] = {r = 1.0, g = 0.2, b = 0.4, a = 1.0},
    ["info"] = {r = 0.42, g = 0.31, b = 0.88, a = 1.0},
    
    -- Special elements
    ["border-active"] = {r = 1.0, g = 0.0, b = 0.6, a = 1.0},     -- Pink highlight
    ["border-inactive"] = {r = 0.2, g = 0.2, b = 0.35, a = 0.8},
    ["border-hover"] = {r = 0.0, g = 0.83, b = 1.0, a = 0.9},     -- Cyan highlight
    
    -- Tooltip
    ["tooltip-bg"] = {r = 0.08, g = 0.05, b = 0.15, a = 0.95},
    
    -- Shadow and glow
    ["shadow"] = {r = 0.0, g = 0.0, b = 0.0, a = 0.5},
    ["glow-pink"] = {r = 1.0, g = 0.0, b = 0.6, a = 0.6},
    ["glow-cyan"] = {r = 0.0, g = 0.83, b = 1.0, a = 0.6},
    ["glow-purple"] = {r = 0.42, g = 0.31, b = 0.88, a = 0.6},
})

-- ============================================================================
-- FONT DEFINITIONS
-- ============================================================================

-- This theme uses the default font definitions
-- Custom fonts can be registered here if needed
