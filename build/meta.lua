--[[============================================================
--=
--=  Metaprogram functions
--=
--=-------------------------------------------------------------
--=
--=  LuaWebGen
--=  by Marcus 'ReFreezed' Thunström
--=
--==============================================================

	ARGS
	ASSERT
	BYTE
	CONST, CONSTSET, STATIC
	convertTextFileEncoding, addBomToUft16File
	copyFile, copyFilesInDirectory, copyDirectoryRecursive
	errorf
	execute, executeRequired
	F
	getReleaseVersion
	getStringBytes
	indexOf
	IS_CHAR
	isFile, isDirectory
	loadParams
	makeDirectory, makeDirectoryRecursive, removeDirectory, removeDirectoryRecursive
	NOSPACE, NOSPACE0
	PUSH_CONTEXT, POP_CONTEXT
	readFile, writeFile, writeTextFile
	Set
	templateToLua
	templateToString, templateToStringUtf16
	toWindowsPath
	traverseDirectory
	unindent
	utf16ToUtf8, utf8ToUtf16
	zipDirectory, zipFiles

--============================================================]]

_G.BYTE = string.byte
_G.F    = string.format



function _G.templateToLua(template, values)
	return (template:gsub("%$(%w+)", values))
end



-- versionString, majorVersionString,minorVersionString,patchVersionString = getReleaseVersion( )
function _G.getReleaseVersion()
	local versionStr = readFile("build/version.txt")

	local major, minor, patch = versionStr:match"^(%d+)%.(%d+)%.(%d+)$"
	assert(major, versionStr)

	return versionStr, major,minor,patch
end



function _G.loadParams()
	local params = {
		pathGpp32    = "",
		path7z       = "",
		pathMagick   = "",
		pathPngCrush = "",
		pathRh       = "",
		pathIconv    = "",
	}

	local ln = 0

	for line in io.lines"local/params.ini" do
		ln = ln+1

		if not (line == "" or line:find"^#") then
			local k, v = line:match"^([%w_]+)%s*=%s*(.*)$"
			if not k then
				errorf("local/param.ini:%d: Bad line format: %s", ln, line)
			end

			if     k == "pathGpp32"    then  params.pathGpp32    = v
			elseif k == "path7z"       then  params.path7z       = v
			elseif k == "pathMagick"   then  params.pathMagick   = v
			elseif k == "pathPngCrush" then  params.pathPngCrush = v
			elseif k == "pathRh"       then  params.pathRh       = v
			elseif k == "pathIconv"    then  params.pathIconv    = v
			else   printf("Warning: params.ini:%d: Unknown param '%s'.", ln, k)  end
		end
	end

	assert(params.pathGpp32    ~= "", "local/param.ini: Missing param 'pathGpp32'.")
	assert(params.path7z       ~= "", "local/param.ini: Missing param 'path7z'.")
	assert(params.pathMagick   ~= "", "local/param.ini: Missing param 'pathMagick'.")
	assert(params.pathPngCrush ~= "", "local/param.ini: Missing param 'pathPngCrush'.")
	assert(params.pathRh       ~= "", "local/param.ini: Missing param 'pathRh'.")
	assert(params.pathIconv    ~= "", "local/param.ini: Missing param 'pathIconv'.")

	return params
end



local function includeArgs(cmd, args)
	local cmdParts = {cmd:gsub("/", "\\"), unpack(args)}

	for i, cmdPart in ipairs(cmdParts) do
		if cmdPart == "" then
			cmdParts[i] = '""'
		elseif cmdPart:find(" ", 1, true) then
			cmdParts[i] = '"'..cmdPart..'"'
		end
	end

	return (
		cmdParts[1]:sub(1, 1) == '"'
		and '"'..table.concat(cmdParts, " ")..'"'
		or  table.concat(cmdParts, " ")
	)
end

-- exitCode = execute( command )
-- exitCode = execute( program, arguments )
function _G.execute(cmd, args)
	if args then
		cmd = includeArgs(cmd, args)
	end

	local exitCode = os.execute(cmd)
	return exitCode
end

-- executeRequired( command )
-- executeRequired( program, arguments )
function _G.executeRequired(cmd, args)
	if args then
		cmd = includeArgs(cmd, args)
	end

	local exitCode = os.execute(cmd)
	if exitCode ~= 0 then
		errorf("Got code %d from command: %s", exitCode, cmd)
	end
end



-- string = templateToString( template, values [, formatter ] )
-- string = formatter( string )
function _G.templateToString(s, values, formatter)
	return (s:gsub("${(%w+)}", function(k)
		local v = values[k]
		if not v     then  errorf("No value '%s'.", k)  end
		if formatter then  v = formatter(v)  end
		return v
	end))
end

-- string = templateToStringUtf16( params, template, values [, formatter ] )
-- string = formatter( string )
function _G.templateToStringUtf16(params, s, values, formatter)
	return (s:gsub("$%z{%z([%w%z]+)}%z", function(k)
		k       = utf16ToUtf8(params, k)
		local v = values[k]
		if not v     then  errorf("No value '%s'.", k)  end
		if formatter then  v = formatter(v)  end
		return utf8ToUtf16(params, v)
	end))
end



function _G.utf16ToUtf8(params, s)
	-- @Speed, OMG!!!
	writeFile("temp/encodingIn.txt", s)
	convertTextFileEncoding(params, "temp/encodingIn.txt", "temp/encodingOut.txt", "UTF-16LE", "UTF-8")
	return (readFile("temp/encodingOut.txt"))
end

function _G.utf8ToUtf16(params, s)
	-- @Speed, OMG!!!
	writeFile("temp/encodingIn.txt", s)
	convertTextFileEncoding(params, "temp/encodingIn.txt", "temp/encodingOut.txt", "UTF-8", "UTF-16LE")
	return (readFile("temp/encodingOut.txt"))
end



-- convertTextFileEncoding( params, inputPath, outputPath, fromEncoding, toEncoding [, addBom=false ] )
function _G.convertTextFileEncoding(params, inputPath, outputPath, fromEncoding, toEncoding, addBom)
	assert((inputPath ~= outputPath), inputPath)

	executeRequired(F([[""%s" -f %s -t %s "%s" > "%s""]], params.pathIconv, fromEncoding, toEncoding, inputPath, outputPath))

	if addBom then
		assert((toEncoding == "UTF-16LE"), toEncoding)
		addBomToUft16File(outputPath)
	end
end

function _G.addBomToUft16File(path) -- LE, specifically.
	local file     = assert(io.open(path, "r+b"))
	local contents = file:read"*a"
	file:seek("set", 0)
	file:write("\255\254", contents)
	file:close()
end



function _G.toWindowsPath(s)
	return (s:gsub("/", "\\"))
end



do
	-- Note: CWD matter!
	-- Note: To strip the path to folderToZip inside the resulting zip file, prepend "./".

	-- zipDirectory( params, zipFilePath, folderToZip [, append=false ] )
	function _G.zipDirectory(params, zipFilePath, folderToZip, append)
		if not append and isFile(zipFilePath) then
			assert(os.remove(zipFilePath))
		end
		executeRequired(params.path7z, {"a", "-tzip", zipFilePath, folderToZip})
	end

	-- zipFiles( params, zipFilePath, pathsToZip [, append=false ] )
	function _G.zipFiles(params, zipFilePath, pathsToZip, append)
		if not append and isFile(zipFilePath) then
			assert(os.remove(zipFilePath))
		end

		writeTextFile("temp/zipIncludes.txt", table.concat(pathsToZip, "\n").."\n")

		executeRequired(params.path7z, {"a", "-tzip", zipFilePath, "@temp/zipIncludes.txt"})
	end
end



function _G.readFile(path)
	local file     = assert(io.open(path, "rb"))
	local contents = file:read("*a")
	file:close()
	return contents
end

function _G.writeFile(path, contents)
	local file = assert(io.open(path, "wb"))
	file:write(contents)
	file:close()
end
function _G.writeTextFile(path, contents)
	local file = assert(io.open(path, "w"))
	file:write(contents)
	file:close()
end



function _G.copyFile(pathFrom, pathTo)
	writeFile(pathTo, readFile(pathFrom))
end

-- copyFilesInDirectory( fromDirectory, toDirectory [, filenamePattern ] )
function _G.copyFilesInDirectory(dirIn, dirOut, filenamePat)
	for filename in lfs.dir(dirIn) do
		if not (filename == "." or filename == ".." or (filenamePat and not filename:find(filenamePat))) then
			local path = dirIn.."/"..filename

			if isFile(path) then
				makeDirectoryRecursive(dirOut)
				copyFile(path, dirOut.."/"..filename)
			end
		end
	end
end

-- copyDirectoryRecursive( fromDirectory, toDirectory [, filenamesToIgnore ] )
function _G.copyDirectoryRecursive(dirIn, dirOut, ignores)
	for filename in lfs.dir(dirIn) do
		if not (filename == "." or filename == ".." or (ignores and indexOf(ignores, filename))) then
			local path = dirIn.."/"..filename

			if isFile(path) then
				makeDirectoryRecursive(dirOut)
				copyFile(path, dirOut.."/"..filename)
			elseif isDirectory(path) then
				copyDirectoryRecursive(path, dirOut.."/"..filename, ignores)
			end
		end
	end
end



function _G.makeDirectory(dir)
	if isDirectory(dir) then  return  end

	local ok, err = lfs.mkdir(dir)
	if not ok then
		errorf("Could not make directory '%s'. (%s)", dir, err)
	end
end
function _G.makeDirectoryRecursive(dir)
	if not isDirectory(dir) then
		executeRequired("MKDIR", {toWindowsPath(dir)})
	end
end

function _G.removeDirectory(dir)
	if not isDirectory(dir) then  return  end

	local ok, err = lfs.rmdir(dir)
	if not ok then
		errorf("Could not remove directory '%s'. (%s)", dir, err)
	end
end
function _G.removeDirectoryRecursive(dir)
	if isDirectory(dir) then
		executeRequired("RMDIR", {"/S", "/Q", toWindowsPath(dir)})
	end
end



do
	local function traverse(dir, cb)
		for filename in lfs.dir(dir) do
			if not (filename == "." or filename == "..") then
				local path = dir.."/"..filename

				local action = cb(path)
				if action == "stop" then  return "stop"  end

				if action ~= "ignore" and lfs.attributes(path, "mode") == "directory" then
					action = traverse(path, cb)
					if action == "stop" then  return "stop"  end
				end
			end
		end

		-- return "continue" -- Not needed.
	end

	-- traverseDirectory( directory, callback )
	-- [ "ignore"|"stop" = ] callback( path )
	function _G.traverseDirectory(dir, cb)
		traverse(dir, cb)
	end
end



function _G.isFile(path)
	return lfs.attributes(path, "mode") == "file"
end

function _G.isDirectory(path)
	return lfs.attributes(path, "mode") == "directory"
end



function _G.indexOf(t, v)
	for i = 1, #t do
		if t[i] == v then  return i  end
	end
	return nil
end



-- Remove spaces.
function _G.NOSPACE(s)
	return (s:gsub(" +", ""))
end

-- Remove spaces and replace NULL bytes with new spaces afterwards.
function _G.NOSPACE0(s)
	return (s:gsub(" +", ""):gsub("%z", " "))
end



do
	local function outputArgumentChecks(errLevel, argsStr)
		local optionalPos = argsStr:find("?", 1, true) or #argsStr
		local n           = 1
		local first       = true

		for pos, argNames, types in argsStr:gmatch"()([%w_,]+):([%w_,*]+)" do
			if types == "*" then
				n = n + #argNames:gsub("[^,]+", "") + 1

			else
				if pos > optionalPos then  types = types..",nil"  end

				local multipleTypes = types:find(",", 1, true) ~= nil
				local ifFormat      = multipleTypes and "not isAny(type(%s), %s)" or 'type(%s) ~= "%s"'
				local typesCode     = multipleTypes and types:gsub("[%w_]+", '"%0"') or types
				local typesText     = multipleTypes and types:gsub(",",      " or ") or types

				for argName in argNames:gmatch"[%w_]+" do
					if not first then  __LUA"\n"  end
					first = false

					__LUA(F(
						"if %s then  errorf(%d, \"Bad argument #%d '%s'. (Expected %s, got %%s)\", type(%s))  end",
						F(ifFormat, argName, typesCode),
						errLevel + 1,
						n,
						argName,
						typesText,
						argName
					))
					n = n + 1
				end
			end
		end
	end

	-- ARGS [ (errorLevel=1) ] "arg1:arg1Type1,arg1Type2 arg2,arg3:arg2And3Type ? optionalArg4:optionalArg4Type ..."
	function _G.ARGS(errLevelOrArgsStr)
		if type(errLevelOrArgsStr) == "string" then
			local argsStr = errLevelOrArgsStr
			outputArgumentChecks(1, argsStr)
		else
			local errLevel = errLevelOrArgsStr
			return function(argsStr)
				outputArgumentChecks(errLevel, argsStr)
			end
		end
	end
end



function errorf(s, ...)
	error(F(s, ...), 2)
end



local ctxName

function _G.PUSH_CONTEXT(_ctxName)
	ctxName = _ctxName
	__LUA"do "
		__LUA"local function "__LUA(ctxName)__LUA"Context(ctx)"
end

function _G.POP_CONTEXT()
		__LUA"end "
		__LUA"local ctx = pushContext("__VAL(ctxName)__LUA", "__LUA(ctxName)__LUA"Context) "
		__LUA(ctxName)__LUA"Context(ctx) "
	__LUA"end"
end



function _G.unindent(s)
	local indent = s:match"^\t+"
	if indent then
		s = s
			:gsub("\n"..indent, "\n")
			:sub(#indent+1)
			:gsub("\t+$", "")
	end

	return s
end



function _G.Set(values)
	local set = {}
	for _, v in ipairs(values) do
		set[v] = true
	end
	return set
end



local function compare(v1, v2)
	if type(v1) ~= type(v2) then  return false     end
	if type(v1) ~= "table"  then  return v1 == v2  end

	for k in pairs(v1) do
		if not compare(v1[k], v2[k]) then  return false  end
	end
	for k in pairs(v2) do
		if v1[k] == nil then  return false  end
	end

	return true
end

-- name = @@CONST{ ... }
function _G.CONST(tCode)
	local t = assert(loadstring("return "..tCode))()

	for _, constName in ipairs(constants) do
		if compare(constants[constName], t) then  return constName  end
	end

	local constName = "CONST" .. (#constants+1)
	table.insert(constants, constName)
	constants[constName] = t

	return constName
end

-- name = @@CONSTSET{ value1, ... }
function _G.CONSTSET(valuesCode)
	return CONST("Set("..valuesCode..")")
end

-- name = @@STATIC( identifier )
-- name = @@STATIC{ ... }
function _G.STATIC(tCodeOrIdent)
	local staticName, t

	if tCodeOrIdent:find"^{" then
		staticName = "STATIC" .. (#statics+1)
		t          = assert(loadstring("return"..tCodeOrIdent))()
	else
		staticName = tCodeOrIdent
		t          = {}
	end

	assert(not statics[staticName], staticName)

	table.insert(statics, staticName)
	statics[staticName] = t

	return staticName
end



-- @@ASSERT( condition [, message=auto ] )
function ASSERT(condCode, messageCode)
	if not DEV then  return ""  end

	messageCode = messageCode or F("%q", "Assertion failed: "..condCode)

	return "if not ("..condCode..") then error("..messageCode..") end"
end



-- bool     = @@IS_CHAR( string, position, stringWithOneAsciiCharacter )
-- true|nil = @@IS_CHAR( string, position, stringWithMultipleAsciiCharacters )
function _G.IS_CHAR(sCode, posCode, cCode)
	local c = assert(loadstring("return "..cCode))()
	assert(type(c) == "string")
	assert(#c > 0)

	if posCode == "1" then  posCode = ""  end

	if #c == 1 then
		return F("((%s):byte(%s) == %d)", sCode, posCode, c:byte())
	else
		return F("%s[(%s):byte(%s)]", CONSTSET('{getStringBytes'..cCode..'}'), sCode, posCode)
	end
end



-- byte1, ... = getStringBytes( string )
function _G.getStringBytes(s)
	return s:byte(1, #s)
end


