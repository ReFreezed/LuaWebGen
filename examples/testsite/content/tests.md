{{
page.title = 'Some "tests"<hr>'
page.date  = "2021-05-22 09:00 +02"

P.foo = "bar"
}}



## Parsing

Paragraph with [a link](http://foo.example.com/).

Paragraph with [a link]({{ url"/relative-link" }}).

Paragraph with [a link]({{ /relative-link }}).

Paragraph with [a link]({{ urlAbs"/absolute-link" }}).

An image: ![the alt]({{ /images/head.png }})

An image < <img src="{{ /images/head.png }}"> > inside markdown.

An image < {{ '<img src="'..url'/images/head.png'..'">' }} > inside markdown.

{{-- Line comment. {{"nope"}}
}}
{{--[[ Block comment. {{"nope"}} ]]}}
{{--[=[ --[[ Messy block comment. {{"nope"}} ]] ]=]}}

{{
-- globalVar = 123 -- Error: Cannot assign globals!
local localVar = function()end
-- localVar = globalVar -- Error: Cannot access non-existing globals!
}}
{{ localVar }}

{{
-- function()end -- Error: Invalid expression!
}}
{{
-- function globalFunc() end -- Error: Cannot assign globals!
}}

<p style="text-align: center;">
	Centered text in HTML. The following is not a list!
	- 1
	- 2
</p>

{{
-- Larger block of code.
print("Hello")
for i = 1, 3 do
	echof("- Blargh %d.\n", i)
end
}}

foo < {{ P.foo }} == "baz" > 0? <hr>

Two variations of control structures:

- using template: {{ for i = 1, 3 }}{{ i }}{{ end }}

- using normal Lua: {{
for i = 1, 3 do
	echo(i)
end
}}

{{if(1+2==3)}}
No spaces.
{{end}}

{{  if  1+2  ==  3  }}
Extra spaces.
{{  end  }}

Many curly braces: {{{{{x="foo"}}}}}

<!--
{{
print("This code will run!")
-- print("This will not...")
}}
-->

All {{ "Spaces" }} Allowed

{{ "No"  }} {{* "Spaces" *}} {{  "Allowed" }}
{{ "No" *}} {{  "Spaces"  }} {{* "Allowed" }}
{{ "No" *}} {{* "Spaces" *}} {{* "Allowed" }}

One {{  "Space" *}} Allowed
One {{* "Space"  }} Allowed

{{ "No" }}

{{* "Newlines" *}}

{{ "Allowed" }}

{{fori {5,99,- -8}}}
- {{it}}
{{end}}

URL: {{ /foo }}
URL: {{ ./foo }}
URL: {{ ../foo }}
URL: {{ http://example.com/foo }}

Markdown parsing, problematic link: [Snake!](https://en.wikipedia.org/wiki/Snake_(video_game_genre))

Markdown parsing, solution: [Snake!](<https://en.wikipedia.org/wiki/Snake_(video_game_genre)>)



## Value Expressions

String: {{ "Water" }}

Operations: {{ 1+2*3 }}

Operations: {{ "a-".."-b" -- Inline comment.
}}

Operations: {{ 1 + --[[ Inline comment. ]] 2 }}

Value from function: {{ date"%Y-%m-%d" }}

No value from function: {{ print("Just a print to console.") }}

Field: {{ page.title }}

Table: {{ site }}

Param: {{ P.foo }}

Text: {{ "foo <img>" }}

Html: {{ "<img>" }}

echo: {{ echo('<img src="'..url"/images/head.png"..'">') }}

echoRaw: {{ echoRaw('<img src="'..url"/images/head.png"..'">') }}



## Control Structures

{{ local depth = 0 }}
{{ do }}
{{ local depth = 1 }}
{{ do }}
{{ local depth = 2 }}
Inner do...end at {{ depth }}.
{{ end }}
Outer do...end at {{ depth }}.
{{ end }}
Outside do...end at {{ depth }}.

{{ local favoriteFruit = "banana" }}
{{ if favoriteFruit == "apple" }}
Favorite fruit is apple!
{{ elseif favoriteFruit == "banana" }}
Favorite fruit is banana!
{{ else }}
Favorite fruit is neither apple nor banana. :(
{{ end }}

{{ for i = 1, 3 }}
- For {{ i }}
{{ end }}

{{ for 3 }}
- Short form {{ i }}
{{ end }}

{{ for < 3 }}
- Backwards {{ i }}
{{ end }}

{{ local n = 3 }}
{{ while n > 0 }}
- Countdown #{{ n }}
{{ n = n-1 }}
{{ end }}

{{ repeat }}
{{ n = n+1 }}
- Count #{{ n }}
{{ until n >= 3 }}



## Data

Dogs:
{{ fori dog in data.dogs }}
- {{ i }}: {{ dog.name }} (age {{ dog.age }})
{{ end }}

Cats, in reverse:
{{ fori < data.cats.cats }}
- {{ i }}: {{ it.name }} (age {{ it.age }})
{{ end }}

{{ io.write("JSON: ") ; printObject(data.random) }}
{{ io.write("XML: ")  ; print(data.barf:getFirstElement()) }}



## Scripts

ipsum: {{ ipsum() }}

echoOgres: {{ scripts.echoOgres() --[[ echoOgres() and scripts.echoOgres() refer to the same script. ]] }}

fullscreenImage: {{ fullscreenImage"/images/head.png" }}



{{
local function errorTests()
	-- (               -- Template parsing error.
	-- }} {{if 1}} {{  -- Template parsing error.
	-- nil             -- Lua parsing error.
	-- x = 5 + nil     -- Lua runtime error.
	-- error("Oh no!") -- User-raised error.
end
errorTests()
}}


