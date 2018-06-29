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

_WEBGEN_VERSION = "0.12.0"



-- Settings.

DIR_CONTENT = "content"
DIR_DATA    = "data"
DIR_LAYOUTS = "layouts"
DIR_LOGS    = "logs"
DIR_OUTPUT  = "output"
DIR_SCRIPTS = "scripts"

AUTOBUILD_MIN_INTERVAL = 1.00



-- Constants.

HTML_ENTITY_PATTERN = '[&<>"]'
HTML_ENTITIES = {
	['&'] = "&amp;",
	['<'] = "&lt;",
	['>'] = "&gt;",
	['"'] = "&quot;",
}

URI_PERCENT_CODES_TO_NOT_ENCODE = {
	["%2d"]="-",["%2e"]=".",["%7e"]="~",--["???"]="_",
	["%21"]="!",["%23"]="#",["%24"]="$",["%26"]="&",["%27"]="'",["%28"]="(",["%29"]=")",["%2a"]="*",["%2b"]="+",
	["%2c"]=",",["%2f"]="/",["%3a"]=":",["%3b"]=";",["%3d"]="=",["%3f"]="?",["%40"]="@",["%5b"]="[",["%5d"]="]",
}

TEMPLATE_EXTENSION_SET = {["html"]=true, ["md"]=true, ["css"]=true}
PAGE_EXTENSION_SET     = {["html"]=true, ["md"]=true}

OUTPUT_CATEGORY_SET = {["page"]=true, ["otherTemplate"]=true, ["otherRaw"]=true}

DATA_FILE_EXTENSIONS = {"lua","toml","xml"}
IMAGE_EXTENSIONS     = {"png","jpg","jpeg","gif"}

NOOP = function()end



-- Modules.

gd          = require"gd"
lfs         = require"lfs"
socket      = require"socket"

escapeUri   = require"socket.url".escape

markdownLib = require"markdown"
parseToml   = require"toml".parse
xmlLib      = require"pl.xml"

_assert     = assert
_error      = error
_pcall      = pcall
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
oncePrints               = {}

_                        = nil -- Dummy.



-- Site variables. These are reset in buildWebsite() (including _G.oncePrints).
site                       = nil

pages                      = nil
pagesGenerating            = nil

contextStack               = nil
proxies                    = nil
proxySources               = nil
layoutTemplates            = nil
scriptFunctions            = nil

ignoreFiles                = nil
ignoreFolders              = nil

fileProcessors             = nil

outputPathFormat           = "%s"
rewriteExcludes            = nil

noTrailingSlash            = false

writtenOutputFiles         = nil
writtenOutputUrls          = nil
writtenRedirects           = nil
outputFileCount            = 0
outputFileCounts           = nil
outputFileByteCount        = 0
outputFilePreservedCount   = 0
outputFileSkippedPageCount = 0

thumbnailInfos             = nil


