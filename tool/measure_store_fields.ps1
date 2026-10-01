#Requires -Version 5.1
<#
.SYNOPSIS
    Measures the Google Play text fields against their character limits.

.DESCRIPTION
    Reads the fenced blocks in store/listing.md and
    store/release-notes-1.0.0.md, measures each one, and compares the result
    to the Play Console limit. Exits non-zero if any field is over its limit.

    Each block is located relative to its section heading rather than by
    position, so adding or removing an unrelated fenced block elsewhere in the
    file cannot silently change which text gets measured.

    Both store documents quote the length their field must have. If you edit a
    field, update that quote as well, or this script's numbers and the prose
    will disagree.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tool\measure_store_fields.ps1
#>
[CmdletBinding()]
param(
    [string] $Root
)

$ErrorActionPreference = 'Stop'

# Resolved in the body rather than as a param default: $PSScriptRoot is not
# reliably populated while parameter defaults are evaluated in 5.1.
if (-not $Root) {
    $Root = Split-Path -Parent $PSScriptRoot
}

# Three backticks, built from a char code so this file can document fences
# without containing any.
$fence = [string][char]96 * 3

function Get-FirstFenceIndex {
    param($Lines, [string] $Name)

    for ($i = 0; $i -lt $Lines.Length; $i++) {
        if ($Lines[$i] -eq $fence) { return $i }
    }
    throw "No fenced block found in $Name"
}

function Get-FenceIndex {
    param($Lines, [string] $Heading)

    for ($i = 0; $i -lt $Lines.Length; $i++) {
        if ($Lines[$i] -eq $Heading) {
            for ($j = $i; $j -lt $Lines.Length; $j++) {
                if ($Lines[$j] -eq $fence) { return $j }
            }
        }
    }
    throw "No fenced block found for heading '$Heading'"
}

function Measure-Field {
    param($Lines, [int] $OpenAt, [string] $Name, [int] $Limit)

    $close = -1
    for ($i = $OpenAt + 1; $i -lt $Lines.Length; $i++) {
        if ($Lines[$i] -eq $fence) { $close = $i; break }
    }
    if ($close -lt 0) {
        throw "$Name : fence at line $($OpenAt + 1) is never closed"
    }

    $text = $Lines[($OpenAt + 1)..($close - 1)] -join "`n"
    $len = $text.Length

    [pscustomobject]@{
        Field  = $Name
        Length = $len
        Limit  = $Limit
        Status = if ($len -le $Limit) { 'OK' } else { 'OVER LIMIT' }
    }
}

$listing = [IO.File]::ReadAllLines((Join-Path $Root 'store\listing.md'))
$notes = [IO.File]::ReadAllLines((Join-Path $Root 'store\release-notes-1.0.0.md'))

$results = @(
    Measure-Field -Lines $listing `
        -OpenAt (Get-FenceIndex $listing '## Short description') `
        -Name 'short description' -Limit 80
    Measure-Field -Lines $listing `
        -OpenAt (Get-FenceIndex $listing '## Full description') `
        -Name 'full description' -Limit 4000
    Measure-Field -Lines $notes `
        -OpenAt (Get-FirstFenceIndex $notes 'store\release-notes-1.0.0.md') `
        -Name 'release notes' -Limit 500
)

$results | Format-Table -AutoSize | Out-String | Write-Output

$over = @($results | Where-Object { $_.Status -ne 'OK' })
foreach ($f in $over) {
    Write-Error ("{0} is {1} characters, over its limit of {2} by {3}" -f
            $f.Field, $f.Length, $f.Limit, ($f.Length - $f.Limit))
}

if ($over.Count -gt 0) { exit 1 }

Write-Output 'All Play text fields are within their limits.'
exit 0
