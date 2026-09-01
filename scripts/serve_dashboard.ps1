# Local dashboard + docs server (no Docker required)
param(
  [int]$Port = 8888,
  [string]$Root = (Join-Path (Split-Path $PSScriptRoot -Parent) "docs")
)
Set-Location $Root
Write-Host "CardOpsAI dashboard: http://localhost:$Port/dashboard.html"
Write-Host "Docs index:         http://localhost:$Port/index.html"
Write-Host "Press Ctrl+C to stop"
python -m http.server $Port
