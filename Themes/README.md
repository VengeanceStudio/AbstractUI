# AbstractUI Themes

Theme definitions for the AbstractUI framework.

## Available Themes

### AbstractGlass
Dark, translucent glass aesthetic with subtle gradients.
- **Primary Color**: Cyan (#00CCFF)
- **Background**: Very dark blue, almost black
- **Style**: Minimalist, modern, subtle transparency
- **Best For**: Clean, professional interface

### NeonSciFi
Bright neon accents with holographic effects and futuristic styling.
- **Primary Color**: Cyan neon (#00FFFF)
- **Background**: Deep black-blue
- **Style**: High contrast, glowing effects, futuristic
- **Best For**: Eye-catching, cyberpunk aesthetic

## Creating a Custom Theme

1. Create a new .lua file in Themes/ directory
2. Register color palette with ColorPalette:RegisterPalette()
3. Register fonts with FontKit:RegisterThemeFonts()
4. Add theme file to AbstractUI.toc
5. Create corresponding texture atlas (optional)

### Minimum Required Colors

```lua
-- Essential colors
primary, secondary, accent
bg-primary, bg-secondary
text-primary, text-secondary, text-disabled
button-bg, button-hover, button-pressed
panel-bg, panel-border
tooltip-bg
```

### Example Theme Structure

```lua
local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local ColorPalette = AbstractUI.ColorPalette
local FontKit = AbstractUI.FontKit

ColorPalette:RegisterPalette("MyTheme", {
    ["primary"] = {r = 1.0, g = 0.5, b = 0.0, a = 1.0},
    -- ... more colors
})

FontKit:RegisterThemeFonts("MyTheme", {
    ["body"] = "Friz Quadrata TT",
    -- ... more fonts
})
```
