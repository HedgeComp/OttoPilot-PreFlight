@echo off
cd /d "%~dp0"
powershell.exe -executionpolicy bypass -windowstyle Normal -Noprofile -file ".\staging\postflight.ps1"
pause