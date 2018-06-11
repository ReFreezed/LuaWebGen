# LuaWebGen

Static website generator in Lua 5.1. Somewhat inspired by [Hugo](https://gohugo.io/). Currently in **beta**.

Webpages are generated using HTML and markdown *templates* with embedded Lua code. CSS files can also include code.

- [Why?](#why)
- [Example](#example)
- [Installation/Usage](#installationusage)
- [Reference](#reference)



## Why?

The rant: After using *Hugo* for a short time I got fed up with how annoying it was to add custom functionality (everything has to be a template), how "content" and "static" files were treated differently, how CSS files were excluded from the templating system, how you couldn't display data from the data folder easily on pages, how confusing index files were, and other silly things.

Being a programmer, I though treating all files equally and enabling the use of an actual programming language would solve most of these problems.



## Example

A blog post (my-first-post.md):

```markdown
{{
-- This is embedded Lua.
page.title = "My First Blog Post!"
}}

Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Duis nec justo mollis, varius nulla sed, commodo nibh.

# List of Cats

{{for i, cat in ipairs(data.myCats)}}
- Cat {{i}} is named {{cat.name}}.
{{end}}
```

Page template (page.html):

```html
{{include"header"}}
{{include"navigation"}}

<main>
	<h1 id="{{urlize(page.title)}}">{{page.title}}</h1>
	{{page.content}}
</main>

{{include"footer"}}
```



## Installation/Usage

LuaWebGen currently runs on Windows by installing [Lua for Windows](https://github.com/rjpcomputing/luaforwindows), or installing these modules:

- LuaFileSystem
- Socket

(The only Windows-specific feature currently used is *ROBOCOPY* for cleaning up generated output folders. This dependency will be removed at some point...)

To generate a website, run this from the command line:

```
lua main.lua "path/to/site/root"
```

LuaWebGen expects this folder hierarchy:

```
site-root/
    content/           -- All website content, including pages, images, CSS and JavaScript files.
        index.html|md  -- Homepage/root index page (good to have one).
    data/              -- Optional data folder. Can contain .lua and .toml files.
    output/            -- Automatically created output folder.
    scripts/           -- Optional Lua script folder. The scripts must return a function.
    templates/         -- All HTML templates.
        page.html      -- Default page template.
```



## Reference

**Note:** You cannot add you own globals directly - use the *scripts* folder to define global functions,
and the *data* folder to store globally accessible data.

- [Global Functions](#global-functions)
- [The `site` Object](#the-site-object)
- [The `page` Object](#the-page-object)
- [Other Globals](#other-globals)


### Global Functions

`date( ... )`<br>
Alias for os.date(). (See the [C docs for date format](http://www.cplusplus.com/reference/ctime/strftime/).)

`F( ... )`<br>
Alias for string.format().

`generatorMeta( )`<br>
Generate HTML generator meta tag (e.g. `<meta name="generator" content="LuaWebGen 1.0.0">`). This tag makes it possible to track how many websites use this generator, which is cool.

`include( filename )`<br>
Insert a HTML template from the *templates* folder. Exclude the extension from the filename (e.g. `include"footer"`).

`sortNatural( array [, attribute ] )`<br>
[Naturally sort](https://en.wikipedia.org/wiki/Natural_sort_order) an array of strings. If the array contains tables you can sort by a specific *attribute* instead.

`trim( string )`<br>
Remove surrounding whitespace from a string.

`trimNewlines( string )`<br>
Remove surrounding newlines from a string.

`url( urlString )`<br>
Percent-encode a URL (spaces become `%20` etc.).

`urlize( string )`<br>
Make a string look like a URL. Useful when converting page titles to URL slugs.


### The `site` Object

These can be configured in *config.lua* .

`site.baseUrl`<br>
The base part of the website's URL, e.g. `http://www.example.com/`.

`site.languageCode`<br>
The code for language of the website, e.g. `dk`. (This doesn't do much yet, but will be used for i18n in the future.)

`site.title`<br>
The title of the website.


### The `page` Object

`page.content`<br>
The contents of the current page. Available to templates.

`page.isHome`<br>
If the current page is the root index page, aka the home page.

`page.isIndex`<br>
If the current page is an index page.

`page.isPage`<br>
If the current page is in fact a page. This value is false for CSS files.

`page.permalink`<br>
The URL to the current page.

`page.title`<br>
The title of the current page.


### Other Globals

`data`<br>
Access data from the *data* folder. E.g. type `data.cats` to retrieve `data/cats.lua`.

`params` or `P`<br>
Table for storing any custom data you want.


You can also use any normal Lua library, like `io` and `math` (including `lfs` and `socket`).


