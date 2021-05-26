# {{ site.title }}

## Cool Links

{{ fori {
	"/plants/",               -- Current URL.
	"/plantz/",               -- Page alias.
	"/flowers/",              -- Old link.
	"/view.php?page=flowers", -- Old link.
	"/bad-link/",             -- 404 error.
} *}}
- [{{ prettyUrl(it) }}]({{ it }})
{{ end }}
