-- ============================================================================
-- Macro Icon Data Provider
-- ============================================================================
-- Provides icon file name data for the Macro Icon Selector module
-- ============================================================================

LargerMacroIconSelectionData = {}

function LargerMacroIconSelectionData:GetFileData()
    return _G.ICON_FILE_NAMES or {}
end

-- Make it accessible globally
_G.LargerMacroIconSelectionData = LargerMacroIconSelectionData
