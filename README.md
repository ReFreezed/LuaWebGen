# LuaWebGen

Static website generator in Lua 5.1. Somewhat inspired by [Hugo](https://gohugo.io/). Currently in **beta**.

Webpages are generated using HTML and markdown *templates* with embedded Lua code. CSS files can also include code.

- [Why?](#why)
- [Example](#example)
- [Installation / Usage](#installation-usage)
- [Reference](Reference.md)



## Why?

The rant: After using *Hugo* for a short time I got fed up with
how annoying it was to add custom functionality (everything has to be a template),
how "content" and "static" files were treated differently,
how CSS files were excluded from the templating system,
how you couldn't display data from the data folder easily on pages,
how confusing index files were, and other silly things.

Being a programmer, I thought treating all files equally and enabling the use of an actual programming
language would solve most of these problems.



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



## Installation / Usage

LuaWebGen requires Lua 5.1 and these libraries:

- LuaFileSystem
- LuaSocket

If you're on Windows you can simply install [Lua for Windows](https://github.com/rjpcomputing/luaforwindows).

> **Note:** LuaWebGen has only been tested on Windows.

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
    layouts/           -- All HTML layout templates.
        page.html      -- Default page template.
    output/            -- Automatically created output folder.
    scripts/           -- Optional Lua script folder. The scripts must return a function.
    config.lua         -- Site-wide configurations.
```

Everything in the *content* folder will be processed and end up in the *output* folder.

> **Note:** The *output* folder is automatically cleaned from files and folders that do not exist in the *content* folder,
> so it's not a good idea to save files in the *output* folder.


