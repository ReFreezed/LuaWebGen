# LuaWebGen Reference

- [Notes](#notes)
- [Configuration](#config)
- [Control Structures](#control-structures)
- [Functions](#functions)
	- [Global Functions](#global-functions)
	- [Context-Specific Functions](#context-specific-functions)
- [Objects](#objects)
	- [`site`](#site)
	- [`page`](#page)
	- [Other Objects](#other-objects)



## Notes

You can use any standard Lua library normally, like `io` and `math` (including <abbr title="LuaFileSystem">`lfs`</abbr> and `socket`).

You cannot add you own globals directly - use the *scripts* folder to define global functions,
and the *data* folder to store globally accessible data.
The idea is that this restriction should prevent accidental global access.



## Configuration

Site-specific configurations are stored in `config.lua` in the site root. The file is expected to return a table with any of these fields:

```lua
title         -- See site.title
baseUrl       -- See site.baseUrl
languageCode  -- See site.languageCode

ignoreFiles   -- Array of filename patterns to exclude from site generation.
ignoreFolders -- Array of folder name patterns to exclude from site generation.

before        -- Function that is called before site generation.
after         -- Function that is called after site generation.
```

All fields are optional.



## Control Structures

Control structures in templates behave pretty much like in normal Lua, but here are some additions.

#### fori

Two versions of a simplified `for` statement.

```markdown
{{fori dog in data.dogs}}
- {{dog.name}}
{{end}}

{{fori data.dogs}}
- {{it.name}}
{{end}}
```



## Functions



### Global Functions

- [`date()`](#date)
- [`F()`](#f)
- [`generatorMeta()`](#generatormeta)
- [`include()`](#include)
- [`sortNatural()`](#sortnatural)
- [`trim()`](#trim)
- [`trimNewlines()`](#trimnewlines)
- [`url()`](#url)
- [`urlize()`](#urlize)

#### date()
`string = date( format [, time=now ] )`

Alias for [`os.date()`](http://www.lua.org/manual/5.1/manual.html#pdf-os.date).
(See the [C docs for date format](http://www.cplusplus.com/reference/ctime/strftime/).)

#### F()
`string = F( format, ... )`

Alias for [`string.format()`](http://www.lua.org/manual/5.1/manual.html#pdf-string.format).

#### generatorMeta()
`string = generatorMeta( )`

Generate HTML generator meta tag (e.g. `<meta name="generator" content="LuaWebGen 1.0.0">`).
This tag makes it possible to track how many websites use this generator, which is cool.
This should be placed in the `<head>` element.

#### include()
`string = include( filename )`

Insert a HTML template from the *layouts* folder. Exclude the extension from the filename (e.g. `include"footer"`).

#### sortNatural()
`array = sortNatural( array [, attribute ] )`

[Naturally sort](https://en.wikipedia.org/wiki/Natural_sort_order) an array of strings.
If the array contains tables you can sort by a specific *attribute* instead.

#### trim()
`string = trim( string )`

Remove surrounding whitespace from a string.

#### trimNewlines()
`string = trimNewlines( string )`

Remove surrounding newlines from a string.

#### url()
`encodedString = url( urlString )`

Percent-encode a URL (spaces become `%20` etc.).

#### urlize()
`urlSegment = urlize( string )`

Make a string look like a URL. Useful when converting page titles to URL slugs.



### Context-Specific Functions

- [`echo()`](#echo)
- [`echoRaw()`](#echoraw)
- [`generateFromTemplate()`](#generatefromtemplate)

There are currently two contexts where code can run:

- Templates (HTML, markdown and CSS files)
- Config (`config.before()` and `config.after()`)

#### echo()
`echo( string )`

Output a string from a template. Available in templates.

> **Note:** This function is used under the hood and it's often not necessary to call it manually.
> For example, these rows do the same thing:
> ```
> {{date"%Y"}}
> {{echo(date"%Y")}}
> ```

#### echoRaw()
`echoRaw( string )`

Like `echo()`, output a string from a template, except this string doesn't become HTML encoded. Available in templates.

```lua
echo   ("a < b") -- Output is "a &lt; b"
echoRaw("a < b") -- Output is "a < b"
```

#### generateFromTemplate()
`generateFromTemplate( path, templateString )`

Generate a page from a template. Available in `config.before()` and `config.after()`. Example:
```lua
generateFromTemplate("dogs/fido.md", "# Fido\n\nFido is fluffy!")
```



### `site`

These values can be configured in *config.lua* .

#### site.baseUrl
The base part of the website's URL, e.g. `http://www.example.com/`.

#### site.languageCode
The code for the language of the website, e.g. `dk`. (This doesn't do much yet, but will be used for i18n in the future.)

#### site.title
The title of the website.



### `page`

#### page.content
The contents of the current page. Available to layout templates.

#### page.isHome
If the current page is the root index page, aka the home page.

#### page.isIndex
If the current page is an index page.

#### page.isPage
If the current page is in fact a page. This value is false for CSS files.

#### page.permalink
The URL to the current page.

#### page.title
The title of the current page. Each page should update this value.



### Other Objects

#### data
Access data from the *data* folder. E.g. type `data.cats` to retrieve the contents of `data/cats.lua`.

#### params
`params` or `P`

Table for storing any custom data you want.


