{{
page.title = 'First "Post"<!>'
P.foo = "bar"
}}



This is the first post. The title is "{{page.title}}" and foo is "{{P.foo}}".

Here's a paragraph with [a link]({{url"/some-page"}}) and an image: ![the alt](/images/icon.png)

An HTML image > <img src="/images/icon.png"> < inside text.

A composed HTML image > {{'<img src="'..url'/images/icon.png'..'">'}} < inside text.

{{-- Comment 1}}
{{--[[ Comment 2 {{"asdf"}} ]]}}
{{--[=[ --[[ Comment 3 {{"asdf"}} ]] ]=]}}

{{local localVar = 123}}
{{--localVar = globalVar}}
{{--globalVar = 123}}



## Plain Output

{{date("%Y-%m-%d")}}



## Do

{{do}}
Outer do...end
{{do}}
Inner do...end
{{end}}
Back to outer do...end
{{end}}



## If/Else

{{local favoriteFruit = "banana"}}
{{if favoriteFruit == "apple"}}
Favorite fruit is apple!
{{elseif favoriteFruit == "banana"}}
Favorite fruit is banana!
{{else}}
Favorite fruit is neither apple nor banana. :(
{{end}}



## For

{{for i = 1, 3}}
- Item #{{i}}.
{{end}}



## While

{{local n = 3}}
{{while n > 0}}
- Countdown #{{n}}.
{{n = n-1}}
{{end}}



## Repeat

{{local count = 0}}
{{repeat}}
{{count = count+1}}
- Count #{{count}}.
{{until count >= 3}}



## HTML

<p style="text-align: center;">
	Centered text!
	- 1
	- 2
</p>



## Parsing Tests

{{page}}

foo < {{P.foo}} == "baz" > 0? <hr>



## Data

Dogs:
{{fori dog in data.dogs}}
- {{dog.name}} (age {{dog.age}})
{{end}}

Cats:
{{fori data.cats.cats}}
- {{it.name}} (age {{it.age}})
{{end}}



## Scripts

{{ipsum()}}

{{fullscreenImage("/images/icon.png")}}



End of the first post!
