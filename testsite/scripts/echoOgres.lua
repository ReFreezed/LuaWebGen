return function()
	local ogreCount = math.random(3, 9)

	echo(F("The ogres are attacking!\n"))
	echo(F("There are %d of them this time!\n", ogreCount))
end
