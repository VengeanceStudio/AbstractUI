-- ============================================================================
-- Tile Database Extractor for AbstractUI
-- ============================================================================
-- This module extracts map tile data from WoW's exploration system
-- Run /extracttiles to begin extraction process

local AbstractUI = LibStub("AceAddon-3.0"):GetAddon("AbstractUI")
local TileExtractor = AbstractUI:NewModule("TileExtractor", "AceConsole-3.0")

local extractedData = {}
local currentMapIndex = 1
local allMapIDs = {}
local isExtracting = false

-- ============================================================================
-- EXTRACTION FUNCTIONS
-- ============================================================================

function TileExtractor:StartExtraction()
    if isExtracting then
        self:Print("Extraction already in progress...")
        return
    end
    
    self:Print("Starting tile database extraction...")
    self:Print("This will take several minutes. Please wait...")
    
    isExtracting = true
    extractedData = {}
    allMapIDs = {}
    currentMapIndex = 1
    
    -- Collect all valid map IDs
    -- WoW map IDs typically range from 1 to 2500+ (as of Dragonflight/War Within)
    for mapID = 1, 3000 do
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.mapID then
            table.insert(allMapIDs, mapID)
        end
    end
    
    self:Print(string.format("Found %d valid maps. Beginning extraction...", #allMapIDs))
    
    -- Start the extraction process
    self:ExtractNextBatch()
end

function TileExtractor:ExtractNextBatch()
    if not isExtracting then return end
    
    local batchSize = 10 -- Process 10 maps at a time
    local processed = 0
    
    while processed < batchSize and currentMapIndex <= #allMapIDs do
        local mapID = allMapIDs[currentMapIndex]
        self:ExtractMapTiles(mapID)
        currentMapIndex = currentMapIndex + 1
        processed = processed + 1
    end
    
    -- Progress update
    if currentMapIndex % 100 == 0 then
        self:Print(string.format("Progress: %d/%d maps processed", currentMapIndex, #allMapIDs))
    end
    
    -- Continue or finish
    if currentMapIndex <= #allMapIDs then
        C_Timer.After(0.1, function() self:ExtractNextBatch() end)
    else
        self:FinishExtraction()
    end
end

function TileExtractor:ExtractMapTiles(mapID)
    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo then return end
    
    -- Get art layers for this map
    local layers = C_Map.GetMapArtLayers(mapID)
    if not layers or #layers == 0 then return end
    
    local layerInfo = layers[1] -- Primary layer
    
    -- Get all exploration textures (includes unexplored tiles)
    local exploredTextures = C_MapExplorationInfo.GetExploredMapTextures(mapID)
    if not exploredTextures or #exploredTextures == 0 then return end
    
    -- Store data for this map
    local mapData = {
        mapID = mapID,
        mapName = mapInfo.name,
        artID = layerInfo.layerWidth or 0, -- Use as identifier
        tiles = {}
    }
    
    -- Extract tile information
    for _, textureInfo in ipairs(exploredTextures) do
        local tile = {
            width = textureInfo.textureWidth or 256,
            height = textureInfo.textureHeight or 256,
            offsetX = textureInfo.offsetX or 0,
            offsetY = textureInfo.offsetY or 0,
            fileDataIDs = {}
        }
        
        -- Record file data IDs if available
        if textureInfo.fileDataIDs then
            for _, fileID in ipairs(textureInfo.fileDataIDs) do
                if fileID and fileID > 0 then
                    table.insert(tile.fileDataIDs, fileID)
                end
            end
        end
        
        -- Only include tiles that have actual texture data
        if #tile.fileDataIDs > 0 then
            table.insert(mapData.tiles, tile)
        end
    end
    
    -- Only save maps that have tiles
    if #mapData.tiles > 0 then
        extractedData[mapID] = mapData
    end
end

function TileExtractor:FinishExtraction()
    isExtracting = false
    
    local totalMaps = 0
    local totalTiles = 0
    
    for mapID, data in pairs(extractedData) do
        totalMaps = totalMaps + 1
        totalTiles = totalTiles + #data.tiles
    end
    
    self:Print("=======================================================")
    self:Print(string.format("Extraction Complete!"))
    self:Print(string.format("Total Maps: %d", totalMaps))
    self:Print(string.format("Total Tiles: %d", totalTiles))
    self:Print("=======================================================")
    self:Print("Run /exporttiles to export the database to chat")
    self:Print("(You can copy/paste from chat to save the data)")
end

function TileExtractor:ExportToChat()
    if not extractedData or not next(extractedData) then
        self:Print("No data to export. Run /extracttiles first.")
        return
    end
    
    self:Print("Exporting tile database...")
    self:Print("=== BEGIN TILE DATABASE ===")
    
    -- Export in Lua table format
    print("local TileDatabase = {")
    
    for mapID, data in pairs(extractedData) do
        print(string.format("    [%d] = { -- %s", mapID, data.mapName))
        
        for _, tile in ipairs(data.tiles) do
            local key = string.format("%d:%d:%d:%d", tile.width, tile.height, tile.offsetX, tile.offsetY)
            local fileIDs = table.concat(tile.fileDataIDs, ",")
            print(string.format('        ["%s"] = "%s",', key, fileIDs))
        end
        
        print("    },")
    end
    
    print("}")
    self:Print("=== END TILE DATABASE ===")
    self:Print("Copy the data from your chat window!")
end

function TileExtractor:ExportToFile()
    if not extractedData or not next(extractedData) then
        self:Print("No data to export. Run /extracttiles first.")
        return
    end
    
    -- Create the database module content
    local output = {}
    table.insert(output, "-- ============================================================================")
    table.insert(output, "-- AbstractUI Tile Database")
    table.insert(output, string.format("-- Generated: %s", date("%Y-%m-%d %H:%M:%S")))
    table.insert(output, "-- ============================================================================")
    table.insert(output, "")
    table.insert(output, "local addonName, AbstractUI = ...")
    table.insert(output, "")
    table.insert(output, "AbstractUI.TileDatabase = {")
    
    -- Sort map IDs for consistent output
    local sortedMapIDs = {}
    for mapID in pairs(extractedData) do
        table.insert(sortedMapIDs, mapID)
    end
    table.sort(sortedMapIDs)
    
    local totalTiles = 0
    for _, mapID in ipairs(sortedMapIDs) do
        local data = extractedData[mapID]
        table.insert(output, string.format("    [%d] = { -- %s (%d tiles)", mapID, data.mapName, #data.tiles))
        
        for _, tile in ipairs(data.tiles) do
            local key = string.format("%d:%d:%d:%d", tile.width, tile.height, tile.offsetX, tile.offsetY)
            local fileIDs = table.concat(tile.fileDataIDs, ",")
            table.insert(output, string.format('        ["%s"] = "%s",', key, fileIDs))
            totalTiles = totalTiles + 1
        end
        
        table.insert(output, "    },")
    end
    
    table.insert(output, "}")
    
    local fullText = table.concat(output, "\n")
    
    self:Print("=======================================================")
    self:Print(string.format("Database Statistics:"))
    self:Print(string.format("- Maps: %d", #sortedMapIDs))
    self:Print(string.format("- Tiles: %d", totalTiles))
    self:Print(string.format("- Size: ~%.2f KB", #fullText / 1024))
    self:Print("=======================================================")
    self:Print("Database generated! The data is ready to be saved.")
    self:Print("Copy from chat using /exporttiles or access via")
    self:Print("AbstractUI.TileExtractor:GetExtractedData()")
    
    return fullText
end

function TileExtractor:ExportMergedToFile()
    if not AbstractUITileData or not next(AbstractUITileData) then
        self:Print("No merged data found. Run /extracttiles then /savetiles first.")
        return
    end
    
    self:Print("=================================================================")
    self:Print("Creating formatted file in SavedVariables...")
    self:Print("=================================================================")
    
    -- Build the complete file content as a table of lines
    local output = {}
    table.insert(output, "-- ============================================================================")
    table.insert(output, "-- AbstractUI Tile Database")
    table.insert(output, string.format("-- Generated: %s", date("%Y-%m-%d %H:%M:%S")))
    table.insert(output, "-- ============================================================================")
    table.insert(output, "")
    table.insert(output, "local addonName, AbstractUI = ...")
    table.insert(output, "")
    table.insert(output, "AbstractUI.TileDatabase = {")
    
    -- Sort map IDs
    local sortedMapIDs = {}
    for mapID in pairs(AbstractUITileData) do
        table.insert(sortedMapIDs, mapID)
    end
    table.sort(sortedMapIDs)
    
    local totalTiles = 0
    for _, mapID in ipairs(sortedMapIDs) do
        local data = AbstractUITileData[mapID]
        table.insert(output, string.format("    [%d] = { -- %s", mapID, data.mapName))
        
        for _, tile in ipairs(data.tiles) do
            local key = string.format("%d:%d:%d:%d", tile.width, tile.height, tile.offsetX, tile.offsetY)
            local fileIDs = table.concat(tile.fileDataIDs, ",")
            table.insert(output, string.format('        ["%s"] = "%s",', key, fileIDs))
            totalTiles = totalTiles + 1
        end
        
        table.insert(output, "    },")
    end
    
    table.insert(output, "}")
    
    -- Store as a table (array of lines) instead of one giant string
    AbstractUITileExport = output
    
    local estimatedSize = 0
    for _, line in ipairs(output) do
        estimatedSize = estimatedSize + #line + 1 -- +1 for newline
    end
    
    self:Print("=================================================================")
    self:Print("EXPORT COMPLETE!")
    self:Print("=================================================================")
    self:Print(string.format("Total: %d maps, %d tiles", #sortedMapIDs, totalTiles))
    self:Print(string.format("Lines: %d", #output))
    self:Print(string.format("Size: ~%.2f KB", estimatedSize / 1024))
    self:Print("")
    self:Print("Next steps:")
    self:Print("1. /logout (saves data to disk)")
    self:Print("2. Navigate to: WTF\\Account\\YOUR_ACCOUNT\\SavedVariables\\")
    self:Print("3. Open: AbstractUI.lua in a text editor")
    self:Print("4. Find: AbstractUITileExport = { (it's a table)")
    self:Print("5. Copy the entire table (all lines)")
    self:Print("6. Replace in Modules\\TileDatabase.lua")
    self:Print("")
    self:Print("TIP: The export is now a table of lines, much cleaner!")
    self:Print("=================================================================")
end

function TileExtractor:GetExtractedData()
    return extractedData
end

function TileExtractor:SaveToVariable()
    if not extractedData or not next(extractedData) then
        self:Print("No data to save. Run /extracttiles first.")
        return
    end
    
    -- Initialize if needed
    if not AbstractUITileData then
        AbstractUITileData = {}
    end
    
    -- Merge with existing data (allows combining extractions from multiple characters)
    local newMaps = 0
    local newTiles = 0
    
    for mapID, data in pairs(extractedData) do
        if not AbstractUITileData[mapID] then
            -- New map entirely
            AbstractUITileData[mapID] = data
            newMaps = newMaps + 1
            newTiles = newTiles + #data.tiles
        else
            -- Map exists, merge tiles
            local existingTiles = {}
            for _, tile in ipairs(AbstractUITileData[mapID].tiles) do
                local key = string.format("%d:%d:%d:%d", tile.width, tile.height, tile.offsetX, tile.offsetY)
                existingTiles[key] = tile
            end
            
            -- Add new tiles
            for _, tile in ipairs(data.tiles) do
                local key = string.format("%d:%d:%d:%d", tile.width, tile.height, tile.offsetX, tile.offsetY)
                if not existingTiles[key] then
                    table.insert(AbstractUITileData[mapID].tiles, tile)
                    newTiles = newTiles + 1
                else
                    -- Merge file IDs
                    local existingFileIDs = {}
                    for _, id in ipairs(existingTiles[key].fileDataIDs) do
                        existingFileIDs[id] = true
                    end
                    
                    for _, id in ipairs(tile.fileDataIDs) do
                        if not existingFileIDs[id] then
                            table.insert(existingTiles[key].fileDataIDs, id)
                        end
                    end
                end
            end
        end
    end
    
    self:Print("=======================================================")
    self:Print(string.format("Tile data merged into AbstractUITileData"))
    self:Print(string.format("Added: %d new maps, %d new tiles", newMaps, newTiles))
    self:Print(string.format("Total: %d maps in database", self:CountMaps(AbstractUITileData)))
    self:Print("=======================================================")
    self:Print("Access via: /dump AbstractUITileData")
    self:Print("Export via: /exportmerged")
end

function TileExtractor:CountMaps(data)
    local count = 0
    for _ in pairs(data) do
        count = count + 1
    end
    return count
end

function TileExtractor:ExportMerged()
    if not AbstractUITileData or not next(AbstractUITileData) then
        self:Print("No merged data found. Run /extracttiles then /savetiles first.")
        return
    end
    
    -- Sort map IDs
    local sortedMapIDs = {}
    for mapID in pairs(AbstractUITileData) do
        table.insert(sortedMapIDs, mapID)
    end
    table.sort(sortedMapIDs)
    
    local totalTiles = 0
    for _, mapID in ipairs(sortedMapIDs) do
        local data = AbstractUITileData[mapID]
        totalTiles = totalTiles + #data.tiles
    end
    
    self:Print("=================================================================")
    self:Print("Tile Database Ready for Export!")
    self:Print("=================================================================")
    self:Print(string.format("Total: %d maps, %d tiles", #sortedMapIDs, totalTiles))
    self:Print("")
    self:Print("The data is saved in your SavedVariables file.")
    self:Print("Follow these steps:")
    self:Print("")
    self:Print("1. /logout (saves AbstractUITileData to disk)")
    self:Print("2. Navigate to: WTF\\Account\\YOUR_ACCOUNT\\SavedVariables\\")
    self:Print("3. Open: AbstractUI.lua in a text editor")
    self:Print("4. Look for: AbstractUITileData = { ... }")
    self:Print("5. Run /exportfile to generate the conversion command")
    self:Print("")
    self:Print("Or use /exportchunks to export in smaller pieces")
    self:Print("=================================================================")
end

function TileExtractor:ExportInChunks()
    if not AbstractUITileData or not next(AbstractUITileData) then
        self:Print("No merged data found. Run /extracttiles then /savetiles first.")
        return
    end
    
    -- Sort map IDs
    local sortedMapIDs = {}
    for mapID in pairs(AbstractUITileData) do
        table.insert(sortedMapIDs, mapID)
    end
    table.sort(sortedMapIDs)
    
    local chunkSize = 20 -- Export 20 maps at a time
    local totalChunks = math.ceil(#sortedMapIDs / chunkSize)
    
    self:Print("=================================================================")
    self:Print(string.format("Exporting in %d chunks (%d maps per chunk)", totalChunks, chunkSize))
    self:Print("=================================================================")
    
    for chunk = 1, totalChunks do
        local startIdx = (chunk - 1) * chunkSize + 1
        local endIdx = math.min(chunk * chunkSize, #sortedMapIDs)
        
        self:Print("")
        self:Print(string.format("=== CHUNK %d of %d (Maps %d-%d) ===", chunk, totalChunks, startIdx, endIdx))
        
        for i = startIdx, endIdx do
            local mapID = sortedMapIDs[i]
            local data = AbstractUITileData[mapID]
            
            print(string.format("    [%d] = { -- %s", mapID, data.mapName))
            
            for _, tile in ipairs(data.tiles) do
                local key = string.format("%d:%d:%d:%d", tile.width, tile.height, tile.offsetX, tile.offsetY)
                local fileIDs = table.concat(tile.fileDataIDs, ",")
                print(string.format('        ["%s"] = "%s",', key, fileIDs))
            end
            
            print("    },")
        end
        
        if chunk < totalChunks then
            self:Print(string.format("--- Copy chunk %d, then type: /nextchunk ---", chunk))
            return -- Stop here, let user copy this chunk
        end
    end
    
    self:Print("")
    self:Print("=== EXPORT COMPLETE ===")
    self:Print("All chunks exported. Combine them in TileDatabase.lua")
end

-- Store chunk state
TileExtractor.currentChunk = 1
TileExtractor.totalChunksCount = 0
TileExtractor.sortedMapIDs = nil

function TileExtractor:StartChunkedExport()
    if not AbstractUITileData or not next(AbstractUITileData) then
        self:Print("No merged data found. Run /extracttiles then /savetiles first.")
        return
    end
    
    -- Sort map IDs
    self.sortedMapIDs = {}
    for mapID in pairs(AbstractUITileData) do
        table.insert(self.sortedMapIDs, mapID)
    end
    table.sort(self.sortedMapIDs)
    
    local chunkSize = 20
    self.totalChunksCount = math.ceil(#self.sortedMapIDs / chunkSize)
    self.currentChunk = 1
    
    self:Print("=================================================================")
    self:Print(string.format("Starting chunked export: %d chunks (%d maps total)", 
        self.totalChunksCount, #self.sortedMapIDs))
    self:Print("=================================================================")
    self:Print("Copy each chunk and combine them in TileDatabase.lua")
    self:Print("Type /nextchunk after copying each piece")
    self:Print("")
    
    self:ExportNextChunk()
end

function TileExtractor:ExportNextChunk()
    if not self.sortedMapIDs or self.currentChunk > self.totalChunksCount then
        self:Print("No chunked export in progress. Use /exportchunked to start.")
        return
    end
    
    local chunkSize = 20
    local startIdx = (self.currentChunk - 1) * chunkSize + 1
    local endIdx = math.min(self.currentChunk * chunkSize, #self.sortedMapIDs)
    
    self:Print(string.format("=== CHUNK %d of %d ===", self.currentChunk, self.totalChunksCount))
    
    if self.currentChunk == 1 then
        print("-- ============================================================================")
        print("-- AbstractUI Tile Database")
        print(string.format("-- Generated: %s", date("%Y-%m-%d %H:%M:%S")))
        print("-- ============================================================================")
        print("")
        print("local addonName, AbstractUI = ...")
        print("")
        print("AbstractUI.TileDatabase = {")
    end
    
    for i = startIdx, endIdx do
        local mapID = self.sortedMapIDs[i]
        local data = AbstractUITileData[mapID]
        
        print(string.format("    [%d] = { -- %s", mapID, data.mapName))
        
        for _, tile in ipairs(data.tiles) do
            local key = string.format("%d:%d:%d:%d", tile.width, tile.height, tile.offsetX, tile.offsetY)
            local fileIDs = table.concat(tile.fileDataIDs, ",")
            print(string.format('        ["%s"] = "%s",', key, fileIDs))
        end
        
        print("    },")
    end
    
    if self.currentChunk >= self.totalChunksCount then
        print("}")
        self:Print("")
        self:Print("=== EXPORT COMPLETE ===")
        self:Print("All data exported! Copy everything and paste into TileDatabase.lua")
        self.currentChunk = 1
        self.sortedMapIDs = nil
    else
        self:Print("")
        self:Print(string.format("Copied? Type /nextchunk for chunk %d of %d", 
            self.currentChunk + 1, self.totalChunksCount))
        self.currentChunk = self.currentChunk + 1
    end
end

function TileExtractor:ClearMerged()
    AbstractUITileData = nil
    self:Print("Merged database cleared. Start fresh with /extracttiles")
end

function TileExtractor:ShowMergedStats()
    if not AbstractUITileData or not next(AbstractUITileData) then
        self:Print("No merged data found.")
        return
    end
    
    local totalMaps = 0
    local totalTiles = 0
    local largestMap = nil
    local largestMapTiles = 0
    
    for mapID, data in pairs(AbstractUITileData) do
        totalMaps = totalMaps + 1
        totalTiles = totalTiles + #data.tiles
        
        if #data.tiles > largestMapTiles then
            largestMapTiles = #data.tiles
            largestMap = data.mapName
        end
    end
    
    self:Print("=======================================================")
    self:Print("Merged Database Statistics:")
    self:Print(string.format("Total Maps: %d", totalMaps))
    self:Print(string.format("Total Tiles: %d", totalTiles))
    self:Print(string.format("Average Tiles/Map: %.1f", totalTiles / totalMaps))
    self:Print(string.format("Largest Map: %s (%d tiles)", largestMap or "N/A", largestMapTiles))
    self:Print("=======================================================")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function TileExtractor:OnInitialize()
    self:RegisterChatCommand("extracttiles", "StartExtraction")
    self:RegisterChatCommand("exporttiles", "ExportToChat")
    self:RegisterChatCommand("savetiles", "SaveToVariable")
    self:RegisterChatCommand("exporttilesfile", "ExportToFile")
    self:RegisterChatCommand("exportmerged", "ExportMerged")
    self:RegisterChatCommand("exportfile", "ExportMergedToFile")
    self:RegisterChatCommand("exportchunked", "StartChunkedExport")
    self:RegisterChatCommand("nextchunk", "ExportNextChunk")
    self:RegisterChatCommand("clearmerged", "ClearMerged")
    self:RegisterChatCommand("mergedstats", "ShowMergedStats")
    
    -- Commented out to reduce chat spam on login
    -- self:Print("Tile Extractor loaded. Commands available:")
    -- self:Print("  /extracttiles - Begin extraction process")
    -- self:Print("  /savetiles - Save/merge to global variable")
    -- self:Print("  /mergedstats - Show merged database statistics")
    -- self:Print("  /exportfile - Write to SavedVariables file (RECOMMENDED)")
    -- self:Print("  /clearmerged - Clear merged data")
    -- self:Print("")
    -- self:Print("Multi-Character Workflow:")
    -- self:Print("  1. Character 1: /extracttiles then /savetiles")
    -- self:Print("  2. Character 2: /extracttiles then /savetiles (merges)")
    -- self:Print("  3. Character 3: /extracttiles then /savetiles (merges)")
    -- self:Print("  4. Any character: /exportfile then /logout")
    -- self:Print("  5. Copy from SavedVariables\\AbstractUI.lua file")
end

return TileExtractor
