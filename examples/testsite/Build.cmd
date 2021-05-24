@ECHO OFF

REM  LuaWebGen operates on the current directory, so let's make
REM  sure we're in the directory containing this script.
CD /D "%~dp0"

REM  Build the website with LuaWebGen.
..\..\webgen.exe build

REM  This would also work instead of the previous line:
REM  lua ../../webgen.lua build
