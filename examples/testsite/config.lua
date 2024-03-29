local config = {
	title         = "Test Website",
	baseUrl       = "http://example.com/",
	languageCode  = "en",

	ignoreFiles   = {"%.tmp$", "%.psd$"},
	ignoreFolders = {"^%."},

	processors    = {}, -- Defined here below...

	-- autoLockPages = true,

	redirections  = {
		["/blog/original-first/"]         = "/blog/first/",         -- Internal redirect.
		["/duck/"]                        = "http://duck.example/", -- External redirect.
		["/index.php?page=dogs&dog=fido"] = "/dogs/fido/",          -- Redirect with query. (Requires .htaccess file to work.)
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



-- Before regular generation.
local dogPageTemplate = [[
{{
page.title = "A Dog of Mine: "..P.dog.name
page.date  = "2012-01-14"
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



-- After regular generation.
config.after = function()
	outputRaw("/raw-test.html", "So raw!")
	print("We did it!")
end



-- After all generation.
config.validate = function()
	local fileInfos = getOutputtedFiles()

	print("Written files:")
	printf("  %-30s %-40s %s", "SOURCE", "PATH", "URL")
	for _, fileInfo in ipairs(fileInfos) do
		printf("  %-30s %-40s %s", fileInfo.sourcePath, fileInfo.path, fileInfo.url)
	end

	local fileInfoNonTemplate = find(fileInfos, "sourcePath", "/images/head.png")
	local fileInfoNonPage     = find(fileInfos, "sourcePath", "/css/style.css")
	local fileInfoPage        = find(fileInfos, "sourcePath", "/blog/index.md")
	local fileInfoSitemap     = find(fileInfos, "sourcePath", "/sitemap.xml")
	assert(fileInfoNonTemplate.serial < fileInfoNonPage.serial)
	assert(fileInfoNonPage.serial     < fileInfoPage.serial)
	assert(fileInfoPage.serial        < fileInfoSitemap.serial)
end



tests.runTests()

return config
