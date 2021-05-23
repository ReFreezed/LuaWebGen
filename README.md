<h1 align="center"><img src="gfx/logo.png" width="200" height="200" alt="LuaWebGen" title="LuaWebGen"></h1>

<p align="center">
	<a href="https://github.com/ReFreezed/LuaWebGen/releases/latest">
		<img src="https://img.shields.io/github/release/ReFreezed/LuaWebGen.svg" alt="">
	</a>
	<a href="https://github.com/ReFreezed/LuaWebGen/blob/master/LICENSE">
		<img src="https://img.shields.io/github/license/ReFreezed/LuaWebGen.svg" alt="">
	</a>
</p>

**LuaWebGen** - static website generator, powered by Lua. Somewhat inspired by [Hugo](https://gohugo.io/).

Webpages are generated using HTML and Markdown *templates* with embedded Lua code.
CSS files can also include code.

[**Download latest release**](https://github.com/ReFreezed/LuaWebGen/releases/latest)

- [Why?](#why)
- [Example](#example)
- [Installation / Usage](#installation--usage)
	- [Windows](#windows)
	- [Universal](#universal)
	- [Build Website](#build-website)
- [Documentation](https://github.com/ReFreezed/LuaWebGen/wiki)



## Why?

The rant: After using *Hugo* for a little while I got fed up with
how annoying it was to add custom functionality (everything has to be a template),
how "content" and "static" files were treated differently,
how CSS files were excluded from the templating system,
how you couldn't display data from the data folder easily on pages,
how confusing index files were, and other silly things.

Being a programmer, I thought treating all files equally and enabling the use of an actual programming
language would solve most of these problems.



## Example

A blog post, `my-first-post.md`:

```markdown
{{
page.title = "The First!"
local foot = "not hand"
}}

Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Duis nec justo mollis, varius nulla sed, commodo nibh.

Foot is {{ foot }}<br>
1 + 2 * 3 = {{ 1+2*3 }}<br>
Current year is {{ os.date"%Y" }}

## List of Cats

{{ for i, cat in ipairs(data.myCats) }}
- Cat {{ i }} is named {{ cat.name }}.
{{ end }}

![Cute cat]({{ getCatImageUrl() }})
```

Page layout template, `page.html`:

```html
{{ include"header" }}
{{ include"navigation" }}

<main>
	<h1 id="{{ urlize(page.title) }}">{{ page.title }}</h1>
	{{ page.content }}
</main>

{{ include"footer" }}
```



## Installation / Usage

There are two versions of LuaWebGen: Windows and universal.
Begin by [downloading](https://github.com/ReFreezed/LuaWebGen/releases/latest) and unzipping the program somewhere.


### Windows
Just run `webgen.exe`, like this:

```batch
cd path/to/siteroot
path/to/webgen.exe command [options]
```

If you add the program folder to your [PATH](https://www.computerhope.com/issues/ch000549.htm)
it's a bit nicer:

```batch
cd path/to/siteroot
webgen command [options]
```

> **Note:** The documentation uses this format.


### Universal
This version requires these things to be installed:

- [Lua 5.1](https://www.lua.org/)
- [LuaFileSystem](https://keplerproject.github.io/luafilesystem/) - required for file system access.

Some functionality also require these things:

- [Lua-GD](https://ittner.github.io/lua-gd/) - required for image manipulation.
- [LuaSocket](http://w3.impa.br/~diego/software/luasocket/home.html) - optional, for more CPU-friendly auto-builds.

> **Hint:** On Windows you can simply install [Lua for Windows](https://github.com/rjpcomputing/luaforwindows)
> which includes everything that's needed in a neat package.

Run the program like this:

```batch
cd path/to/siteroot
lua path/to/webgen.lua command [options]
```

> **Note:** LuaWebGen has only been tested on Windows so far.


### Build Website

To generate a new empty website, run something like this from the
[command line](https://github.com/ReFreezed/LuaWebGen/wiki/Command-Line):

```batch
webgen new site "my-website"
cd "my-website"
webgen new page "blog/first-post.md"
webgen build
```

LuaWebGen uses this [folder structure](https://github.com/ReFreezed/LuaWebGen/wiki/Home#folder-structure) for a website project:

```
my-website/             -- Root of the website project.
    content/            -- All website content, including pages, images, CSS and JavaScript files.
        index.(html|md) -- Homepage/root index page.
    data/               -- Optional data folder. Can contain Lua, TOML, JSON and XML files.
    layouts/            -- All HTML layout templates.
        page.html       -- Default page layout template.
    output/             -- Where the built website ends up.
    scripts/            -- Optional Lua script folder. Scripts must return a function.
    config.lua          -- Site-wide configurations.
```

Everything in the *content* folder will be processed and end up in the *output* folder.

See the [wiki](https://github.com/ReFreezed/LuaWebGen/wiki) for the full documentation.


