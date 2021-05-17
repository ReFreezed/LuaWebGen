@ECHO OFF
CD /D "%~dp0.."
lua build/build.lua %*
