--[[============================================================
--=
--=  Global Functions
--=
--=-------------------------------------------------------------
--=
--=  LuaWebGen - static website generator in Lua!
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--==============================================================

	assert, assertf, assertType, assertTable
	createDirectory, isDirectoryEmpty, removeEmptyDirectories
	createThumbnail
	dateStringToTime
	encodeHtmlEntities
	error, errorf, fileerror, errorInGeneratedCodeFromTemplate
	F, formatBytes, formatTemplate
	generateFromTemplate, generateFromTemplateFile, generateRedirection
	generatorMeta
	getDirectory, getFilename, getExtension, getBasename
	getFileContents
	getKeys
	getLayoutTemplate
	getLineNumber
	getProtectionWrapper
	indexOf, itemWith, itemWithAll
	insertLineNumberCode
	isAny
	isFile, isDirectory
	isStringMatchingAnyPattern
	markdownToHtml
	newDataFolderReader, isDataFolderReader, preloadData
	newPage
	newStringBuffer
	parseMarkdownTemplate, parseHtmlTemplate, parseOtherTemplate
	pathToSitePath, sitePathToPath
	pcall
	print, printOnce, printf, printfOnce, log, logprint, logVerbose
	pushContext, popContext, assertContext, getContext
	removeItem
	rewriteOutputPath
	round
	serializeLua
	sortNatural
	splitString
	storeArgs
	toNormalPath, toWindowsPath
	tostringForTemplates
	toUrl, toUrlAbsolute, urlize
	traverseDirectory, traverseFiles
	trim, trimNewlines
	unindent
	urlExists
	writeOutputFile, preserveExistingOutputFile

--============================================================]]



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
				local pathRel  = path:sub(_pathRelStart)
				local extLower = getExtension(name):lower()
				local abort    = cb(path, pathRel, name, extLower)
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
	local function maybeInsertPossibleValueExpression(lua, code)
		local expr = F("do\n\tlocal v = (\n\t\t%s\n\t)\n\tif type(v) == 'string' and v:match'%%S' == '<' then  echoRaw(v)  elseif v ~= nil then  echo(v)  end\nend\n", code)
		if not loadstring(expr) then  return false  end

		table.insert(lua, expr)
		return true
	end

	local function parseTemplate(page, path, template, pos, level, enableHtmlEncoding)

		--= Generate Lua.
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

			-- Note: A long comment here refers to a comment that spans the whole code block:
			-- "{{--[===[ A comment, yay! ]] ... ]===]}}"
			if longCommentLevel then
				pos = pos+4+#longCommentLevel -- Eat "--[=[".
				_, codePosEnd = template:find("%]"..longCommentLevel.."%]}}", pos)

				if not codePosEnd then
					fileerror(
						path, template, pos,
						'Comment block never ends. ("{{--[%s[" must end with "]%s]}}")',
						longCommentLevel, longCommentLevel
					)
				end

			else
				_, codePosEnd = template:find("}}", pos, true)

				if not codePosEnd then
					fileerror(path, template, pos, 'Code block never ends.')
				end
			end

			local codeUntrimmed = template:sub(codePosStart+2, codePosEnd-2)
			local code          = trim(codeUntrimmed)
			-- print("CODE: "..code)

			----------------------------------------------------------------

			-- Comments.
			if longCommentLevel or code:find"^%-%-[^\n]*$" then
				-- void

			-- fori item in array ... end
			-- fori array ... end
			elseif code:find"^fori%f[^%w_]" then
				local foriItem, foriArr = code:match"^fori +([%a_][%w_]+) +in +(%S.*)$"

				if not foriArr then
					foriArr = code:match"^fori +(.+)$"

					if not foriArr then
						fileerror(path, template, pos, "Invalid fori statement.")
					end
				end

				table.insert(lua, "for _, ")
				table.insert(lua, foriItem or "it")
				table.insert(lua, " in ipairs(")
				table.insert(lua, foriArr)
				table.insert(lua, ") do\n")

				local innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(
					page, path, template, codePosEnd+1, level+1, enableHtmlEncoding
				)
				local innerEndCode = trim(template:sub(innerEndCodePosStart+2, innerEndCodePosEnd-2))

				if innerEndCode ~= "end" then
					fileerror(
						path, template, innerEndCodePosStart,
						"Expected end for 'fori' starting at line %d.",
						getLineNumber(template, pos)
					)
				end

				for _, luaCode in ipairs(innerLua) do  table.insert(lua, luaCode)  end
				table.insert(lua, "end\n")

				codePosEnd = innerEndCodePosEnd

			-- Value expression.
			elseif not code:find"^function%s*%(" and maybeInsertPossibleValueExpression(lua, code) then
				-- void

			-- for index, item in expression ... end
			-- for index = from, to, step ... end
			-- for to ... end
			elseif codeUntrimmed:find"^ *for%f[^%w_]" then
				local shortformBackwards, shortformNumber = code:match"^for%s+(%-?)(%d+)$"

				if shortformBackwards == "-" then
					table.insert(lua, "for i = ")
					table.insert(lua, shortformNumber)
					table.insert(lua, ", 1, -1 do\n")
				elseif shortformNumber then
					table.insert(lua, "for i = 1, ")
					table.insert(lua, shortformNumber)
					table.insert(lua, " do\n")
				else
					table.insert(lua, code)
					table.insert(lua, " do\n")
				end

				local innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(
					page, path, template, codePosEnd+1, level+1, enableHtmlEncoding
				)
				local innerEndCode = trim(template:sub(innerEndCodePosStart+2, innerEndCodePosEnd-2))

				if innerEndCode ~= "end" then
					fileerror(
						path, template, innerEndCodePosStart,
						"Expected end for 'for' starting at line %d.",
						getLineNumber(template, pos)
					)
				end

				for _, luaCode in ipairs(innerLua) do  table.insert(lua, luaCode)  end
				table.insert(lua, "end\n")

				codePosEnd = innerEndCodePosEnd

			-- do ... end
			elseif code == "do" then
				table.insert(lua, "do\n")

				local innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(
					page, path, template, codePosEnd+1, level+1, enableHtmlEncoding
				)
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
			elseif codeUntrimmed:find"^ *if%f[^%w_]" then
				table.insert(lua, code)
				table.insert(lua, " then\n")

				local innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(
					page, path, template, codePosEnd+1, level+1, enableHtmlEncoding
				)
				local innerEndCode = trim(template:sub(innerEndCodePosStart+2, innerEndCodePosEnd-2))

				for _, luaCode in ipairs(innerLua) do  table.insert(lua, luaCode)  end
				insertLineNumberCode(lua, getLineNumber(template, innerEndCodePosStart))

				while innerEndCode:find"^elseif[ (]" do
					table.insert(lua, innerEndCode)
					table.insert(lua, " then\n")

					innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(
						page, path, template, innerEndCodePosEnd+1, level+1, enableHtmlEncoding
					)
					innerEndCode = trim(template:sub(innerEndCodePosStart+2, innerEndCodePosEnd-2))

					for _, luaCode in ipairs(innerLua) do  table.insert(lua, luaCode)  end
					insertLineNumberCode(lua, getLineNumber(template, innerEndCodePosStart))
				end

				if innerEndCode == "else" then
					table.insert(lua, "else\n")

					innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(
						page, path, template, innerEndCodePosEnd+1, level+1, enableHtmlEncoding
					)
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

			-- while expression ... end
			elseif codeUntrimmed:find"^ *while%f[^%w_]" then
				table.insert(lua, code)
				table.insert(lua, " do\n")

				local innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(
					page, path, template, codePosEnd+1, level+1, enableHtmlEncoding
				)
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

				local innerLua, innerEndCodePosStart, innerEndCodePosEnd = parseTemplate(
					page, path, template, codePosEnd+1, level+1, enableHtmlEncoding
				)
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

			-- End of block.
			elseif code == "end" or code:find"^until[ (]" or code == "else" or code:find"^elseif[ (]" then
				if level == 1 then
					fileerror(path, template, pos, "Unexpected '%s'.", (code:match"^%w+"))
				end
				return lua, codePosStart, codePosEnd

			else
				table.insert(lua, code)
				table.insert(lua, "\n")
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

		local chunk, err = loadstring(luaCode)
		if not chunk then
			errorInGeneratedCodeFromTemplate(path, luaCode, err)
		end

		setfenv(chunk, scriptEnvironment)

		local ctx = pushContext("template")
		ctx.page = page
		ctx._scriptEnvironmentGlobals.page   = getProtectionWrapper(page, "page")
		ctx._scriptEnvironmentGlobals.params = page.params
		ctx._scriptEnvironmentGlobals.P      = page.params
		ctx.out = out
		ctx.enableHtmlEncoding = enableHtmlEncoding

		local ok, err = pcall(chunk)

		popContext("template")

		if not ok then
			errorInGeneratedCodeFromTemplate(path, luaCode, err)
		end

		out = table.concat(out)
			:gsub("[ \t]+\n", "\n") -- :Beautify
			:gsub("\n\n\n+", "\n\n") -- :Beautify

		--==============================================================

		return out
	end

	function parseMarkdownTemplate(page, path, template)
		local md = parseTemplate(page, path, template, 1, 1, true)

		local html = markdownToHtml(md)
		html = trimNewlines(html).."\n" -- :Beautify

		-- print("-- HTML --") print(html) print("-- /HTML --")

		return html
	end

	function parseHtmlTemplate(page, path, template)
		local html = parseTemplate(page, path, template, 1, 1, true)
		html = trimNewlines(html).."\n" -- :Beautify

		-- print("-- HTML --") print(html) print("-- /HTML --")

		return html
	end

	function parseOtherTemplate(page, path, template)
		local contents = parseTemplate(page, path, template, 1, 1, false)
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



-- writeOutputFile( category, pathRelative, url, dataString [ modificationTime ] )
function writeOutputFile(category, pathRel, url, data, modTime)
	local pathOutputRel = rewriteOutputPath(pathRel)
	if writtenOutputFiles[pathOutputRel] then
		errorf("Duplicate output file '%s'.", pathOutputRel)
	end
	assert(not writtenOutputUrls[url])

	local filename = getFilename(pathRel)
	local extLower = getExtension(filename):lower()

	if fileProcessors[extLower] then
		pushContext("config")
		data = fileProcessors[extLower](data, pathToSitePath(pathRel))
		popContext("config")

		assertType(data, "string", "File processor didn't return a string. (%s)", extLower)
	end

	local path = DIR_OUTPUT.."/"..pathOutputRel
	logVerbose("Writing: %s", path)

	createDirectory(getDirectory(path))

	local file = assert(io.open(path, "wb"))
	file:write(data)
	file:close()

	if modTime then
		local ok, err = lfs.touch(path, modTime)
		if not ok then
			logprint("Error: Could not update modification time for '%s': %s", path, err)
		end
	end

	table.insert(writtenOutputFiles, pathOutputRel)
	writtenOutputFiles[pathOutputRel] = true
	writtenOutputUrls[url] = true

	assert(OUTPUT_CATEGORY_SET[category], category)
	outputFileCount = outputFileCount+1
	outputFileCounts[category] = outputFileCounts[category]+1

	outputFileByteCount = outputFileByteCount+#data
end

-- preserveExistingOutputFile( category, pathRelative, url )
function preserveExistingOutputFile(category, pathRel, url)
	local pathOutputRel = rewriteOutputPath(pathRel)
	if writtenOutputFiles[pathOutputRel] then
		errorf("Duplicate output file '%s'.", pathOutputRel)
	end
	assert(not writtenOutputUrls[url])

	local path = DIR_OUTPUT.."/"..pathOutputRel
	-- logVerbose("Preserving: %s", path)

	local dataLen, err = lfs.attributes(path, "size")
	if not dataLen then
		logprint("Error: Could not retrieve size of file '%s'. (%s)", path, err)
		dataLen = 0
	end

	table.insert(writtenOutputFiles, pathOutputRel)
	writtenOutputFiles[pathOutputRel] = true
	writtenOutputUrls[url] = true

	assert(OUTPUT_CATEGORY_SET[category], category)
	outputFileCount = outputFileCount+1
	outputFileCounts[category] = outputFileCounts[category]+1
	outputFilePreservedCount = outputFilePreservedCount+1

	outputFileByteCount = outputFileByteCount+dataLen
end



function createDirectory(path)
	if path:find"^/" or path:find"^%a:" then
		errorf(2, "[Internal] Absolute paths are disabled. (%s)", path)
	end
	if path:find"//" then
		errorf(2, "Path looks invalid: '%s'", path)
	end

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
				logVerbose("Removing empty folder: %s", path)
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

	function printOnce(...)
		local argCount = select("#", ...)
		for i = 1, argCount do
			values[i] = tostring(select(i, ...))
		end

		local s = table.concat(values, "\t", 1, argCount)

		if oncePrints[s] then  return  end
		oncePrints[s] = true

		_print(...)
		log(s)
	end
end

function printf(s, ...)
	print(s:format(...))
end

function printfOnce(s, ...)
	printOnce(s:format(...))
end

-- log( string )
-- log( formatString, ... )
function log(s, ...)
	if select("#", ...) > 0 then  s = s:format(...)  end

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
	if select("#", ...) > 0 then  s = s:format(...)  end

	printf("[%s]  %s", os.date"%Y-%m-%d %H:%M:%S", s)
end

function logVerbose(...)
	if verbosePrint then
		logprint(...)
	else
		log(...)
	end
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

function formatTemplate(s, values)
	s = s:gsub(":([%a_][%w_]*):", function(k)
		if values[k] == nil then
			logprint("[formatTemplate] WARNING: No value for ':%s:'.", k)
		else
			return tostring(values[k])
		end
	end)

	return unindent(s)
end



function toUrl(url)
	if type(url) ~= "string" then
		errorf(2, "Bad type of 'url' argument. (Got %s)", type(url))
	end

	url = escapeUri(url)
	url = url:gsub("%%[0-9a-f][0-9a-f]", URI_PERCENT_CODES_TO_NOT_ENCODE)

	return url
end
-- print(toUrl("http://www.example.com/some-path/File~With (Stuff_åäö).jpg?key=value&foo=bar#hash")) -- TEST

function toUrlAbsolute(url)
	url = url:gsub("^/%f[^/]", site.baseUrl)
	return toUrl(url)
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



-- array = sortNatural( array [, attribute ] )
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

			if type(k) ~= "string" then
				return nil

			elseif k == "." or k == ".." then
				errorf(2, "Bad data key '%s'.", k)

			elseif isFile(F("%s/%s.lua", path, k)) then
				local filePath = F("%s/%s.lua", path, k)
				local chunk    = assert(loadfile(filePath))
				setfenv(chunk, scriptEnvironment)

				pushContext("none")
				dataObj = chunk()
				popContext("none")

				if not dataObj then
					errorf(2, "Lua data file returned nothing. (%s)", filePath)
				end

			elseif isFile(F("%s/%s.toml", path, k)) then
				local filePath = F("%s/%s.toml", path, k)
				local contents = assert(getFileContents(filePath))
				dataObj = assert(parseToml(contents))

			elseif isFile(F("%s/%s.xml", path, k)) then
				local filePath = F("%s/%s.xml", path, k)
				local contents = assert(getFileContents(filePath))
				dataObj = assert(xmlLib.parse(contents, false))

			elseif isDirectory(F("%s/%s", path, k)) then
				dataObj = newDataFolderReader(F("%s/%s", path, k))

			else
				printfOnce("WARNING: Bad data path '%s/%s'.", path, k)
				return nil
			end

			assert(dataObj ~= nil)
			rawset(dataFolderReader, k, dataObj)
			return dataObj
		end,
	})

	dataReaderPaths[dataFolderReader] = path
	return dataFolderReader
end

function isDataFolderReader(t)
	return dataReaderPaths[t] ~= nil
end

function preloadData(dataFolderReader)
	if dataIsPreloaded[dataFolderReader] then  return  end

	for name in lfs.dir(dataReaderPaths[dataFolderReader]) do
		local path     = dataReaderPaths[dataFolderReader].."/"..name
		local basename = getBasename(name)

		if
			not rawget(dataFolderReader, basename) and name ~= "." and name ~= ".." and (
				(isFile(path)      and not isStringMatchingAnyPattern(name, ignoreFiles  )) or
				(isDirectory(path) and not isStringMatchingAnyPattern(name, ignoreFolders))
			)
		then
			if indexOf(DATA_FILE_EXTENSIONS, getExtension(name)) then
				local _ = dataFolderReader[basename]
			end
		end
	end

	dataIsPreloaded[dataFolderReader] = true
end



function getProtectionWrapper(obj, name)
	local proxy = proxies[obj]
	if proxy then  return proxy  end

	proxy = setmetatable({}, {
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

	proxies[obj]        = proxy
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



function getDirectory(genericPath)
	return (genericPath:gsub("/?[^/]+$", ""))
end

function getFilename(genericPath)
	return genericPath:match"[^/]+$"
end

function getExtension(filename)
	return filename:match"%.([^.]+)$" or ""
end

function getBasename(filename)
	local ext = getExtension(filename)
	if ext == "" then  return filename  end

	return filename:sub(1, #filename-#ext-1)
end



-- generateFromTemplate( page, template [, modificationTime ] )
function generateFromTemplate(page, template, modTime)
	assert(type(page) == "table")
	assert(type(template) == "string")

	if page._isGenerated then
		errorf(2, "Page has already generated. (%s)", page._path)
	end
	if pagesGenerating[page._pathOut] then
		errorf(2, "Recursive page generation detected. (%s)", page._path)
	end

	pagesGenerating[page._pathOut] = true

	local pathRel  = page._path
	local filename = getFilename(pathRel)
	local ext      = getExtension(filename)
	local extLower = ext:lower()

	local outStr

	if extLower == "md" then
		page.content = parseMarkdownTemplate(page, pathRel, template)
	elseif extLower == "html" then
		page.content = parseHtmlTemplate(page, pathRel, template)
	else
		assert(not page.isPage)
		outStr = parseOtherTemplate(page, pathRel, template)
	end

	if page.isPage then
		if
			(page.isDraft and not includeDrafts) or -- Is draft?
			(dateStringToTime(page.publishDate) > os.time()) -- Is in future?
		then
			outputFileSkippedPageCount = outputFileSkippedPageCount+1
			pagesGenerating[page._pathOut] = nil
			page._isSkipped = true
			return
		end

		local layoutTemplate, layoutPath = getLayoutTemplate(page)
		outStr = parseHtmlTemplate(page, layoutPath, layoutTemplate)
	end

	assert(outStr)
	writeOutputFile(page._category, page._pathOut, page.url, outStr, modTime)

	pagesGenerating[page._pathOut] = nil
	page._isGenerated = true
end

function generateFromTemplateFile(page)
	if page._isSkipped then return end

	local path     = DIR_CONTENT.."/"..page._path
	local template = assert(getFileContents(path))
	local modTime  = lfs.attributes(path, "modification")

	if modTime then
		page.publishDate = os.date("%Y-%m-%d %H:%M:%S", modTime) -- Default value.
	end

	generateFromTemplate(page, template, modTime)
end

function generateRedirection(slug, targetUrl)
	assertType(slug, "string")
	assertType(targetUrl, "string")

	if not slug:find"^/" then
		errorf(2, "URL slugs must begin with a '/'. (%s)", slug)
	end

	if writtenRedirects[slug] == targetUrl then
		errorf(2, "Duplicate redirect from '%s' to '%s'.", slug, targetUrl)
	elseif writtenRedirects[slug] then
		errorf(2, "Duplicate redirect from '%s' (to different targets).", slug)
	end

	local pathRel  = (slug:gsub("/$", "").."/index.html"):gsub("^/", "")
	local contents = formatTemplate(
		[=[
			<!DOCTYPE html>
			<html>
				<head>
					<meta charset="utf-8">
					<meta name="robots" content="noindex">
					<meta http-equiv="refresh" content="0; url=:urlPercent:">
					<title>:url:</title>
					<link rel="canonical" href=":urlPercent:">
				</head>
				<body>
					<p>Page has moved. If you are not redirected automatically,
					click <a href=":urlPercent:">here</a>.</p>
				</body>
			</html>
		]=], {
			url        =               encodeHtmlEntities(targetUrl) ,
			urlPercent = toUrlAbsolute(encodeHtmlEntities(targetUrl)),
		}
	)

	writeOutputFile("page", pathRel, slug, contents)
	writtenRedirects[slug] = targetUrl
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



-- template, path = getLayoutTemplate( page )
function getLayoutTemplate(page)
	local path = F("%s/%s.html", DIR_LAYOUTS, page.layout)

	local template = layoutTemplates[path]
	if template then  return template  end

	local template, err = getFileContents(path)
	if not template then
		errorf("%s: Could not load layout '%s'. (%s)", page._path, page.layout, err)
	end

	layoutTemplates[path] = template
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



function unindent(s)
	local indent = s:match"^\t+"
	if indent then
		s = s
			:gsub("\n"..indent, "\n")
			:sub(#indent+1)
			:gsub("\t+$", "")
	end

	return s
end



function pushContext(ctxName)
	local ctx = {_name=ctxName, _scriptEnvironmentGlobals={}}
	table.insert(contextStack, ctx)
	return ctx
end

function popContext(ctxName)
	assertContext(ctxName)
	table.remove(contextStack)
end

-- assertContext( contextName [, functionContext ] )
function assertContext(ctxName, funcContext)
	local ctx = contextStack[#contextStack]
	if not ctx or ctx._name ~= ctxName then
		if funcContext then
			errorf(2, "[%s] Context is wrong. (Expected '%s', but is '%s')", funcContext, ctxName, ctx and ctx._name or "none")
		else
			errorf(2,      "Context is wrong. (Expected '%s', but is '%s')",              ctxName, ctx and ctx._name or "none")
		end
	end
end

-- context = getContext( [ contextName ] )
function getContext(ctxName)
	if ctxName then  assertContext(ctxName)  end

	local ctx = contextStack[#contextStack] or error("There is no context.")
	return ctx
end



-- thumbnailInfo = createThumbnail( imagePathRelative, thumbWidth [, thumbHeight, errorLevel=1 )
do
	local imageLoaders = {
		["png"]  = gd.createFromPng,
		["jpg"]  = gd.createFromJpeg,
		["jpeg"] = gd.createFromJpeg,
		["gif"]  = gd.createFromGif,
	}
	local imageCreatorMethods = {
		["png"]  = "pngStr",
		["jpg"]  = "jpegStr",
		["jpeg"] = "jpegStr",
		["gif"]  = "gifStr",
	}

	function createThumbnail(pathImageRel, thumbW, thumbH, errLevel)
		thumbW   = thumbW or 0
		thumbH   = thumbH or 0
		errLevel = (errLevel or 1)+1

		if thumbW == 0 and thumbH == 0 then
			error("Thumbnail images must have at least a width or a height.", errLevel)
		end

		local id = F("%s:%dx%d", pathImageRel, thumbW, thumbH)
		if thumbnailInfos[id] then
			return thumbnailInfos[id]
		end

		local filename  = getFilename(pathImageRel)
		local basename  = getBasename(filename)
		local ext       = getExtension(filename)
		local extLower  = ext:lower()
		local folder    = pathImageRel:sub(1, #pathImageRel-#filename) -- Ending in "/".
		local pathImage = DIR_CONTENT.."/"..pathImageRel

		if not isFile(pathImage) then
			errorf(errLevel, "File does not exist: %s", pathImage)
		end

		local loadImage = imageLoaders[extLower]
			or errorf(errLevel, "Unknown image file format '%'.", extLower)

		local image = loadImage(pathImage)
			or errorf(errLevel, "Could not load image '%s'. Maybe the image is corrupted?", pathImage)

		local imageW, imageH = image:sizeXY()
		assert(imageW > 0)
		assert(imageH > 0)
		local aspectRatio = imageW/imageH

		if thumbW == 0 then
			thumbW = round(thumbH*aspectRatio)
		elseif thumbH == 0 then
			thumbH = round(thumbW/aspectRatio)
		end
		thumbW = math.max(thumbW, 1)
		thumbH = math.max(thumbH, 1)

		local scale = math.min(imageW/thumbW, imageH/thumbH)

		local thumb = gd.createTrueColor(thumbW, thumbH)
		thumb:copyResampled(
			image,
			0, -- dstX
			0, -- dstY
			round((imageW-thumbW*scale)/2), -- srcX
			round((imageH-thumbH*scale)/2), -- srcY
			thumbW, -- dstW
			thumbH, -- dstH
			round(thumbW*scale), -- srcW
			round(thumbH*scale)  -- srcH
		)

		local imageCreatorMethod = "jpegStr"--assert(imageCreatorMethods[extLower], extLower)
		local contents           = thumb[imageCreatorMethod](thumb, 75)
		local pathThumbRel       = F("%s%s.%dx%d.%s", folder, basename, thumbW, thumbH, "jpg")--ext)
		writeOutputFile("otherRaw", pathThumbRel, "/"..pathThumbRel, contents)

		local thumbInfo = {
			path   = pathThumbRel,
			width  = thumbW,
			height = thumbH,
		}

		thumbnailInfos[id] = thumbInfo
		return thumbInfo
	end

end



function round(n)
	return math.floor(n+0.5)
end



function newStringBuffer()
	local buffer = {}

	return function(...)
		if select("#", ...) == 0 then  return table.concat(buffer)  end

		local s = select("#", ...) == 1 and assertType(..., "string") or F(...)
		table.insert(buffer, s)
	end
end



function newPage(pathRel)
	assertType(pathRel, "string")

	local filename = getFilename(pathRel)
	local ext      = getExtension(filename)
	local extLower = ext:lower()

	assert(TEMPLATE_EXTENSION_SET[extLower], extLower)

	local isPage  = PAGE_EXTENSION_SET[extLower] or false
	local isIndex = isPage  and getBasename(filename) == "index"
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

	local page = {
		_category   = category,
		_isGenerated= false,
		_isSkipped  = false,
		_path       = pathRel,
		_pathOut    = pathRelOut,

		isPage      = isPage,
		isIndex     = isIndex,
		isHome      = isHome,

		layout      = site.defaultLayout,
		title       = "",
		content     = "",

		publishDate = os.date("%Y-%m-%d %H:%M:%S", 0),
		isDraft     = false,
		isSpecial   = not isPage,

		aliases     = {},

		url         = "/"..permalinkRel,
		permalink   = site.baseUrl..(noTrailingSlash and permalinkRel:gsub("/$", "") or permalinkRel),
		rssLink     = "", -- @Incomplete @Doc

		params      = {},
	}
	-- print(pathRel, (not isPage and " " or isHome and "H" or isIndex and "I" or "P"), page.permalink) -- DEBUG

	return page
end



function pathToSitePath(pathRel)
	if pathRel:find"^/" then
		errorf(2, "Path is not valid: %s", pathRel)
	end
	return "/"..pathRel
end

function sitePathToPath(sitePath)
	if not sitePath:find"^/" then
		errorf(2, "Path is not a valid site path - they must start with '/': %s", sitePath)
	end
	return (sitePath:gsub("^/", ""))
end



-- Return any data as a Lua code string.
-- luaString = serializeLua( value )
do
	local SIMPLE_TYPES = {["boolean"]=true,["nil"]=true,["number"]=true,}
	local KEYWORDS = {
		["and"]=true,["break"]=true,["do"]=true,["else"]=true,["elseif"]=true,
		["end"]=true,["false"]=true,["for"]=true,["function"]=true,["if"]=true,
		["in"]=true,["local"]=true,["nil"]=true,["not"]=true,["or"]=true,["repeat"]=true,
		["return"]=true,["then"]=true,["true"]=true,["until"]=true,["while"]=true,
	}

	local function _serializeLua(out, data)
		local dataType = type(data)

		if dataType == "table" then
			local first   = true
			local i       = 0
			local indices = {}

			local insert = table.insert
			insert(out, " { ")

			while true do
				i = i+1

				if data[i] == nil then
					i = i+1
					if data[i] == nil then  break  end

					if not first then  insert(out, ",")  end
					insert(out, "nil")
					first = false
				end

				if not first then  insert(out, ",")  end
				first = false

				_serializeLua(out, data[i])
				indices[i] = true
			end

			for k, v in pairs(data) do
				if not indices[k] then
					if not first then  insert(out, ",")  end
					first = false

					if not KEYWORDS[k] and type(k) == "string" and k:find"^[a-zA-Z_][a-zA-Z0-9_]*$" then
						insert(out, k)
					else
						insert(out, "[")
						_serializeLua(out, k)
						insert(out, "]")
					end

					insert(out, "=")
					_serializeLua(out, v)
				end
			end

			insert(out, " } ")

		elseif dataType == "string" then
			table.insert(out, F("%q", data))

		elseif SIMPLE_TYPES[dataType] then
			table.insert(out, tostring(data))

		else
			errorf("Cannot serialize value type '%s'. (%s)", dataType, tostring(data))
		end

		return out
	end

	function serializeLua(data)
		return (table.concat(_serializeLua({}, data)))
	end

end



function getKeys(t)
	local keys = {}
	for k in pairs(t) do  table.insert(keys, k)  end
	return keys
end



function urlExists(url)
	if not url:find"^/" then
		errorf(2, "Local URLs must begin with a '/'. (%s)", url)
	end

	return writtenOutputUrls[url] == true
end



-- bool = isAny( valueToCompare, value1, ... )
-- bool = isAny( valueToCompare, arrayOfValues )
function isAny(v, ...)
	local len = select("#", ...)

	if len == 1 and type(...) == "table" then
		for _, item in ipairs(...) do
			if v == item then  return true  end
		end

	else
		for i = 1, len do
			if v == select(i, ...) then  return true  end
		end
	end

	return false
end



function rewriteOutputPath(pathRel)
	local sitePath = pathToSitePath(pathRel)

	for _, pat in ipairs(rewriteExcludes) do
		if sitePath:find(pat) then  return pathRel  end
	end

	if type(outputPathFormat) == "function" then
		local sitePathNew = outputPathFormat(sitePath)

		if type(sitePathNew) ~= "string" then
			errorf("config.rewriteOutputPath() did not return a string. (%s)", sitePath)
		elseif sitePathNew == "" then
			errorf("config.rewriteOutputPath() returned an empty string. (%s)", sitePath)
		end

		return (sitePathToPath(sitePathNew))

	else
		return (sitePathToPath(outputPathFormat:format(sitePath)))
	end
end



-- removeItem( array, value1, ... )
function removeItem(t, ...)
	for i = 1, select("#", ...) do
		local iToRemove = indexOf(t, select(i, ...))

		if iToRemove then  table.remove(t, iToRemove)  end
	end
end


