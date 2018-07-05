--[[============================================================
--=
--=  App
--=
--=-------------------------------------------------------------
--=
--=  LuaWebGen - static website generator in Lua!
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]



-- Parse arguments.
--==============================================================

local i = 1

local command = args[i] or error("[arg] Missing command.")
i = i+1

local ignoreModificationTimes = false
local autobuild = false

----------------------------------------------------------------

if command == "new" then
	local kind = args[i] or error("[arg] Missing kind after 'new'.")
	i = i+1

	if kind == "page" then
		local pathRel = args[i] or error("[arg] Missing path after 'page'.")
		pathRel = pathRel:gsub("^/", "")
		i = i+1

		if args[i] then
			errorf("[arg] Unknown argument '%s'.", args[i])
		end

		local filename = getFilename(pathRel)
		local basename = getBasename(filename)
		local title    = basename :gsub("%-+", " ") :gsub("^%a", string.upper) :gsub(" %a", string.upper)

		local contents = formatTemplate(
			[=[
				{{
				page.title = :titleQuoted:
				page.date  = ":date:"
				}}

				:content:
			]=], {
				titleQuoted = F("%q", title),
				content     = "",
				date        = getDatetime(),
			}
		)

		local path = DIR_CONTENT.."/"..pathRel
		if lfs.attributes(path, "mode") then
			errorf("Item already exists: %s", path)
		end

		createDirectory(getDirectory(path))

		local file = assert(io.open(path, "wb"))
		file:write(contents)
		file:close()

		printf("Created page: %s", path)

	elseif kind == "site" then
		local pathToSite = args[i] or error("[arg] Missing path after 'site'.")
		i = i+1

		if args[i] then
			errorf("[arg] Unknown argument '%s'.", args[i])
		end

		-- Create folders.
		for _, path in ipairs{
			pathToSite,
			pathToSite.."/"..DIR_CONTENT,
			pathToSite.."/"..DIR_DATA,
			pathToSite.."/"..DIR_LAYOUTS,
			pathToSite.."/"..DIR_LOGS,
			pathToSite.."/"..DIR_OUTPUT,
			pathToSite.."/"..DIR_SCRIPTS,
		} do
			if not isDirectory(path) then
				assert(lfs.mkdir(path))
			end
		end

		-- Create config.
		local path = pathToSite.."/config.lua"

		if not isFile(path) then
			local title = getFilename(pathToSite)

			local contents = formatTemplate(
				[=[
					return {
						title         = :titleQuoted:,
						baseUrl       = "http://example.com/",
						languageCode  = "en",

						ignoreFiles   = {"%.tmp$"},
						ignoreFolders = {"^%."},
					}
				]=], {
					titleQuoted = F("%q", title),
				}
			)

			local file = assert(io.open(path, "wb"))
			file:write(contents)
			file:close()
		end

		-- Create default page layout.
		local path = F("%s/%s/page.html", pathToSite, DIR_LAYOUTS)

		if not isFile(path) then
			local title = getFilename(pathToSite)

			local contents = formatTemplate(
				[=[
					<!DOCTYPE html>
					<html lang="{{site.languageCode}}">
					<head>
						<meta charset="utf-8">

						<meta name="viewport" content="width=device-width, initial-scale=1">
						{{generatorMeta()}}

						<base href="{{site.baseUrl}}">

						<title>
							{{page.title ~= "" and page.title.." |" or ""}}
							{{site.title}}
						</title>

						<link rel="canonical" href="{{page.permalink}}">
					</head>

					<body>
						{{page.content}}
					</body>

					</html>
				]=], {
					-- ...
				}
			)

			local file = assert(io.open(path, "wb"))
			file:write(contents)
			file:close()
		end

		printf("Created site: %s", pathToSite)

	else
		errorf("[arg] Unknown kind '%s' after 'new'.", kind)
	end

	return

----------------------------------------------------------------

elseif command == "build" then
	while args[i] do
		local arg = args[i]

		if arg == "--force" or arg == "-f" then
			ignoreModificationTimes = true

		elseif arg == "--autobuild" or arg == "-a" then
			autobuild = true

		elseif arg == "--drafts" or arg == "-d" then
			includeDrafts = true

		elseif arg == "--verbose" or arg == "-v" then
			verbosePrint = true

		elseif arg:find"^%-" then
			errorf("[arg] Unknown option '%s'.", arg)

		else
			errorf("[arg] Unknown argument '%s'.", arg)
		end

		i = i+1
	end

	if not (isDirectory(DIR_CONTENT) or isDirectory(DIR_LAYOUTS) or isFile"config.lua") then
		error("The current folder doesn't seem to contain a site.")
	end

	if ignoreModificationTimes then  logprint("Option --force: Ignoring modification times.")  end
	if autobuild               then  logprint("Option --autobuild: Auto-building website.")  end
	if includeDrafts           then  logprint("Option --drafts: Drafts are included.")  end
	if verbosePrint            then  logprint("Option --verbose: Verbose printing enabled.")  end

	logprint("Site folder: %s", toNormalPath(lfs.currentdir()))

----------------------------------------------------------------
else
	errorf("[arg] Unknown command '%s'.", command)
end



-- Prepare log file.
--==============================================================

do
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
end



-- Prepare script environment.
--==============================================================

scriptEnvironmentGlobals = {
	_WEBGEN_VERSION      = _WEBGEN_VERSION,
	DATA_FILE_EXTENSIONS = DATA_FILE_EXTENSIONS,
	IMAGE_EXTENSIONS     = IMAGE_EXTENSIONS,

	-- Lua globals.
	_G             = nil, -- Deny direct access to the script environment.
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

	next = function(t)
		if isDataFolderReader(t) then  preloadData(t)  end

		return next(t)
	end,

	pairs = function(t)
		if isDataFolderReader(t) then
			return scriptEnvironmentGlobals.pairsSorted(t)
		end

		return pairs(t)
	end,

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

	-- Site objects. (Create at site generation.)
	site           = nil,
	data           = nil,

	-- Page objects. (Create for each individual page. Store in context.)
	page           = nil,
	params         = nil,
	P              = nil,

	-- Utility functions.
	----------------------------------------------------------------

	ceil           = math.ceil,
	date           = os.date,
	entities       = encodeHtmlEntities,
	errorf         = errorf,
	F              = F,
	find           = itemWith,
	findAll        = itemWithAll,
	floor          = math.floor,
	formatTemplate = formatTemplate,
	generatorMeta  = generatorMeta,
	getFilename    = getFilename,
	getKeys        = getKeys,
	indexOf        = indexOf,
	isAny          = isAny,
	markdown       = markdownToHtml,
	max            = math.max,
	min            = math.min,
	newBuffer      = newStringBuffer,
	prettyUrl      = toPrettyUrl,
	printf         = printf,
	printfOnce     = printfOnce,
	printOnce      = printOnce,
	removeItem     = removeItem,
	round          = round,
	sortNatural    = sortNatural,
	split          = splitString,
	toLua          = serializeLua,
	toTime         = datetimeToTime,
	trim           = trim,
	trimNewlines   = trimNewlines,
	url            = toUrl,
	urlAbs         = toUrlAbsolute,
	urlExists      = urlExists,
	urlize         = urlize,

	chooseExistingFile = function(sitePathWithoutExt, exts)
		local pathWithoutExt = sitePathToPath(sitePathWithoutExt)

		for _, ext in ipairs(exts) do
			local pathRel = pathWithoutExt.."."..ext
			if isFile(DIR_CONTENT.."/"..pathRel) then  return pathToSitePath(pathRel)  end
		end

		return nil
	end,

	chooseExistingImage = function(sitePathWithoutExt)
		return scriptEnvironmentGlobals.chooseExistingFile(sitePathWithoutExt, IMAGE_EXTENSIONS)
	end,

	fileExists = function(sitePath)
		local pathRel = sitePathToPath(sitePath)
		return isFile(DIR_CONTENT.."/"..pathRel)
	end,

	fileExistsInOutput = function(sitePath, skipRewriting)
		local pathRel       = sitePathToPath(sitePath)
		local pathOutputRel = skipRewriting and pathRel or rewriteOutputPath(pathRel)
		return isFile(DIR_OUTPUT.."/"..pathOutputRel)
	end,

	getExtension = function(genericPath)
		return getExtension(getFilename(genericPath))
	end,

	getBasename = function(genericPath)
		return getBasename(getFilename(genericPath))
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

	-- html = thumb( imagePath, thumbWidth [, thumbHeight ] [, isLink=false ] )
	thumb = function(sitePathImageRel, thumbW, thumbH, isLink)
		if type(thumbH) == "boolean" then
			thumbH, isLink = 0, thumbH
		end

		local pathImageRel = sitePathToPath(sitePathImageRel)
		local thumbInfo = createThumbnail(pathImageRel, thumbW, thumbH, 2)

		local b = newStringBuffer()
		if isLink then  b('<a href="%s" target="_blank">', toUrl("/"..pathImageRel))  end
		b('<img src="%s" width="%d" height="%d" alt="">', toUrl("/"..thumbInfo.path), thumbInfo.width, thumbInfo.height)
		if isLink then  b('</a>')  end

		return b()
	end,

	cssPrefix = function(prop, v)
		return F("-ms-%s: %s; -moz-%s: %s; -webkit-%s: %s; %s: %s;", prop, v, prop, v, prop, v, prop, v)
	end,

	warning = function(s)
		s = F("!!! WARNING: %s !!!", s)
		local border = ("!"):rep(#s)
		print()
		print(border)
		printf("!!! WARNING: %s !!!", s)
		print(border)
		print()
	end,

	warningOnce = function(s)
		s = F("!!! WARNING: %s !!!", s)

		if oncePrints[s] then  return  end
		oncePrints[s] = true

		local border = ("!"):rep(#s)
		print()
		print(border)
		print(s)
		print(border)
		print()
	end,

	-- html = a( url [, label=prettyUrl ] )
	a = function(url, label)
		return F(
			'<a href="%s">%s</a>',
			encodeHtmlEntities(toUrl(url)),
			encodeHtmlEntities(label or toPrettyUrl(url))
		)
	end,

	-- html = img( url [, alt="", title ] )
	-- html = img( url [, alt="", useAltAsTitle ] )
	img = function(url, alt, title)
		if title then
			return F(
				'<img src="%s" alt="%s" title="%s">',
				encodeHtmlEntities(toUrl(url)),
				encodeHtmlEntities(alt or ""),
				encodeHtmlEntities(title == true and alt or title)
			)
		else
			return F(
				'<img src="%s" alt="%s">',
				encodeHtmlEntities(toUrl(url)),
				encodeHtmlEntities(alt or "")
			)
		end
	end,

	-- filePaths = files( folder, [ onlyFilenames=false, ] stringPattern )
	-- filePaths = files( folder, [ onlyFilenames=false, ] fileExtensionArray )
	-- filePaths = files( folder, [ onlyFilenames=false, ] filterFunction )
	files = function(sitePath, onlyFilenames, filter)
		if type(onlyFilenames) ~= "boolean" then
			onlyFilenames, filter = false, onlyFilenames
		end

		local pathRel = sitePathToPath(sitePath)
		local dirPath = pathRel == "" and DIR_CONTENT or DIR_CONTENT.."/"..pathRel
		local sitePaths = {}

		for name in lfs.dir(dirPath) do
			if name ~= "." and name ~= ".." and isFile(dirPath.."/"..name) then
				if filter == nil then
					table.insert(sitePaths, (onlyFilenames and name or sitePath.."/"..name))

				elseif type(filter) == "string" then
					if name:find(filter) then
						table.insert(sitePaths, (onlyFilenames and name or sitePath.."/"..name))
					end

				elseif type(filter) == "table" then
					if indexOf(filter, getExtension(name)) then
						table.insert(sitePaths, (onlyFilenames and name or sitePath.."/"..name))
					end

				elseif type(filter) == "function" then
					if filter(name) then
						table.insert(sitePaths, (onlyFilenames and name or sitePath.."/"..name))
					end

				else
					errorf(2, "Invalid filter type '%s'. (Must be string, table or function)", type(filter))
				end
			end
		end

		return sitePaths
	end,

	toDatetime = function(time)
		assertarg(1, time, "number")
		return getDatetime(time)
	end,

	now = function()
		return getDatetime()
	end,

	getCompleteOutputPath = function(sitePath)
		local pathRel = sitePathToPath(sitePath)
		local pathOutputRel = rewriteOutputPath(pathRel)
		return DIR_OUTPUT.."/"..pathOutputRel
	end,

	pairsSorted = function(t)
		if isDataFolderReader(t) then  preloadData(t)  end

		local keys = sortNatural(getKeys(t))
		local i    = 0

		return function()
			i = i+1
			local k = keys[i]
			if k then  return k, t[k]  end
		end
	end,

	-- Context functions.
	----------------------------------------------------------------

	echo = function(s)
		assertContext("template", "echo")
		s = tostringForTemplates(s)

		local ctx = getContext"template"

		if ctx.enableHtmlEncoding then
			s = encodeHtmlEntities(s)
		end
		table.insert(ctx.out, s)
	end,

	echoRaw = function(s)
		assertContext("template", "echoRaw")
		table.insert(getContext"template".out, tostringForTemplates(s))
	end,

	echof = function(s, ...)
		assertContext("template", "echof")
		scriptEnvironmentGlobals.echo(s:format(...))
	end,

	echofRaw = function(s, ...)
		assertContext("template", "echofRaw")
		scriptEnvironmentGlobals.echoRaw(s:format(...))
	end,

	include = function(htmlFileBasename)
		assertContext("template", "include")
		assert(not htmlFileBasename:find"^/")

		local path = F("%s/%s.html", DIR_LAYOUTS, htmlFileBasename)
		local template, err = getFileContents(path)
		if not template then
			errorf(2, "Could not read file '%s': %s", path, err)
		end

		local html = parseHtmlTemplate(getContext().page, path, template)
		return html
	end,

	generateFromTemplate = function(sitePathRel, template)
		assertContext("config", "generateFromTemplate")

		local pathRel = sitePathToPath(sitePathRel)
		local page    = newPage(pathRel)
		generateFromTemplate(page, template)

		if page.isPage.v and not page._isSkipped then
			table.insert(pages, page)
		end

		return getProtectionWrapper(page, "page")
	end,

	outputRaw = function(sitePathRel, contents)
		assertContext("config", "outputRaw")
		assertType(contents, "string", "The contents must be a string.")

		local pathRel = sitePathToPath(sitePathRel)
		writeOutputFile("otherRaw", pathRel, sitePathRel, contents)
	end,

	preserveRaw = function(sitePathRel)
		assertContext("config", "preserveRaw")

		local pathRel       = sitePathToPath(sitePathRel)
		local pathOutputRel = rewriteOutputPath(pathRel)
		local path          = DIR_OUTPUT.."/"..pathOutputRel

		if not isFile(path) then
			errorf(2, "File does not exist. (%s)", path)
		end

		preserveExistingOutputFile("otherRaw", pathRel, sitePathRel)
	end,

	isCurrentUrl = function(url)
		assertContext("template", "isCurrentUrl")
		return getContext().page.url.v == url
	end,

	isCurrentUrlBelow = function(urlPrefix)
		assertContext("template", "isCurrentUrl")
		return getContext().page.url.v:sub(1, #urlPrefix) == urlPrefix
	end,

	subpages = function()
		assertContext("template", "subpages")

		local pageCurrent = getContext().page
		local dir = getDirectory(pageCurrent._path)

		local subpages = {}
		for _, page in ipairs(pages) do
			if page ~= pageCurrent and page._path:sub(1, #dir) == dir then
				if not page._isGenerated then
					generateFromTemplateFile(page)
				end
				if not (page._isSkipped or page.isSpecial.v) then
					table.insert(subpages, page)
				end
			end
		end

		table.sort(subpages, function(a, b)
			local aDatetime = a.publishDate:g()
			local bDatetime = b.publishDate:g()
			if aDatetime ~= bDatetime then  return aDatetime > bDatetime  end

			return a._path < b._path
		end)

		for i, page in ipairs(subpages) do
			subpages[i] = getProtectionWrapper(page, "page")
		end

		return subpages
	end,

	validateUrls = function(urls)
		local ok = true
		for _, url in ipairs(urls) do
			if not urlExists(url) then
				printf("Error: URL is missing: %s", url)
				ok = false
			end
		end

		if not ok then
			error("URLs were missing.", 2)
		end
	end,

	-- Hacks. (These are not very robust!)
	----------------------------------------------------------------

	XXX_minimizeCss = function(s)
		local oldLen = #s
		local header = s:match"^/%*.-%*/" or ""

		s = header..s
			:sub(#header+1)
			:gsub("/%*.-%*/", "")   -- Remove comments.
			:gsub("\t+",      "")   -- Remove all tabs.
			:gsub("\n +",     "\n") -- Remove space indentations.
			:gsub("  +",      " ")  -- Remove extra spaces.
			:gsub("\n\n+",    "\n") -- Remove empty lines.
			:gsub("%b{}",     function(scope)  return (scope:gsub("\n", " "))  end) -- Compress rules to one line each.

		if verbosePrint then
			printf("[opti] %s  from %d  to %d  (diff=%d)", getFilename(path), oldLen, #s, oldLen-#s)
		end

		return s
	end,

	XXX_minimizeJavaScript = function(s)
		local oldLen = #s
		local header = s:match"^/%*.-%*/" or ""

		s = header..s
			:sub(#header+1)
			:gsub("()/%*.-%*/", "")   -- Remove long comments.
			:gsub("\n\t+",      "\n") -- Remove indentations.
			:gsub("\n//[^\n]*", "\n") :gsub(" // [^\n]*", "") -- Remove all comment lines.
			:gsub("\n\n+",      "\n") -- Remove empty lines.

		if verbosePrint then
			printf("[opti] %s  from %d  to %d  (diff=%d)", getFilename(path), oldLen, #s, oldLen-#s)
		end

		return s
	end,

	XXX_minimizeHtaccess = function(s)
		local oldLen = #s

		s = s
			:gsub("^\t+",      "") -- Remove indentations.
			:gsub("\n#[^\n]*", "\n") :gsub("^#[^\n]*", "") -- Remove all comments.
			:gsub("\n\n+",     "\n") :gsub("^\n",      "") -- Remove empty lines.

		if verbosePrint then
			printf("[opti] %s  from %d  to %d  (diff=%d)", getFilename(path), oldLen, #s, oldLen-#s)
		end

		return s
	end,

	XXX_getMinimizingProcessors = function()
		return {
			["css"]      = scriptEnvironmentGlobals.XXX_minimizeCss,
			["htaccess"] = scriptEnvironmentGlobals.XXX_minimizeHtaccess,
			["js"]       = scriptEnvironmentGlobals.XXX_minimizeJavaScript,
		}
	end

	----------------------------------------------------------------
}



scriptEnvironment = setmetatable({}, {
	__index = function(env, k)
		local v = scriptEnvironmentGlobals[k] or getContext()._scriptEnvironmentGlobals[k]
		if v ~= nil then  return v  end

		v = scriptFunctions[k]
		if v then  return v  end

		if isFile(F("%s/%s.lua", DIR_SCRIPTS, k)) then
			local path = F("%s/%s.lua", DIR_SCRIPTS, k)

			local chunk, err = loadfile(path)
			if not chunk then
				error(err, 2)
			end

			setfenv(chunk, env)
			v = chunk()
			if type(v) ~= "function" then
				errorf(2, "%s did not return a function.", path)
			end

			scriptFunctions[k] = v
			return v
		end

		errorf(2, "Tried to get non-existent global or script '%s'.", tostring(k))
	end,

	__newindex = function(env, k, v)
		errorf(2, "Tried to set global '%s'. (Globals are disabled.)", tostring(k))
	end,
})



-- Build website!
--==============================================================

local function buildWebsite()
	local startTime = socket.gettime()

	oncePrints = {}
	resetSiteVariables()

	scriptEnvironmentGlobals.site = getProtectionWrapper(site, "site", true)
	scriptEnvironmentGlobals.data = newDataFolderReader(DIR_DATA)



	-- Read config.
	----------------------------------------------------------------

	local config

	if not isFile"config.lua" then
		config = {}
	else
		local chunk = assert(loadfile"config.lua")
		setfenv(chunk, scriptEnvironment)
		config = chunk()
		assertTable(config, nil, nil, "config.lua must return a table.")
	end

	local function get(kPath, default, assertFunc, ...)
		local v = config
		local tLast = nil
		local kLast = nil

		for k in kPath:gmatch"[^.]+" do
			if type(v) ~= "table" then  return default  end

			kLast = k
			tLast = v
			v = v[k]
			if v == nil then  return default  end
		end

		assertFunc(v, ...)

		tLast[kLast] = nil
		return v
	end

	local function getV(kPath, default, vType) -- Value.
		return get(kPath, default, assertType, vType, "config.%s must be a %s.", kPath, vType)
	end

	local function getT(kPath, default, kType, vType) -- Table
		return get(
			kPath, default, assertTable, kType, vType,
			"config.%s must be a table of [%s]=%s.",
			kPath, (kType or "value"), (vType or "value")
		)
	end

	local function getA(kPath, default, vType) -- Array.
		return get(kPath, default, assertTable, "number", vType, "config.%s must be an array of %s.", kPath, vType)
	end

	site.title.v           = getV("title",             "",     "string")
	site.baseUrl.v         = getV("baseUrl",           "",     "string")
	site.languageCode.v    = getV("languageCode",      "",     "string")
	site.defaultLayout.v   = getV("defaultLayout",     "page", "string")

	site.redirections.v    = getT("redirections",      {},     "string", "string")

	ignoreFiles            = getA("ignoreFiles",       {},     "string")
	ignoreFolders          = getA("ignoreFolders",     {},     "string")

	fileProcessors         = getT("processors",        {},     "string", "function")

	local htaccessRedirect = getV("htaccess.redirect", false,  "boolean")
	local htaccess         = getT("htaccess",          nil,    "string")
	local handleHtaccess   = htaccess ~= nil
	--[[
	local handleHtaccess   = getV("htaccess",          false,  "boolean")
	local htaccessWww      = getV("htaccessWww",       nil,    "boolean")
	local htaccessErrors   = getT("htaccessErrors",    {},     "number", "string")
	--]]

	outputPathFormat       = get("rewriteOutputPath", "%s", NOOP)
	assert(isAny(type(outputPathFormat), "string","function"), "config.rewriteOutputPath must be a string or a function.")
	rewriteExcludes        = getA("rewriteExcludes",   {},     "string")

	local onBefore         = getV("before",            nil,    "function")
	local onAfter          = getV("after",             nil,    "function")
	local onValidate       = getV("validate",          nil,    "function")

	noTrailingSlash        = getV("removeTrailingSlashFromPermalinks", false, "boolean")

	for k in pairs(config) do
		printf("WARNING: Unknown config field '%s'.", k)
	end
	for k in pairs(htaccess or {}) do
		printf("WARNING: Unknown config.htaccess field '%s'.", k)
	end


	-- Fix details.

	if not site.baseUrl.v:find"/$" then
		site.baseUrl.v = site.baseUrl.v.."/" -- Note: Could result in simply "/".
	end



	-- Generate website from content folder.
	----------------------------------------------------------------

	logprint("Generating website...")

	for category in pairs(OUTPUT_CATEGORY_SET) do
		outputFileCounts[category] = 0
	end

	if onBefore then
		pushContext("config")
		onBefore()
		popContext("config")
	end

	-- Generate output.
	traverseFiles(DIR_CONTENT, ignoreFolders, function(path, pathRel, filename, extLower)
		if isStringMatchingAnyPattern(filename, ignoreFiles) then
			-- Ignore.

		elseif TEMPLATE_EXTENSION_SET[extLower] then
			local page = newPage(pathRel)
			if page.isPage.v then
				table.insert(pages, page)
			else
				generateFromTemplateFile(page)
			end

		elseif not (handleHtaccess and pathRel == ".htaccess") then
			local modTime = lfs.attributes(path, "modification")
			local pathOutputRel = rewriteOutputPath(pathRel)

			-- Non-templates should be OK to preserve (if there's no file processor).
			local oldModTime
				=   not ignoreModificationTimes
				and not fileProcessors[extLower]
				and lfs.attributes(DIR_OUTPUT.."/"..pathOutputRel, "modification")
				or  nil

			if modTime and modTime == oldModTime then
				preserveExistingOutputFile("otherRaw", pathRel, pathRel)
			else
				local contents = assert(getFileContents(path))
				writeOutputFile("otherRaw", pathRel, "/"..pathRel, contents, modTime)
			end
		end
	end)

	for _, page in ipairs(pages) do
		if not (page._isGenerated or page._isSkipped) then
			generateFromTemplateFile(page)
		end
	end

	if onAfter then
		pushContext("config")
		onAfter()
		popContext("config")
	end

	-- Redirects.
	for _, page in ipairs(pages) do
		if page.isPage.v and not page._isSkipped then
			assert(page._isGenerated)

			for _, aliasSlug in ipairs(page.aliases.v) do
				generateRedirection(aliasSlug, page.permalink.v)
			end
		end
	end

	for slug, targetUrl in pairs(site.redirections.v) do
		generateRedirection(slug, targetUrl)
	end

	-- Htaccess.
	if handleHtaccess then
		local contents = getFileContents(DIR_CONTENT.."/.htaccess") or ""

		if htaccessRedirect and next(writtenRedirects) then
			local b = newStringBuffer()
			b("<IfModule mod_rewrite.c>\n")
			b("\tRewriteEngine On\n")

			for _, slug in ipairs(sortNatural(getKeys(writtenRedirects))) do
				local targetUrl = writtenRedirects[slug]

				b('\tRewriteCond %%{REQUEST_URI} "^%s$"\n', htaccessRewriteEscapeRegex(slug))
				b('\tRewriteRule .* "%s" [R=301,L]\n', htaccessRewriteEscapeReplacement(targetUrl))

				--[[ Rewrite examples.  @Incomplete: Queries.

				# from /dogs/index.php
				# to   /dogs
				RewriteCond  %{REQUEST_URI}   ^/dogs/index\.php$
				RewriteRule  .*               /dogs  [R=301,L]

				# from /dogs/info.php?p=mr_bark
				# to   /dogs/mr-bark
				RewriteCond  %{REQUEST_URI}   ^/dogs/info\.php$
				RewriteCond  %{QUERY_STRING}  ^p=mr_bark$
				RewriteRule  .*               /dogs/mr-bark?  [R=301,L]
				]]
			end

			b("</IfModule>\n")
			local directives = b()

			local count
			contents, count = gsub2(contents, "# *:webgen%.redirections: *\n", directives)
			if count == 0 then
				contents = F("%s\n%s", contents, directives)
			end
		end

		writeOutputFile("otherRaw", ".htaccess", "/.htaccess", contents)
	end

	if onValidate then
		pushContext("validation")
		onValidate()
		popContext("validation")
	end

	-- Cleanup old generated stuff.
	traverseFiles(DIR_OUTPUT, nil, function(path, pathOutputRel, filename, extLower)
		if not writtenOutputFiles[pathOutputRel] then
			logVerbose("Removing: %s", path)
			assert(os.remove(path))
		end
	end)
	removeEmptyDirectories(DIR_OUTPUT)

	logprint("Generating website... done!")



	----------------------------------------------------------------

	if contextStack[1] then
		logprint("Error: Context stack is not empty after generation. (Depth is %d)", #contextStack)
	end

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
	_print("Press Ctrl+C to stop auto-building.")

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



--==============================================================

_print(F("Check log for details: %s", logPath))
logFile:close()
