--[[============================================================
--=
--=  LuaWebGen - static website generator in Lua!
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See the bottom of this file)
--=
--============================================================]]

local _WEBGEN_VERSION = "0.3.0"



-- Settings.

local DIR_CONTENT = "content"
local DIR_DATA    = "data"
local DIR_LAYOUTS = "layouts"
local DIR_LOGS    = "logs"
local DIR_OUTPUT  = "output"
local DIR_SCRIPTS = "scripts"

local AUTOBUILD_MIN_INTERVAL = 1.00



-- Constants.

local HTML_ENTITY_PATTERN = '[&<>"]'
local HTML_ENTITIES = {
	['&'] = "&amp;",
	['<'] = "&lt;",
	['>'] = "&gt;",
	['"'] = "&quot;",
}

local URI_PERCENT_CODES_TO_NOT_ENCODE = {
	["%2d"]="-",["%2e"]=".",["%7e"]="~",--["???"]="_",
	["%21"]="!",["%23"]="#",["%24"]="$",["%26"]="&",["%27"]="'",["%28"]="(",["%29"]=")",["%2a"]="*",["%2b"]="+",
	["%2c"]=",",["%2f"]="/",["%3a"]=":",["%3b"]=";",["%3d"]="=",["%3f"]="?",["%40"]="@",["%5b"]="[",["%5d"]="]",
}

local TEMPLATE_EXTENSION_SET = {["html"]=true, ["md"]=true, ["css"]=true}
local PAGE_EXTENSION_SET     = {["html"]=true, ["md"]=true}

local OUTPUT_CATEGORY_SET = {["page"]=true, ["otherTemplate"]=true, ["otherRaw"]=true}

local IMAGE_EXTENSIONS = {"png","jpg","jpeg","gif"}



-- Modules.
package.path = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("[^/\\]*$", "lib/?.lua;")..package.path

local lfs         = require"lfs"
local socket      = require"socket"

local escapeUri   = require"socket.url".escape

local markdownLib = require"markdown"
local parseToml   = require"toml".parse
local xmlLib      = require"pl.xml"

local _assert     = assert
local _error      = error
local _pcall      = pcall
local _print      = print



-- Misc variables.

local logFile       = nil
local logPath       = ""
local logBuffer     = {}

local includeDrafts = false



-- Site variables.
local site                              = nil

local scriptFunctions                   = nil
local scriptEnvironmentGlobals          = nil

local ignoreFiles                       = nil
local ignoreFolders                     = nil

local fileProcessors                    = nil

local removeTrailingSlashFromPermalinks = false

local writtenOutputFiles                = nil
local outputFileCount                   = 0
local outputFileCounts                  = nil
local outputFileByteCount               = 0
local outputFilePreservedCount          = 0
local outputFileSkippedPageCount        = 0

local proxySources                      = nil

local pageLayoutTemplatePath            = nil
local pageLayoutTemplate                = nil

local scriptsCanOutput                  = false



--==============================================================
--= Functions ==================================================
--==============================================================

local assert, assertf, assertType, assertTable
local clearPageVariables
local createDirectory, isDirectoryEmpty, removeEmptyDirectories
local createEnvironment
local dateStringToTime
local encodeHtmlEntities
local error, errorf, fileerror, errorInGeneratedCodeFromTemplate
local F, formatBytes
local generateFromTemplate
local generatorMeta
local getDirectory, getFilename, getExtension
local getFileContents
local getLayoutTemplate
local getLineNumber
local include
local indexOf, itemWith, itemWithAll
local insertLineNumberCode
local isFile, isDirectory
local isStringMatchingAnyPattern
local markdownToHtml
local newDataFolderReader
local newGeneratorObjectProxy
local parseMarkdownTemplate, parseHtmlTemplate, parseOtherTemplate
local pcall
local print, printf, log, logprint
local sortNatural
local splitString
local storeArgs
local toNormalPath, toWindowsPath
local tostringForTemplates
local toUrl, toUrlAbsolute, urlize
local traverseDirectory, traverseFiles
local trim, trimNewlines
local writeOutputFile, preserveExistingOutputFile



function traverseDirectory(dirPath, ignoreFolders, cb, _pathRelStart)
	_pathRelStart = _pathRelStart or #dirPath+2

	for name in lfs.dir(dirPath) do
		local path = dirPath.."/"..name

		if name ~= "." and name ~= ".." then
			local mode = lfs.attributes(path, "mode")

			if mode == "file" then
				local pathRel = path:sub(_pathRelStart)
				local abort   = cb(path, pathRel, name, "file")
				if abort then  return true  end

			elseif mode == "directory" and not (ignoreFolders and isStringMatchingAnyPattern(name, ignoreFolders)) then
				local pathRel = path:sub(_pathRelStart)
				local abort   = cb(path, pathRel, name, "directory")
				if abort then  return true  end

				local abort = traverseDirectory(path, ignoreFolders, cb, _pathRelStart)
				if abort then  return true  end
			end

		end
	end

end

function traverseFiles(dirPath, ignoreFolders, cb, _pathRelStart)
	_pathRelStart = _pathRelStart or #dirPath+2

	for name in lfs.dir(dirPath) do
		local path = dirPath.."/"..name

		if name ~= "." and name ~= ".." then
			local mode = lfs.attributes(path, "mode")

			if mode == "file" then
				local pathRel = path:sub(_pathRelStart)
				local ext     = getExtension(name)
				local abort   = cb(path, pathRel, name, ext)
				if abort then  return true  end

			elseif mode == "directory" and not (ignoreFolders and isStringMatchingAnyPattern(name, ignoreFolders)) then
				local abort = traverseFiles(path, ignoreFolders, cb, _pathRelStart)
				if abort then  return true  end
			end

		end
	end

end



function isStringMatchingAnyPattern(s, patterns)
	for _, pat in ipairs(patterns) do
		if s:find(pat) then  return true  end
	end
	return false
end



function getFileContents(path)
	local file, err = io.open(path, "rb")
	if not file then  return nil, err  end

	local contents = file:read("*all")
	file:close()
	return contents
end



do
	local function parseTemplate(path, template, pos, level, enableHtmlEncoding)

		--= Generate Lua.
		--= @Robustness: Validate each individual code snippet. [LOW]
		--==============================================================

		local blockStartPos = pos
		local lua = {}

		while pos <= #template do
			local codePosStart = template:find("{{", pos, true)
			if not codePosStart then  break  end

			if codePosStart > pos then
				local plainSegment = template:sub(pos, codePosStart-1)
				local luaStatement = F("echoRaw(%q)\n", plainSegment) --:gsub("\\\n", "\\n")
				table.insert(lua, luaStatement)
			end

			pos = codePosStart
			pos = pos+2 -- Eat "{{".

			insertLineNumberCode(lua, getLineNumber(template, pos))

			local codePosEnd
			local longCommentLevel = template:match("^%-%-%[(=*)%[", pos)

			if longCommentLevel then
				pos = pos+4+#longCommentLevel -- Eat "--[=[".
				_, codePosEnd = template:find("%]"..longCommentLevel.."%]}}", pos)
				assert(codePosEnd, pos)
			else
				_, codePosEnd = template:find("}}", pos, true)
				assert(codePosEnd, pos)
			end

			local code = trim(template:sub(codePosStart+2, codePosEnd-2))
			-- print("CODE: "..code)

			-- local markdownContextIsHtml = ?

			----------------------------------------------------------------

			if code:find"^%-%-" then
				-- Ignore comments.

			-- do ... end
			elseif code == "do" then
				table.insert(lua, "do\n")

				local innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(path, template, codePosEnd+1, level+1, enableHtmlEncoding)
				local innerEndCode = trim(template:sub(innerEndCodePosStart+2, innerEndCodePosEnd-2))

				if innerEndCode ~= "end" then
					fileerror(
						path, template, innerEndCodePosStart,
						"Expected end for 'do' starting at line %d.",
						getLineNumber(template, pos)
					)
				end

				for _, luaCode in ipairs(innerLua) do  table.insert(lua, luaCode)  end
				table.insert(lua, "end\n")

				codePosEnd = innerEndCodePosEnd

			-- if expression ... end
			elseif code:find"^if[ (]" then
				table.insert(lua, code)
				table.insert(lua, " then\n")

				local innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(path, template, codePosEnd+1, level+1, enableHtmlEncoding)
				local innerEndCode = trim(template:sub(innerEndCodePosStart+2, innerEndCodePosEnd-2))

				for _, luaCode in ipairs(innerLua) do  table.insert(lua, luaCode)  end
				insertLineNumberCode(lua, getLineNumber(template, innerEndCodePosStart))

				while innerEndCode:find"^elseif[ (]" do
					table.insert(lua, innerEndCode)
					table.insert(lua, " then\n")

					innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(path, template, innerEndCodePosEnd+1, level+1, enableHtmlEncoding)
					innerEndCode = trim(template:sub(innerEndCodePosStart+2, innerEndCodePosEnd-2))

					for _, luaCode in ipairs(innerLua) do  table.insert(lua, luaCode)  end
					insertLineNumberCode(lua, getLineNumber(template, innerEndCodePosStart))
				end

				if innerEndCode == "else" then
					table.insert(lua, "else\n")

					innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(path, template, innerEndCodePosEnd+1, level+1, enableHtmlEncoding)
					innerEndCode = trim(template:sub(innerEndCodePosStart+2, innerEndCodePosEnd-2))

					for _, luaCode in ipairs(innerLua) do  table.insert(lua, luaCode)  end
					insertLineNumberCode(lua, getLineNumber(template, innerEndCodePosStart))
				end

				if innerEndCode ~= "end" then
					fileerror(
						path, template, innerEndCodePosStart,
						"Expected end for 'if' starting at line %d.",
						getLineNumber(template, pos)
					)
				end

				table.insert(lua, "end\n")

				codePosEnd = innerEndCodePosEnd

			-- for index, item in ipairs(expression) ... end
			-- fori item in expression ... end
			-- fori expression ... end
			elseif code:find"^fori? " then
				if code:find"^fori" then
					local foriItem, foriArr = code:match"^fori +([%a_][%w_]+) +in +(%S.*)$"

					if not foriArr then
						foriArr = code:match"^fori +(.+)$"
					end

					if not foriArr then
						fileerror(path, template, pos, "Invalid fori statement.")
					end

					table.insert(lua, "for _, ")
					table.insert(lua, foriItem or "it")
					table.insert(lua, " in ipairs(")
					table.insert(lua, foriArr)
					table.insert(lua, ") do\n")

				else
					table.insert(lua, code)
					table.insert(lua, " do\n")
				end

				local innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(path, template, codePosEnd+1, level+1, enableHtmlEncoding)
				local innerEndCode = trim(template:sub(innerEndCodePosStart+2, innerEndCodePosEnd-2))

				if innerEndCode ~= "end" then
					fileerror(
						path, template, innerEndCodePosStart,
						"Expected end for '%s' starting at line %d.",
						code:match"^%w+", getLineNumber(template, pos)
					)
				end

				for _, luaCode in ipairs(innerLua) do  table.insert(lua, luaCode)  end
				table.insert(lua, "end\n")

				codePosEnd = innerEndCodePosEnd

			-- while expression ... end
			elseif code:find"^while[ (]" then
				table.insert(lua, code)
				table.insert(lua, " do\n")

				local innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(path, template, codePosEnd+1, level+1, enableHtmlEncoding)
				local innerEndCode = trim(template:sub(innerEndCodePosStart+2, innerEndCodePosEnd-2))

				if innerEndCode ~= "end" then
					fileerror(
						path, template, innerEndCodePosStart,
						"Expected end for 'while' starting at line %d.",
						getLineNumber(template, pos)
					)
				end

				for _, luaCode in ipairs(innerLua) do  table.insert(lua, luaCode)  end
				table.insert(lua, "end\n")

				codePosEnd = innerEndCodePosEnd

			-- repeat ... until expression
			elseif code == "repeat" then
				table.insert(lua, "repeat\n")

				local innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(path, template, codePosEnd+1, level+1, enableHtmlEncoding)
				local innerEndCode = trim(template:sub(innerEndCodePosStart+2, innerEndCodePosEnd-2))

				if not innerEndCode:find"^until[ (]" then
					fileerror(
						path, template, innerEndCodePosStart,
						"Expected until for 'repeat' starting at line %d.",
						getLineNumber(template, pos)
					)
				end

				for _, luaCode in ipairs(innerLua) do  table.insert(lua, luaCode)  end
				insertLineNumberCode(lua, getLineNumber(template, innerEndCodePosStart))
				table.insert(lua, innerEndCode)
				table.insert(lua, "\n")

				codePosEnd = innerEndCodePosEnd

			-- URL short form.
			elseif code:find"^/" then
				table.insert(lua, F("echo(url%q)\n", code))

			-- Other kind of code block that doesn't return any value.
			elseif code:find"^local " or code:find"^[%w_.]+ *=[^=]" then
				table.insert(lua, code)
				table.insert(lua, "\n")

			-- End of block.
			elseif code == "end" or code:find"^until[ (]" or code == "else" or code:find"^elseif[ (]" then
				if level == 1 then
					fileerror(path, template, pos, "Unexpected '%s'.", (code:match"^%w+"))
				end
				return lua, codePosStart, codePosEnd

			-- Expression that returns a value (or function call that doesn't).
			else
				table.insert(lua, F("do\n\tlocal v = (%s)\n\tif type(v) == 'string' and v:match'%%S' == '<' then  echoRaw(v)  elseif v ~= nil then  echo(tostring(v))  end\nend\n", code))
			end

			----------------------------------------------------------------

			pos = codePosEnd+1
		end

		if level > 1 then
			fileerror(path, template, blockStartPos, "Block never ends.")
		end

		if pos <= #template then
			local plainSegment = template:sub(pos)
			local luaStatement = F("echoRaw(%q)\n", plainSegment) --:gsub("\\\n", "\\n")
			table.insert(lua, luaStatement)
		end

		local luaCode = table.concat(lua)

		-- print("-- LUA --") print(luaCode) print("-- /LUA --")

		--= Generate output.
		--==============================================================

		local out = {}

		local funcs = {
			include = include,
			echoRaw = function(s)
				table.insert(out, s)
			end,
			echo = function(s)
				if enableHtmlEncoding then
					s = encodeHtmlEntities(s)
				end
				table.insert(out, s)
			end,
		}

		local chunk, err = loadstring(luaCode)
		if not chunk then
			errorInGeneratedCodeFromTemplate(path, luaCode, err)
		end

		local env = createEnvironment(scriptEnvironmentGlobals, funcs, true)
		setfenv(chunk, env)

		local ok, err = pcall(chunk)
		if not ok then
			errorInGeneratedCodeFromTemplate(path, luaCode, err)
		end

		out = table.concat(out)
			:gsub("[ \t]+\n", "\n") -- :Beautify
			:gsub("\n\n\n+", "\n\n") -- :Beautify

		--==============================================================

		return out
	end

	function parseMarkdownTemplate(path, template)
		local md = parseTemplate(path, template, 1, 1, true)

		local html = markdownToHtml(md)
		html = trimNewlines(html).."\n" -- :Beautify

		-- print("-- HTML --") print(html) print("-- /HTML --")

		return html
	end

	function parseHtmlTemplate(path, template)
		local html = parseTemplate(path, template, 1, 1, true)
		html = trimNewlines(html).."\n" -- :Beautify

		-- print("-- HTML --") print(html) print("-- /HTML --")

		return html
	end

	function parseOtherTemplate(path, template)
		local contents = parseTemplate(path, template, 1, 1, false)
		contents = trimNewlines(contents).."\n" -- :Beautify

		-- print("-- CONTENTS --") print(contents) print("-- /CONTENTS --")

		return contents
	end

end



-- error( errorMessage [, level=1 ] )
function error(err, level)
	log(debug.traceback("Error: "..tostring(err)))

	if logFile then  logFile:flush()  end

	_error(err, (level or 1)+1)
end

-- errorf( [ level, ] formatString, ...)
function errorf(level, s, ...)
	if type(level) == "number" then
		error(s:format(...), level+1)
	else
		error(level:format(s, ...), 2)
	end
end

-- fileerror( path, contents, position,   formatString, ... )
-- fileerror( path, nil,      lineNumber, formatString, ... )
function fileerror(path, contents, pos, s, ...)
	local ln = contents and getLineNumber(contents, pos) or pos
	if type(s) ~= "string" then
		s = ("%s:%d: %s"):format(path, ln, tostring(s))
	else
		s = ("%s:%d: "..s):format(path, ln, ...)
	end
	error(s, 2)
end

function errorInGeneratedCodeFromTemplate(path, genCode, errInGenCode)
	local lnInGenCode, err
	if type(errInGenCode) == "string" then
		lnInGenCode, err = errInGenCode:match'^%[string ".-"%]:(%d+): (.+)'
	end

	local lnInTemplate = 0

	if not lnInGenCode then
		err = tostring(errInGenCode)

	else
		for line in genCode:gmatch"([^\n]*)\n?" do
			lnInGenCode = lnInGenCode-1
			lnInTemplate = tonumber(line:match"^%-%- @LINE(%d+)$") or lnInTemplate
			if lnInGenCode <= 1 then  break  end
		end
	end

	fileerror(path, nil, lnInTemplate, "%s", err)
end



function getLineNumber(s, pos)
	local lineCount = 1
	for posCurrent in s:gmatch"()\n" do
		if posCurrent < pos then
			lineCount = lineCount+1
		else
			break
		end
	end
	return lineCount
end



-- writeOutputFile( category, pathRelative, dataString [ modificationTime ] )
function writeOutputFile(category, pathRel, data, modTime)
	if writtenOutputFiles[pathRel] then
		errorf("Duplicate output file '%s'.", pathRel)
	end

	local filename = getFilename(pathRel)
	local ext      = getExtension(filename)
	if fileProcessors[ext] then
		data = fileProcessors[ext](data, pathRel)
		assertType(data, "string", "File processor didn't return a string. (%s)", ext)
	end

	local path = DIR_OUTPUT.."/"..pathRel
	log("Writing: %s", path)

	local dirPath = path:gsub("/[^/]+$", "")
	createDirectory(dirPath)

	local file = assert(io.open(path, "wb"))
	file:write(data)
	file:close()

	if modTime then
		local ok, err = lfs.touch(path, modTime)
		if not ok then
			logprint("Error: Could not update modification time for '%s': %s", path, err)
		end
	end

	table.insert(writtenOutputFiles, pathRel)
	writtenOutputFiles[pathRel] = true

	assert(OUTPUT_CATEGORY_SET[category], category)
	outputFileCount = outputFileCount+1
	outputFileCounts[category] = outputFileCounts[category]+1

	outputFileByteCount = outputFileByteCount+#data
end

-- preserveExistingOutputFile( category, pathRelative )
function preserveExistingOutputFile(category, pathRel)
	if writtenOutputFiles[pathRel] then
		errorf("Duplicate output file '%s'.", pathRel)
	end

	local path = DIR_OUTPUT.."/"..pathRel
	-- log("Preserving: %s", path)

	local dataLen, err = lfs.attributes(path, "size")
	if not dataLen then
		logprint("Error: Could not retrieve size of file '%s': %s", path, err)
		dataLen = 0
	end

	table.insert(writtenOutputFiles, pathRel)
	writtenOutputFiles[pathRel] = true

	assert(OUTPUT_CATEGORY_SET[category], category)
	outputFileCount = outputFileCount+1
	outputFileCounts[category] = outputFileCounts[category]+1
	outputFilePreservedCount = outputFilePreservedCount+1

	outputFileByteCount = outputFileByteCount+dataLen
end



function createDirectory(path)
	assert(not path:find"^/") -- Avoid absolute paths - they were probably a mistake.
	assert(not path:find"^%a:") -- Windows drive letter.

	local pathConstructed = ""

	for folder in path:gmatch"[^/]+" do
		pathConstructed = (pathConstructed == "" and folder or pathConstructed.."/"..folder)
		if not (isDirectory(pathConstructed) or lfs.mkdir(pathConstructed)) then
			errorf("Could not create directory '%s'.", pathConstructed)
		end
	end
end

function isDirectoryEmpty(dirPath)
	for name in lfs.dir(dirPath) do
		if name ~= "." and name ~= ".." then  return false  end
	end
	return true
end

function removeEmptyDirectories(dirPath)
	for name in lfs.dir(dirPath) do
		local path = dirPath.."/"..name

		if name ~= "." and name ~= ".." and isDirectory(path) then
			removeEmptyDirectories(path)
			if isDirectoryEmpty(path) then
				log("Removing empty folder: %s", path)
				assert(lfs.rmdir(path))
			end
		end

	end
end



do
	local values = {}

	function print(...)
		_print(...)

		local argCount = select("#", ...)
		for i = 1, argCount do
			values[i] = tostring(select(i, ...))
		end

		log(table.concat(values, "\t", 1, argCount))
	end
end

function printf(s, ...)
	print(s:format(...))
end

-- log( string )
-- log( formatString, ... )
function log(s, ...)
	if select("#", ...) > 0 then
		s = s:format(...)
	end

	if not logFile then
		table.insert(logBuffer, s)
		return
	end

	for i, s in ipairs(logBuffer) do
		logFile:write(s, "\n")
		logBuffer[i] = nil
	end

	logFile:write(s, "\n")
end

function logprint(s, ...)
	if select("#", ...) > 0 then
		s = s:format(...)
	end

	printf("[%s]  %s", os.date"%Y-%m-%d %H:%M:%S", s)
end



function insertLineNumberCode(t, ln)
	table.insert(t, "-- @LINE")
	table.insert(t, ln)
	table.insert(t, "\n")
end



function isFile(path)
	return lfs.attributes(path, "mode") == "file"
end

function isDirectory(path)
	return lfs.attributes(path, "mode") == "directory"
end



F = string.format

function formatBytes(n)
	if n > (1024*1024*1024)/100 then
		return F("%.2f GB", n/(1024*1024*1024))
	elseif n > (1024*1024)/100 then
		return F("%.2f MB", n/(1024*1024))
	elseif n > (1024)/100 then
		return F("%.2f KB", n/(1024))
	end
	return F("%d bytes", n)
end



function include(htmlFileBasename)
	local path = F("%s/%s.html", DIR_LAYOUTS, htmlFileBasename)
	local template, err = getFileContents(path)
	if not template then
		errorf(2, "Could not read file '%s': %s", path, err)
	end
	local html = parseHtmlTemplate(path, template)
	return html
end



function toUrl(urlStr)
	urlStr = escapeUri(urlStr)
	urlStr = urlStr:gsub("%%[0-9a-f][0-9a-f]", URI_PERCENT_CODES_TO_NOT_ENCODE)

	return urlStr
end
-- print(toUrl("http://www.example.com/some-path/File~With (Stuff_åäö).jpg?key=value&foo=bar#hash")) -- TEST

function toUrlAbsolute(urlStr)
	urlStr = urlStr:gsub("^/%f[^/]", site.baseUrl)
	return toUrl(urlStr)
end

function urlize(text)
	text = text
		:lower()
		:gsub("[%p ]+", "-")
		:gsub("^%-+", "")
		:gsub("%-+$", "")

	return text == "" and "-" or text
end



function generatorMeta(hideVersion)
	return
		hideVersion
		and '<meta name="generator" content="LuaWebGen">'
		or  '<meta name="generator" content="LuaWebGen '.._WEBGEN_VERSION..'">'
end



function trim(s)
	s = s :gsub("^%s+", "") :gsub("%s+$", "")
	return s
end

function trimNewlines(s)
	s = s :gsub("^\n+", "") :gsub("\n+$", "")
	return s
end



do
	local function formatValue(t, out, isDeep)
		if isDeep and type(t) == "string" then
			table.insert(out, '"')
			table.insert(out, t)
			table.insert(out, '"')
			return

		elseif type(t) ~= "table" then
			table.insert(out, tostring(t))
			return
		end

		local proxySource = proxySources[t]
		if proxySource then
			return formatValue(proxySource, out, isDeep)
		end

		local keys = {}
		for k in pairs(t) do
			table.insert(keys, k)
		end
		sortNatural(keys)

		table.insert(out, "{")
		for i, k in ipairs(keys) do
			if i > 1 then  table.insert(out, ", ")  end
			table.insert(out, tostring(k))
			table.insert(out, "=")
			formatValue(t[k], out, true)
		end
		table.insert(out, "}")
	end

	function tostringForTemplates(v)
		local out = {}
		formatValue(v, out, false)
		return table.concat(out)
	end
end



-- table = sortNatural( table [, attribute ] )
do
	local function pad(numStr)
		return ("%03d%s"):format(#numStr, numStr)
	end
	local function compare(a, b)
		return (tostringForTemplates(a):gsub("%d+", pad) < tostringForTemplates(b):gsub("%d+", pad))
	end

	function sortNatural(t, k)
		if k then
			table.sort(t, function(a, b)
				return compare(a[k], b[k])
			end)
		else
			table.sort(t, compare)
		end
		return t
	end
end



function newDataFolderReader(path)
	local dataFolderReader = {}

	setmetatable(dataFolderReader, {
		__index = function(dataFolderReader, k)
			local dataObj

			if isFile(F("%s/%s.lua", path, k)) then
				dataObj = assert(loadfile(F("%s/%s.lua", path, k)))()

			elseif isFile(F("%s/%s.toml", path, k)) then
				dataObj = parseToml(assert(getFileContents(F("%s/%s.toml", path, k))))

			elseif isFile(F("%s/%s.xml", path, k)) then
				dataObj = assert(xmlLib.parse(assert(getFileContents(F("%s/%s.xml", path, k))), false))

			elseif isDirectory(F("%s/%s", path, k)) then
				return newDataFolderReader(F("%s/%s", path, k))

			else
				errorf("Bad data path '%s/%s'.", path, k)
			end

			assert(dataObj ~= nil)
			rawset(dataFolderReader, k, dataObj)
			return dataObj
		end,
	})

	return dataFolderReader
end



function newGeneratorObjectProxy(obj, name)
	local proxy = setmetatable({}, {

		__index = function(proxy, k)
			local v = obj[k]
			if v ~= nil then  return v  end

			errorf(2, "Tried to get non-existent %s field '%s'.", name, tostring(k))
		end,

		__newindex = function(proxy, k, v)
			if obj[k] == nil then
				errorf(2, "'%s' is not a valid %s field.", tostring(k), name)
			elseif type(v) ~= type(obj[k]) then
				errorf(2, "Expected %s for %s field '%s' but got %s (%s).", type(obj[k]), name, k, type(v), tostring(v))
			else
				obj[k] = v
			end
		end,

	})
	proxySources[proxy] = obj
	return proxy
end



function toNormalPath(osPath)
	local path = osPath:gsub("\\", "/")
	return path
end

function toWindowsPath(path)
	local winPath = path:gsub("/", "\\")
	return winPath
end



-- environment = createEnvironment( globals [, functions, enableScriptFunctions=false ] )
function createEnvironment(G, funcs, enableScriptFunctions)
	local env = {}

	setmetatable(env, {
		__index = function(env, k)
			local v = funcs and funcs[k] or G[k]
			if v ~= nil then  return v  end

			if not enableScriptFunctions then
				errorf(2, "Tried to get non-existent global '%s'.", tostring(k))
			end

			v = scriptFunctions[k]
			if v then
				setfenv(v, env) -- The script environment must update for each page.
				return v
			end

			if isFile(F("%s/%s.lua", DIR_SCRIPTS, k)) then
				local path = F("%s/%s.lua", DIR_SCRIPTS, k)

				local chunk, err = loadfile(path)
				if not chunk then
					error(err, 2)
				end

				v = chunk()
				if type(v) ~= "function" then
					errorf(2, "%s did not return a function.", path)
				end

				setfenv(v, env)
				scriptFunctions[k] = v
				return v
			end

			errorf(2, "Tried to get non-existent global or script '%s'.", tostring(k))
		end,

		__newindex = function(env, k, v)
			errorf(2, "Tried to set global '%s'. (Globals are disabled.)", tostring(k))
		end,
	})

	return env
end



function getDirectory(path)
	return (path:gsub("/[^/]+$", ""))
end

function getFilename(path)
	return path:match"[^/]+$"
end

function getExtension(filename)
	return filename:match"%.([^.]+)$" or ""
end



-- generateFromTemplate( pathRelative, template [, modificationTime ] )
function generateFromTemplate(pathRel, template, modTime)
	assert(type(pathRel) == "string")
	assert(type(template) == "string")

	local filename = getFilename(pathRel)
	local ext      = getExtension(filename)

	assert(TEMPLATE_EXTENSION_SET[ext])

	local isPage  = PAGE_EXTENSION_SET[ext] or false
	local isIndex = isPage  and filename:sub(1, #filename-#ext-1) == "index"
	local isHome  = isIndex and pathRel == filename

	local category = isPage and "page" or "otherTemplate"

	local permalinkRel = (
		not isPage and pathRel
		or isHome and ""
		or isIndex and pathRel:sub(1, -#filename-1)
		or pathRel:sub(1, -#ext-2).."/"
	)

	local pathRelOut
		=  (not isPage and permalinkRel)
		or (permalinkRel == "" and "" or permalinkRel).."index.html"

	-- UPDATE:
	-- Templates should always regenerate, unless we know all includes are unmodified.
	-- Just checking oldModTime isn't enough!

	-- local oldModTime
	-- 	=   not ignoreModificationTimes
	-- 	and lfs.attributes(DIR_OUTPUT.."/"..pathRelOut, "modification")
	-- 	or  nil

	-- if not isPage and modTime and modTime == oldModTime then
	-- 	preserveExistingOutputFile(category, pathRelOut)

	-- else
		local page = {
			layout      = "page",
			title       = "",
			content     = "",

			publishDate = os.date("%Y-%m-%d %H:%M:%S", 0),
			isDraft     = false,

			permalink   = site.baseUrl..(removeTrailingSlashFromPermalinks and permalinkRel:gsub("/$", "") or permalinkRel),
			rssLink     = "", -- @Incomplete @Doc

			isPage      = isPage,
			isIndex     = isIndex,
			isHome      = isHome,
		}
		-- print(pathRel, (not isPage and " " or isHome and "H" or isIndex and "I" or "P"), page.permalink) -- DEBUG

		local scriptParams = {}

		scriptEnvironmentGlobals.page   = newGeneratorObjectProxy(page, "page")
		scriptEnvironmentGlobals.params = scriptParams
		scriptEnvironmentGlobals.P      = scriptParams

		local out

		if ext == "md" then
			page.content = parseMarkdownTemplate(pathRel, template)
		elseif ext == "html" then
			page.content = parseHtmlTemplate(pathRel, template)
		else
			assert(not isPage)
			out = parseOtherTemplate(pathRel, template)
		end

		if isPage then
			if
				(page.isDraft and not includeDrafts) or -- Is draft?
				(dateStringToTime(page.publishDate) > os.time()) -- Is in future?
			then
				outputFileSkippedPageCount = outputFileSkippedPageCount+1
				clearPageVariables()
				return
			end

			local layoutTemplate, layoutPath = getLayoutTemplate(page.layout, pathRel)
			out = parseHtmlTemplate(layoutPath, layoutTemplate)
		end

		clearPageVariables()

		assert(out)
		writeOutputFile(category, pathRelOut, out, modTime)
	-- end
end



function assert(...)
	if not select(1, ...) then
		error(select(2, ...) or "assertion failed!", 2)
	end
	return ...
end

function assertf(v, err, ...)
	if not v then
		if select("#", ...) > 0 then  err = err:format(...)  end
		assert(false, err)
	end
	return v
end

function assertType(v, vType, err, ...)
	assertf(type(v) == vType, err, ...)
	return v
end

-- value = assertTable( value [, fieldKeyType, fieldValueType, errorMessage, ... ] )
function assertTable(t, kType, vType, err, ...)
	assertType(t, "table", err, ...)
	for k, v in pairs(t) do
		if kType then  assertType(k, kType, err, ...)  end
		if vType then  assertType(v, vType, err, ...)  end
	end
	return t
end



function indexOf(t, v)
	for i, item in ipairs(t) do
		if item == v then  return i  end
	end
	return nil
end

function itemWith(t, k, v)
	for i, item in ipairs(t) do
		if item[k] == v then  return item, i  end
	end
	return nil
end

function itemWithAll(t, k, v)
	local items = {}
	for _, item in ipairs(t) do
		if item[k] == v then  table.insert(items, item)  end
	end
	return items
end



function encodeHtmlEntities(s)
	s = s:gsub(HTML_ENTITY_PATTERN, HTML_ENTITIES)
	return s
end



function markdownToHtml(md)
	return markdownLib(md)
end



function pcall(...)
	local savedAssert = assert
	local savedError  = error
	local savedPcall  = pcall

	assert = _assert
	error  = _error
	pcall  = _pcall

	local args = storeArgs(_pcall(...))

	assert = savedAssert
	error  = savedError
	pcall  = savedPcall

	if not args[1] then
		return false, args[2]
	else
		return unpack(args, 1, args.n)
	end
end



function storeArgs(...)
	return {n=select("#", ...), ...}
end



-- template, path = getLayoutTemplate( layoutName [, context ] )
function getLayoutTemplate(layoutName, context)
	if layoutName == "page" and pageLayoutTemplate then
		return pageLayoutTemplate, pageLayoutTemplatePath
	end

	local path = F("%s/%s.html", DIR_LAYOUTS, layoutName)
	local template, err = getFileContents(path)

	if not template then
		if context then
			errorf("%s: Could not load layout '%s'. (%s)", context, layoutName, err)
		else
			errorf("Could not load layout '%s'. (%s)", layoutName, err)
		end
	end

	return template, path
end



-- parts = splitString( string, separatorPattern [, startIndex=1, plain=false ] )
function splitString(s, sep, i, plain)
	i = i or 1
	local parts = {}

	while true do
		local i1, i2 = s:find(sep, i, plain)
		if not i1 then  break  end

		table.insert(parts, s:sub(i, i1-1))
		i = i2+1
	end

	table.insert(parts, s:sub(i))
	return parts
end



function clearPageVariables()
	scriptEnvironmentGlobals.page   = nil
	scriptEnvironmentGlobals.params = nil
	scriptEnvironmentGlobals.P      = nil
end



function dateStringToTime(dateStr)
	local year, month, day, hour, minute, second = dateStr:match"^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$"
	if not year then
		errorf("Invalid date string '%s'. (Format must be 'YYYY-MM-DD hh:mm:ss')", dateStr)
	end

	local time = os.time{
		year  = tonumber(year),
		month = tonumber(month),
		day   = tonumber(day),
		hour  = tonumber(hour),
		min   = tonumber(minute),
		sec   = tonumber(second),
	}
	return time
end



--==============================================================
--==============================================================
--==============================================================



local ignoreModificationTimes = false
local autobuild = false

local pathToSiteOnDisc = nil

local args = {...}
local i = 1

while args[i] do
	local arg = args[i]

	if arg == "-f" or arg == "--force" then
		ignoreModificationTimes = true

	elseif arg == "-a" or arg == "--autobuild" then
		autobuild = true

	elseif arg == "-d" or arg == "--drafts" then
		includeDrafts = true

	elseif arg:find"^%-" then
		errorf("[arg] Unknown option '%s'.", arg)

	elseif not pathToSiteOnDisc then
		pathToSiteOnDisc = arg

	else
		errorf("[arg] Unknown argument '%s'.", arg)
	end

	i = i+1
end

if not pathToSiteOnDisc then  error("Missing required pathToSiteOnDisc argument.")  end

if ignoreModificationTimes then  logprint("Option --force: Ignoring modification times.")  end
if autobuild               then  logprint("Option --autobuild: Auto-building website. Press Ctrl+C to stop.")  end
if includeDrafts           then  logprint("Option --drafts: Drafts are included.")  end

assert(lfs.chdir(pathToSiteOnDisc))
logprint("Site folder: %s", toNormalPath(lfs.currentdir()))



-- Prepare log file.
----------------------------------------------------------------

if not isDirectory(DIR_LOGS) then
	assert(lfs.mkdir(DIR_LOGS))
end

local basePath = DIR_LOGS..os.date"/%Y%m%d_%H%M%S"

logPath = basePath..".log"
local i = 1
while isFile(logPath) do
	i = i+1
	logPath = basePath.."_"..i..".log"
end

logFile = io.open(logPath, "w")



----------------------------------------------------------------

local function resetSiteVariables()
	site = {
		title        = "",
		baseUrl      = "/",
		languageCode = "",
	}

	scriptFunctions                   = {}
	scriptEnvironmentGlobals          = nil

	ignoreFiles                       = nil
	ignoreFolders                     = nil

	fileProcessors                    = nil

	removeTrailingSlashFromPermalinks = false

	writtenOutputFiles                = {}
	outputFileCount                   = 0
	outputFileCounts                  = {}
	outputFileByteCount               = 0
	outputFilePreservedCount          = 0
	outputFileSkippedPageCount        = 0

	proxySources                      = {}

	pageLayoutTemplatePath            = nil
	pageLayoutTemplate                = nil

	scriptsCanOutput                  = false


	scriptEnvironmentGlobals = {
		_WEBGEN_VERSION  = _WEBGEN_VERSION,
		IMAGE_EXTENSIONS = IMAGE_EXTENSIONS,

		-- Lua gloals.
		_G             = nil,
		_VERSION       = _VERSION,
		assert         = _assert,
		collectgarbage = collectgarbage,
		dofile         = dofile,
		error          = _error,
		getfenv        = getfenv,
		getmetatable   = getmetatable,
		ipairs         = ipairs,
		load           = load,
		loadfile       = loadfile,
		loadstring     = loadstring,
		module         = module,
		next           = next,
		pairs          = pairs,
		pcall          = _pcall,
		print          = print,
		rawequal       = rawequal,
		rawget         = rawget,
		rawset         = rawset,
		require        = require,
		select         = select,
		setfenv        = setfenv,
		setmetatable   = setmetatable,
		tonumber       = tonumber,
		tostring       = tostringForTemplates,
		type           = type,
		unpack         = unpack,
		xpcall         = xpcall,

		-- Lua modules.
		coroutine      = coroutine,
		debug          = debug,
		io             = io,
		math           = math,
		os             = os,
		package        = package,
		string         = string,
		table          = table,

		-- Lua libraries.
		lfs            = lfs,
		socket         = socket,

		-- Generator page objects. (Create for each individual page.)
		page           = nil,
		params         = nil,
		P              = nil,

		-- Other generator objects.
		site           = newGeneratorObjectProxy(site, "site"),
		data           = newDataFolderReader(DIR_DATA),

		-- Generator functions.
		date           = os.date,
		entities       = encodeHtmlEntities,
		F              = F,
		find           = itemWith,
		findAll        = itemWithAll,
		generatorMeta  = generatorMeta,
		getFilename    = getFilename,
		indexOf        = indexOf,
		markdown       = markdownToHtml,
		printf         = printf,
		sortNatural    = sortNatural,
		split          = splitString,
		trim           = trim,
		trimNewlines   = trimNewlines,
		url            = toUrl,
		urlAbs         = toUrlAbsolute,
		urlize         = urlize,

		chooseExistingFile = function(pathWithoutExt, exts)
			for _, ext in ipairs(exts) do
				local path = pathWithoutExt.."."..ext
				if isFile(DIR_CONTENT.."/"..path) then  return path  end
			end
			return nil
		end,

		chooseExistingImage = function(pathWithoutExt)
			return scriptEnvironmentGlobals.chooseExistingFile(pathWithoutExt, IMAGE_EXTENSIONS)
		end,

		fileExists = function(path)
			return isFile(DIR_CONTENT.."/"..path)
		end,

		getExtension = function(path)
			return getExtension(getFilename(path))
		end,

		isAny = function(v1, values)
			for _, v2 in ipairs(values) do
				if v1 == v2 then  return true  end
			end
			return false
		end,

		newBuffer = function()
			local buffer = {}

			return function(...)
				if select("#", ...) == 0 then  return table.concat(buffer)  end

				local s = select("#", ...) == 1 and assertType(..., "string") or F(...)
				table.insert(buffer, s)
			end
		end,

		X = function(node, tagName) -- @Doc
			assertType(node, "table", "Invalid XML argument.")
			return (itemWith(node, "tag", tagName))
		end,

		Xs = function(node, tagName) -- @Doc
			assertType(node, "table", "Invalid XML argument.")
			return (itemWithAll(node, "tag", tagName))
		end,

		forXml = function(node, tagName) -- @Doc
			assertType(node, "table", "Invalid XML argument.")
			return ipairs(itemWithAll(node, "tag", tagName))
		end,

		printXmlTree = function(node) -- @Doc
			assertType(node, "table", "Invalid XML argument.")

			local function printNode(node, indent)
				print(("    "):rep(indent)..node.tag)

				indent = indent+1
				for _, childNode in ipairs(node) do
					if type(childNode) == "table" then
						printNode(childNode, indent)
					end
				end
			end

			if xmlLib.is_tag(node) then
				printNode(node, 0)
			else
				print("(xml array)")
				for _, childNode in ipairs(node) do
					printNode(childNode, 1)
				end
			end
		end,

		-- xmlGetTexts = function(node, tags)
		-- 	local texts = {}
		-- 	for i, tagName in ipairs(tags) do
		-- 		texts[tagName] = itemWith(node, "tag", tagName):get_text()
		-- 	end
		-- 	return texts
		-- end

		-- xmlGetTexts = function(node, ...) -- Messy to call!
		-- 	local function getText(tagName, ...)
		-- 		if select("#", ...) > 0 then
		-- 			return itemWith("tag", tagName):get_text(), getText(...)
		-- 		end
		-- 	end
		-- 	return getText(...)
		-- end

		-- xmlGetTexts = function(node) -- Different than above.
		-- 	local texts = {}
		-- 	for i, childNode in ipairs(node) do
		-- 		texts[i] = childNode:get_text()
		-- 	end
		-- 	return texts
		-- end

		-- Context functions.

		generateFromTemplate = function(pathRel, template)
			assert(scriptsCanOutput)
			generateFromTemplate(pathRel, template, nil)
		end,

		outputRaw = function(pathRel, contents)
			assert(scriptsCanOutput)
			assertType(contents, "string", "The contents must be a string.")
			writeOutputFile("otherRaw", pathRel, contents)
		end,
	}
end

local function buildWebsite()
	local startTime = socket.gettime()

	resetSiteVariables()



	-- Read config.
	----------------------------------------------------------------

	local config
	local env = createEnvironment(scriptEnvironmentGlobals)

	if not isFile"config.lua" then
		config = {}
	else
		local chunk = assert(loadfile"config.lua")
		setfenv(chunk, env)
		config = chunk()
		assertTable(config, nil, nil, "config.lua must return a table.")
	end

	site.title        = assertType(config.title        or "", "string", "config.title must be a string.")
	site.baseUrl      = assertType(config.baseUrl      or "", "string", "config.baseUrl must be a string.")
	site.languageCode = assertType(config.languageCode or "", "string", "config.languageCode must be a string.")

	ignoreFiles   = assertTable(config.ignoreFiles   or {}, "number", "string", "config.ignoreFiles must be an array of strings.")
	ignoreFolders = assertTable(config.ignoreFolders or {}, "number", "string", "config.ignoreFolders must be an array of strings.")

	fileProcessors = assertTable(config.processors or {}, "string", "function", "config.processors must be a table of functions.")

	removeTrailingSlashFromPermalinks = assertType(config.removeTrailingSlashFromPermalinks or false, "boolean", "config.removeTrailingSlashFromPermalinks must be a boolean.")


	-- Fix details.

	if not site.baseUrl:find"/$" then
		site.baseUrl = site.baseUrl.."/" -- Note: Could result in simply "/".
	end



	-- Generate website from content folder.
	----------------------------------------------------------------

	logprint("Generating website...")

	for category in pairs(OUTPUT_CATEGORY_SET) do
		outputFileCounts[category] = 0
	end

	local err
	pageLayoutTemplatePath = DIR_LAYOUTS.."/page.html"
	pageLayoutTemplate, err = getFileContents(pageLayoutTemplatePath)
	if not pageLayoutTemplate then
		logprint("Notice: Could not load default page layout. (%s)", err)
	end

	if config.before then
		scriptsCanOutput = true
		config.before()
		scriptsCanOutput = false
	end

	-- Generate output.
	traverseFiles(DIR_CONTENT, ignoreFolders, function(path, pathRel, filename, ext)
		local modTime = lfs.attributes(path, "modification")

		if isStringMatchingAnyPattern(filename, ignoreFiles) then
			-- Ignore.

		elseif TEMPLATE_EXTENSION_SET[ext] then
			local template = assert(getFileContents(path))
			generateFromTemplate(pathRel, template, modTime)

		else
			local category = "otherRaw"

			-- Non-templates should be OK to preserve (if there's no file processor).
			local oldModTime
				=   not ignoreModificationTimes
				and not fileProcessors[ext]
				and lfs.attributes(DIR_OUTPUT.."/"..pathRel, "modification")
				or  nil

			if modTime and modTime == oldModTime then
				preserveExistingOutputFile(category, pathRel)
			else
				local contents = assert(getFileContents(path))
				writeOutputFile(category, pathRel, contents, modTime)
			end
		end
	end)

	if config.after then
		scriptsCanOutput = true
		config.after()
		scriptsCanOutput = false
	end

	-- Cleanup old generated stuff.
	traverseFiles(DIR_OUTPUT, nil, function(path, pathRel, filename, ext)
		if not writtenOutputFiles[pathRel] then
			log("Removing: %s", path)
			assert(os.remove(path))
		end
	end)
	removeEmptyDirectories(DIR_OUTPUT)

	logprint("Generating website... done!")



	----------------------------------------------------------------

	local endTime = socket.gettime()

	printf(("-"):rep(64))
	printf("Files: %d", outputFileCount)
	printf("    Pages:           %d  (Skipped: %d)", outputFileCounts["page"], outputFileSkippedPageCount)
	printf("    OtherTemplates:  %d", outputFileCounts["otherTemplate"])
	printf("    OtherFiles:      %d  (Preserved: %d, %.1f%%)",
		outputFileCounts["otherRaw"], outputFilePreservedCount,
		outputFileCounts["otherRaw"] == 0 and 100 or outputFilePreservedCount/outputFileCounts["otherRaw"]*100
	)
	printf("TotalSize: %s", formatBytes(outputFileByteCount))
	printf("Time: %.2f seconds", endTime-startTime)
	printf(("-"):rep(64))

	logFile:flush()
end

buildWebsite()



if autobuild then
	local lastDirTree = nil

	while true do
		socket.sleep(AUTOBUILD_MIN_INTERVAL)

		local dirTree = {}
		local somethingChanged = false

		local function checkFile(path, silent)
			dirTree[path] = assert(lfs.attributes(path, "modification"))

			if lastDirTree and lastDirTree[path] and dirTree[path] > lastDirTree[path] then
				if not silent then
					printf("Detected file change: %s", path)
				end
				somethingChanged = true
			end
		end

		local function checkDirectory(dir, silent)
			traverseDirectory(dir, ignoreFolders, function(path, pathRel, name, itemType)
				if itemType == "directory" then
					dirTree[path] = -1

				elseif itemType == "file" then
					if isStringMatchingAnyPattern(name, ignoreFiles) then  return  end
					checkFile(path, silent)
				end

				if lastDirTree and not lastDirTree[path] then
					somethingChanged = true
					if not silent then
						printf("Detected addition: %s", path)
					end
				end
			end)
		end

		-- Check for additions and modifications.
		checkFile("config.lua")
		local configChanged = somethingChanged
		checkDirectory(DIR_CONTENT)
		checkDirectory(DIR_DATA)
		checkDirectory(DIR_LAYOUTS)
		checkDirectory(DIR_SCRIPTS)

		-- Check for removals.
		if lastDirTree and not somethingChanged then
			for path in pairs(lastDirTree) do
				if not dirTree[path] then
					somethingChanged = true
					printf("Detected removal: %s", path)
					break
				end
			end
		end

		if somethingChanged then buildWebsite() end

		if configChanged then
			-- Recheck everything in case config.ignore* changed.
			dirTree = {["config.lua"]=dirTree["config.lua"]}
			checkDirectory(DIR_CONTENT, true)
			checkDirectory(DIR_DATA,    true)
			checkDirectory(DIR_LAYOUTS, true)
			checkDirectory(DIR_SCRIPTS, true)
		end

		lastDirTree = dirTree
	end
end



_print(F("Check log for details: %s", logPath))
logFile:close()

--==============================================================
--=
--=  MIT License
--=
--=  Copyright © 2018 Marcus 'ReFreezed' Thunström
--=
--=  Permission is hereby granted, free of charge, to any person obtaining a copy
--=  of this software and associated documentation files (the "Software"), to deal
--=  in the Software without restriction, including without limitation the rights
--=  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--=  copies of the Software, and to permit persons to whom the Software is
--=  furnished to do so, subject to the following conditions:
--=
--=  The above copyright notice and this permission notice shall be included in all
--=  copies or substantial portions of the Software.
--=
--=  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--=  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--=  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--=  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--=  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--=  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--=  SOFTWARE.
--=
--==============================================================
