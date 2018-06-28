{{
page.title = "Blog"
}}

This is the blog index.

## Posts

{{fori page in subpages()}}
- [{{page.title}}]({{page.permalink}})
{{end}}

And, that's it!
