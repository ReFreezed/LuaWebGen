# LuaWebGen Reference

- [Notes](#notes)
- [Command Line](#command-line)
- [Site Configuration](#site-configuration)
- [Control Structures](#control-structures)
- [Constants](#constants)
- [Functions](#functions)
	- [Global Functions](#global-functions)
	- [Context-Specific Functions](#context-specific-functions)
- [Objects](#objects)
	- [`site`](#site)
	- [`page`](#page)
	- [Other Objects](#other-objects)



## Notes

You can use any standard Lua library normally in your code, like `io` and `math` (including <abbr title="LuaFileSystem">`lfs`</abbr> and `socket`).

You cannot add you own globals directly - use the *scripts* folder to define global functions,
and the *data* folder to store globally accessible data.
The idea is that this restriction should prevent accidental global access.



## Command Line

To generate your website, run this from the command line:

```
lua "path/to/LuaWebGen/main.lua" "path/to/site/root" [options]
```

### Options

#### `--autobuild` or `-a`
Auto-build website when changes are detected. This makes LuaWebGen run until you press `Ctrl`+`C` in the command prompt.

#### `--force` or `-f`
Force-update all.
This makes LuaWebGen treat all previously outputted files as if they were modified.
This has the same effect as deleting the `output` folder.



## Site Configuration

Site-specific configurations are stored in `config.lua` in the site root. The file is expected to return a table with any of these fields:

```lua
title         -- See site.title
baseUrl       -- See site.baseUrl
languageCode  -- See site.languageCode

ignoreFiles   -- Array of filename patterns to exclude from site generation.
ignoreFolders -- Array of folder name patterns to exclude from site generation.

processors    -- Table with file content processors.

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



## Constants

#### `_WEBGEN_VERSION`
The current version of LuaWebGen, e.g. `1.0.2`.

#### `IMAGE_EXTENSIONS`
An array of common image file extensions.



## Functions



### Global Functions

- [`chooseExistingFile()`](#chooseexistingfile)
- [`chooseExistingImage()`](#chooseexistingimage)
- [`date()`](#date)
- [`entities()`](#entities)
- [`F()`](#f)
- [`fileExists()`](#fileexists)
- [`find()`](#find)
- [`findAll()`](#findall)
- [`generatorMeta()`](#generatormeta)
- [`getExtension()`](#getextension)
- [`getFilename()`](#getfilename)
- [`isAny()`](#isany)
- [`markdown()`](#markdown)
- [`newBuffer()`](#newbuffer)
- [`printf()`](#printf)
- [`sortNatural()`](#sortnatural)
- [`trim()`](#trim)
- [`trimNewlines()`](#trimnewlines)
- [`url()`](#url)
- [`urlAbs()`](#urlAbs)
- [`urlize()`](#urlize)

#### chooseExistingFile()
`path = chooseExistingFile( pathWithoutExtension, extensions )`

Return the path of an existing file with any of the specified extensions. Returns nil if no file exists.

#### chooseExistingImage()
`path = chooseExistingImage( pathWithoutExtension )`

Return the path of an existing image file with any of the specified extensions. Returns nil if no image file exists.

Short form for `chooseExistingFile(pathWithoutExtension, IMAGE_EXTENSIONS)`.

#### date()
`string = date( format [, time=now ] )`

Alias for [`os.date()`](http://www.lua.org/manual/5.1/manual.html#pdf-os.date).
(See the [C docs for date format](http://www.cplusplus.com/reference/ctime/strftime/).)

#### entities()
`html = entities( text )`

Encode HTML entities, e.g. `<` to `&lt;`.

#### F()
`string = F( format, ... )`

Alias for [`string.format()`](http://www.lua.org/manual/5.1/manual.html#pdf-string.format).

#### fileExists()
`bool = fileExists( path )`

Check if a file exists in the *content* folder.

#### find()
`item, index = find( array, attribute, value )`

Get the item in the array whose `attribute` is `value`. Returns `nil` if no item is found.

#### findAll()
`items = findAll( array, attribute, value )`

Get all items in the array whose `attribute` is `value`.

#### generatorMeta()
`html = generatorMeta( [ hideVersion=false ] )`

Generate HTML generator meta tag (e.g. `<meta name="generator" content="LuaWebGen 1.0.0">`).
This tag makes it possible to track how many websites use this generator, which is cool.
This should be placed in the `<head>` element.

#### getExtension()
`extension = getExtension( path )`

Get the extension part of a path or filename.

#### getFilename()
`filename = getFilename( path )`

Get the filename part of a path.

#### isAny()
`bool = isAny( value, values )`

Check if `value` exists in the `values` array.

#### markdown()
`html = markdown( markdownText )`

Convert markdown to HTML.

#### newBuffer()
`buffer = newBuffer( )`

Create a handy string buffer object, like so:

```lua
local b = newBuffer()

-- Add things.
b('<img src="icon.png">') -- One argument adds a plain string.
b('<h1>%s</h1>', entities(page.title)) -- Multiple arguments acts like string.format() .

-- Get the contents.
local html = b() -- No arguments returns the buffer as a string.
```

#### printf()
`printf( format, ... )`

Short form for `print(F(format, ...))`.

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

> **Note:** `url()` does not encode HTML entities, like ampersand, thus does not produce valid HTML:
> ```lua
> local src = url"/thumb.php?size=200&name=Hello world!"
> local html = F('<img src="%s">', src) -- Incorrect.
> local html = F('<img src="%s">', entities(src)) -- Correct.
> ```

#### urlAbs()
`encodedString = urlAbs( urlString )`

Same as [`url()`](#url) but also prepends `site.baseUrl` to relative URLs, making them absolute.

#### urlize()
`urlPart = urlize( string )`

Make a string look like a URL. Useful e.g. when converting page titles to URL slugs.

```lua
urlize("Hello, big world!") -- "hello-big-world"
```



### Context-Specific Functions

- [`echo()`](#echo)
- [`echoRaw()`](#echoraw)
- [`generateFromTemplate()`](#generatefromtemplate)
- [`include()`](#include)

There are currently two contexts where code can run:

- Templates (HTML, markdown and CSS files)
- Config (`config.before()` and `config.after()`)

#### echo()
`echo( string )`

Output a string from a template. HTML entities are encoded automatically. Available in templates.

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

#### include()
`html = include( filename )`

Get a HTML template from the *layouts* folder. Available in templates. **Note:** Exclude the extension in the filename (e.g. `include"footer"`).



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


