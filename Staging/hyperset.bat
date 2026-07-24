@ECHO OFF
title HyperPilot Test Terminal
set PATH=%PATH%;C:\resources
cd /d C:\resources
rem powershell.exe -ExecutionPolicy Bypass -WindowStyle Normal -NoProfile -NoExit -command "cls"
powershell.exe -ExecutionPolicy Bypass -WindowStyle Normal -NoProfile -NoExit -command ^
"Add-Type -Name Win -Namespace Console -MemberDefinition '[DllImport(\"kernel32.dll\")] public static extern IntPtr GetConsoleWindow(); [DllImport(\"user32.dll\")] public static extern bool SetForegroundWindow(IntPtr hWnd);'; [Console.Win]::SetForegroundWindow([Console.Win]::GetConsoleWindow()); cls"
exit /b