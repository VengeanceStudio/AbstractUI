-- ============================================================================
-- Macro Icon Data Provider
-- ============================================================================
-- Provides icon file name data for the Macro Icon Selector module
-- ============================================================================

local _, ns = ...

LargerMacroIconSelectionData = {}

function LargerMacroIconSelectionData:GetFileData()
    return ns.ICON_FILE_NAMES
end

-- Make it accessible globally
_G.LargerMacroIconSelectionData = LargerMacroIconSelectionData
