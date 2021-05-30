{{
page.title = "Blog"
page.date  = "2019-06-27 14:00:01 CST"
}}

This is the blog index.

## Posts

{{ fori page in subpages() }}
- [{{ page.title }}]({{ url(page.url) }})
{{ end }}

And, that's it!
