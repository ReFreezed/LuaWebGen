--[[============================================================
--=
--=  URI parsing, composition and relative URL resolution
--=  Contains code from LuaSocket by Diego Nehab
--=
--==============================================================

	absolute
	escape, unescape
	parse, build
	parsePath, buildPath

--============================================================]]

local M = {}

-- Protect a path segment, to prevent it from interfering with the url parsing.
local ALLOWED_SEGMENTS = {
	["-"]=true, ["_"]=true, ["."]=true, ["!"]=true, ["~"]=true, ["*"]=true, ["'"]=true, ["("]=true,
	[")"]=true, [":"]=true, ["@"]=true, ["&"]=true, ["="]=true, ["+"]=true, ["$"]=true, [","]=true,
	-- Plus alphanumeric chars.
}
local function protectSegment(s)
	return s:gsub("[^A-Za-z0-9_]", function(c)
		if not ALLOWED_SEGMENTS[c] then
			return string.format("%%%02x", c:byte())
		end
	end)
end

-- Build a path from a base path and a relative path.
local function absolutePath(basePath, relativePath)
	if relativePath:sub(1, 1) == "/" then  return relativePath  end

	local path = basePath:gsub("[^/]*$", "")
	path       = path .. relativePath

	path = path:gsub("[^/]*%./", function(s)
		if s ~= "./" then  return s  else  return ""  end
	end)

	path = path:gsub("/%.$", "/")

	repeat
		local beforeReduced = path
		path = path:gsub("[^/]*/%.%./", function(s)
			if s ~= "../../" then  return ""  end
		end)
	until path == beforeReduced

	path = path:gsub("[^/]*/%.%.$", function(s)
		if s ~= "../.." then  return ""  end
	end)

	return path
end

-- Encode a string into its escaped hexadecimal representation.
function M.escape(binStr)
	return binStr:gsub("([^A-Za-z0-9_])", function(c)
		return F("%%%02x", c:byte())
	end)
end

-- Decode a string from its escaped hexadecimal representation.
function M.unescape(binStr)
	return (binStr:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

--
-- Parse a url into a table with all its parts according to RFC 2396.
--
-- The following grammar describes the names given to the URL parts:
-- <url>       ::= <scheme> :// <authority> / <path> ; <params> ? <query> # <fragment>
-- <authority> ::= <userinfo> @ <host> : <port>
-- <userinfo>  ::= <user> [ : <password> ]
-- <path>      ::= { <segment> / } <segment>
--
-- Input
--   url: uniform resource locator of request
--   default: table with default values for each field
--
-- Returns
--   table with the following fields, where RFC naming conventions have
--   been preserved:
--     scheme, authority, userinfo, user, password, host, port,
--     path, params, query, fragment
--
-- Note: The leading '/' in {/<path>} is considered part of <path>.
--
function M.parse(url, default)
	if (url or "") == "" then  return nil, "invalid url"  end

	local parsed = {}
	if default then
		for k, v in pairs(default) do  parsed[k] = v  end
	end

	url = url:gsub("#(.*)$",               function(f)  parsed.fragment  = f ; return ""  end)
	url = url:gsub("^([%w][%w%+%-%.]*)%:", function(s)  parsed.scheme    = s ; return ""  end)
	url = url:gsub("^//([^/]*)",           function(n)  parsed.authority = n ; return ""  end)
	url = url:gsub("%?(.*)",               function(q)  parsed.query     = q ; return ""  end)
	url = url:gsub("%;(.*)",               function(p)  parsed.params    = p ; return ""  end)

	-- The path is whatever's left.
	if url ~= "" then  parsed.path = url  end

	local authority = parsed.authority
	if not authority then  return parsed  end

	authority = authority:gsub("^([^@]*)@", function(u)  parsed.userinfo = u ; return ""  end)
	authority = authority:gsub(":([^:]*)$", function(p)  parsed.port     = p ; return ""  end)

	if authority ~= "" then  parsed.host = authority  end

	local userinfo = parsed.userinfo
	if not userinfo then  return parsed  end

	userinfo    = userinfo:gsub(":([^:]*)$", function(p)  parsed.password = p ; return ""  end)
	parsed.user = userinfo

	return parsed
end

-- Rebuild a parsed URL from its components.
-- Components are protected if any reserved or unallowed characters are found.
function M.build(parsed)
	local ppath = M.parsePath(parsed.path or "")
	local url   = M.buildPath(ppath)

	if parsed.params then  url = url .. ";" .. parsed.params  end
	if parsed.query  then  url = url .. "?" .. parsed.query   end

	local authority = parsed.authority

	if parsed.host then
		authority = parsed.host
		if parsed.port then  authority = authority .. ":" .. parsed.port  end

		local userinfo = parsed.userinfo

		if parsed.user then
			userinfo = parsed.user
			if parsed.password then
				userinfo = userinfo .. ":" .. parsed.password
			end
		end

		if userinfo then  authority = userinfo .. "@" .. authority  end
	end

	if authority       then  url = "//" .. authority    .. url    end
	if parsed.scheme   then  url = parsed.scheme .. ":" .. url    end
	if parsed.fragment then  url = url .. "#" .. parsed.fragment  end

	return url
end

-- Build an absolute URL from a base and a relative URL according to RFC 2396.
function M.absolute(baseUrl, relativeUrl)
	local baseParsed
	if type(baseUrl) == "table" then
		baseParsed = baseUrl
		baseUrl    = M.build(baseParsed)
	else
		baseParsed = M.parse(baseUrl)
	end

	local relativeParsed = M.parse(relativeUrl)

	if not baseParsed        then  return relativeUrl  end
	if not relativeParsed    then  return baseUrl      end
	if relativeParsed.scheme then  return relativeUrl  end

	relativeParsed.scheme = baseParsed.scheme

	if not relativeParsed.authority then
		relativeParsed.authority = baseParsed.authority
		if not relativeParsed.path then
			relativeParsed.path = baseParsed.path
			if not relativeParsed.params then
				relativeParsed.params = baseParsed.params
				relativeParsed.query  = relativeParsed.query or baseParsed.query
			end
		else
			relativeParsed.path = absolutePath((baseParsed.path or ""), relativeParsed.path)
		end
	end

	return M.build(relativeParsed)
end

-- Break a path into its segments, unescaping the segments.
function M.parsePath(path)
	local parsed = {}
	path         = path or ""

	path:gsub("[^/]+", function(s)
		table.insert(parsed, s)
	end)

	for i = 1, #parsed do
		parsed[i] = M.unescape(parsed[i])
	end

	parsed.isAbsolute  = (path:sub( 1,  1) == "/")
	parsed.isDirectory = (path:sub(-1, -1) == "/")

	return parsed
end

-- Build a path component from its segments, escaping protected characters.
-- If unsafe is true, segments are not protected before path is built.
function M.buildPath(parsed, unsafe)
	local path = ""
	local n    = #parsed

	if unsafe then
		for i = 1, n-1 do
			path = path .. parsed[i] .. "/"
		end
		if n > 0 then
			path = path .. parsed[n]
			if parsed.isDirectory then  path = path .. "/"  end
		end
	else
		for i = 1, n-1 do
			path = path .. protectSegment(parsed[i]) .. "/"
		end
		if n > 0 then
			path = path .. protectSegment(parsed[n])
			if parsed.isDirectory then  path = path .. "/"  end
		end
	end

	if parsed.isAbsolute then  path = "/" .. path  end

	return path
end

return M
