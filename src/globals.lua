--[[============================================================
--=
--=  Global Variables and Constants
--=
--=-------------------------------------------------------------
--=
--=  LuaWebGen - static website generator in Lua!
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

_WEBGEN_VERSION = "0.18.0"



-- Settings.

DIR_CONTENT            = "content" -- @Incomplete: Make directories configurable.
DIR_DATA               = "data"
DIR_LAYOUTS            = "layouts"
DIR_LOGS               = "logs"
DIR_OUTPUT             = "output"
DIR_SCRIPTS            = "scripts"

AUTOBUILD_MIN_INTERVAL = 1.00

ERROR_TRACEBACK_LINES  = 25



-- Constants.

FILE_TYPE_SET          = {["markdown"]=true, ["html"]=true, ["othertemplate"]=true}
OUTPUT_CATEGORY_SET    = {["page"]=true, ["template"]=true, ["raw"]=true}

DATA_FILE_EXTENSIONS   = {"lua","toml","xml"}
IMAGE_EXTENSIONS       = {"png","jpg","jpeg","gif"}

NOOP                   = function()end



-- Modules.

gd          = require"gd"
lfs         = require"lfs"
socket      = require"socket"

escapeUri   = require"socket.url".escape

dateLib     = require"date"
markdownLib = require"markdown"
parseToml   = require"toml".parse
xmlLib      = require"pl.xml"

_print      = print



-- Misc variables.

logFile                  = nil
logPath                  = ""
logBuffer                = {}

includeDrafts            = false
verbosePrint             = false

scriptEnvironment        = nil
scriptEnvironmentGlobals = nil

dataReaderPaths          = setmetatable({}, {__mode="k"})
dataIsPreloaded          = setmetatable({}, {__mode="k"})
protectionWrappers       = setmetatable({}, {__mode="kv"})
protectionedObjects      = setmetatable({}, {__mode="kv"})

oncePrints               = {}

_                        = nil -- Dummy.



-- Site variables. These are reset in buildWebsite() (including _G.oncePrints).
function resetSiteVariables()
	site = {
		_readonly = true,

		title = {
			v = "",
			g = function(field) return field.v end,
		},
		baseUrl = {
			v = "",
			g = function(field) return field.v end,
		},
		languageCode = {
			v = "",
			g = function(field) return field.v end,
		},
		defaultLayout = {
			v = "page",
			g = function(field) return field.v end,
		},

		redirections = {
			v = {}, -- k=url, v=targetUrl.
			g = function(field) return field.v end,
		},
	}

	ignoreFiles                = {} -- Array.
	ignoreFolders              = {} -- Array.

	fileTypes                  = {["md"]="markdown", ["html"]="html", ["css"]="othertemplate"}
	fileProcessors             = {} -- k=extension, v=function(data, sitePath).

	htaErrors                  = {} -- k=httpStatusCode, v=document.

	outputPathFormat           = "%s"
	rewriteExcludes            = {} -- Array of pathPat.

	autoLockPages              = false
	noTrailingSlash            = false


	contextStack               = {} -- Array.
	layoutTemplates            = {} -- k=path, v=template.
	scriptFunctions            = {} -- k=scriptName, v=function(...).

	pages                      = {} -- Array.
	pagesGenerating            = {} -- Set of 'pathRelOut'.

	writtenOutputFiles         = {} -- Set and array of 'pathOutputRel'.
	writtenOutputUrls          = {} -- Set of 'url'.
	writtenRedirects           = {} -- k=url, v=targetUrl.
	unwrittenRedirects         = {} -- k=url, v=targetUrl.
	outputFileCount            = 0
	outputFileCounts           = {} -- k=category, v=count.
	outputFileByteCount        = 0
	outputFilePreservedCount   = 0  -- This should only count raw files. Maybe rename the variable?
	outputFileSkippedPageCount = 0

	thumbnailInfos             = {}
end

resetSiteVariables()


