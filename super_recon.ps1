#!/usr/bin/env pwsh
# super_recon.ps1 — Wrapper PowerShell para ReconIP
# Tenta WSL, depois Git Bash, depois avisa

$ErrorActionPreference = "Stop"

Write-Host "[*] ReconIP v2.0 — Wrapper Windows" -ForegroundColor Cyan
Write-Host ""

# Tenta WSL
$wsl = Get-Command wsl -ErrorAction SilentlyContinue
if ($wsl) {
    Write-Host "[*] WSL detectado. Executando via WSL..." -ForegroundColor Cyan
    wsl bash ./reconip.sh @args
    exit $LASTEXITCODE
}

# Tenta Git Bash
$bash = Get-Command bash -ErrorAction SilentlyContinue
if ($bash) {
    Write-Host "[*] Git Bash detectado. Executando..." -ForegroundColor Cyan
    bash.exe ./reconip.sh @args
    exit $LASTEXITCODE
}

Write-Host "[!] Nenhum shell Bash encontrado." -ForegroundColor Red
Write-Host "[!] Instale WSL (recomendado) ou Git Bash." -ForegroundColor Yellow
Write-Host ""
Write-Host "WSL:     wsl --install (Admin PowerShell)" -ForegroundColor Gray
Write-Host "Git Bash: https://git-scm.com" -ForegroundColor Gray
exit 1
