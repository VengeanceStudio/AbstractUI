# AbstractUI Framework Architecture

Complete framework implementation for texture atlas, UI component factory, and theme system.

## Structure

```
Framework/
├── Atlas.lua           - Texture atlas management and coordinate mapping
├── ColorPalette.lua    - Theme color system with RGB/RGBA support
├── FontKit.lua         - Font management and application
├── LayoutHelper.lua    - Grid system, anchoring, responsive scaling
├── FrameFactory.lua    - Component factory (buttons, panels, tabs, scrollbars, tooltips)
└── README.md           - Framework documentation

Themes/
├── AbstractGlass.lua   - Abstract Dark Glass theme
├── NeonSciFi.lua       - Neon Sci-Fi theme
└── README.md           - Theme documentation

Media/Textures/Atlas/
├── Common.tga          - Shared UI elements (to be created)
├── AbstractGlass.tga   - Dark glass theme textures (to be created)
├── NeonSciFi.tga       - Neon sci-fi theme textures (to be created)
└── README.md           - Atlas documentation
```

## Features Implemented

### Atlas System
- Texture coordinate mapping for efficient atlas usage
- Multiple atlas support (Common, AbstractGlass, NeonSciFi)
- Pixel-to-texcoord conversion helpers
- Texture preloading system
- Region-based texture application

### Color Palette System
- Theme-based color management
- Hex-to-RGB conversion
- Color manipulation (lighten, darken, alpha)
- Multi-theme support with active theme switching
- Comprehensive color definitions for all UI components

### Font Kit System
- Theme-specific font selections
- Predefined size scales (tiny, small, normal, medium, large, huge, massive)
- LibSharedMedia-3.0 integration
- Font application helpers
- Custom size support

### Layout Helper System
- 8-pixel grid system with snap-to-grid
- Standard anchor positions (9 cardinal points)
- Responsive scaling based on resolution (reference: 2133x1200)
- VBox and HBox layout containers
- Fill parent and centering utilities
- Margin and padding management

### Frame Factory System
- **Buttons**: Normal, hover, pressed, disabled states with theme textures
- **Panels**: Background and border with theme styling
- **Tabs**: Active/inactive states with text color switching
- **Scrollbars**: Track and thumb with theme textures
- **Tooltips**: Themed backgrounds with custom font application
- Theme switching capability

## Themes

### Abstract Dark Glass
- **Visual Style**: Dark, translucent glass with subtle gradients
- **Primary Color**: Cyan (#00CCFF)
- **Background**: Very dark blue (RGB: 12, 12, 25)
- **Transparency**: High (90-95% opacity)
- **Best For**: Clean, professional, minimal distraction

### Neon Sci-Fi
- **Visual Style**: High-contrast neon with glowing effects
- **Primary Color**: Cyan neon (#00FFFF)
- **Background**: Deep black-blue (RGB: 0, 0, 12)
- **Effects**: Holographic overlays, glow effects
- **Best For**: Cyberpunk aesthetic, high visibility

## Integration

The framework is loaded in [AbstractUI.toc](AbstractUI.toc) before the core engine and modules:

```
Framework\Atlas.lua
Framework\ColorPalette.lua
Framework\FontKit.lua
Framework\LayoutHelper.lua
Framework\FrameFactory.lua
Themes\AbstractGlass.lua
Themes\NeonSciFi.lua
```

FrameFactory is initialized in [Core.lua](Core.lua) during addon OnEnable.

## Usage Example

```lua
local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local FrameFactory = AbstractUI.FrameFactory
local ColorPalette = AbstractUI.ColorPalette
local LayoutHelper = AbstractUI.LayoutHelper

-- Set theme
FrameFactory:SetTheme("AbstractGlass")

-- Create themed button
local button = FrameFactory:CreateButton(parent, 120, 32, "My Button")
LayoutHelper:SetAnchor(button, "CENTER", parent)

-- Get theme color
local r, g, b, a = ColorPalette:GetColor("primary")

-- Create panel with layout
local panel = FrameFactory:CreatePanel(parent, 400, 300)
local vbox = LayoutHelper:CreateVBox(panel, 8)
vbox:Add(button, 32)
```

## Next Steps

1. **Create Texture Atlases**: Design and create .tga files for Common, AbstractGlass, and NeonSciFi atlases
2. **Integrate with Existing Modules**: Update existing modules to use FrameFactory instead of raw CreateFrame
3. **Theme Options**: Add theme selection to the options menu
4. **Additional Components**: Expand FrameFactory with checkboxes, sliders, dropdowns, etc.
5. **Animation System**: Add animation helpers for fades, slides, and effects

## File Locations

- Framework files: `/Framework/`
- Theme files: `/Themes/`
- Atlas textures: `/Media/Textures/Atlas/`
- Documentation: README.md in each directory
