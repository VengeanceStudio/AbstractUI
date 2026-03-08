# ============================================================================
# Convert AbstractUITileExport Table to TileDatabase.lua
# ============================================================================
# This script reads the AbstractUITileExport table from SavedVariables
# and converts it back to the TileDatabase.lua file format
# ============================================================================

param(
    [string]$WoWPath = "",
    [string]$AccountName = ""
)

Write-Host "AbstractUI Tile Export Converter" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Find WoW directory if not provided
if (-not $WoWPath) {
    $wowPaths = @(
        "${env:ProgramFiles(x86)}\World of Warcraft\_retail_",
        "$env:ProgramFiles\World of Warcraft\_retail_",
        "C:\Program Files (x86)\World of Warcraft\_retail_",
        "C:\World of Warcraft\_retail_",
        "D:\World of Warcraft\_retail_"
    )
    
    foreach ($path in $wowPaths) {
        if (Test-Path $path) {
            $WoWPath = $path
            break
        }
    }
    
    if (-not $WoWPath) {
        Write-Host "Could not find WoW Retail installation. Please specify:" -ForegroundColor Yellow
        $WoWPath = Read-Host "WoW Retail Path"
    }
}

Write-Host "WoW Path: $WoWPath" -ForegroundColor Green

# Find SavedVariables
$savedVarsPath = Join-Path $WoWPath "WTF\Account"

if (-not (Test-Path $savedVarsPath)) {
    Write-Host "ERROR: SavedVariables path not found!" -ForegroundColor Red
    exit 1
}

# Get account folders
$accounts = Get-ChildItem -Path $savedVarsPath -Directory | Where-Object { 
    $_.Name -notmatch "^SavedVariables$" 
}

if ($accounts.Count -eq 0) {
    Write-Host "ERROR: No account folders found" -ForegroundColor Red
    exit 1
}

# Select account
if (-not $AccountName -and $accounts.Count -eq 1) {
    $AccountName = $accounts[0].Name
} elseif (-not $AccountName) {
    Write-Host "Select account:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $accounts.Count; $i++) {
        Write-Host "  [$i] $($accounts[$i].Name)"
    }
    $selection = Read-Host "Account number"
    $AccountName = $accounts[[int]$selection].Name
}

Write-Host "Account: $AccountName" -ForegroundColor Green

# Read AbstractUI.lua
$abstractUIPath = Join-Path $savedVarsPath "$AccountName\SavedVariables\AbstractUI.lua"

if (-not (Test-Path $abstractUIPath)) {
    Write-Host "ERROR: AbstractUI.lua not found at:" -ForegroundColor Red
    Write-Host "  $abstractUIPath" -ForegroundColor Red
    exit 1
}

Write-Host "Reading: AbstractUI.lua..." -ForegroundColor Cyan
$content = Get-Content -Path $abstractUIPath -Raw

# Check if AbstractUITileExport exists
if ($content -notmatch 'AbstractUITileExport\s*=\s*\{') {
    Write-Host "ERROR: AbstractUITileExport not found!" -ForegroundColor Red
    Write-Host "Make sure you ran /exportfile in-game and logged out." -ForegroundColor Yellow
    exit 1
}

Write-Host "Found AbstractUITileExport table!" -ForegroundColor Green
Write-Host ""

# Extract the table
if ($content -match 'AbstractUITileExport\s*=\s*\{([\s\S]*?)\n\}') {
    $tableContent = $Matches[1]
    
    # Extract all quoted strings (handles escaped quotes inside strings)
    # Pattern: "..." where content can contain \" and other escape sequences
    $lines = [regex]::Matches($tableContent, '"((?:[^"\\]|\\.)*)"') | ForEach-Object {
        $line = $_.Groups[1].Value
        # Unescape Lua escape sequences
        $line = $line -replace '\\(.)', '$1'  # Convert \x to x for all escape sequences
        $line
    }
    
    if ($lines.Count -gt 0) {
        Write-Host "Extracted $($lines.Count) lines" -ForegroundColor Green
        Write-Host ""
        
        # Write output
        $outputPath = Join-Path $PSScriptRoot "Modules\TileDatabase.lua"
        $lines | Out-File -FilePath $outputPath -Encoding UTF8
        
        Write-Host "=================================" -ForegroundColor Cyan
        Write-Host "SUCCESS!" -ForegroundColor Green
        Write-Host "=================================" -ForegroundColor Cyan
        Write-Host "Output saved to:" -ForegroundColor White
        Write-Host "  $outputPath" -ForegroundColor Green
        Write-Host ""
        Write-Host "File size: $([math]::Round((Get-Item $outputPath).Length / 1KB, 2)) KB" -ForegroundColor White
        Write-Host "Lines: $($lines.Count)" -ForegroundColor White
    } else {
        Write-Host "ERROR: Could not extract lines from table" -ForegroundColor Red
        Write-Host ""
        Write-Host "Manual method:" -ForegroundColor Yellow
        Write-Host "1. Open $abstractUIPath" -ForegroundColor White
        Write-Host "2. Find AbstractUITileExport = {" -ForegroundColor White
        Write-Host "3. Copy all the quoted strings" -ForegroundColor White
        Write-Host "4. Paste into Modules\TileDatabase.lua" -ForegroundColor White
    }
} else {
    Write-Host "ERROR: Could not parse AbstractUITileExport table" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual method:" -ForegroundColor Yellow
    Write-Host "1. Open $abstractUIPath" -ForegroundColor White
    Write-Host "2. Find AbstractUITileExport = {" -ForegroundColor White
    Write-Host "3. Copy all the lines (each [n] = \"...\" entry)" -ForegroundColor White
    Write-Host "4. Manually reconstruct in Modules\TileDatabase.lua" -ForegroundColor White
}
