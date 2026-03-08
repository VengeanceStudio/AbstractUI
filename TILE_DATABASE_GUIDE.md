# Tile Database Extraction Guide

This guide explains how to build a complete tile database for AbstractUI's fog of war removal feature that will be **included with the addon** for all users.

## Overview

Once you extract the tile database using your 3 characters and include it with the addon:
- ✅ **New users get instant fog removal** without any setup
- ✅ **No need for users to explore zones** - your data covers them
- ✅ **Works out of the box** - just enable the "Reveal Map" option
- ✅ **Distributed with the addon** - users download it automatically

## Quick Start (For You - Addon Author)

### Step 1: Extract from Character 1
```
/extracttiles    → Scans all maps (2-5 minutes)
/savetiles       → Saves to AbstractUITileData
/logout          → Persists data
```

### Step 2: Extract from Character 2
```
Login with Character 2
/extracttiles    → Scans all maps
/savetiles       → MERGES with Character 1 data
/logout
```

### Step 3: Extract from Character 3
```
Login with Character 3
/extracttiles    → Scans all maps
/savetiles       → MERGES with all previous data
/mergedstats     → Shows total: X maps, Y tiles
```

### Step 4: Export and Bundle

**Problem:** The full export is too large for WoW's chat window to display.

**Solution:** Export to SavedVariables!

```
/exportfile      → Formats the complete database
                 → Stores in AbstractUITileExport variable
                 → Shows instructions
                 
/logout          → Saves to disk

Then on your PC:
1. Navigate to: WTF\Account\YOUR_ACCOUNT\SavedVariables\
2. Open: AbstractUI.lua in text editor
3. Find: AbstractUITileExport = {
4. Copy the entire table (all the lines, from { to })
5. Each line is properly formatted Lua code
6. Paste into: Modules\TileDatabase.lua
7. Save and commit to repository

**OR use the helper script:**
```powershell
.\extract_tile_database.ps1
```
This script automatically reads AbstractUI.lua, extracts the table,
and writes it to Modules\TileDatabase.lua for you!
```

**Note:** AbstractUITileExport is now stored as a **table of strings** (one per line), not a giant escaped string. This makes it much cleaner and easier to read in the SavedVariables file!

### Step 5: Ship It!
```
Users download your addon → TileDatabase.lua included → Fog removal works immediately
```

## For End Users

**Users don't need to do anything!** The tile database is included with the addon.

1. Install AbstractUI
2. Enable "Reveal Map" option in settings
3. Open map - fog is automatically removed for all zones you have data for

## Available Commands

### For Addon Author (Building Database)

| Command | Description |
|---------|-------------|
| `/extracttiles` | Start extraction (2-5 minutes per character) |
| `/savetiles` | Save/merge current extraction to persistent database |
| `/mergedstats` | Show statistics of merged database |
| `/exportfile` | Write formatted database to SavedVariables - RECOMMENDED! |
| `/clearmerged` | Clear merged database and start over |

### For Everyone

| Command | Description |
|---------|-------------|
| `/tweaks status` | Show Tweaks module status including tile database coverage |

## Technical Details

### How It Works

1. **Extraction Phase** (You, the addon author)
   - TileExtractor scans all map IDs (1-3000)
   - Calls `C_MapExplorationInfo.GetExploredMapTextures(mapID)` for each
   - Records texture file data IDs, dimensions, and positions
   - Only captures tiles your character has explored

2. **Merging Phase** (Multiple characters)
   - Each character contributes their explored zones
   - `/savetiles` merges new tiles with existing database
   - Deduplicates tiles already recorded
   - Combines file IDs for same tile positions

3. **Distribution Phase** (Bundled with addon)
   - `/exportmerged` generates complete Lua code
   - You paste into `Modules/TileDatabase.lua`
   - File becomes part of addon distribution
   - All users get the database automatically

4. **Runtime Phase** (End user)
   - User enables "Reveal Map" option
   - Opens world map
   - Tweaks module checks `AbstractUI.TileDatabase[mapID]`
   - If data exists, creates textures for all tiles (explored + unexplored)
   - If no data, falls back to showing only explored tiles

### File Export Process

The complete database is written to its own SavedVariables file as properly formatted Lua code:

**In-game:**
```
/exportfile
→ Creates AbstractUITileExport variable
→ Contains complete formatted Lua code
→ Saved on logout
```

**After logout:**
```
WTF/Account/YOUR_ACCOUNT/SavedVariables/AbstractUI.lua

Look for the AbstractUITileExport table:

AbstractUITileExport = {
    [1] = "-- ============================================================================",
    [2] = "-- AbstractUI Tile Database",
    [3] = "-- Generated: 2026-03-08 12:34:56",
    ...
    [1234] = "}",
}

Each line is stored as a separate string in the table!
Just copy all the strings and reconstruct the file.
```

**Much cleaner format:**
- Stored as a table (array) of strings
- Each line is properly formatted
- No escaped newlines (`\n`)
- Easy to read and copy from SavedVariables
- Select from the first `"--` to the last `"}"`

### Database Format

```lua
AbstractUI.TileDatabase = {
    [mapID] = {
        ["width:height:offsetX:offsetY"] = "fileDataID1,fileDataID2,...",
    }
}
```

**Example:**
```lua
[1208] = { -- Icecrown (23 tiles)
    ["256:256:0:0"] = "447201,447202",
    ["256:256:256:0"] = "447203,447204",
    ["256:256:512:0"] = "447205",
},
```

### Storage Size

Based on 3 well-explored characters:

- **Expected Maps:** 400-600 zones
- **Expected Tiles:** 10,000-20,000 tiles
- **File Size:** 500 KB - 1.5 MB
- **Format:** Plain Lua table (fast to load)

Compare: Leatrix_Maps has ~327 lines of database = ~2 MB total

### Maintenance

**When to re-extract:**
- ⚠️ **Major WoW patches** - Texture file IDs may change
- ⚠️ **New expansions** - New zones added
- ⚠️ **Map overhauls** - Tile layouts change

**How to update:**
1. Run `/extracttiles` on your characters again
2. Existing `AbstractUITileData` will merge with new data
3. Run `/exportmerged` to get updated database
4. Replace `TileDatabase.lua` contents
5. Release new addon version

## Fallback Behavior

If a zone isn't in the database:
- ✅ Tweaks.lua automatically falls back to Blizzard's API
- ✅ Shows tiles the user has already explored
- ✅ No errors or broken maps
- ℹ️ Just no fog removal for that specific zone

Users can check coverage: `/tweaks status`

## Current Integration Status

- ✅ **TileDatabase.lua** - Created and ready to populate
- ✅ **TileExtractor.lua** - Extraction and merging tool ready
- ✅ **Tweaks.lua** - Updated to use TileDatabase with fallback
- ✅ **AbstractUI.toc** - All modules registered
- ✅ **SavedVariables** - AbstractUITileData persists across logins
- ⏳ **Empty Database** - Ready for your extraction!

## Comparison with Leatrix_Maps

| Feature | AbstractUI | Leatrix_Maps |
|---------|-----------|--------------|
| Database Source | Your 3 characters | Comprehensive manual database |
| Coverage | Zones you've explored | All zones (every expansion) |
| File Size | 500 KB - 1.5 MB | ~2 MB (Reveal data alone) |
| Maintenance | Re-extract after patches | Author updates manually |
| Integration | Built into AbstractUI | Separate addon |
| Customization | Part of your UI suite | Standalone |

## Next Steps

1. ✅ Install AbstractUI (has TileExtractor built-in)
2. 🎮 Login with Character 1, run `/extracttiles`, then `/savetiles`, logout
3. 🎮 Login with Character 2, run `/extracttiles`, then `/savetiles`, logout
4. 🎮 Login with Character 3, run `/extracttiles`, then `/savetiles`
5. 📤 Run `/exportfile` then `/logout` to save to disk
6. 🤖 Run `.\extract_tile_database.ps1` (auto-converts)
   - OR manually copy from `SavedVariables\AbstractUI.lua`
7. 📝 Verify `Modules\TileDatabase.lua` is populated
8. 💾 Save and commit to repository
9. 🚀 Users download AbstractUI with full fog removal built-in! 
10. 💾 Save and commit to repository
11. 🚀 Users download AbstractUI with full fog removal built-in!

## Questions?

**How long does extraction take?**  
2-5 minutes per character, depending on zones explored.

**Will it lag in-game?**  
No, extraction processes in small batches with delays between them.

**What if I only do 1 character?**  
You'll have partial coverage - better than nothing! Users can still contribute.

**Can users extract and send you data?**  
Yes! They can run `/extracttiles`, `/savetiles`, `/exportfile`, then send you their AbstractUI.lua SavedVariables file (or just the AbstractUITileExport string from it).

**What happens on WoW patches?**  
File IDs may change. Re-run extraction and update TileDatabase.lua.

**Is this against ToS?**  
No, you're using Blizzard's official API to read data from your own game client.
