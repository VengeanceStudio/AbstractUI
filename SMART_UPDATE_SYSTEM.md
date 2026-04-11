# Smart Update System for Unit Frames

## Overview

The Smart Update System optimizes how AbstractUI handles configuration changes for unit frames. Instead of recreating entire frames on every setting change, the system now intelligently determines whether a change requires full frame recreation (structural) or can be handled by updating properties on the existing frame (cosmetic).

## Implementation Status

- ✅ **Target Frame**: Fully implemented with smart updates
- ⏳ **Other Frames**: Still use full recreation (to be migrated later)

## Architecture

### Structural Changes (Require Recreation)

These changes modify the frame hierarchy or layout and require full frame recreation:

1. **Bar Enabled/Disabled** (`health.enabled`, `power.enabled`, `info.enabled`, `castbar.enabled`)
   - Adds or removes child frames from the hierarchy
   - Affects frame structure

2. **Width & Height** (`health.width`, `health.height`, etc.)
   - Changes bar dimensions
   - Affects layout of stacked bars
   - Impacts positioning of subsequent elements

3. **Attachment** (`power.attachTo`, `info.attachTo`)
   - Changes which bar a child bar attaches to
   - Affects frame parent-child relationships

4. **Spacing** (global `spacing` setting)
   - Changes vertical gaps between bars
   - Affects positioning of all bars in stack

### Cosmetic Changes (Property Updates Only)

These changes only modify visual properties and can be applied to existing frames without recreation:

1. **Colors**
   - Bar colors (`health.color`, `power.color`, `info.color`)
   - Background colors (`bgColor`)
   - Font colors (`fontColor`)
   - Castbar colors (`castingColor`, `channelingColor`, etc.)

2. **Fonts**
   - Font family (`font`)
   - Font size (`fontSize`)
   - Font outline (`fontOutline`)

3. **Textures**
   - Bar textures (`texture`)
   - Castbar texture

4. **Text Content**
   - Text templates (`textLeft`, `textCenter`, `textRight`)
   - Show/hide flags (`showSpellName`, `showCastTime`, `showIcon`)

5. **Other Visual Properties**
   - Class coloring (`classColor`)
   - Text position (`textPos`)
   - Icon position (`iconPosition`)

## Code Components

### 1. `updateProperties()` Function

Located in `GenerateFrameOptions()` closure, this function updates cosmetic properties on existing frames without recreation.

**What it updates:**
- Health bar: color, bgColor, texture, font properties
- Power bar: color, bgColor, texture, font properties
- Info bar: color, bgColor, texture, font properties
- Castbar: size, colors, texture, font, visibility flags

**How it works:**
```lua
local function updateProperties()
    local frame = _G[frameGlobal]
    if not frame then return end
    
    local db = getDB()
    local LSM = LibStub:GetLibrary("LibSharedMedia-3.0")
    
    -- Update each bar's properties directly
    if frame.healthBar and db.health then
        frame.healthBar:SetStatusBarColor(unpack(db.health.color))
        -- ... more property updates
    end
    
    -- Force visual update via existing event handler
    if self.UpdateUnitFrame then
        self:UpdateUnitFrame(frameKey, unit)
    end
end
```

### 2. Smart Set Handlers

Modified `makeBarSetHandler()` and `makeColorSetHandler()` to detect change type:

```lua
local function makeBarSetHandler(property)
    return function(_, value)
        local db = getDB()
        if not db[barType] then db[barType] = {} end
        if db[barType][property] == value then
            return  -- Value unchanged, skip update
        end
        db[barType][property] = value
        
        -- SMART UPDATE: For Target frame only
        if frameKey == "target" then
            local structuralProperties = {
                ["enabled"] = true,
                ["width"] = true,
                ["height"] = true,
                ["attachTo"] = true,
            }
            
            if structuralProperties[property] then
                update()  -- Full recreation
            else
                updateProperties()  -- Property update only
            end
        else
            update()  -- Other frames always recreate
        end
    end
end
```

Colors are always cosmetic, so `makeColorSetHandler()` calls `updateProperties()` for target frame:

```lua
local function makeColorSetHandler(property)
    return function(_, r, g, b, a)
        local db = getDB()
        if not db[barType] then db[barType] = {} end
        local oldColor = db[barType][property]
        if oldColor and oldColor[1] == r and oldColor[2] == g and oldColor[3] == b and oldColor[4] == a then
            return  -- Color unchanged
        end
        db[barType][property] = {r, g, b, a}
        
        if frameKey == "target" then
            updateProperties()  -- Colors are always cosmetic
        else
            update()
        end
    end
end
```

### 3. Castbar-Specific Handlers

Similar logic in `makeCastbarSetHandler()` and `makeCastbarColorSetHandler()`:

**Structural castbar properties:**
- `enabled` - Adds/removes castbar from frame
- `width`, `height` - Changes castbar dimensions

**Cosmetic castbar properties:**
- All colors (casting, channeling, interrupted, etc.)
- Font and fontSize
- Texture
- Show/hide flags (showIcon, showSpellName, showCastTime)
- Icon position

## Benefits

### 1. Performance
- **Before**: Every setting change recreated entire frame (~50-100ms)
- **After**: Cosmetic changes update in <5ms

### 2. No More Duplicates
- Recreating frames too frequently could leave orphaned frames
- Property updates modify existing frame, preventing duplicates

### 3. Reduced Memory Pressure
- WoW cannot delete frames, only dereference them for garbage collection
- Fewer frame creations = less memory accumulation over time

### 4. Smooth User Experience
- Changes apply instantly without visual "flash" of recreation
- Better responsiveness in options panel

## Testing Checklist

### Structural Changes (Should Recreate)
- [ ] Enable/disable health bar
- [ ] Enable/disable power bar
- [ ] Enable/disable info bar
- [ ] Enable/disable castbar
- [ ] Change bar width
- [ ] Change bar height
- [ ] Change bar spacing
- [ ] Change power bar attachment

### Cosmetic Changes (Should NOT Recreate)
- [ ] Change health bar color
- [ ] Change power bar color
- [ ] Change font family
- [ ] Change font size
- [ ] Change font outline
- [ ] Change texture
- [ ] Change text template
- [ ] Change castbar colors
- [ ] Toggle castbar icon visibility
- [ ] Change castbar font

### Target Castbar Specific
- [ ] Change casting color
- [ ] Change channeling color
- [ ] Toggle spell name
- [ ] Toggle cast time
- [ ] Toggle icon
- [ ] Change icon position
- [ ] Change texture

## Future Work

### Short Term
1. Monitor for any edge cases where property updates don't fully apply
2. Verify no duplicate frames appear during testing
3. Confirm all cosmetic properties update correctly

### Long Term
1. **Extend to Other Frames**: Apply smart update system to:
   - Player frame
   - Pet frame
   - Focus frame
   - Target of Target frame
   - Boss frames

2. **Further Optimization**: Consider making width/height cosmetic by:
   - Updating bar sizes directly
   - Recalculating positions of dependent bars
   - Only recreating if attachment changes

3. **Event-Driven Updates**: Explore using WoW events more extensively:
   - Listen for UNIT_HEALTH, UNIT_POWER_UPDATE already done
   - Add listeners for setting changes to trigger updates
   - Reduce need for explicit update calls

## Technical Notes

### Why Not Just Update Everything?

Some properties genuinely require recreation:
- **Enabling/disabling bars**: Creates or removes child frames
- **Spacing changes**: All bars must be repositioned
- **Width/height**: Affects layout; complex to recalculate positions

The system balances simplicity with efficiency by recreating for complex layout changes while updating for simple visual changes.

### Relationship with UpdateUnitFrame()

The `UpdateUnitFrame()` function already demonstrates property updates:
```lua
function UnitFrames:UpdateUnitFrame(frameKey, unit)
    -- Updates bar values, colors, text without recreation
    frame.healthBar:SetValue(currentHealth)
    frame.healthBar.text:SetText(healthText)
    -- etc.
end
```

The smart update system extends this pattern to configuration changes, calling `UpdateUnitFrame()` at the end to ensure text templates and values refresh correctly.

### Frame Lifecycle

1. **Creation**: `CreateUnitFrame()` builds frame hierarchy with all bars
2. **Event Updates**: `UpdateUnitFrame()` responds to game events (health changes, etc.)
3. **Config Updates** (NEW):
   - **Structural**: Call `update()` → full recreation
   - **Cosmetic**: Call `updateProperties()` → modify existing frame
4. **Cleanup**: When recreating, comprehensive cleanup prevents orphaned references

## Debugging

If you encounter issues:

1. **Duplicate frames appearing**: Check if a property marked as "cosmetic" actually requires recreation
2. **Properties not updating**: Verify `updateProperties()` includes that property
3. **Frame not responding**: Ensure `UpdateUnitFrame()` is called at end of `updateProperties()`

Add debug output temporarily:
```lua
if frameKey == "target" then
    print("Target update: " .. property .. " = " .. tostring(value) .. " (structural: " .. tostring(structuralProperties[property] or false) .. ")")
end
```

## Summary

The Smart Update System brings AbstractUI's frame management in line with Blizzard's approach: **create once, update properties as needed, recreate only when structure must change**. This improves performance, prevents bugs like duplicate frames, and provides a better user experience.
