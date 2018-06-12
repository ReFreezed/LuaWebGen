--[[============================================================
--=
--=  LuaWebGen - static website generator in Lua!
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See the bottom of this file)
--=
--============================================================]]

local WEB_GEN_VERSION = "0.1.0"



local PATH_CONTENT = "content"
local PATH_DATA    = "data"
local PATH_LAYOUTS = "layouts"
local PATH_OUTPUT  = "output"
local PATH_SCRIPTS = "scripts"

local HTML_ENTITY_PATTERN = '[&<]'--'[&<>"]'
local HTML_ENTITIES = {
	['&'] = "&amp;",
	['<'] = "&lt;",
	-- ['>'] = "&gt;",
	-- ['"'] = "&quot;",
}

local URI_PERCENT_CODES_TO_NOT_ENCODE = {
	["%2d"]="-",["%2e"]=".",["%7e"]="~",--["???"]="_",
	["%21"]="!",["%23"]="#",["%24"]="$",["%26"]="&",["%27"]="'",["%28"]="(",["%29"]=")",["%2a"]="*",["%2b"]="+",
	["%2c"]=",",["%2f"]="/",["%3a"]=":",["%3b"]=";",["%3d"]="=",["%3f"]="?",["%40"]="@",["%5b"]="[",["%5d"]="]",
}

local TEMPLATE_EXTENSION_SET = {["html"]=true, ["md"]=true, ["css"]=true}
local PAGE_EXTENSION_SET     = {["html"]=true, ["md"]=true}

local OUTPUT_CATEGORY_SET = {["page"]=true, ["otherTemplate"]=true, ["otherRaw"]=true}



package.path = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("[^/\\]*$", "?.lua;")..package.path

local lfs           = require"lfs"
local socket        = require"socket"

local escapeUri     = require"socket.url".escape

local parseMarkdown = require"lib.markdown"
local parseToml     = require"lib.toml".parse



local site = {
	title        = "",
	baseUrl      = "/",
	languageCode = "",
}

local scriptFunctions = {}
local scriptEnvironmentGlobals = nil

local ignoreFiles   = {}
local ignoreFolders = {}

local removeTrailingSlashFromPermalinks = false

local writtenOutputFiles = {}
local outputFileCount = 0
local outputFileCounts = {}
local outputFileByteCount = 0

local proxySources = {}



--==============================================================
--= Functions ==================================================
--==============================================================

local createDirectory
local errorf, fileerror, errorInGeneratedCodeFromTemplate
local F
local generatorMeta
local getFileContents
local getLineNumber
local include
local insertLineNumberCode
local isFile, isDirectory
local isStringMatchingAnyPattern
local log
local newDataFolderReader
local newGeneratorObjectProxy
local parseMarkdownTemplate, parseHtmlTemplate, parseOtherTemplate
local sortNatural
local tostringForTemplate
local toUrl, urlize
local toWindowsPath
local traverseFiles
local trim, trimNewlines
local writeOutputFile, preserveExistingOutputFile



function traverseFiles(dirPath, ignoreFolders, cb, _pathRelStart)
	_pathRelStart = _pathRelStart or #dirPath+2

	for name in lfs.dir(dirPath) do
		local path = dirPath.."/"..name

		if name ~= "." and name ~= ".." then
			local mode = lfs.attributes(path, "mode")

			if mode == "file" then
				local pathRel = path:sub(_pathRelStart)
				local ext = name:match"%.([^.]+)$" or ""
				local abort = cb(path, pathRel, name, ext)
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
				local luaStatement = F("echoRaw(%q)\n", plainSegment) :gsub("\\\n", "\\n")
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
			local luaStatement = F("echoRaw(%q)\n", plainSegment) :gsub("\\\n", "\\n")
			table.insert(lua, luaStatement)
		end

		local luaCode = table.concat(lua)

		-- print("-- LUA --") print(luaCode) print("-- /LUA --")

		--= Generate output.
		--==============================================================

		local out = {}

		local funcs = {
			echoRaw = function(s)
				table.insert(out, s)
			end,
			echo = function(s)
				if enableHtmlEncoding then
					s = s:gsub(HTML_ENTITY_PATTERN, HTML_ENTITIES)
				end
				table.insert(out, s)
			end,
		}

		local chunk, err = loadstring(luaCode)
		if not chunk then
			errorInGeneratedCodeFromTemplate(path, luaCode, err)
		end

		local env = setmetatable({}, {
			__index = function(env, k)
				local v = funcs[k] or scriptEnvironmentGlobals[k]
				if v ~= nil then  return v  end

				v = scriptFunctions[k]
				if v then
					setfenv(v, env)
					return v
				end

				if isFile(F("%s/%s.lua", PATH_SCRIPTS, k)) then
					local chunk = assert(loadfile(F("%s/%s.lua", PATH_SCRIPTS, k)))
					v = chunk()
					assert(type(v) == "function")

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
		scriptEnvironmentGlobals._G = env
		setfenv(chunk, env)

		local ok, err = pcall(chunk)
		if not ok then
			errorInGeneratedCodeFromTemplate(path, luaCode, err)
		end

		out = table.concat(out)
			:gsub("[ \t]+\n", "\n")
			:gsub("\n\n\n+", "\n\n")

		--==============================================================

		return out
	end

	function parseMarkdownTemplate(path, template)
		local md = parseTemplate(path, template, 1, 1, true)

		local html = parseMarkdown(md):gsub("/>", ">")
		html = trimNewlines(html).."\n"

		-- print("-- HTML --") print(html) print("-- /HTML --")

		return html
	end

	function parseHtmlTemplate(path, template)
		local html = parseTemplate(path, template, 1, 1, true)
		html = trimNewlines(html).."\n"

		-- print("-- HTML --") print(html) print("-- /HTML --")

		return html
	end

	function parseOtherTemplate(path, template)
		local contents = parseTemplate(path, template, 1, 1, false)
		contents = trimNewlines(contents).."\n"

		-- print("-- CONTENTS --") print(contents) print("-- /CONTENTS --")

		return contents
	end

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
	error(("%s:%d: "..s):format(path, ln, ...), 2)
end

function errorInGeneratedCodeFromTemplate(path, genCode, errInGenCode)
	local lnInGenCode, err = errInGenCode:match'^%[string ".-"%]:(%d+): (.+)'
	local lnInTemplate = 0
	if not lnInGenCode then
		err = errInGenCode
	else
		for line in genCode:gmatch"([^\n]*)\n?" do
			lnInGenCode = lnInGenCode-1
			lnInTemplate = tonumber(line:match"^%-%- @LINE(%d+)$") or lnInTemplate
			if lnInGenCode <= 1 then  break  end
		end
	end
	fileerror(path, nil, lnInTemplate, err)
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

	local path = PATH_OUTPUT.."/"..pathRel
	log("Writing: %s", path)

	local dirPath = path:gsub("/[^/]+$", "")
	createDirectory(dirPath)

	local file = assert(io.open(path, "wb"))
	file:write(data)
	file:close()

	if modTime then
		local ok, err = lfs.touch(path, modTime)
		if not ok then
			log("Error: Could not update modification time for '%s': %s", path, err)
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

	local path = PATH_OUTPUT.."/"..pathRel
	log("Preserving: %s", path)

	local dataLen, err = lfs.attributes(path, "size")
	if not dataLen then
		log("Error: Could not retrieve size of file '%s': %s", path, err)
		dataLen = 0
	end

	table.insert(writtenOutputFiles, pathRel)
	writtenOutputFiles[pathRel] = true

	assert(OUTPUT_CATEGORY_SET[category], category)
	outputFileCount = outputFileCount+1
	outputFileCounts[category] = outputFileCounts[category]+1

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



function log(s, ...)
	if select("#", ...) > 0 then  s = s:format(...)  end

	print(F("[%s] %s", os.date"%Y-%m-%d %H:%M:%S", s))
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



function include(htmlFileBasename)
	local path     = F("%s/%s.html", PATH_LAYOUTS, htmlFileBasename)
	local template = assert(getFileContents(path))
	local html     = parseHtmlTemplate(path, template)
	return html
end



function toUrl(urlStr)
	urlStr = urlStr:gsub("^/", site.baseUrl)
	urlStr = escapeUri(urlStr)
	urlStr = urlStr:gsub("%%[0-9a-f][0-9a-f]", URI_PERCENT_CODES_TO_NOT_ENCODE)

	return urlStr
end
-- print(toUrl("http://www.example.com/some-path/File~With (Stuff_åäö).jpg?key=value&foo=bar#hash")) -- TEST

function urlize(text)
	text = text
		:lower()
		:gsub("[%p ]+", "-")
		:gsub("^%-+", "")
		:gsub("%-+$", "")

	return text == "" and "-" or text
end



function generatorMeta()
	return '<meta name="generator" content="LuaWebGen '..WEB_GEN_VERSION..'">'
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

	function tostringForTemplate(v)
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
		return (tostringForTemplate(a):gsub("%d+", pad) < tostringForTemplate(b):gsub("%d+", pad))
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
			local mode = lfs.attributes(path.."/"..k, "mode")

			if isFile(F("%s/%s.lua", path, k)) then
				local dataObj = assert(loadfile(F("%s/%s.lua", path, k)))()
				assert(dataObj ~= nil)
				rawset(dataFolderReader, k, dataObj)
				return dataObj

			elseif isFile(F("%s/%s.toml", path, k)) then
				local dataObj = parseToml(assert(getFileContents(F("%s/%s.toml", path, k))))
				assert(dataObj ~= nil)
				rawset(dataFolderReader, k, dataObj)
				return dataObj

			elseif lfs.attributes(F("%s/%s", path, k), "mode") == "folder" then
				return newDataFolderReader(F("%s/%s", path, k))

			else
				errorf("Bad data path '%s/%s'.", path, k)
			end
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



function toWindowsPath(path)
	local winPath = path:gsub("/", "\\")
	return winPath
end



--==============================================================
--==============================================================
--==============================================================



log("Generating website...")

local pathToSiteOnDisc = ...
if not pathToSiteOnDisc then
	error("Missing required pathToSiteOnDisc argument.")
end

assert(lfs.chdir(pathToSiteOnDisc))



-- Read config.
----------------------------------------------------------------

local chunk = loadfile"config.lua"
local config

if chunk then
	config = chunk()
	assert(type(config) == "table", "config.lua must return a table.")
else
	config = {}
end

site.title        = config.title        or ""
site.baseUrl      = config.baseUrl      or ""
site.languageCode = config.languageCode or ""

ignoreFiles   = config.ignoreFiles   or ignoreFiles
ignoreFolders = config.ignoreFolders or ignoreFolders

removeTrailingSlashFromPermalinks = config.removeTrailingSlashFromPermalinks or false


-- Fix details.

if not site.baseUrl:find"/$" then
	site.baseUrl = site.baseUrl.."/" -- Note: Could result in simply "/".
end



-- Prepare script environment.
----------------------------------------------------------------

scriptEnvironmentGlobals = {
	-- Lua gloals.
	_G             = nil, -- Set where scriptEnvironmentGlobals is used.
	_VERSION       = _VERSION,
	assert         = assert,
	collectgarbage = collectgarbage,
	dofile         = dofile,
	error          = error,
	getfenv        = getfenv,
	getmetatable   = getmetatable,
	ipairs         = ipairs,
	load           = load,
	loadfile       = loadfile,
	loadstring     = loadstring,
	module         = module,
	next           = next,
	pairs          = pairs,
	pcall          = pcall,
	print          = print,
	rawequal       = rawequal,
	rawget         = rawget,
	rawset         = rawset,
	require        = require,
	select         = select,
	setfenv        = setfenv,
	setmetatable   = setmetatable,
	tonumber       = tonumber,
	tostring       = tostringForTemplate,
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

	-- Generator functions.
	date           = os.date,
	F              = F,
	generatorMeta  = generatorMeta,
	include        = include,
	sortNatural    = sortNatural,
	trim           = trim,
	trimNewlines   = trimNewlines,
	url            = toUrl,
	urlize         = urlize,

	-- Generator page objects. (Create for each individual page.)
	page           = nil,
	params         = nil,
	P              = nil,

	-- Other generator objects.
	site           = newGeneratorObjectProxy(site, "site"),
	data           = newDataFolderReader(PATH_DATA),
}



-- Generate website from content folder.
----------------------------------------------------------------

for category in pairs(OUTPUT_CATEGORY_SET) do
	outputFileCounts[category] = 0
end

local pageLayoutTemplatePath = PATH_LAYOUTS.."/page.html"
local pageLayoutTemplate = assert(getFileContents(pageLayoutTemplatePath))

-- Generate output.
traverseFiles(PATH_CONTENT, ignoreFolders, function(path, pathRel, filename, ext)
	local modTime = lfs.attributes(path, "modification")

	if isStringMatchingAnyPattern(filename, ignoreFiles) then
		-- Ignore.

	elseif TEMPLATE_EXTENSION_SET[ext] then
		local isPage  = PAGE_EXTENSION_SET[ext] or false
		local isIndex = isPage  and filename:sub(1, #filename-#ext-1) == "index"
		local isHome  = isIndex and pathRel == filename

		local permalinkRel = (
			not isPage and pathRel
			or isHome and ""
			or isIndex and pathRel:sub(1, -#filename-1)
			or pathRel:sub(1, -#ext-2).."/"
		)

		local pathRelOut
			=  (not isPage and permalinkRel)
			or (permalinkRel == "" and "" or permalinkRel).."index.html"

		local category = isPage and "page" or "otherTemplate"
		local oldModTime = lfs.attributes(PATH_OUTPUT.."/"..pathRelOut, "modification")

		if modTime and modTime == oldModTime then
			preserveExistingOutputFile(category, pathRelOut)

		else
			local page = {
				title     = "",
				content   = "",
				permalink = site.baseUrl..(removeTrailingSlashFromPermalinks and permalinkRel:gsub("/$", "") or permalinkRel),
				rssLink   = "", -- @Incomplete

				isPage    = isPage,
				isIndex   = isIndex,
				isHome    = isHome,
			}
			-- print(pathRel, (not isPage and " " or isHome and "H" or isIndex and "I" or "P"), page.permalink) -- DEBUG

			local scriptParams = {}

			scriptEnvironmentGlobals.page   = newGeneratorObjectProxy(page, "page")
			scriptEnvironmentGlobals.params = scriptParams
			scriptEnvironmentGlobals.P      = scriptParams

			local contents = assert(getFileContents(path))
			local out

			if ext == "md" then
				page.content = parseMarkdownTemplate(pathRel, contents)
				out = parseHtmlTemplate(pageLayoutTemplatePath, pageLayoutTemplate)

			elseif ext == "html" then
				page.content = parseHtmlTemplate(pathRel, contents)
				out = parseHtmlTemplate(pageLayoutTemplatePath, pageLayoutTemplate)

			else
				assert(not isPage)
				out = parseOtherTemplate(pathRel, contents)
			end

			assert(out)
			writeOutputFile(category, pathRelOut, out, modTime)
		end

	else
		local contents = assert(getFileContents(path))
		writeOutputFile("otherRaw", pathRel, contents, modTime)
	end
end)

-- assert(false, "DEBUG")

-- Cleanup old generated files.
traverseFiles(PATH_OUTPUT, nil, function(path, pathRel, filename, ext)
	if not writtenOutputFiles[pathRel] then
		log("Removing: %s", path)
		os.remove(path)
	end
end)

-- Cleanup empty folders.
-- https://superuser.com/a/972366
log("Removing empty folders...")
local winPath = toWindowsPath(PATH_OUTPUT)
local code = os.execute(F([[ROBOCOPY "%s" "%s" /S /MOVE > NUL]], winPath, winPath))
if code ~= 0 then
	error("[ROBOCOPY] Could not remove empty folders.")
end
log("Removing empty folders... done!")



----------------------------------------------------------------

log("Generating website... done!")

print(("-"):rep(64))
print(F("Files: %d", outputFileCount))
print(F("    Pages           %d", outputFileCounts["page"]))
print(F("    OtherTemplates  %d", outputFileCounts["otherTemplate"]))
print(F("    OtherFiles      %d", outputFileCounts["otherRaw"]))
print(F("TotalSize: %.2f kb", outputFileByteCount/1024))
print(("-"):rep(64))

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
