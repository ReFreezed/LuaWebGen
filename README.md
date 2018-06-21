# LuaWebGen
![](https://img.shields.io/badge/beta-0.8-green.svg)

Static website generator in Lua 5.1. Somewhat inspired by [Hugo](https://gohugo.io/). Currently in **beta**.

Webpages are generated using HTML and markdown *templates* with embedded Lua code. CSS files can also include code.

- [Why?](#why)
- [Example](#example)
- [Installation / Usage](#installation--usage)
- [Reference](Reference.md)



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
page.title = "My First Blog Post!"
local foo = "bar"
}}

Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Duis nec justo mollis, varius nulla sed, commodo nibh.

1 + 2 * 3 = {{1+2*3}}<br>
foo is {{foo}}

# List of Cats

{{for i, cat in ipairs(data.myCats)}}
- Cat {{i}} is named {{cat.name}}.
{{end}}
```

Page template, `page.html`:

```html
{{include"header"}}
{{include"navigation"}}

<main>
	<h1 id="{{urlize(page.title)}}">{{page.title}}</h1>
	{{page.content}}
</main>

{{include"footer"}}
```



## Installation / Usage

LuaWebGen requires Lua 5.1 and these libraries:

- [Lua-GD](https://ittner.github.io/lua-gd/) for image manipulation.
- [LuaFileSystem](https://keplerproject.github.io/luafilesystem/) for file system access.
- [LuaSocket](http://w3.impa.br/~diego/software/luasocket/home.html) for URL handling.

If you're on Windows you can simply install [Lua for Windows](https://github.com/rjpcomputing/luaforwindows).

> **Note:** LuaWebGen has only been tested on Windows.

To generate a website, run this from the command line:

```batch
cd path/to/site/root
lua path/to/LuaWebGen/main.lua build
```

LuaWebGen expects this folder hierarchy:

```
site-root/
    content/           -- All website content, including pages, images, CSS and JavaScript files.
        index.html|md  -- Homepage/root index page (good to have one).
    data/              -- Optional data folder. Can contain .lua and .toml files.
    layouts/           -- All HTML layout templates.
        page.html      -- Default page template.
    logs/              -- Automatically created log file folder.
    output/            -- Automatically created output folder.
    scripts/           -- Optional Lua script folder. The scripts must return a function.
    config.lua         -- Site-wide configurations.
```

Everything in the *content* folder will be processed and end up in the *output* folder.

> **Note:** The *output* folder is automatically cleaned from files and folders that do not exist in the *content* folder,
> so it's not a good idea to save files in the *output* folder.


