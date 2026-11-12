<#
.SYNOPSIS
    Publishes addons from this repo into a local WoW installation.

.DESCRIPTION
    Copies <edition>\<Addon>\src to <game folder>\Interface\AddOns\<Addon>.
    If the target folder already exists, it is deleted first.
    The game folder for each edition comes from WOW_EDITIONS in the .env file
    next to this script (see .env.example).

.EXAMPLE
    .\publish.ps1 forever AskAI
    .\publish.ps1 forever all
    .\publish.ps1 forever AskAI TwistBar
    .\publish.ps1 -List
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Edition,

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Addon,

    [switch]$List
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$envFile = Join-Path $root '.env'

function Read-Editions {
    if (-not (Test-Path -LiteralPath $envFile)) {
        throw "Missing $envFile. Copy .env.example to .env and set your game folders."
    }
    $value = $null
    foreach ($line in Get-Content -LiteralPath $envFile) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        $i = $t.IndexOf('=')
        if ($i -lt 1) { continue }
        if ($t.Substring(0, $i).Trim() -eq 'WOW_EDITIONS') {
            $value = $t.Substring($i + 1).Trim()
        }
    }
    if (-not $value) { throw "WOW_EDITIONS is not set in $envFile." }
    try {
        $json = $value | ConvertFrom-Json
    } catch {
        throw "WOW_EDITIONS in $envFile is not valid JSON (use / or \\ in paths): $($_.Exception.Message)"
    }
    $map = @{}
    foreach ($p in $json.PSObject.Properties) { $map[$p.Name.ToLower()] = [string]$p.Value }
    return $map
}

function Get-AddonDirs([string]$editionDir) {
    Get-ChildItem -LiteralPath $editionDir -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'src') }
}

$editions = Read-Editions

if ($List -or -not $Edition) {
    Write-Host 'Editions (.env):'
    foreach ($k in $editions.Keys | Sort-Object) { Write-Host "  $k -> $($editions[$k])" }
    foreach ($k in $editions.Keys | Sort-Object) {
        $dir = Join-Path $root $k
        if (Test-Path -LiteralPath $dir) {
            Write-Host "Addons in ${k}:"
            Get-AddonDirs $dir | ForEach-Object { Write-Host "  $($_.Name)" }
        }
    }
    if (-not $Edition) { Write-Host "`nUsage: publish <edition> <addon...|all>" }
    exit 0
}

$key = $Edition.ToLower()
if (-not $editions.ContainsKey($key)) {
    throw "Unknown edition '$Edition'. Defined in .env: $(($editions.Keys | Sort-Object) -join ', ')"
}
$gameDir = $editions[$key]
if (-not (Test-Path -LiteralPath $gameDir)) { throw "Game folder for '$Edition' not found: $gameDir" }

$editionDir = Join-Path $root $key
if (-not (Test-Path -LiteralPath $editionDir)) { throw "No '$key' folder in the repo ($editionDir)." }

$available = @(Get-AddonDirs $editionDir)
if (-not $Addon -or $Addon.Count -eq 0) { throw "Name an addon, or 'all'. Available: $($available.Name -join ', ')" }

if ($Addon -contains 'all') {
    $selected = $available
} else {
    $selected = foreach ($a in $Addon) {
        $match = $available | Where-Object { $_.Name -ieq $a }
        if (-not $match) { throw "Addon '$a' not found in $key. Available: $($available.Name -join ', ')" }
        $match
    }
}

$addOnsDir = Join-Path $gameDir 'Interface\AddOns'
if (-not (Test-Path -LiteralPath $addOnsDir)) { New-Item -ItemType Directory -Path $addOnsDir -Force | Out-Null }

foreach ($dir in $selected) {
    $src = Join-Path $dir.FullName 'src'
    # WoW needs the folder name to match the .toc file name exactly.
    $toc = Get-ChildItem -LiteralPath $src -Filter '*.toc' -File | Select-Object -First 1
    $name = if ($toc) { $toc.BaseName } else { $dir.Name }
    if (-not $name) { throw "Could not determine addon name for $($dir.FullName)." }

    $target = Join-Path $addOnsDir $name
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }
    Copy-Item -LiteralPath $src -Destination $target -Recurse -Force
    Write-Host "Published $key/$name -> $target"
}
