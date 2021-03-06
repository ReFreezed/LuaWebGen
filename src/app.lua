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

_G.ignoreModificationTimes = false
_G.autobuild = false

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
						title         = :title:,
						baseUrl       = "http://:host:/",
						languageCode  = "en",

						ignoreFiles   = {"%.tmp$"},
						ignoreFolders = {"^%."},
					}
				]=], {
					title = F("%q", title),
					host  = title:find"^[%w.]+%.%a+$" and title:lower() or "example.com",
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

	-- Continue...

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
			return pairsSorted(preloadData(t))
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

	ceil             = math.ceil,
	date             = os.date,
	entities         = encodeHtmlEntities,
	errorf           = errorf,
	F                = F,
	find             = itemWith,
	findAll          = itemWithAll,
	floor            = math.floor,
	formatTemplate   = formatTemplate,
	generatorMeta    = generatorMeta,
	getFilename      = getFilename,
	getKeys          = getKeys,
	indexOf          = indexOf,
	ipairsr          = ipairsr,
	isAny            = isAny,
	markdown         = markdownToHtml,
	max              = math.max,
	min              = math.min,
	newStringBuilder = newStringBuilder, newBuffer = newStringBuilder,
	prettyUrl        = toPrettyUrl,
	printf           = printf,
	printfOnce       = printfOnce,
	printOnce        = printOnce,
	removeItem       = removeItem,
	round            = round,
	sortNatural      = sortNatural,
	split            = splitString,
	toLua            = serializeLua,
	toTime           = datetimeToTime,
	trim             = trim,
	trimNewlines     = trimNewlines,
	url              = toUrl,
	urlAbs           = toUrlAbsolute,
	urlExists        = urlExists,
	urlize           = urlize,

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

	-- html, thumbUrl, thumbWidth, thumbHeight = thumb( imagePath, thumbWidth [, thumbHeight ] [, isLink=false ] )
	thumb = function(sitePathImageRel, thumbW, thumbH, isLink)
		if type(thumbH) == "boolean" then
			thumbH, isLink = 0, thumbH
		end

		local pathImageRel = sitePathToPath(sitePathImageRel)
		local thumbInfo    = createThumbnail(pathImageRel, thumbW, thumbH, 2)
		local thumbUrl     = toUrl("/"..thumbInfo.path)

		local b = newStringBuilder()
		if isLink then  b('<a href="%s" target="_blank">', toUrl("/"..pathImageRel))  end
		b('<img src="%s" width="%d" height="%d" alt="">', encodeHtmlEntities(thumbUrl), thumbInfo.width, thumbInfo.height)
		if isLink then  b('</a>')  end

		return b(), thumbUrl, thumbInfo.width, thumbInfo.height
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
		-- @Incomplete: Do we want to add 'width' and 'height' attributes here if the URL looks like a local image path?
		-- Maybe we want a separate function for that, like imgLocal()? Not sure...
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
		return pairsSorted(isDataFolderReader(t) and preloadData(t) or t)
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

	getImageDimensions = function(sitePath)
		return getImageDimensions(sitePathToPath(sitePath))
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

		local html = parseTemplate(getContext().page, path, template, "html")
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
		writeOutputFile("raw", pathRel, sitePathRel, contents)
	end,

	preserveRaw = function(sitePathRel)
		assertContext("config", "preserveRaw")

		local pathRel       = sitePathToPath(sitePathRel)
		local pathOutputRel = rewriteOutputPath(pathRel)
		local path          = DIR_OUTPUT.."/"..pathOutputRel

		if not isFile(path) then
			errorf(2, "File does not exist. (%s)", path)
		end

		preserveExistingOutputFile("raw", pathRel, sitePathRel)
	end,

	isCurrentUrl = function(url)
		assertContext("template", "isCurrentUrl")
		return getContext().page.url.v == url
	end,

	isCurrentUrlBelow = function(urlPrefix)
		assertContext("template", "isCurrentUrl")
		return getContext().page.url.v:sub(1, #urlPrefix) == urlPrefix
	end,

	subpages = function(allowCurrentPage)
		assertContext("template", "subpages")

		local pageCurrent = getContext().page
		local dir = getDirectory(pageCurrent._path)

		local subpages = {}
		for _, page in ipairs(pages) do
			if (page ~= pageCurrent or allowCurrentPage) and page._path:sub(1, #dir) == dir then
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

	lock = function()
		assertContext("template", "lock")

		local page = getContext().page
		page._isLocked = true -- Note: It's OK to lock multiple times.
		page._readonly = true
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
			:gsub("\n\t+",     "\n") -- Remove indentations.
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

	scriptEnvironmentGlobals.site = getProtectionWrapper(site, "site")
	scriptEnvironmentGlobals.data = newDataFolderReader(DIR_DATA, true)



	-- Read config.
	----------------------------------------------------------------

	if not isFile"config.lua" then
		error(makeErrorf("%s:0: %s", toNormalPath(lfs.currentdir()), "Missing config.lua"))
	end

	local chunk = assert(loadfile"config.lua")
	setfenv(chunk, scriptEnvironment)
	local config = chunk()
	assertTable(config, nil, nil, "config.lua must return a table.")

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

	site.title.v           = getV("title",             "",                    "string")
	site.baseUrl.v         = getV("baseUrl",           "",                    "string")
	site.languageCode.v    = getV("languageCode",      "",                    "string")
	site.defaultLayout.v   = getV("defaultLayout",     "page",                "string")

	site.redirections.v    = getT("redirections",      site.redirections.v,   "string", "string")

	ignoreFiles            = getA("ignoreFiles",       ignoreFiles,           "string")
	ignoreFolders          = getA("ignoreFolders",     ignoreFolders,         "string")

	fileTypes              = getT("types",             fileTypes,             "string", "string")
	fileProcessors         = getT("processors",        fileProcessors,        "string", "function")

	local htaRedirect      = getV("htaccess.redirect", false,                 "boolean")
	local htaWww           = getV("htaccess.www",      false,                 "boolean")
	htaErrors              = getT("htaccess.errors",   htaErrors,             "number", "string")
	local htaNoIndexes     = getV("htaccess.noIndexes",false,                 "boolean")
	local htaPrettyUrlDir  = getV("htaccess.XXX_prettyUrlDirectory", "",      "string")
	local htaDenyAccess    = getA("htaccess.XXX_denyDirectAccess",   {},      "string")
	local htaccess         = getT("htaccess",          nil,                   "string")
	local handleHtaccess   = htaccess ~= nil

	outputPathFormat       = get("rewriteOutputPath", "%s", NOOP)
	rewriteExcludes        = getA("rewriteExcludes",   rewriteExcludes,       "string")

	local onBefore         = getV("before",            nil,                   "function")
	local onAfter          = getV("after",             nil,                   "function")
	local onValidate       = getV("validate",          nil,                   "function")

	autoLockPages          = getV("autoLockPages",     false,                 "boolean")
	noTrailingSlash        = getV("removeTrailingSlashFromPermalinks", false, "boolean")

	for k in pairs(config) do
		logprint("WARNING: Unknown config field '%s'.", k)
	end
	for k in pairs(htaccess or {}) do
		logprint("WARNING: Unknown config.htaccess field '%s'.", k)
	end


	assert(isAny(type(outputPathFormat), "string","function"), "config.rewriteOutputPath must be a string or a function.")

	-- Validate config.types
	for ext, fileType in pairs(fileTypes) do
		if ext ~= ext:lower() then
			errorf("File extensions must be lower case: config.types[\"%s\"]", ext)
		elseif not FILE_TYPE_SET[fileType] then
			errorf("Invalid generator file type '%s'.", fileType)
		end
	end

	-- Validate config.processors
	for ext in pairs(fileProcessors) do
		if ext ~= ext:lower() then
			errorf("File extensions must be lower case: config.processors[\"%s\"]", ext)
		end
	end

	-- Validate config.baseUrl
	local parsedUrl = socket.url.parse(site.baseUrl.v)

	if site.baseUrl.v == "" then
		errorf("config.baseUrl is missing or empty.", site.baseUrl.v)

	elseif not parsedUrl.host then
		errorf("Missing host in config.baseUrl (%s)", site.baseUrl.v)

	elseif not parsedUrl.scheme then
		errorf("Missing scheme in config.baseUrl (%s)", site.baseUrl.v)
	elseif not isAny(parsedUrl.scheme, "http", "https") then
		errorf("Invalid scheme in config.baseUrl (Expected http or https, got '%s')", parsedUrl.scheme)

	elseif not (parsedUrl.path or ""):find"/$" then
		errorf("config.baseUrl must end with a '/'. (%s)", site.baseUrl.v)

	elseif parsedUrl.query then
		errorf("config.baseUrl Cannot contain a query. (%s)", site.baseUrl.v)
	elseif parsedUrl.fragment then
		errorf("config.baseUrl Cannot contain a fragment. (%s)", site.baseUrl.v)
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

		elseif fileTypes[extLower] == "othertemplate" then
			generateFromTemplateFile(newPage(pathRel))

		elseif fileTypes[extLower] then
			table.insert(pages, newPage(pathRel)) -- Generate later.

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
				preserveExistingOutputFile("raw", pathRel, pathRel)
			else
				local contents = assert(getFileContents(path))
				writeOutputFile("raw", pathRel, "/"..pathRel, contents, modTime)
			end

		else
			-- Ignore file.
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

			for _, url in ipairs(page.aliases.v) do
				generateRedirection(url, page.permalink.v)
			end
		end
	end

	for url, targetUrl in pairs(site.redirections.v) do
		generateRedirection(url, targetUrl)
	end

	-- Htaccess.
	if handleHtaccess then
		local contents = getFileContents(DIR_CONTENT.."/.htaccess") or ""

		-- Non-rewriting.
		--------------------------------

		if htaNoIndexes then
			contents = contents.."\nOptions -Indexes\n"
		end

		if next(htaErrors) then
			local b = newStringBuilder()

			for errCode, target in pairsSorted(htaErrors) do
				-- The target may be a URL or HTML code.
				b('ErrorDocument %d %s\n', errCode, target)
			end

			contents = F("%s\n%s", contents, b())
		end

		-- Rewriting.
		--------------------------------

		local escapeTestStr = htaccessRewriteEscapeTestString
		local escapeCondPat = htaccessRewriteEscapeCondPattern
		local escapeRuleSub = htaccessRewriteEscapeRuleSubstitution

		local b = newStringBuilder()

		b("<IfModule mod_rewrite.c>\n")
		b("\tOptions +FollowSymLinks\n") -- Required for rewriting to work in .htaccess files!
		b("\tRewriteEngine On\n")
		b("\n")

		local rewriteStartIndex = #b+1

		if htaWww then
			local protocol, theRest = site.baseUrl.v:match"^(https?)://(.+)"
			if theRest:find"^www%." then
				b("\t# Add www.\n")
				b("\tRewriteCond %{HTTP_HOST} !^www\\. [NC]\n")
				b('\tRewriteRule .* %s://www.%%{HTTP_HOST}%%{REQUEST_URI} [R=301,L]\n', protocol)
			else
				b("\t# Remove www.\n")
				b("\tRewriteCond %{HTTP_HOST} ^www\\.(.*)\n")
				b('\tRewriteRule .* %s://%%1%%{REQUEST_URI} [R=301,L]\n', protocol)
			end
			b("\n")
		end

		if htaRedirect and (next(writtenRedirects) or next(unwrittenRedirects)) then
			b("\t# Redirect moved resources.\n")

			for url, targetUrl in pairsSorted(writtenRedirects) do
				if targetUrl:sub(1, #site.baseUrl.v) == site.baseUrl.v then
					targetUrl = targetUrl:sub(#site.baseUrl.v) -- Note: We keep the initial '/'.
				end

				b('\tRewriteCond %%{REQUEST_URI} "=%s"\n', url)
				b('\tRewriteRule .* "%s" [R=301,L]\n', escapeRuleSub(targetUrl))
			end

			for url, targetUrl in pairsSorted(unwrittenRedirects) do
				if targetUrl:sub(1, #site.baseUrl.v) == site.baseUrl.v then
					targetUrl = targetUrl:sub(#site.baseUrl.v) -- Note: We keep the initial '/'.
				end

				local slug, query = url:match"^(.-)%?(.*)$"
				if not slug then  slug = url  end

				b('\tRewriteCond %%{REQUEST_URI} "=%s"\n', slug)

				if query then
					b('\tRewriteCond %%{QUERY_STRING} "=%s"\n', query)
				end

				b(
					'\tRewriteRule .* "%s%s" [R=301,L]\n',
					escapeRuleSub(targetUrl),
					(not query or targetUrl:find("?", 1, true)) and "" or "?"
				)
			end

			b("\n")
		end

		if noTrailingSlash then
			b("\t# Remove trailing slash.\n")
			b("\tRewriteCond %{REQUEST_FILENAME} !-d\n")
			b("\tRewriteCond %{REQUEST_URI} ./$\n")
			b("\tRewriteRule (.*)/$ /$1 [R=301,L]\n")
			b("\n")
		end

		if htaDenyAccess[1] then
			b("\t# Deny direct access to some directories.\n")
			b("\tRewriteCond %{ENV:REDIRECT_STATUS} ^$\n")

			for i, urlPrefix in ipairs(htaDenyAccess) do
				b(
					'\tRewriteCond %%{REQUEST_URI} "^%s"%s\n',
					escapeCondPat(urlPrefix),
					htaDenyAccess[i+1] and " [OR]" or ""
				)
			end

			b("\tRewriteRule ^ - [R=404,L]\n")
			b("\n")
		end

		if htaPrettyUrlDir ~= "" then
			b('\t# Point to "%s" directory.\n', htaPrettyUrlDir)
			b("\tRewriteCond %{REQUEST_FILENAME} !-f\n")
			b('\tRewriteCond "%%{DOCUMENT_ROOT}/%s/%%{REQUEST_URI}" -f\n', escapeTestStr(htaPrettyUrlDir))
			b('\tRewriteRule .* "/%s/$0" [L]\n', escapeRuleSub(htaPrettyUrlDir))
			b("\n")

			b("\tRewriteCond %{REQUEST_FILENAME} !-f\n")
			b("\tRewriteCond %{REQUEST_URI} !^/$\n")
			b('\tRewriteCond "%%{DOCUMENT_ROOT}/%s/%%{REQUEST_URI}/" -d\n', escapeTestStr(htaPrettyUrlDir))
			b('\tRewriteRule .* "/%s/$0/" [L]\n', escapeRuleSub(htaPrettyUrlDir))
			b("\n")
		end

		if b[rewriteStartIndex] then
			if b[#b] == "\n" then
				b[#b] = nil
			end

			b("</IfModule>\n")

			local directives = b()

			local count
			contents, count = gsub2(contents, "# *:webgen%.rewriting: *\n", directives)
			if count == 0 then
				contents = F("%s\n%s", contents, directives)
			end
		end

		--------------------------------

		writeOutputFile("raw", ".htaccess", "/.htaccess", contents)
	end -- handleHtaccess

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
	printf("    OtherTemplates:  %d", outputFileCounts["template"])
	printf("    OtherFiles:      %d  (Preserved: %d, %.1f%%)",
		outputFileCounts["raw"], outputFilePreservedCount,
		outputFileCounts["raw"] == 0 and 100 or outputFilePreservedCount/outputFileCounts["raw"]*100
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
