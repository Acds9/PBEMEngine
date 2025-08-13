@echo off
jai build.jai
if %ERRORLEVEL% == 0 (
    bin\PBEM.exe
)