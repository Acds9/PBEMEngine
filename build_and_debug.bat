@echo off
jai build.jai
if %ERRORLEVEL% == 0 (
    raddbg bin\PBEM.exe
)