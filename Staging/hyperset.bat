@ECHO OFF
title HyperPilot Test Terminal
set PATH=%PATH%;C:\resources
cd /d C:\resources
powershell.exe -ExecutionPolicy Bypass -WindowStyle Normal -NoProfile -NoExit -command "cls"
exit /b