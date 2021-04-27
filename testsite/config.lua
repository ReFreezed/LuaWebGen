local config = {
	title         = "Test Website",
	baseUrl       = "http://example.com/",
	languageCode  = "en",

	ignoreFiles   = {"%.tmp$", "%.psd$"},
	ignoreFolders = {"^%."},

	processors    = {}, -- Defined here below...

	-- autoLockPages = true,

	redirections  = {
		["/also-first/"] = "/first/",
		["/duck/"]       = "https://duckduckgo.com/",
	},

	-- Enable special .htaccess file handling.
	htaccess = {
		redirect = true,
	},
}



-- File processors.
config.processors["css"] = function(css)
	-- Remove CSS comments, before the file is written to the output folder.
	css = css:gsub("/%*.-%*/", "")
	return css
end



-- Before generation.
local dogPageTemplate = [[
{{
page.title = "A Dog of Mine: "..P.dog.name
}}

The dog named {{P.dog.name}} is {{P.dog.age}} years old.
]]

config.before = function()
	-- Generate dog pages from database.
	for _, dog in ipairs(data.dogs) do
		local path = F("/dogs/%s.md", urlize(dog.name))
		generateFromTemplate(path, dogPageTemplate, {dog=dog})
	end
end



-- After generation.
config.after = function()
	print("We did it!")
end

config.validate = function()
	print("All URLs:")
	for _, fileInfo in ipairs(getOutputtedFiles()) do
		printf("  %s", fileInfo.url)
	end
end



return config
