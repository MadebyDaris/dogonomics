@echo off
:: DogoHub Windows Launcher
:: Runs the DogoHub TUI from the root directory

cd /d %~dp0\..\..\..
echo Compiling and launching DogoHub TUI Mode...
go run dogonomics.go --hub
pause
