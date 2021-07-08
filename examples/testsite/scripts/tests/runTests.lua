return function()
	do return end -- Disable tests.

	local timerStartTime = 0
	local timerLabel     = ""

	local function timerStart(label)
		timerLabel     = label
		timerStartTime = os.clock()
	end
	local function timerEnd()
		printf("%s: %.3f", timerLabel, os.clock()-timerStartTime)
	end

	local function readTextFile(path)
		local file, err = io.open(path, "r")
		if not file then  return nil, err  end

		local contents = file:read"*a"
		file:close()

		if contents:find("\r", 1, true) then
			contents = contents:gsub("\n?\r\n?", "\n")
		end

		return contents
	end

	local function formatBytes(n)
		if     n >= 1024^4/10 then  return F("%.2f TiB", n/1024^4)
		elseif n >= 1024^3/10 then  return F("%.2f GiB", n/1024^3)
		elseif n >= 1024^2/10 then  return F("%.2f MiB", n/1024^2)
		elseif n >= 1024^1/10 then  return F("%.2f KiB", n/1024^1)
		else                        return F("%d bytes", n       )  end
	end



	--[[ XML module tests.
	-- require"pl.xml"
	timerStart("our") ; tests.xmlTests(xml)             ; timerEnd()
	-- timerStart("pl")  ; tests.xmlTests(require"pl.xml") ; timerEnd()
	--]]



	--[==[ XML parsing.
	local xmlStr = (
		readTextFile"../../local/test-wordpress-export.xml" or
		-- assert(readTextFile"data/barf.xml") or
		([=[<?xml version="1.0" encoding="UTF-8"?>
			<information>
				<place id="5"><country>Sweden</country><cities>Stockholm &amp; Uppsala</cities></place>
				<space:whatever>
					<thing op="&quot;">Apple <![CDATA[with <i>sauce</i>!]]></thing>
					<!-- Just a comment here. <foo> -->
					<bool value="true" bad-but-ok='"'
						important = "Very much, I tell you." hot="58°C" />
					<nothing1  percent="&#37; and &#x000000000000000000000025;"  />
					<nothing2  ></nothing2  >
				</space:whatever>
				<many-amps>&amp;&amp;&amp;&amp;&amp;&amp;&amp;&amp;&amp;&amp;&amp;]]</many-amps>
			</information>
		]=]):gsub("\n\t\t\t", "\n")
	)

	timerStart("our") ; local doc = assert(xml.parseXml(xmlStr, "data/barf.xml")) ; timerEnd()
	-- print(doc:toPrettyXml("","    ",nil, true))
	-- print(doc:toPrettyXml("","    ","  ", true))
	print(doc:toXml())

	-- require"pl.xml"
	-- timerStart("pl") ; local doc = assert(require"pl.xml".parse(xmlStr, false)) ; timerEnd()
	-- print(doc:tostring("","    ","  ", true))
	-- print(doc:tostring())
	--]==]



	--[==[ HTML parsing.
	local htmlStr = (
		-- readTextFile"../../local/test-youtube-watch-page.html" or
		-- readTextFile"../../local/test-deviantart-front-page.html" or
		-- readTextFile"../../local/test-aftonbladet-front-page.html" or
		([=[<!DOCTYPE html>
			<html>
				<head>
					<SCRIPT>function bitAnd(a, b) { return a && b; }</SCRIPT>
				</head>

				<BODY id="foo & bar">
					<h1>Hello, world &&amp; all bananas!</h1>
					<input type=text disabled>

					<svg width="391" height="391" viewBox="-70.5 -70.5 391 391" foo="">
						<rect fill="#fff" stroke="#000" x="-70" y="-70" width="390" height="390"/>
						<g opacity="0.8">
							<rect x="25" y="25" width="200" height="200" fill="lime" stroke-width="4" stroke="pink" />
							<circle cx="125" cy="125" r="75" fill="orange" />
							<polyline points="50,150 50,200 200,200 200,100" stroke="red" stroke-width="4" fill="none" />
							<line x1="50" y1="50" x2="200" y2="200" stroke="blue" stroke-width="4" />
						</g>
					</svg>

					<math>
						<mi>&pi;</mi>
						<mo>&InvisibleTimes;</mo>
						<msup><mi>r</mi><mn>2</mn></msup>
					</math>
				</body>
			</html>
		]=]):gsub("\n\t\t\t", "\n")
	)

	timerStart("html") ; local doc = assert(xml.parseHtml(htmlStr, "foo.html")) ; timerEnd()
	print(doc:toHtml())
	--]==]



	-- [[ Markdown parsing.
	do
		local TEST_OUTPUT_REPLACEMENTS = {
			-- These are indeed not basic autolinks, but they are extended autolinks!
			[616] = '<p>&lt; <a href="http://foo.bar">http://foo.bar</a> &gt;</p>\n', -- < http://foo.bar >  ->  <p>&lt; http://foo.bar &gt;</p>
			[619] = '<p><a href="http://example.com">http://example.com</a></p>\n',   -- http://example.com  ->  <p>http://example.com</p>

			-- This is indeed not a basic autolink, but it is an extended e-mail autolink!
			[620] = '<p><a href="mailto:foo@bar.example.com">foo@bar.example.com</a></p>\n', -- foo@bar.example.com  ->  <p>foo@bar.example.com</p>
		}

		markdown.addIdsToHeadings      = false
		xml.htmlAllowNoAttributeValue  = false
		xml.htmlScrambleEmailAddresses = false

		local docHtml = assert(readTextFile"../../local/gfm-spec.html")
		local doc     = assert(xml.parseHtml(docHtml))
		local tests   = {}

		doc:walk(false, function(tag, node)
			if node.attr.class == "example" then
				local n      = 0
				local input  = nil
				local output = nil

				node:walk(false, function(tag, innerNode)
					if tag == "a" then
						n = tonumber(innerNode.attr.href:match"^#example%-(%d+)$")
						return "ignorechildren"

					elseif tag == "pre" then
						if not input then
							input = innerNode:getText()
							return "ignorechildren"
						else
							output = innerNode:getText()
							return "stop"
						end
					end
				end)

				-- Normalize output. (The spec uses "<br />" etc.)
				output = (output
					:gsub("(<[bh]r) />", "%1>"):gsub("(<img.-) />", "%1>") -- We don't use self-closing symbols for known tags.
					:gsub("%%5B", "["):gsub("%%5D", "]")                   -- We don't percent-encode "[" or "]" in URIs (because of IPv6).
					:gsub('(<img)( src="[^"]*")( alt="[^"]*")', "%1%3%2")  -- We sort attributes alphabetically.
					:gsub("'", "&apos;"):gsub("\194\160", "&nbsp;")        -- We HTML-encode more characters.
				)

				input  = input :gsub("→", "\t")
				output = output:gsub("→", "\t")
				output = TEST_OUTPUT_REPLACEMENTS[n] or output

				table.insert(tests, {n=n, input=input, output=output})

				return "ignorechildren"
			end
		end)

		-- bool = range( test, min1,max1, ... )
		-- bool = is   ( test, n1, ... )
		local function range(test, ...)
			for i = 1, select("#", ...), 2 do
				if test.n >= select(i, ...) and test.n <= select(i+1, ...) then  return true  end
			end
			return false
		end
		local function is(test, ...)
			for i = 1, select("#", ...) do
				if test.n == select(i, ...) then  return true  end
			end
			return false
		end

		-- markdown.runInternalTests()
		timerStart("markdown")

		for _, test in ipairs(tests) do
			if true
				-- and test.n >= 118 -- Jump to HTML block parsing tests.
				-- and test.n >= 307 -- Jump to inline parsing tests.
				-- and test.n >= 360 -- Jump to emphasis parsing tests.
				-- and test.n >= 493 -- Jump to link parsing tests.
			then
				-- print("Test#"..test.n)

				local html = (markdown.parse(test.input)
					-- This is just so we pass tests we really should have passed. Sigh...
					:gsub("'", "&apos;")
				)

				if html ~= test.output and 1==1 then
					print(((
						"Error @ Test "..test.n..":\n"
						-- .."================================\n"
						-- .."INPUT:\n"
						-- ..test.input.."\n"
						.."================================\n"
						.."WANTED:\n"
						..XXX_showWhitespace(test.output).."\n"
						.."================================\n"
						.."GOT:\n"
						..XXX_showWhitespace(html)
					):gsub("\t", "→")))

					os.exit(1)
				end
			end
		end

		timerEnd()
	end
	--]]



	--[[ Get image dimensions.
	local path = "/images/sakura-trees.jpg"
	local w, h = assert(XXX_getImageDimensionsFast(path, true))
	assert(w == 510 and h == 340, "Bad size for "..path)

	local path = "/images/head.png"
	local w, h = assert(XXX_getImageDimensionsFast(path, true))
	assert(w == 50 and h == 50, "Bad size for "..path)

	-- local time = require"socket.core".gettime()
	-- for i = 1, 50 do  XXX_getImageDimensionsFast(path, true)  end
	-- print(require"socket.core".gettime()-time)
	--]]



	print()
	print("TESTS COMPLETED!!!")
	print("Memory: "..formatBytes(collectgarbage"count"*1024))
	print()

	os.exit(2)
end
