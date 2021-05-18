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

	--[[ XML module tests.
	-- require"pl.xml"
	timerStart("our") ; tests.xmlTests(xml)             ; timerEnd()
	-- timerStart("pl")  ; tests.xmlTests(require"pl.xml") ; timerEnd()
	--]]

	--[==[ XML parsing.
	local xmlStr = (
		readTextFile"../local/test-wordpress-export.xml" or
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

	-- [==[ HTML parsing.
	local htmlStr = (
		-- readTextFile"../local/test-youtube-watch-page.html" or
		-- readTextFile"../local/test-deviantart-front-page.html" or
		-- readTextFile"../local/test-aftonbladet-front-page.html" or
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

	print()
	print("TESTS COMPLETED!!!")
	print()
	os.exit(1)
end
