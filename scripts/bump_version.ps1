# Flutter App Version Auto-Increment Script using Git
# Function: Auto-increment version when building APK
# Rule: patch +1, build +1

$pubspecPath = Join-Path $PSScriptRoot "..\pubspec.yaml"

Write-Host "Starting version update..."

# Read file line by line
$lines = Get-Content -Path $pubspecPath -Encoding UTF8
$foundVersion = $false
$newLines = @()

foreach ($line in $lines) {
    if ($line -match '^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$') {
        $currentVersion = $matches[1]
        Write-Host "Current version: $currentVersion"
        
        # Parse version parts
        $parts = $currentVersion -split '\.'
        $major = [int]$parts[0]
        $minor = [int]$parts[1]
        $patchAndBuild = $parts[2] -split '\+'
        $patch = [int]$patchAndBuild[0]
        $build = [int]$patchAndBuild[1]
        
        # Increment version: patch +1, build +1
        $newPatch = $patch + 1
        $newBuild = $build + 1
        
        $newVersion = "$major.$minor.$newPatch+$newBuild"
        
        Write-Host "New version: $newVersion"
        Write-Host "  - Version: $major.$minor.$newPatch (+0.0$($newPatch - $patch))"
        Write-Host "  - Build number: +$($newBuild - $build) (current: $newBuild)"
        
        # Replace version line
        $newLine = $line -replace $currentVersion, $newVersion
        $newLines += $newLine
        $foundVersion = $true
        
        Write-Host ""
        Write-Host "Version info:"
        Write-Host "   Old version: $currentVersion"
        Write-Host "   New version: $newVersion"
    } else {
        $newLines += $line
    }
}

if (-not $foundVersion) {
    Write-Host "Error: Version not found in pubspec.yaml"
    exit 1
}

# Write back to file
$newLines | Set-Content -Path $pubspecPath -Encoding UTF8

Write-Host ""
Write-Host "Version updated successfully!"
Write-Host "Saved to: $pubspecPath"

# Use git to verify and show the change
Write-Host ""
Write-Host "Git diff:"
git diff $pubspecPath

Write-Host ""
Write-Host "✅ Done! You can now build the APK"
