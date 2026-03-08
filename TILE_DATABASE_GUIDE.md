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

**Solution:** Use chunked export!

```
/exportchunked   → Exports chunk 1 (header + first 20 maps)
                 → Copy from chat
                 → Type /nextchunk
                 → Copy chunk 2
                 → Repeat until complete
```

Each chunk contains ~20 maps worth of data (small enough to copy).
Paste all chunks together in `Modules/TileDatabase.lua` to rebuild the complete file.

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
| `/exportchunked` | Export in small chunks - RECOMMENDED! |
| `/nextchunk` | Continue to next chunk during export |
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

### Chunked Export Process

Since the complete database is too large for WoW's chat window, use chunked export:

```
/exportchunked
=== CHUNK 1 of 25 ===
[Header and first 20 maps displayed]

→ Select all text, Ctrl+C
→ Type: /nextchunk

=== CHUNK 2 of 25 ===
[Next 20 maps displayed]

→ Select all text, Ctrl+C
→ Type: /nextchunk

[Repeat until...]

=== CHUNK 25 of 25 ===
[Final maps + closing brace]
=== EXPORT COMPLETE ===
```

**To combine chunks:**
1. Open `Modules/TileDatabase.lua` in text editor
2. Delete everything (start fresh)
3. Paste chunk 1 (contains header + opening)
4. Paste chunk 2 (maps only)
5. Paste chunk 3 (maps only)
6. Continue pasting all chunks in order
7. Last chunk contains the closing brace
8. Save file

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
2. 🎮 Login with Character 1, run `/extracttiles`, then `/savetiles`
3. 🎮 Login with Character 2, run `/extracttiles`, then `/savetiles`
4. 🎮 Login with Character 3, run `/extracttiles`, then `/savetiles`
5. 📋 Run `/exportchunked` and `/nextchunk` repeatedly
6. 📝 Copy each chunk one at a time
7. 📄 Paste all chunks into `Modules/TileDatabase.lua` (in order!)
8. 💾 Save file and commit to repository
9. 🚀 Users download AbstractUI with full fog removal built-in!

## Questions?

**How long does extraction take?**  
2-5 minutes per character, depending on zones explored.

**Will it lag in-game?**  
No, extraction processes in small batches with delays between them.

**What if I only do 1 character?**  
You'll have partial coverage - better than nothing! Users can still contribute.

**Can users extract and send you data?**  
Yes! They can run the same commands and send you their `/exportmerged` output.

**What happens on WoW patches?**  
File IDs may change. Re-run extraction and update TileDatabase.lua.

**Is this against ToS?**  
No, you're using Blizzard's official API to read data from your own game client.
