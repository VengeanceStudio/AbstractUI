-- MidnightUI Theme: Midnight Warrior
-- Based on Midnight Transparent with Warrior class color text (#C79C6E)

local ColorPalette = _G.MidnightUI_ColorPalette
local FontKit = _G.MidnightUI_FontKit

if not ColorPalette or not FontKit then return end

-- ============================================================================
-- COLOR PALETTE
-- ============================================================================

ColorPalette:RegisterPalette("MidnightWarrior", {
    -- Core UI Colors (8 main colors for theme editor)
    ["panel-bg"] = {r = 0.05, g = 0.05, b = 0.05, a = 0.65},       -- Very transparent black (from Transparent)
    ["panel-border"] = {r = 0.235, g = 0.184, b = 0.129, a = 0.90}, -- Dark Warrior tan (#3C2F21)
    ["accent-primary"] = {r = 0.55, g = 0.60, b = 0.70, a = 0.85}, -- Steel blue-grey (from Transparent)
    ["button-bg"] = {r = 0.08, g = 0.08, b = 0.10, a = 0.60},      -- Transparent dark charcoal
    ["button-hover"] = {r = 0.40, g = 0.42, b = 0.48, a = 0.75},   -- Medium grey-blue
    ["text-primary"] = {r = 0.780, g = 0.612, b = 0.431, a = 1.0}, -- Warrior class color (#C79C6E)
    ["text-secondary"] = {r = 0.70, g = 0.70, b = 0.75, a = 0.95}, -- Light grey (from Transparent)
    ["tab-active"] = {r = 0.40, g = 0.42, b = 0.48, a = 0.75},     -- Medium grey-blue
    
    -- Extended colors for full UI coverage
    ["primary"] = {r = 0.55, g = 0.60, b = 0.70, a = 0.85},        -- Steel blue-grey (from Transparent)
    ["secondary"] = {r = 0.10, g = 0.10, b = 0.12, a = 0.65},      -- Dark transparent charcoal
    ["accent"] = {r = 0.45, g = 0.48, b = 0.55, a = 0.80},         -- Grey-blue accent (from Transparent)
    
    -- Background colors (high transparency)
    ["bg-primary"] = {r = 0.05, g = 0.05, b = 0.05, a = 0.65},     -- Very transparent black
    ["bg-secondary"] = {r = 0.08, g = 0.08, b = 0.10, a = 0.60},   -- Even more transparent
    ["bg-tertiary"] = {r = 0.10, g = 0.10, b = 0.12, a = 0.55},    -- Very transparent charcoal
    
    -- Text colors
    ["text-muted"] = {r = 0.55, g = 0.55, b = 0.60, a = 0.90},     -- Muted grey (from Transparent)
    ["text-disabled"] = {r = 0.35, g = 0.35, b = 0.40, a = 0.70},  -- Dark muted grey (from Transparent)
    
    -- Component colors
    ["button-pressed"] = {r = 0.60, g = 0.65, b = 0.75, a = 0.90}, -- Bright steel blue (from Transparent)
    ["button-disabled"] = {r = 0.05, g = 0.05, b = 0.05, a = 0.40},
    
    -- Toggle switch colors
    ["toggle-off-bg"] = {r = 0.05, g = 0.03, b = 0.02, a = 1.0},
    ["toggle-off-border"] = {r = 0.35, g = 0.25, b = 0.20, a = 0.8},
    
    ["tab-inactive"] = {r = 0.08, g = 0.08, b = 0.10, a = 0.55},
    ["tab-selected-bg"] = {r = 0.40, g = 0.42, b = 0.48, a = 0.75},
    
    -- Status colors
    ["success"] = {r = 0.40, g = 0.80, b = 0.50, a = 0.85},        -- Green
    ["warning"] = {r = 0.90, g = 0.70, b = 0.30, a = 0.85},        -- Orange
    ["error"] = {r = 0.90, g = 0.30, b = 0.30, a = 0.85},          -- Red
    ["info"] = {r = 0.45, g = 0.55, b = 0.75, a = 0.85},           -- Blue-grey (from Transparent)
    
    -- Border colors
    ["border-subtle"] = {r = 0.25, g = 0.25, b = 0.28, a = 0.60},
    ["border-medium"] = {r = 0.35, g = 0.35, b = 0.40, a = 0.70},
    ["border-strong"] = {r = 0.45, g = 0.48, b = 0.55, a = 0.85},
    
    -- Tooltip colors
    ["tooltip-bg"] = {r = 0.05, g = 0.05, b = 0.05, a = 0.90},
    
    -- Shadow & highlight
    ["shadow"] = {r = 0.0, g = 0.0, b = 0.0, a = 0.70},
    ["highlight"] = {r = 0.70, g = 0.75, b = 0.85, a = 0.25},
    
    -- Selection & hover states
    ["selected-bg"] = {r = 0.40, g = 0.42, b = 0.48, a = 0.75},
    ["hover-bg"] = {r = 0.30, g = 0.32, b = 0.38, a = 0.70},
    
    -- Scrollbar & progress
    ["scrollbar-thumb"] = {r = 0.40, g = 0.42, b = 0.48, a = 0.75},
    ["scrollbar-track"] = {r = 0.08, g = 0.08, b = 0.10, a = 0.50},
    ["progress-fill"] = {r = 0.55, g = 0.60, b = 0.70, a = 0.85},
})

-- ============================================================================
-- FONT DEFINITIONS
-- ============================================================================

-- This theme uses the default font definitions
-- Custom fonts can be registered here if needed
