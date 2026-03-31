@echo off
REM ============================================================
REM Tom Spark's ARR Stack — Folder Structure Setup (Windows)
REM https://github.com/loponai/arrstack
REM
REM Creates the folder structure required for hard links.
REM Run this ONCE before starting the stack.
REM
REM Edit DATA_DIR below if your media drive is different.
REM ============================================================

set DATA_DIR=D:\data

echo.
echo === Tom Spark's ARR Stack — Folder Setup (Windows) ===
echo.
echo Creating folder structure at %DATA_DIR%...
echo.

mkdir "%DATA_DIR%\torrents\movies" 2>nul
mkdir "%DATA_DIR%\torrents\tv" 2>nul
mkdir "%DATA_DIR%\torrents\music" 2>nul
mkdir "%DATA_DIR%\media\movies" 2>nul
mkdir "%DATA_DIR%\media\tv" 2>nul
mkdir "%DATA_DIR%\media\music" 2>nul

echo Done! Folder structure:
echo.
echo   %DATA_DIR%\
echo   +-- torrents\
echo   ¦   +-- movies\
echo   ¦   +-- tv\
echo   ¦   +-- music\
echo   +-- media\
echo       +-- movies\
echo       +-- tv\
echo       +-- music\
echo.
echo IMPORTANT: For hard links to work, torrents and media
echo must be on the SAME drive (both under %DATA_DIR%).
echo.

pause
