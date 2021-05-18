LuaWebGen
Developed by Marcus 'ReFreezed' Thunström

Website: https://github.com/ReFreezed/LuaWebGen
Documentation: https://github.com/ReFreezed/LuaWebGen/wiki

1. Disclaimer
2. Installation / Usage
3. Example



1. Disclaimer
==============================================================================

The software is provided "as is", without warranty of any kind, express or
implied, including but not limited to the warranties of merchantability,
fitness for a particular purpose and noninfringement. In no event shall the
authors or copyright holders be liable for any claim, damages or other
liability, whether in an action of contract, tort or otherwise, arising from,
out of or in connection with the software or the use or other dealings in the
software.



2. Installation / Usage
==============================================================================

There are two versions of LuaWebGen: Windows and universal.


Windows
------------------------------------------------------------------------------

Just run webgen.exe, like this:

    cd path/to/siteroot
    path/to/webgen.exe command [options]

If you add the program folder to your PATH it's a bit nicer:

    cd path/to/siteroot
    webgen command [options]

(Note: The documentation uses this format.)


Universal
------------------------------------------------------------------------------

This version requires these things to be installed:

- Lua 5.1 (https://www.lua.org/)
- LuaFileSystem - required for file system access. (https://keplerproject.github.io/luafilesystem/)

Some functionality also require these things:

- Lua-GD - required for image manipulation. (https://ittner.github.io/lua-gd/)
- LuaSocket - optional, for more CPU-friendly auto-builds. (http://w3.impa.br/~diego/software/luasocket/home.html)

Hint: On Windows you can simply install Lua for Windows which includes
everything that's needed in a neat package:
https://github.com/rjpcomputing/luaforwindows

Run the program like this:

    cd path/to/siteroot
    lua path/to/webgen.lua command [options]

(Note: LuaWebGen has only been tested on Windows so far.)


Build Website
------------------------------------------------------------------------------

To generate a new empty website, run something like this from the command line:

    webgen new site "my-website"
    cd "my-website"
    webgen new page "blog/first-post.md"
    webgen build

LuaWebGen uses this folder structure for a website project:

    my-website/             -- Root of the website project.
        content/            -- All website content, including pages, images, CSS and JavaScript files.
            index.(html|md) -- Homepage/root index page.
        data/               -- Optional data folder. Can contain Lua, TOML, JSON and XML files.
        layouts/            -- All HTML layout templates.
            page.html       -- Default page layout template.
        output/             -- Where the built website ends up.
        scripts/            -- Optional Lua script folder. Scripts must return a function.
        config.lua          -- Site-wide configurations.

Everything in the 'content' folder will be processed and end up in the
'output' folder.

(Note: The 'output' folder is automatically cleaned from files and folders that
do not exist in the 'content' folder, so don't save files in the 'output' folder!)

See the wiki for the full documentation:
https://github.com/ReFreezed/LuaWebGen/wiki



3. Example
==============================================================================

A blog post, my-first-post.md:

    {{
    page.title = "The First!"
    local foot = "not hand"
    }}

    Lorem ipsum dolor sit amet, consectetur adipiscing elit.
    Duis nec justo mollis, varius nulla sed, commodo nibh.

    Foot is {{foot}}<br>
    1 + 2 * 3 = {{1+2*3}}<br>
    Current year is {{os.date"%Y"}}

    ## List of Cats

    {{for i, cat in ipairs(data.myCats)}}
    - Cat {{i}} is named {{cat.name}}.
    {{end}}

    ![Cute cat]({{ getCatImageUrl() }})

Page layout template, page.html:

    {{include"header"}}
    {{include"navigation"}}

    <main>
        <h1 id="{{urlize(page.title)}}">{{page.title}}</h1>
        {{page.content}}
    </main>

    {{include"footer"}}



==============================================================================
