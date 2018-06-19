@ECHO OFF

REM LuaWebGen operates on the current folder, so let's navigate into testsite first.
CD testsite

REM Build testsite with LuaWebGen.
..\webgen.exe build

REM This would also work instead of the previous line:
REM lua ../main.lua build
