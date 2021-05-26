return {
	title        = "Apache Example",
	baseUrl      = "http://apache.example/",
	languageCode = "en",

	redirections = {
		["/flowers/"]              = "/plants/",
		["/view.php?page=flowers"] = "/plants/",
	},

	htaccess = {
		www       = true, -- Modify "www." to match baseUrl.
		redirect  = true, -- Add directives for redirecting page aliases and the redirections above.
		noIndexes = true, -- Disable automatic index pages that list files.

		errors = {
			[404] = "/404/index.html",
		},
	},
}
