# LuaWebGen Reference

- [Notes](#notes)
- [Command Line](#command-line)
	- [Commands](#commands)
	- [Build Options](#build-options)
- [Site Configuration](#site-configuration)
- [Control Structures](#control-structures)
- [Constants](#constants)
- [Functions](#functions)
	- [Utility Functions](#utility-functions)
	- [Context-Specific Functions](#context-specific-functions)
- [Objects](#objects)
	- [`site`](#site)
	- [`page`](#page)
	- [Other Objects](#other-objects)



## Notes

You can use any standard Lua library normally in your code, like `io` and `os`
(including <abbr title="LuaFileSystem">`lfs`</abbr> and `socket`).

You cannot add you own globals directly - use the *scripts* folder to define global functions,
and the *data* folder to store globally accessible data.
The idea is that this restriction should prevent accidental global access.



## Command Line

To use LuaWebGen, navigate to your site's root folder and run this from the command line:

```batch
lua "path/to/LuaWebGen/main.lua" some_command [options]
```

In Windows you can optionally add `path/to/LuaWebGen` to your [`PATH`](https://www.computerhope.com/issues/ch000549.htm)
and take advantage of `webgen.exe`:

```batch
webgen some_command [options]
```

Much nicer! The rest of the documentation will use this format.

### Commands

#### build
```batch
webgen build [options]
```

Build the website. (Also look at available [options](#build-options).)

#### new page
```batch
webgen new page "page_path"
```

Create a new page with some basic information. Example: `webgen new page blog/first-post.md`

#### new site
```batch
webgen new site "folder_name"
```

Initialize a folder to contain a new site.

### Build Options

#### `--autobuild` or `-a`
Auto-build website when changes are detected. This makes LuaWebGen run until you press `Ctrl`+`C` in the command prompt.

#### `--drafts` or `-d`
Include page drafts when building. Meant for debugging.

#### `--force` or `-f`
Force-update all.
This makes LuaWebGen treat all previously outputted files as if they were modified.
This has the same effect as deleting the `output` folder.

#### `--verbose` or `-v`
Enable verbose printing in the console.



## Site Configuration

Site-specific configurations are stored in `config.lua` in the site root. The file is expected to return a table with any of these fields:

```lua
title             -- See site.title
baseUrl           -- See site.baseUrl
languageCode      -- See site.languageCode
defaultLayout     -- See site.defaultLayout

redirections      -- Table with source URL slugs as keys and target URLs are values.

ignoreFiles       -- Array of filename patterns to exclude from site generation.
ignoreFolders     -- Array of folder name patterns to exclude from site generation.

processors        -- Table with file content processors.

rewriteOutputPath -- See below.
rewriteExcludes   -- See below.

before            -- Function that is called before site generation.
after             -- Function that is called after main site generation.
validate          -- Function that is called after all tasks are done.
```

All fields are optional.

#### rewriteOutputPath
Use this to control where files are written inside the *output* folder.
Note that URLs don't change.
Example usage of `rewriteOutputPath` is to use it together with URL rewriting on the server.
Most people should ignore this configuration entirely.

If the value is a string then it's used as format for the path. Example:
```lua
config.rewriteOutputPath = "/subfolder%s" -- %s is the original path.
-- "content/index.html"   is written to "output/subfolder/index.html"
-- "content/blog/post.md" is written to "output/subfolder/blog/post/index.html"
-- etc.
```

If the value is a function then the function is expected to return the rewritten path. Example:
```lua
config.rewriteOutputPath = function(path)
	-- Put .css and .js files in a subfolder.
	if isAny(getExtension(path), {"css","js"}) then
		return "/subfolder"..path
	end
	return path
end
```

The default value for `rewriteOutputPath` is `"%s"`

#### rewriteExcludes
This is an array of path patterns for files that should not be rewritten by `rewriteOutputPath`. Example:
```lua
-- Exclude topmost .htaccess file.
config.rewriteExcludes = {"^/%.htaccess$"}
```



## Control Structures

Control structures in templates behave pretty much like in normal Lua, but here are some additions.

#### fori

Two versions of a simplified `for` statement:

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



### Utility Functions

- [`chooseExistingFile()`](#chooseexistingfile)
- [`chooseExistingImage()`](#chooseexistingimage)
- [`cssPrefix()`](#cssprefix)
- [`date()`](#date)
- [`entities()`](#entities)
- [`errorf()`](#errorf)
- [`F()`](#f)
- [`fileExists()`](#fileexists)
- [`find()`](#find)
- [`findAll()`](#findall)
- [`formatTemplate()`](#formattemplate)
- [`generatorMeta()`](#generatormeta)
- [`getExtension()`](#getextension)
- [`getFilename()`](#getfilename)
- [`getKeys()`](#getkeys)
- [`indexOf()`](#indexof)
- [`isAny()`](#isany)
- [`markdown()`](#markdown)
- [`max()`](#max)
- [`min()`](#min)
- [`newBuffer()`](#newbuffer)
- [`printf()`](#printf)
- [`printfOnce()`](#printfOnce)
- [`printOnce()`](#printOnce)
- [`round()`](#round)
- [`sortNatural()`](#sortnatural)
- [`split()`](#split)
- [`thumb()`](#thumb)
- [`toLua()`](#tolua)
- [`toTime()`](#totime)
- [`trim()`](#trim)
- [`trimNewlines()`](#trimnewlines)
- [`url()`](#url)
- [`urlAbs()`](#urlabs)
- [`urlExists()`](#urlexists)
- [`urlize()`](#urlize)
- [`validateUrls()`](#validateurls)
- [`warning()`](#warning)
- [`warningOnce()`](#warningonce)

#### chooseExistingFile()
`path = chooseExistingFile( pathWithoutExtension, extensions )`

Return the path of an existing file with any of the specified extensions. Returns `nil` if no file exists.

#### chooseExistingImage()
`path = chooseExistingImage( pathWithoutExtension )`

Return the path of an existing image file with any of the specified extensions. Returns `nil` if no image file exists.

Short form for `chooseExistingFile(pathWithoutExtension, IMAGE_EXTENSIONS)`.

#### cssPrefix()
`css = cssPrefix( property, value )`

Quick and dirty way of adding vendor-specific prefixes to a CSS property. Example:

```lua
local css = cssPrefix("flex", "auto")
-- css is "-ms-flex: auto; -moz-flex: auto; -webkit-flex: auto; flex: auto;"
```

#### date()
`string = date( format [, time=now ] )`

Alias for [`os.date()`](http://www.lua.org/manual/5.1/manual.html#pdf-os.date).
(See the [C docs for date format](http://www.cplusplus.com/reference/ctime/strftime/).)

#### entities()
`html = entities( text )`

Encode HTML entities, e.g. `<` to `&lt;`.

#### errorf()
`errorf( [ level=1, ] format, ... )`

Trigger an error with a formatted message.

Short form for `error(F(format, ...), level)`.

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

#### formatTemplate()
`template = formatTemplate( format, valueTable )`

Quick and dirty formatting of a template, presumably before using `generateFromTemplate()`.
This replaces all instances of `:key:` with the corresponding field from `values`.
Example:

```lua
local template = formatTemplate(
	[[
		{{
		page.title  = :title:
		page.layout = "awesome"
		}}

		My dog likes :thing:.
		Other dogs probably like :thing: too!
	]],
	{
		title = F("%q", "Timmie the Dog"), -- Remember, the title is in the Lua code.
		thing = "bones",
	}
)
generateFromTemplate("dogs/info.md", template)
```

Also see [`toLua()`](#tolua).

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

#### getKeys()
`keys = getKeys( table )`

Get the keys from a table.

#### indexOf()
`index = indexOf( array, value )`

Get the index of a value in an array. Returns `nil` if the value was not found.

#### isAny()
`bool = isAny( value, values )`

Check if `value` exists in the `values` array.

#### markdown()
`html = markdown( markdownText )`

Convert markdown to HTML.

#### max()
`n = max( n1, n2, ... )`

Alias for [`math.max()`](http://www.lua.org/manual/5.1/manual.html#pdf-math.max).

#### min()
`n = min( n1, n2, ... )`

Alias for [`math.min()`](http://www.lua.org/manual/5.1/manual.html#pdf-math.min).

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

#### printfOnce()
`printfOnce( format, ... )`

Print a formatted message only once. Meant for preventing too much spam in the console/log.

#### printOnce()
`printOnce( ... )`

Print value(s) only once. Meant for preventing too much spam in the console/log.

#### round()
`number = round( number )`

Round a number.

#### sortNatural()
`array = sortNatural( array [, attribute ] )`

[Naturally sort](https://en.wikipedia.org/wiki/Natural_sort_order) an array of strings.
If the array contains tables you can sort by a specific *attribute* instead.

#### split()
`parts = split( string, separatorPattern [, startIndex=1, plain=false ] )`

Split a string by a pattern. Example:

```lua
local dogs = split("Fido,Grumpy,The Destroyer", ",")
```

#### thumb()
`html = thumb( imagePath, thumbWidth [, thumbHeight ] [, isLink=false ] )`

Create a thumbnail from an image.
At least one of `thumbWidth` or `thumbHeight` must be a positive number.
Example:

```
{{thumb("/images/gorillaz-fan-art.png", 400, 400, true)}}
{{thumb("/images/a-big-tree.gif", 512, true)}}
{{thumb("/images/1000-clown-cars.jpg", 0, 350, false)}}
```

#### toLua()
`luaString = toLua( value )`

Convert any value to Lua code. Useful e.g. when sending tables to layouts. Example:

```lua
local credits = {
	{what="Fabric", who="Soft Inc."},
	{what="Paint",  who="Bob Bobson Co."},
}

local template = formatTemplate(
	[[
		{{
		page.title = :title:
		P.creditsInPageFooter = :credits:
		}}

		Experience the best carpets around!
	]],
	{
		title   = toLua("Carpets"),
		credits = toLua(credits),
	}
)

generateFromTemplate("products/carpets.md", template)
```

#### toTime()
`time = toTime( datetime )`

Convert a *datetime* used in LuaWebGen to a normal time value that standard libraries understand.
`datetime` must have the format `"YYYY-MM-DD hh:mm:ss"`.
Example:

```lua
local time = toTime(page.publishDate)
local publishYear = os.date("%Y", time)
```

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

#### urlExists()
`urlExists( url )`

Check that files for URLs exist.
Useful e.g. after moving a bunch of pages (that now should have aliases).
Example:

```lua
function config.validate()
	local url = "/old-folder/my-post/"
	if not urlExists(url) then
		error("Page is missing: "..url)
	end
end
```

#### urlize()
`urlPart = urlize( string )`

Make a string look like a URL. Useful e.g. when converting page titles to URL slugs.

```lua
urlize("Hello, big world!") -- "hello-big-world"
```

#### validateUrls()
`validateUrls( url )`

Check that files for URLs exist.
Useful e.g. after moving a bunch of pages (that now should have aliases).
Example:

```lua
function config.validate()
	validateUrls{
		"/old-folder/my-post/",
		"/work-in-progress/dog.png",
	}
end
```

#### warning()
`warning( message )`

Prints a big warning message to the console. Nothing else happens.

#### warningOnce()
`warningOnce( message )`

Prints a big warning message to the console once only. Nothing else happens.



### Context-Specific Functions

- [`echo()`](#echo)
- [`echoRaw()`](#echoraw)
- [`generateFromTemplate()`](#generatefromtemplate)
- [`include()`](#include)
- [`isCurrentUrl()`](#iscurrenturl)
- [`isCurrentUrlBelow()`](#iscurrenturlbelow)
- [`outputRaw()`](#outputraw)
- [`subpages()`](#subpages)

There are currently 3 contexts where code can run:

- Templates (HTML, markdown and CSS files)
- Config (`config.before()` and `config.after()`)
- Validation (`config.validate()`)

#### echo()
`echo( string )`

Output a string from a template. HTML entities are encoded automatically. Available in templates.
Also, see [`echoRaw()`](#echoraw).

> **Note:** This function is used under the hood and it's often not necessary to call it manually.
> For example, these rows do the same thing:
> ```
> {{date"%Y"}}
> {{echo(date"%Y")}}
> ```

#### echoRaw()
`echoRaw( string )`

Like [`echo()`](#echo), output a string from a template, except HTML entities don't become encoded in this string.
Available in templates.

```lua
echo   ("a < b") -- Output is "a &lt; b"
echoRaw("a < b") -- Output is "a < b"
```

> **Note:** In templates, if echo isn't used then HTML entities are sometimes encoded and
> sometimes not - LuaWebGen tries to be smart about it:
> ```
> {{"<br>"}}            -- Output is "<br>"
> {{"Foo <br>"}}        -- Output is "Foo &lt;br&gt;"
>
> {{echo"<br>"}}        -- Output is "&lt;br&gt;"
> {{echo"Foo <br>"}}    -- Output is "Foo &lt;br&gt;"
>
> {{echoRaw"<br>"}}     -- Output is "<br>"
> {{echoRaw"Foo <br>"}} -- Output is "Foo <br>"
> ```

#### generateFromTemplate()
`page = generateFromTemplate( path, templateString )`

Generate a page from a template. Available in `config.before()` and `config.after()`. Example:

```lua
local path     = "/dogs/fido.md"
local template = "# Fido\n\nFido is fluffy!"
local page     = generateFromTemplate(path, template)
printf("We generated page '%s'.", page.url)
```

#### include()
`html = include( filename )`

Get a HTML template from the *layouts* folder. Available in templates.
**Note:** Exclude the extension in the filename (e.g. `include"footer"`).

#### isCurrentUrl()
`bool = isCurrentUrl( url )`

Check if the relative URL of the current page is `url`. Example:

```
{{if isCurrentUrl"/blog/last-post/"}}
You've reached the end!
{{end}}
```

#### isCurrentUrlBelow()
`bool = isCurrentUrlBelow( urlPrefix )`

Check if the relative URL of the current page starts with `urlPrefix`. Example:

```html
{{local class = isCurrentUrlBelow"/blog/" and "current" or ""}}

<a href="/blog/" class="{{class}}">Blog</a>
```

#### outputRaw()
`outputRaw( path, contents )`

Output any data to a file. Available in `config.before()` and `config.after()`. Example:
```lua
outputRaw("/docs/versions.txt", "Version 1\nReleased: 2002-10-16\n")
```

#### subpages()
`pages = subpages( )`

Recursively get all pages in the current folder and below, sorted by `publishDate`. Intended for index pages. Available in templates. Example:
```markdown
# Blog Archive

{{fori page in subpages()}}
- [{{page.publishDate}} {{page.title}}]({{page.permalink}})
{{end}}
```

> **Note:** Two pages in the same folder cannot request all subpages - that would result in
> an infinite loop as LuaWebGen tries to generate all subpages before returning a list of them.
> You'll have to generate at least one of those two pages in `config.after()`.



### `site`

These values can be configured in `config.lua`.

#### site.baseUrl
The base part of the website's URL, e.g. `http://www.example.com/`.

#### site.defaultLayout
The default layout pages will use. The default value is `"page"` (which corresponds to the file `layouts/page.html`).

#### site.languageCode
The code for the language of the website, e.g. `dk`. (This doesn't do much yet, but will be used for i18n in the future.)

#### site.title
The title of the website.



### `page`

#### page.aliases
A list of slugs that point to previous locations of the current page. Example:
```
{{
page.title   = "New Improved Page"
page.aliases = {"/my-page/", "/some-archived-page/"}
}}
```

#### page.content
The contents of the current page. Available in layouts.

#### page.isDraft
If the current page is a draft.
Drafts are excluded from the building process (unless the `--drafts` option is used).

#### page.isHome
If the current page is the root index page, aka the home page.

#### page.isIndex
If the current page is an index page.

#### page.isPage
If the current page is in fact a page. This value is false for CSS files.

#### page.isSpecial
If the current page is some kind of special page.
Special pages are ignored by `subpages()`.
Set this to `true` for e.g. 404 error pages.

#### page.layout
What layout the page should use.
The default is the value of `site.defaultLayout`.

#### page.params
Table for storing any custom data you want.

#### page.permalink
The permanent URL to the current page.

#### page.publishDate
What date the page is published (in *local* time).
If the date is in the future then the page is excluded from the build process.
Must have the format `"YYYY-MM-DD hh:mm:ss"`.

#### page.title
The title of the current page. Each page should update this value.

#### page.url
The relative URL to the current page on the site.



### Other Objects

#### data
Access data from the *data* folder.
Type e.g. `data.cats` to retrieve the contents of `data/cats.lua`.
Data files can be `.lua`, `.toml` or `.xml` files.
(LuaWebGen uses [Penlight](https://stevedonovan.github.io/Penlight/api/topics/06-data.md.html#XML) for XML data.)

#### params
`params` or `P`

Table for storing any custom data you want. Short form for [`page.params`](#pageparams).


