local config = {
	title         = "Test Website",
	baseUrl       = "http://example.com/",
	languageCode  = "en",

	ignoreFiles   = {"%.tmp$", "%.psd$"},
	ignoreFolders = {"^%."},

	processors    = {},
}



-- File processors.
config.processors["css"] = function(css)

	-- Remove CSS comments, before the file is written to the output folder.
	css = css:gsub("/%*.-%*/", "")

	return css
end



-- Before generation.
local dogPageFormat = [[
# A Dog of Mine

The dog named %s is %d years old.
]]

config.before = function()

	-- Generate dog pages from database.
	for _, dog in ipairs(data.dogs) do
		local path     = F("/dogs/%s.md", urlize(dog.name))
		local template = F(dogPageFormat, dog.name, dog.age)

		generateFromTemplate(path, template)
	end

end



-- After generation.
config.after = function()
	print("We did it!")
end



return config
