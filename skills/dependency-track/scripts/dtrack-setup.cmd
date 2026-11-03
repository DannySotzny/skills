@echo off
rem Windows launcher for dtrack-setup.sh - runs it with Git Bash (Git for Windows)
rem Usage: dtrack-setup.cmd [--check ^| --status ^| --url URL ^| --key]
setlocal
set "DT_BASH="
for %%P in ("%ProgramFiles%\Git\bin\bash.exe" "%ProgramW6432%\Git\bin\bash.exe" "%LocalAppData%\Programs\Git\bin\bash.exe") do (
    if not defined DT_BASH if exist "%%~P" set "DT_BASH=%%~P"
)
if not defined DT_BASH for /f "delims=" %%G in ('where git.exe 2^>nul') do (
    if not defined DT_BASH if exist "%%~dpG..\bin\bash.exe" set "DT_BASH=%%~dpG..\bin\bash.exe"
)
if not defined DT_BASH (
    echo ERROR: Git Bash not found. Install Git for Windows: winget install Git.Git 1>&2
    exit /b 1
)
rem Forward slashes, so the script can locate its sibling files
set "DT_SCRIPT=%~dp0dtrack-setup.sh"
set "DT_SCRIPT=%DT_SCRIPT:\=/%"
"%DT_BASH%" "%DT_SCRIPT%" %*
exit /b %ERRORLEVEL%
