param(
  [int]$Port = 8765,
  [string]$Root = $PSScriptRoot,
  [switch]$NoBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ContentType {
  param([string]$Path)

  switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
    ".html" { return "text/html; charset=utf-8" }
    ".css" { return "text/css; charset=utf-8" }
    ".js" { return "application/javascript; charset=utf-8" }
    ".json" { return "application/json; charset=utf-8" }
    ".txt" { return "text/plain; charset=utf-8" }
    ".svg" { return "image/svg+xml" }
    ".png" { return "image/png" }
    ".jpg" { return "image/jpeg" }
    ".jpeg" { return "image/jpeg" }
    ".gif" { return "image/gif" }
    ".webp" { return "image/webp" }
    ".pdf" { return "application/pdf" }
    ".xlsx" { return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
    ".xls" { return "application/vnd.ms-excel" }
    ".docx" { return "application/vnd.openxmlformats-officedocument.wordprocessingml.document" }
    ".doc" { return "application/msword" }
    ".zip" { return "application/zip" }
    default { return "application/octet-stream" }
  }
}

function ConvertTo-LocalPath {
  param(
    [string]$UrlPath,
    [string]$RootPath
  )

  $decodedPath = [System.Uri]::UnescapeDataString($UrlPath).TrimStart("/")
  if ([string]::IsNullOrWhiteSpace($decodedPath)) {
    $decodedPath = "index.html"
  }

  $relativePath = $decodedPath -replace "/", [System.IO.Path]::DirectorySeparatorChar
  $rootFull = [System.IO.Path]::GetFullPath($RootPath)
  $localPath = [System.IO.Path]::GetFullPath((Join-Path $rootFull $relativePath))

  if (-not $localPath.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Forbidden path"
  }

  return $localPath
}

$rootFullPath = [System.IO.Path]::GetFullPath($Root)
$downloadsFullPath = [System.IO.Path]::GetFullPath((Join-Path $rootFullPath "downloads"))
$prefix = "http://127.0.0.1:$Port/"

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)

try {
  $listener.Start()
  if (-not $NoBrowser) {
    Start-Process $prefix
  }
  Write-Host "Local download site is running:"
  Write-Host "  $prefix"
  Write-Host ""
  Write-Host "Keep this window open while using the site. Press Ctrl+C to stop."

  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $response = $context.Response

    try {
      $localPath = ConvertTo-LocalPath -UrlPath $context.Request.Url.AbsolutePath -RootPath $rootFullPath
      if ((Test-Path -LiteralPath $localPath -PathType Container)) {
        $localPath = Join-Path $localPath "index.html"
      }

      if (-not (Test-Path -LiteralPath $localPath -PathType Leaf)) {
        $response.StatusCode = 404
        $notFound = [System.Text.Encoding]::UTF8.GetBytes("Not found")
        $response.OutputStream.Write($notFound, 0, $notFound.Length)
        continue
      }

      $isDownloadFile = $localPath.StartsWith($downloadsFullPath, [System.StringComparison]::OrdinalIgnoreCase)
      if ($isDownloadFile) {
        $fileName = [System.IO.Path]::GetFileName($localPath)
        $encodedFileName = [System.Uri]::EscapeDataString($fileName)
        $response.ContentType = "application/octet-stream"
        $response.AddHeader("Content-Disposition", "attachment; filename*=UTF-8''$encodedFileName")
        $response.AddHeader("X-Content-Type-Options", "nosniff")
      } else {
        $response.ContentType = Get-ContentType $localPath
      }

      $response.AddHeader("Cache-Control", "no-store")
      $fileStream = [System.IO.File]::OpenRead($localPath)
      try {
        $response.ContentLength64 = $fileStream.Length
        $fileStream.CopyTo($response.OutputStream)
      } finally {
        $fileStream.Dispose()
      }
    } catch {
      if ($response.StatusCode -eq 200) {
        $response.StatusCode = 500
      }
      $message = [System.Text.Encoding]::UTF8.GetBytes("Server error")
      $response.OutputStream.Write($message, 0, $message.Length)
    } finally {
      $response.OutputStream.Close()
    }
  }
} finally {
  if ($listener.IsListening) {
    $listener.Stop()
  }
  $listener.Close()
}
