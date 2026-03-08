-- ============================================================================
-- AbstractUI Tile Database
-- ============================================================================
-- Contains texture file data IDs for map exploration (fog of war removal)
-- Generated using the TileExtractor module (/extracttiles command)
-- 
-- To update this database:
--   1. Run /extracttiles on multiple characters with good exploration
--   2. Run /savetiles after each extraction to merge data
--   3. Run /exportmerged to generate the final database
--   4. Copy the output and replace the contents of this file
-- 
-- Database Format:
--   [mapID] = {
--       ["width:height:offsetX:offsetY"] = "fileDataID1,fileDataID2,...",
--   }
-- ============================================================================

local addonName, AbstractUI = ...

-- Initialize the tile database
-- This will be populated after you run the extraction process
AbstractUI.TileDatabase = {
    -- Example entry (remove after first extraction):
    -- [1208] = { -- Icecrown
    --     ["256:256:0:0"] = "447201,447202",
    --     ["256:256:256:0"] = "447203,447204",
    -- },
    
    -- Your extracted data will go here
    -- Run /extracttiles then /exportmerged to generate this data
}

-- Utility function to check if database is populated
function AbstractUI:HasTileData()
    return AbstractUI.TileDatabase and next(AbstractUI.TileDatabase) ~= nil
end

-- Get tile data for a specific map
function AbstractUI:GetMapTileData(mapID)
    if not AbstractUI.TileDatabase then return nil end
    return AbstractUI.TileDatabase[mapID]
end

-- Get statistics about the database
function AbstractUI:GetTileDatabaseStats()
    if not AbstractUI.TileDatabase then 
        return { maps = 0, tiles = 0 }
    end
    
    local totalMaps = 0
    local totalTiles = 0
    
    for mapID, data in pairs(AbstractUI.TileDatabase) do
        totalMaps = totalMaps + 1
        for _ in pairs(data) do
            totalTiles = totalTiles + 1
        end
    end
    
    return {
        maps = totalMaps,
        tiles = totalTiles
    }
end
