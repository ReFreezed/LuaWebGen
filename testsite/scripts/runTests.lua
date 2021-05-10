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
	timerStart("our") ; xmlTests(xml)             ; timerEnd()
	-- timerStart("pl")  ; xmlTests(require"pl.xml") ; timerEnd()
	--]]

	--[==[ XML parsing.
	local xmlStr = (
		readTextFile"../local/wordpress-export.xml" or
		-- assert(readTextFile"data/barf.xml") or
		[=[<?xml version="1.0" encoding="UTF-8"?>
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
		]=]
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
	local htmlStr = [[<!DOCTYPE html>
		<html>
			<head>
				<script>function bitAnd(a, b) { return a && b; }</script>
			</head>
			<body>
				<h1>Hello, world &amp; all bananas!</h1>
			</body>
		</html>
	]]

	timerStart("html") ; local doc = assert(xml.parseHtml(htmlStr, "foo.html")) ; timerEnd()
	print(doc:toHtml())
	--]==]

	print()
	print("TESTS COMPLETED!!!")
	print()
	os.exit(1)
end
