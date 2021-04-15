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

_G.WEBGEN_VERSION = "0.19.0"



-- Settings.

_G.DIR_CONTENT = "content" -- @Incomplete: Make directories configurable.
_G.DIR_DATA    = "data"
_G.DIR_LAYOUTS = "layouts"
_G.DIR_LOGS    = "logs"
_G.DIR_OUTPUT  = "output"
_G.DIR_SCRIPTS = "scripts"

_G.AUTOBUILD_MIN_INTERVAL = 1.00



-- Constants.

_G.FILE_TYPE_SET       = {["markdown"]=true, ["html"]=true, ["othertemplate"]=true}
_G.OUTPUT_CATEGORY_SET = {["page"]=true, ["template"]=true, ["raw"]=true}

_G.DATA_FILE_EXTENSIONS = {"lua","toml","xml"}
_G.IMAGE_EXTENSIONS     = {"png","jpg","jpeg","gif"}

_G.NOOP = function()end



-- Modules.

_G.lfs = require"lfs"

_G.gd     = pcall(require, "gd")     and require"gd"     or nil
_G.socket = pcall(require, "socket") and require"socket" or nil

_G.dateLib     = require"date"
_G.markdownLib = require"markdown"
_G.tomlLib     = require"toml"
_G.urlLib      = require"url"
_G.xmlLib      = require"pl.xml"



-- Misc variables.

_G.logFile   = nil
_G.logPath   = ""
_G.logBuffer = {}

_G.includeDrafts = false
_G.verbosePrint  = false

_G.scriptEnvironment        = nil
_G.scriptEnvironmentGlobals = nil

_G.dataReaderPaths     = setmetatable({}, {__mode="k"})
_G.dataIsPreloaded     = setmetatable({}, {__mode="k"})
_G.protectionWrappers  = setmetatable({}, {__mode="kv"})
_G.protectionedObjects = setmetatable({}, {__mode="kv"})

_G.oncePrints = {}

_G._ = nil -- Dummy.



-- Site variables. These are reset in buildWebsite() (including _G.oncePrints).
function _G.resetSiteVariables()
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


