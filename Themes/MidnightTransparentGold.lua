-- MidnightUI Theme: Midnight Transparent Gold
-- High transparency theme with deep blacks and warm gold/brown accents

local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

-- ============================================================================
-- COLOR PALETTE
-- ============================================================================

ColorPalette:RegisterPalette("MidnightTransparentGold", {
    -- Core UI Colors (8 main colors for theme editor)
    ["panel-bg"] = {r = 0.08, g = 0.06, b = 0.04, a = 0.65},       -- Very transparent black-brown
    ["panel-border"] = {r = 0.60, g = 0.45, b = 0.20, a = 0.70},   -- Gold/bronze
    ["accent-primary"] = {r = 0.80, g = 0.60, b = 0.20, a = 0.85}, -- Bright gold
    ["button-bg"] = {r = 0.10, g = 0.08, b = 0.06, a = 0.60},      -- Transparent dark brown-black
    ["button-hover"] = {r = 0.50, g = 0.38, b = 0.15, a = 0.75},   -- Medium gold
    ["text-primary"] = {r = 0.95, g = 0.85, b = 0.65, a = 1.0},    -- Warm white-gold
    ["text-secondary"] = {r = 0.75, g = 0.65, b = 0.50, a = 0.95}, -- Soft gold-grey
    ["tab-active"] = {r = 0.50, g = 0.38, b = 0.15, a = 0.75},     -- Medium gold
    
    -- Extended colors for full UI coverage
    ["primary"] = {r = 0.80, g = 0.60, b = 0.20, a = 0.85},        -- Bright gold
    ["secondary"] = {r = 0.12, g = 0.10, b = 0.08, a = 0.65},      -- Dark transparent brown
    ["accent"] = {r = 0.60, g = 0.45, b = 0.20, a = 0.80},         -- Gold accent
    
    -- Background colors (high transparency)
    ["bg-primary"] = {r = 0.08, g = 0.06, b = 0.04, a = 0.65},     -- Very transparent
    ["bg-secondary"] = {r = 0.10, g = 0.08, b = 0.06, a = 0.60},   -- Even more transparent
    ["bg-tertiary"] = {r = 0.12, g = 0.10, b = 0.08, a = 0.55},    -- Very transparent
    
    -- Text colors
    ["text-muted"] = {r = 0.60, g = 0.52, b = 0.40, a = 0.90},     -- Muted gold
    ["text-disabled"] = {r = 0.40, g = 0.35, b = 0.28, a = 0.70},  -- Dark muted gold
    
    -- Component colors
    ["button-pressed"] = {r = 0.80, g = 0.60, b = 0.20, a = 0.90}, -- Bright gold
    ["button-disabled"] = {r = 0.08, g = 0.06, b = 0.04, a = 0.40},
    
    -- Toggle switch colors
    ["toggle-off-bg"] = {r = 0.05, g = 0.04, b = 0.02, a = 1.0},
    ["toggle-off-border"] = {r = 0.35, g = 0.30, b = 0.20, a = 0.8},
    
    ["tab-inactive"] = {r = 0.10, g = 0.08, b = 0.06, a = 0.55},
    ["tab-selected-bg"] = {r = 0.50, g = 0.38, b = 0.15, a = 0.75},
    
    -- Status colors
    ["success"] = {r = 0.60, g = 0.80, b = 0.20, a = 0.85},        -- Yellow-green
    ["warning"] = {r = 0.90, g = 0.70, b = 0.20, a = 0.85},        -- Orange-gold
    ["error"] = {r = 0.90, g = 0.30, b = 0.20, a = 0.85},          -- Red-orange
    ["info"] = {r = 0.60, g = 0.45, b = 0.20, a = 0.85},           -- Gold
    
    -- Special elements
    ["border-active"] = {r = 0.80, g = 0.60, b = 0.20, a = 0.85},  -- Bright gold
    ["border-inactive"] = {r = 0.25, g = 0.20, b = 0.15, a = 0.60},
    ["border-hover"] = {r = 0.70, g = 0.53, b = 0.20, a = 0.80},   -- Medium gold
    
    -- Shadow and glow (very subtle for transparency theme)
    ["shadow"] = {r = 0.0, g = 0.0, b = 0.0, a = 0.4},
    ["glow-primary"] = {r = 0.80, g = 0.60, b = 0.20, a = 0.50},   -- Gold glow
    ["glow-secondary"] = {r = 0.60, g = 0.45, b = 0.20, a = 0.35}, -- Subtle gold glow
    
    -- Tooltip colors
    ["tooltip-bg"] = {r = 0.05, g = 0.04, b = 0.03, a = 0.75},     -- Transparent dark
    ["tooltip-border"] = {r = 0.60, g = 0.45, b = 0.20, a = 0.80},
})

-- ============================================================================
-- FONT DEFINITIONS
-- ============================================================================

-- This theme uses the default font definitions
-- The warm, transparent aesthetic pairs well with elegant serif or script fonts
