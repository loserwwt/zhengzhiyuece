param(
  [string]$Root = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Format-FileSize {
  param([long]$Bytes)

  if ($Bytes -lt 1KB) { return "$Bytes B" }
  if ($Bytes -lt 1MB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
  if ($Bytes -lt 1GB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
  return "{0:N1} GB" -f ($Bytes / 1GB)
}

function ConvertTo-UrlPath {
  param([string]$RelativePath)

  $parts = $RelativePath -split "[\\/]+"
  $encoded = foreach ($part in $parts) {
    [System.Uri]::EscapeDataString($part)
  }
  return ($encoded -join "/")
}

$downloadsDir = Join-Path $Root "downloads"
$descriptionsPath = Join-Path $Root "file-descriptions.json"
$outputPath = Join-Path $Root "files.js"

if (-not (Test-Path -LiteralPath $downloadsDir)) {
  New-Item -ItemType Directory -Path $downloadsDir | Out-Null
}

$descriptionMap = @{}
if (Test-Path -LiteralPath $descriptionsPath) {
  $rawDescriptions = Get-Content -LiteralPath $descriptionsPath -Raw -Encoding UTF8
  if ($rawDescriptions.Trim()) {
    $descriptionObject = $rawDescriptions | ConvertFrom-Json
    foreach ($property in $descriptionObject.PSObject.Properties) {
      $descriptionMap[$property.Name] = [string]$property.Value
    }
  }
}

$downloadRoot = (Resolve-Path -LiteralPath $downloadsDir).Path
$files = @()

Get-ChildItem -LiteralPath $downloadsDir -File -Recurse |
  Where-Object { $_.Name -ne ".gitkeep" } |
  Sort-Object -Property @{ Expression = "LastWriteTime"; Descending = $true }, @{ Expression = "Name"; Ascending = $true } |
  ForEach-Object {
    $relativePath = $_.FullName.Substring($downloadRoot.Length).TrimStart("\", "/")
    $relativePath = $relativePath -replace "\\", "/"
    $description = $descriptionMap[$relativePath]
    if (-not $description) {
      $description = $descriptionMap[$_.Name]
    }

    $files += [ordered]@{
      name = $_.Name
      path = "downloads/$(ConvertTo-UrlPath $relativePath)"
      size = Format-FileSize $_.Length
      bytes = $_.Length
      modified = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
      modifiedIso = $_.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")
      description = $description
      extension = $_.Extension.TrimStart(".").ToLowerInvariant()
    }
  }

$generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm")
$json = if ($files.Count -eq 0) { "[]" } else { ConvertTo-Json -InputObject @($files) -Depth 5 }
$content = @"
window.DOWNLOAD_META = {
  generatedAt: "$generatedAt",
};

window.DOWNLOAD_FILES = $json;
"@

Set-Content -LiteralPath $outputPath -Value $content -Encoding UTF8
Write-Host "Updated $outputPath with $($files.Count) file(s)."
