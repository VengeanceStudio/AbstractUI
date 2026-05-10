# AbstractUI Skinning Framework

This folder contains individual frame skin implementations. Each file skins a specific Blizzard UI frame using the shared `AbstractUI.SkinFramework` API.

## Architecture

- **Modules/Skins.lua** - Core skinning module containing:
  - Skin definitions and defaults
  - Common skinning utilities
  - Framework API for individual skins
  - Options UI with per-frame toggles
  
- **/Skins/*.lua** - Individual frame skin implementations
  - Each file handles one specific frame (e.g., CharacterPane.lua)
  - Uses SkinFramework API for consistency
  - Responds to theme changes automatically

## Creating a New Frame Skin

### 1. Create the Module File

Create a new file in `/Skins/` named after the frame (e.g., `SpellBookFrame.lua`):

```lua
local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local MyFrameSkin = AbstractUI:NewModule("MyFrameSkin", "AceEvent-3.0")

local SkinFramework = nil
local skinned = false

function MyFrameSkin:OnInitialize()
    self:RegisterMessage("AbstractUI_DB_READY", "OnDBReady")
end

function MyFrameSkin:OnDBReady()
    -- Get framework reference
    SkinFramework = AbstractUI.SkinFramework
    if not SkinFramework then return end
    
    self:RegisterEvent("ADDON_LOADED")
    
    if MyFrame then
        self:ApplySkin()
    end
end

function MyFrameSkin:ADDON_LOADED(event, addon)
    if addon == "Blizzard_MyFrame" or (addon == "AbstractUI" and MyFrame) then
        C_Timer.After(0.1, function()
            if MyFrame and not skinned then
                self:ApplySkin()
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

function MyFrameSkin:ApplySkin()
    -- Check if this frame is enabled for skinning
    if not SkinFramework:IsFrameEnabled("MyFrameName") then return end
    if skinned then return end
    if not MyFrame then return end
    
    -- Strip Blizzard textures
    SkinFramework:StripTextures(MyFrame, false)
    
    -- Apply AbstractUI backdrop
    SkinFramework:ApplyBackdrop(MyFrame, 0.85)
    
    -- Get theme colors for custom styling
    local colors = SkinFramework:GetThemeColors()
    
    -- Custom skinning code here...
    
    skinned = true
    
    -- Listen for theme changes
    self:RegisterMessage("AbstractUI_THEME_CHANGED", "OnThemeChanged")
    self:RegisterMessage("AbstractUI_SKIN_THEME_CHANGED", "OnThemeChanged")
end

function MyFrameSkin:OnThemeChanged()
    if not SkinFramework:IsFrameEnabled("MyFrameName") then return end
    skinned = false
    self:ApplySkin()
end
```

### 2. Add Frame to Skins.lua Options

In `/Modules/Skins.lua`, add your frame to:

1. **Default settings** (`OnDBReady` function):
```lua
frames = {
    -- ... existing frames ...
    MyFrameName = false,  -- Default OFF
}
```

2. **Options UI** (`GetOptions` function):
```lua
MyFrameName = {
    name = "My Frame Display Name",
    desc = "Apply AbstractUI skin to my frame",
    type = "toggle",
    order = 130,  -- Choose appropriate order
    width = "full",
    get = function() return self.db.profile.frames.MyFrameName end,
    set = function(_, v)
        self.db.profile.frames.MyFrameName = v
        StaticPopup_Show("AbstractUI_RELOAD_CONFIRM")
    end
},
```

3. **Load in TOC** - Add to AbstractUI.toc:
```
Skins\MyFrameSkin.lua
```

## SkinFramework API Reference

### Checking Frame Status
```lua
SkinFramework:IsFrameEnabled("FrameName")
```
Returns true if the frame is enabled for skinning in options.

### Getting Theme Colors
```lua
local colors = SkinFramework:GetThemeColors()
-- Returns table: { primary, background, border, text }
-- Each is an array: {r, g, b, a}
```

### Applying Standard Backdrop
```lua
SkinFramework:ApplyBackdrop(frame, opacity)
```
Applies consistent AbstractUI backdrop with theme colors.

### Stripping Blizzard Textures
```lua
SkinFramework:StripTextures(frame, keepPortrait)
```
Removes Blizzard's default textures, NineSlice borders, and backgrounds.

### Skinning Close Buttons
```lua
SkinFramework:SkinCloseButton(button)
```
Applies AbstractUI style to close buttons.

### Getting References
```lua
local ColorPalette = SkinFramework:GetColorPalette()
local FontKit = SkinFramework:GetFontKit()
```

### Theme Change Notifications
Listen for these messages to reapply skins when theme changes:
- `AbstractUI_THEME_CHANGED` - Core theme change
- `AbstractUI_SKIN_THEME_CHANGED` - Skin-specific theme change

## Best Practices

1. **Always check if enabled** - Use `SkinFramework:IsFrameEnabled()` before skinning
2. **Default to OFF** - New frame skins should default to `false` in settings
3. **Use framework utilities** - Don't duplicate color/backdrop code
4. **Listen for theme changes** - Reapply skins when user changes themes
5. **Handle late loading** - Use ADDON_LOADED events for Blizzard frames
6. **Document warnings** - If skinning a frame has known issues, document in option description

## Example: CharacterPane

See `CharacterPane.lua` for a comprehensive example of all framework features in action.
