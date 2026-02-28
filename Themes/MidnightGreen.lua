-- MidnightUI Theme: Midnight Green
-- Dark Matrix-inspired theme with black, dark grey, and bright green accents

local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

-- ============================================================================
-- COLOR PALETTE
-- ============================================================================

ColorPalette:RegisterPalette("MidnightGreen", {
    -- Core UI Colors (8 main colors for theme editor)
    ["panel-bg"] = {r = 0.05, g = 0.05, b = 0.05, a = 0.95},       -- Almost black
    ["panel-border"] = {r = 0.0, g = 1.0, b = 0.0, a = 0.9},       -- Bright green
    ["accent-primary"] = {r = 0.0, g = 1.0, b = 0.0, a = 1.0},     -- Bright green
    ["button-bg"] = {r = 0.10, g = 0.10, b = 0.10, a = 0.9},       -- Dark grey
    ["button-hover"] = {r = 0.0, g = 0.6, b = 0.0, a = 0.95},      -- Dark green
    ["text-primary"] = {r = 0.0, g = 1.0, b = 0.0, a = 1.0},       -- Bright green
    ["text-secondary"] = {r = 0.6, g = 0.8, b = 0.6, a = 1.0},     -- Light green-grey
    ["tab-active"] = {r = 0.0, g = 0.6, b = 0.0, a = 0.95},        -- Dark green
    
    -- Extended colors for full UI coverage
    ["primary"] = {r = 0.0, g = 1.0, b = 0.0, a = 1.0},            -- Bright green
    ["secondary"] = {r = 0.15, g = 0.15, b = 0.15, a = 1.0},       -- Dark grey
    ["accent"] = {r = 0.0, g = 0.8, b = 0.0, a = 1.0},             -- Medium green
    
    -- Background colors
    ["bg-primary"] = {r = 0.05, g = 0.05, b = 0.05, a = 0.95},     -- Almost black
    ["bg-secondary"] = {r = 0.08, g = 0.08, b = 0.08, a = 0.9},    -- Very dark grey
    ["bg-tertiary"] = {r = 0.12, g = 0.12, b = 0.12, a = 0.85},    -- Dark grey
    
    -- Text colors
    ["text-muted"] = {r = 0.4, g = 0.6, b = 0.4, a = 1.0},         -- Muted green
    ["text-disabled"] = {r = 0.25, g = 0.35, b = 0.25, a = 1.0},   -- Very dark green
    
    -- Component colors
    ["button-pressed"] = {r = 0.0, g = 1.0, b = 0.0, a = 1.0},     -- Bright green
    ["button-disabled"] = {r = 0.05, g = 0.05, b = 0.05, a = 0.5},
    
    -- Toggle switch colors
    ["toggle-off-bg"] = {r = 0.02, g = 0.05, b = 0.02, a = 1.0},
    ["toggle-off-border"] = {r = 0.25, g = 0.35, b = 0.25, a = 0.8},
    
    ["tab-inactive"] = {r = 0.10, g = 0.10, b = 0.10, a = 0.8},
    ["tab-selected-bg"] = {r = 0.0, g = 0.6, b = 0.0, a = 0.95},
    
    -- Status colors
    ["success"] = {r = 0.0, g = 1.0, b = 0.0, a = 1.0},            -- Bright green
    ["warning"] = {r = 0.8, g = 0.8, b = 0.0, a = 1.0},            -- Yellow
    ["error"] = {r = 0.8, g = 0.0, b = 0.0, a = 1.0},              -- Red
    ["info"] = {r = 0.0, g = 0.8, b = 0.0, a = 1.0},               -- Green
    
    -- Special elements
    ["border-active"] = {r = 0.0, g = 1.0, b = 0.0, a = 1.0},      -- Bright green
    ["border-inactive"] = {r = 0.15, g = 0.15, b = 0.15, a = 0.8},
    ["border-hover"] = {r = 0.0, g = 0.8, b = 0.0, a = 0.9},       -- Medium green
    
    -- Shadow and glow
    ["shadow"] = {r = 0.0, g = 0.0, b = 0.0, a = 0.7},
    ["glow-primary"] = {r = 0.0, g = 1.0, b = 0.0, a = 0.6},       -- Green glow
    ["glow-secondary"] = {r = 0.0, g = 0.6, b = 0.0, a = 0.4},     -- Darker green glow
    
    -- Tooltip colors
    ["tooltip-bg"] = {r = 0.0, g = 0.0, b = 0.0, a = 0.95},
    ["tooltip-border"] = {r = 0.0, g = 1.0, b = 0.0, a = 1.0},
})

-- ============================================================================
-- FONT DEFINITIONS
-- ============================================================================

-- This theme uses the default font definitions
-- The Matrix aesthetic works well with clean, monospaced-looking fonts
