# ============================================================================
# AbstractUI Tile Database Converter
# ============================================================================
# NOTE: With the new export system, this script is no longer needed!
# 
# The /exportfile command now creates AbstractUITileExport variable in
# AbstractUI.lua which is already properly formatted.
#
# Usage:
#   1. Run /exportfile in-game
#   2. /logout
#   3. Open SavedVariables/AbstractUI.lua
#   4. Search for: AbstractUITileExport = "..."
#   5. Copy the string value
#   6. Paste into Modules/TileDatabase.lua
# ============================================================================

Write-Host "AbstractUI Tile Database Converter" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTE: This script is no longer needed!" -ForegroundColor Yellow
Write-Host ""
Write-Host "The new export system creates AbstractUITileExport variable" -ForegroundColor Green
Write-Host "in AbstractUI.lua which is already formatted." -ForegroundColor Green
Write-Host ""
Write-Host "Just:" -ForegroundColor Cyan
Write-Host "  1. Run /exportfile in-game" -ForegroundColor White
Write-Host "  2. /logout" -ForegroundColor White
Write-Host "  3. Open SavedVariables/AbstractUI.lua" -ForegroundColor White
Write-Host "  4. Search for: AbstractUITileExport" -ForegroundColor White
Write-Host "  5. Copy the string value" -ForegroundColor White
Write-Host "  6. Paste into Modules/TileDatabase.lua" -ForegroundColor White
Write-Host ""
