# ============================================================================
# AbstractUI Tile Database Converter
# ============================================================================
# This script converts the AbstractUITileData from SavedVariables
# into the format needed for Modules/TileDatabase.lua
#
# Usage:
#   1. Run /extracttiles and /savetiles in-game on all characters
#   2. /logout to save data to disk
#   3. Run this script: .\convert_savedvariables.ps1
#   4. Output is saved to: Modules/TileDatabase.lua
# ============================================================================

Write-Host "AbstractUI Tile Database Converter" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Find WoW directory
$wowPaths = @(
    "$env:ProgramFiles\World of Warcraft",
    "${env:ProgramFiles(x86)}\World of Warcraft",
    "C:\World of Warcraft",
    "D:\World of Warcraft",
    "C:\Program Files\World of Warcraft"
)

$wowPath = $null
foreach ($path in $wowPaths) {
    if (Test-Path $path) {
        $wowPath = $path
        break
    }
}

if (-not $wowPath) {
    Write-Host "ERROR: Could not find World of Warcraft installation" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please specify your WoW path:"
    $wowPath = Read-Host "Path"
    
    if (-not (Test-Path $wowPath)) {
        Write-Host "Invalid path. Exiting." -ForegroundColor Red
        exit 1
    }
}

Write-Host "WoW Installation: $wowPath" -ForegroundColor Green

# Find SavedVariables
$savedVarsPath = Join-Path $wowPath "WTF\Account"
$accounts = Get-ChildItem -Path $savedVarsPath -Directory | Where-Object { $_.Name -notmatch "^SavedVariables$" }

if ($accounts.Count -eq 0) {
    Write-Host "ERROR: No account folders found" -ForegroundColor Red
    exit 1
}

if ($accounts.Count -eq 1) {
    $accountFolder = $accounts[0].Name
} else {
    Write-Host ""
    Write-Host "Multiple accounts found. Select one:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $accounts.Count; $i++) {
        Write-Host "  [$i] $($accounts[$i].Name)"
    }
    $selection = Read-Host "Account number"
    $accountFolder = $accounts[[int]$selection].Name
}

$abstractUILuaPath = Join-Path $savedVarsPath "$accountFolder\SavedVariables\AbstractUI.lua"

if (-not (Test-Path $abstractUILuaPath)) {
    Write-Host "ERROR: AbstractUI.lua not found at:" -ForegroundColor Red
    Write-Host "  $abstractUILuaPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Make sure you:" -ForegroundColor Yellow
    Write-Host "  1. Ran /extracttiles and /savetiles in-game"
    Write-Host "  2. Logged out to save the data"
    exit 1
}

Write-Host "Found: $abstractUILuaPath" -ForegroundColor Green
Write-Host ""
Write-Host "Reading SavedVariables..." -ForegroundColor Cyan

# Read the SavedVariables file
$content = Get-Content -Path $abstractUILuaPath -Raw

# Check if AbstractUITileData exists
if ($content -notmatch 'AbstractUITileData\s*=\s*\{') {
    Write-Host "ERROR: AbstractUITileData not found in SavedVariables" -ForegroundColor Red
    Write-Host "Run /extracttiles and /savetiles in-game first." -ForegroundColor Yellow
    exit 1
}

Write-Host "Processing tile data..." -ForegroundColor Cyan

# Convert the format (this is a simplified approach - the data structure should be similar)
# Extract just the AbstractUITileData table
if ($content -match 'AbstractUITileData\s*=\s*(\{[\s\S]*?\n\})(?:\nAbstract|\Z)') {
    $tileDataSection = $matches[1]
    
    # Count maps and tiles (approximate)
    $mapCount = ([regex]::Matches($tileDataSection, '\["mapID"\]')).Count
    $tileCount = ([regex]::Matches($tileDataSection, '\["tiles"\]')).Count
    
    Write-Host "Found: $mapCount maps" -ForegroundColor Green
    
    # Generate output file
    $outputPath = Join-Path $PSScriptRoot "Modules\TileDatabase.lua"
    
    $output = @"
-- ============================================================================
-- AbstractUI Tile Database
-- ============================================================================
-- Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
-- Converted from SavedVariables
-- ============================================================================

local addonName, AbstractUI = ...

-- NOTE: This conversion is semi-automated
-- You may need to manually format the data structure
-- The original data from SavedVariables uses a different format

-- Original SavedVariables data:
--[[
$tileDataSection
]]--

-- TODO: Convert the above data to this format:
AbstractUI.TileDatabase = {
    -- [mapID] = {
    --     ["width:height:offsetX:offsetY"] = "fileDataID1,fileDataID2",
    -- },
}
"@

    $output | Out-File -FilePath $outputPath -Encoding UTF8
    
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "Partial conversion saved to:" -ForegroundColor Green
    Write-Host "  $outputPath" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT:" -ForegroundColor Yellow
    Write-Host "  The SavedVariables format needs manual conversion."
    Write-Host "  Use /exportchunked in-game instead for automatic formatting."
    Write-Host "=====================================" -ForegroundColor Cyan
    
} else {
    Write-Host "ERROR: Could not parse AbstractUITileData structure" -ForegroundColor Red
    exit 1
}
