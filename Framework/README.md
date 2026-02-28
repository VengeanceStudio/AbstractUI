# MidnightUI Framework

The MidnightUI Framework provides a complete UI component system with theme support.

## Components

### Atlas.lua
Texture atlas management system for efficient texture loading and coordinate mapping.
- Register atlas definitions with regions
- Apply textures to UI elements
- Convert pixel coordinates to texture coordinates

### ColorPalette.lua
Theme color management system with RGB/RGBA support.
- Register color palettes for themes
- Get colors by name from active theme
- Color manipulation (lighten, darken, alpha)

### FontKit.lua
Font management and application system.
- Register fonts per theme
- Predefined size scales (tiny to massive)
- Apply fonts to fontstrings with theme support

### LayoutHelper.lua
Grid system, anchoring, and responsive scaling utilities.
- Grid snapping for consistent spacing
- Standard anchor positions
- Responsive scaling based on resolution
- VBox and HBox layout containers

### FrameFactory.lua
Component factory for creating themed UI elements.
- Create buttons with hover/pressed states
- Create panels with backgrounds and borders
- Create tabs with active/inactive states
- Create scrollbars with themed track/thumb
- Create tooltips with theme styling

## Usage Example

```lua
local MidnightUI = LibStub("AceAddon-3.0"):GetAddon("MidnightUI")
local FrameFactory = MidnightUI.FrameFactory

-- Initialize after addon load
FrameFactory:Initialize()

-- Set active theme
FrameFactory:SetTheme("MidnightGlass")

-- Create a themed button
local button = FrameFactory:CreateButton(parent, 120, 32, "Click Me")
button:SetPoint("CENTER")
button:SetScript("OnClick", function()
    print("Button clicked!")
end)
```

## Theme System

Themes define:
- Color palettes (text, backgrounds, components, status)
- Font selections (title, body, button, etc.)
- Texture atlas mappings

See Themes/ directory for theme implementations.
