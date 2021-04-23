--[[============================================================
--=
--=  Build script
--=
--=  Requires LuaFileSystem!
--=  Preparing a release requires a lot more things!
--=
--=-------------------------------------------------------------
--=
--=  LuaWebGen - static website generator in Lua!
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See LICENSE.txt)
--=
--============================================================]]

io.stdout:setvbuf("no")
io.stderr:setvbuf("no")
collectgarbage("stop")

print("Building...")
local buildStartTime = os.clock()

local DIR_HERE = debug.getinfo(1, "S").source:match"^@(.+)":gsub("\\", "/"):gsub("/?[^/]+$", ""):gsub("^$", ".")

local pp  = require"build.preprocess"
local lfs = require"lfs"

local devMode   = false
local doRelease = false

--
-- Parse args
--

if arg[1] == "dev" then
	devMode = true

elseif arg[1] == "release" then
	doRelease = true

elseif arg[1] then
	error("Unknown mode '"..arg.."'.")
end

assert(not (devMode and doRelease))

--
-- Metaprogram stuff
--

local metaEnv = pp.metaEnvironment

metaEnv.DEV = devMode

metaEnv.lfs = lfs

local chunk = assert(loadfile"build/meta.lua")
setfenv(chunk, metaEnv)
chunk()

setmetatable(_G, {__index=metaEnv})

--
-- Build!
--

makeDirectory("srcgen")

traverseDirectory("src", function(pathIn)
	if pathIn:find"%.lua$" then
		local pathOut = pathIn:gsub("^src/", "srcgen/")

		if pathOut:find("/", 1, true) then
			local dir = pathOut:gsub("/[^/]+$", "")
			makeDirectoryRecursive(dir)
		end

		copyFile(pathIn, pathOut)

	elseif pathIn:find"%.lua2p$" then
		local pathOut = (
			(pathIn:find"/main.lua2p$" and "webgen.lua") or
			pathIn:gsub("^src/", "srcgen/"):gsub("%.lua2p$", ".lua")
		)

		if pathOut:find("/", 1, true) then
			local dir = pathOut:gsub("/[^/]+$", "")
			makeDirectoryRecursive(dir)
		end

		pp.processFile{
			pathIn   = pathIn,
			pathOut  = pathOut,
			pathMeta = pathOut:gsub("%.%w+$", ".meta%0"),

			debug           = false,
			backtickStrings = true,
			canOutputNil    = false,

			onError = function(err)
				os.exit(1)
			end,
		}
	end
end)

printf("Build completed in %.3f seconds!", os.clock()-buildStartTime)

--
-- Prepare release
--

if doRelease then
	print("Preparing release...")

	local params = loadParams()

	local outputDirWin32     = "output/win32/LuaWebGen"
	local outputDirUniversal = "output/universal/LuaWebGen"

	local values
	do
		local versionStr, major,minor,patch = getReleaseVersion()

		values = {
			exeName  = "webgen",
			exePath  = outputDirWin32.."/webgen.exe",
			iconPath = "temp/appIcon.ico",

			appName         = "LuaWebGen",
			appNameShort    = "LuaWebGen", -- Should be less than 16 characters long.
			appNameInternal = "LuaWebGen",

			appVersion      = versionStr,
			appVersionMajor = major,
			appVersionMinor = minor,
			appVersionPatch = patch,
			appIdentifier   = "com.refreezed.luawebgen",

			companyName = "",
			copyright   = os.date"Copyright 2018-%Y Marcus 'ReFreezed' Thunström",

			versionInfoPath = "temp/appInfo.res",
		}
	end

	makeDirectory("temp")

	do
		-- Create missing icon sizes.
		for _, size in ipairs{--[[16,]]24,32,48,64,128,256} do
			executeRequired(params.pathMagick, {
				"gfx/logo.png",
				"-resize", F("%dx%d", size, size),
				F("gfx/appIcon%d.png", size),
			})
		end

		-- Crush icon PNGs.
		for _, size in ipairs{16,24,32,48,64,128,256} do
			executeRequired(params.pathPngCrush, {
				"-ow",          -- Overwrite (must be first).
				"-rem", "alla", -- Remove unnecessary chunks.
				"-reduce",      -- Lossless color reduction.
				"-warn",        -- No spam!
				F("gfx/appIcon%d.png", size),
			})
		end

		-- Create .ico.
		writeFile("temp/icons.txt", ([[
			gfx/appIcon16.png
			gfx/appIcon24.png
			gfx/appIcon32.png
			gfx/appIcon48.png
			gfx/appIcon64.png
			gfx/appIcon128.png
			gfx/appIcon256.png
		]]):gsub("\t", ""))

		executeRequired(params.pathMagick, {
			"@temp/icons.txt",
			values.iconPath,
		})
	end

	-- Windows.
	local PATH_RC_LOG = "temp/robocopy.log"
	os.remove(PATH_RC_LOG)

	do
		local outputDir = outputDirWin32

		-- Compile resource file.
		do
			local contents = readFile("build/appInfoTemplate.rc") -- UTF-16 LE BOM encoded.
			contents       = templateToStringUtf16(params, contents, values)
			writeFile("temp/appInfo.rc", contents)

			executeRequired(params.pathRh, {
				"-open",   "temp/appInfo.rc",
				"-save",   values.versionInfoPath,
				"-action", "compile",
				"-log",    "temp/rh.log", -- @Temp
				-- "-log",    "CONSOLE", -- Why doesn't this work? (And is it just in Sublime?)
			})
		end

		-- Create base for install directory.
		removeDirectoryRecursive(outputDir)
		makeDirectoryRecursive(outputDir)

		-- Create exe.
		do
			executeRequired(params.pathGpp32, {
				"-D", "UNICODE", "-D", "_UNICODE",
				"build/exe.cpp",
				"-mwindows", "-mconsole",
				"-static",
				"-fdata-sections", "-ffunction-sections", "-Wl,--gc-sections,-strip-all",
				-- "-Wl,-Map,temp/output.map", DEBUG
				"-o", "temp/app.exe",
			})

			local TEMPLATE_UPDATE_EXE = ([[
				[FILENAMES]
				Exe    = "temp/app.exe"
				SaveAs = "temp/app.exe"
				Log    = CONSOLE

				[COMMANDS]
				-delete ICONGROUP,,
				-delete VERSIONINFO,,
				-add "${versionInfoPath}", ,,
				-add "${iconPath}", ICONGROUP,MAINICON,0
			]]):gsub("\t+", "")

			local contents = templateToString(TEMPLATE_UPDATE_EXE, values, toWindowsPath)
			writeTextFile("temp/updateExe.rhs", contents)

			executeRequired(params.pathRh, {
				"-script", "temp/updateExe.rhs",
			})
		end

		-- Add remaining files.
		do
			copyDirectoryRecursive("bin",      outputDir.."/bin")
			copyDirectoryRecursive("srcgen",   outputDir.."/srcgen")
			copyDirectoryRecursive("testsite", outputDir.."/testsite", {".gitignore","output","logs"--[[,"Build.cmd"]]})
			copyFile("temp/app.exe",        values.exePath)
			copyFile("webgen.lua",          outputDir.."/webgen.lua")
			copyFile("build/Changelog.txt", outputDir.."/_Changelog.txt")
			copyFile("build/README.txt",    outputDir.."/_README.txt")
		end
	end

	-- Universal.
	do
		local outputDir = outputDirUniversal

		removeDirectoryRecursive(outputDir)
		makeDirectoryRecursive(outputDir)

		copyDirectoryRecursive("srcgen",   outputDir.."/srcgen")
		copyDirectoryRecursive("testsite", outputDir.."/testsite", {".gitignore","output","logs","Build.cmd"})
		copyFile("webgen.lua",          outputDir.."/webgen.lua")
		copyFile("build/Changelog.txt", outputDir.."/_Changelog.txt")
		copyFile("build/README.txt",    outputDir.."/_README.txt")
	end

	-- Zip for distribution!
	zipDirectory(params, "output/LuaWebGen_"..values.appVersion.."_win32.zip",     "./"..outputDirWin32)
	zipDirectory(params, "output/LuaWebGen_"..values.appVersion.."_universal.zip", "./"..outputDirUniversal)

	print("Release ready!")
end
