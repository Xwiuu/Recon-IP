@echo off
REM ReconIP v2.0 — Launcher Windows
REM Tenta WSL, Git Bash, ou PowerShell

title ReconIP v2.0

where wsl >nul 2>nul
if %errorlevel% equ 0 (
    wsl bash ./reconip.sh %*
    exit /b %errorlevel%
)

where bash >nul 2>nul
if %errorlevel% equ 0 (
    bash ./reconip.sh %*
    exit /b %errorlevel%
)

powershell -ExecutionPolicy Bypass -File super_recon.ps1 %*
