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

	--[[ XML module tests.
	-- require"pl.xml"
	timerStart("our") ; xmlTests(xml)             ; timerEnd()
	-- timerStart("pl")  ; xmlTests(require"pl.xml") ; timerEnd()
	--]]

	-- [==[ XML parsing.
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
	-- print(xml.toPrettyXml(doc, "","    ",nil, true))
	-- print(xml.toPrettyXml(doc, "","    ","  ", true))
	print(doc)

	-- require"pl.xml"
	-- timerStart("pl") ; local doc = assert(require"pl.xml".parse(xmlStr, false)) ; timerEnd()
	-- print(require"pl.xml".tostring(doc, "","    ","  ", true))
	-- print(doc)
	--]==]

	print()
	print("TESTS COMPLETED!!!")
	print()
	os.exit(1)
end