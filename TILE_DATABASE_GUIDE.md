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
/exportfile      → Prepares data for extraction
/logout          → Saves to disk
```

### Step 4: Run the Extraction Script
```powershell
.\extract_tile_database.ps1
```
- Automatically finds your WoW installation
- Extracts database from SavedVariables
- Writes to Modules\TileDatabase.lua
- Shows file size and statistics

### Step 5: Ship It!
```
Commit Modules\TileDatabase.lua → Repository updated
Users download your addon → TileDatabase.lua included → Fog removal works immediately
```

## Detailed Export Process

After collecting data from all your characters (Steps 1-3), you need to export the merged database and convert it to the final format.

### In-Game Export

Run the following commands on any character (the merged data is account-wide):

```
/exportfile      → Formats the complete database
                 → Stores in AbstractUITileExport variable  
                 → Shows instructions
                 
/logout          → Saves to disk (IMPORTANT!)
```

**Note:** The data is saved to `WTF\Account\YOUR_ACCOUNT\SavedVariables\AbstractUI.lua` as a table of strings.

### PowerShell Script Extraction (Recommended)

After logging out, run the automated extraction script:

```powershell
.\extract_tile_database.ps1
```

**What it does automatically:**
- 🔍 Finds your WoW installation directory
- 📂 Locates your SavedVariables folder
- 🎮 Prompts you to select your account (if multiple)
- 📥 Reads AbstractUI.lua from SavedVariables
- 🔄 Extracts the AbstractUITileExport table
- ✏️ Writes directly to `Modules\TileDatabase.lua`
- ✅ Reports file size and line count

**Example output:**
```
AbstractUI Tile Export Converter
=================================

WoW Path: C:\Program Files (x86)\World of Warcraft\_retail_
Account: YourAccount
Reading: AbstractUI.lua...
Found AbstractUITileExport table!

Extracted 8234 lines

=================================
SUCCESS!
=================================
Output saved to:
  C:\AbstractUI-Repo\Modules\TileDatabase.lua

File size: 742.15 KB
Lines: 8234
```

### Manual Method (Alternative)

If the script doesn't work or you prefer manual extraction:

1. Navigate to: `WTF\Account\YOUR_ACCOUNT\SavedVariables\`
2. Open: `AbstractUI.lua` in text editor
3. Find: `AbstractUITileExport = {`
4. Copy all the quoted strings from each line: `[1] = "...", [2] = "..."`
5. Reconstruct by removing the array format and joining the strings
6. Paste into: `Modules\TileDatabase.lua`
7. Save and commit to repository

**Note:** AbstractUITileExport is stored as a **table of strings** (one per line), not a giant escaped string. This makes it cleaner to read, but you need to reconstruct it for the final file. The PowerShell script handles this automatically.

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

## PowerShell Script Usage

### Requirements

- Windows PowerShell 5.1+ (included with Windows 10/11)
- WoW must be installed (script auto-detects common paths)
- AbstractUI.lua must exist in SavedVariables (after `/exportfile` and logout)

### Basic Usage

Simply run from the addon directory after exporting in-game:

```powershell
.\extract_tile_database.ps1
```

### Advanced Usage

**Specify WoW path manually:**
```powershell
.\extract_tile_database.ps1 -WoWPath "D:\Games\World of Warcraft\_retail_"
```

**Specify both WoW path and account:**
```powershell
.\extract_tile_database.ps1 -WoWPath "C:\WoW\_retail_" -AccountName "WoW1"
```

### Troubleshooting

**"Could not find WoW Retail installation"**
- Specify path manually with `-WoWPath` parameter
- Ensure you're pointing to the `_retail_` folder

**"AbstractUI.lua not found"**
- Make sure you ran `/exportfile` in-game
- Make sure you logged out (data only saves on logout)
- Check the path: `WTF\Account\YOUR_ACCOUNT\SavedVariables\AbstractUI.lua`

**"AbstractUITileExport not found"**
- Run `/exportfile` in-game (not just `/exportmerged`)
- Ensure you logged out after running the command
- The export must complete successfully

**Script won't run - "execution policy" error:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

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
   - `/exportfile` generates complete Lua code and saves to SavedVariables
   - PowerShell script extracts and writes to `Modules/TileDatabase.lua`
   - File becomes part of addon distribution
   - All users get the database automatically

4. **Runtime Phase** (End user)
   - User enables "Reveal Map" option
   - Opens world map
   - Tweaks module checks `AbstractUI.TileDatabase[mapID]`
   - If data exists, creates textures for all tiles (explored + unexplored)
   - If no data, falls back to showing only explored tiles

### File Export Process

The complete database is written to SavedVariables and then extracted using the PowerShell script:

**In-game:**
```
/exportfile
→ Creates AbstractUITileExport variable
→ Contains complete formatted Lua code (as table of strings)
→ Saved on logout
```

**After logout - Use the PowerShell Script:**
```powershell
.\extract_tile_database.ps1
```

**What the script does:**
1. Locates your WoW installation (checks common paths)
2. Finds SavedVariables in `WTF\Account\[YourAccount]\SavedVariables\`
3. Reads `AbstractUI.lua`
4. Extracts the `AbstractUITileExport` table
5. Converts the table of strings back to a proper Lua file
6. Writes output directly to `Modules\TileDatabase.lua`

**Script features:**
- ✅ Auto-detects WoW installation path
- ✅ Handles multiple accounts (prompts you to select)
- ✅ Processes escaped characters correctly
- ✅ Reports file size and line count
- ✅ Provides clear error messages if something goes wrong

**SavedVariables structure (for reference):**
```lua
WTF/Account/YOUR_ACCOUNT/SavedVariables/AbstractUI.lua

AbstractUITileExport = {
    [1] = "-- ============================================================================",
    [2] = "-- AbstractUI Tile Database",
    [3] = "-- Generated: 2026-03-08 12:34:56",
    ...
    [1234] = "}",
}
```

**Much cleaner format than before:**
- Stored as a table (array) of strings, one per line
- Each line is properly formatted
- No giant escaped strings with `\n` throughout
- Easy to read in SavedVariables
- Script handles all the conversion automatically

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
3. Run `/exportfile` and `/logout` to save to disk
4. Run `.\extract_tile_database.ps1` to update `TileDatabase.lua`
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
6. 🤖 **Run `.\extract_tile_database.ps1`** (RECOMMENDED - automatic extraction)
   - Script finds WoW directory automatically
   - Extracts and converts the database in one step
   - Writes directly to `Modules\TileDatabase.lua`
7. 📝 Verify `Modules\TileDatabase.lua` is populated
8. 💾 Commit to repository
9. 🚀 Users download AbstractUI with full fog removal built-in!

## Questions?

**How long does extraction take?**  
2-5 minutes per character, depending on zones explored.

**Will it lag in-game?**  
No, extraction processes in small batches with delays between them.

**What if I only do 1 character?**  
You'll have partial coverage - better than nothing! Users can still contribute.

**Can users extract and send you data?**  
Yes! They can run `/extracttiles`, `/savetiles`, `/exportfile`, then send you their AbstractUI.lua SavedVariables file (or just the AbstractUITileExport section from it). You can use the PowerShell script to process it.

**What happens on WoW patches?**  
File IDs may change. Re-run extraction and update TileDatabase.lua using the same process.

**Is this against ToS?**  
No, you're using Blizzard's official API to read data from your own game client.

**What if the PowerShell script doesn't work?**  
The script tries to auto-detect your WoW path. If it fails:
- Run with explicit path: `.\extract_tile_database.ps1 -WoWPath "C:\Your\WoW\Path\_retail_"`
- Or use the manual method described in "Detailed Export Process" section above

**Can I run the script on another computer?**  
Yes! Copy both `extract_tile_database.ps1` and your `AbstractUI.lua` SavedVariables file. Run the script with parameters:
```powershell
.\extract_tile_database.ps1 -WoWPath "C:\Path\To\WoW\_retail_" -AccountName "YourAccount"
```
