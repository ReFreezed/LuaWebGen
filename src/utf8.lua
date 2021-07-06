--[[============================================================
--=
--=  UTF-8 module
--=
--=-------------------------------------------------------------
--=
--=  LuaWebGen - static website generator in Lua!
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See LICENSE.txt)
--=
--==============================================================

	CHARACTER_PATTERN

	codepointToString
	getCharacterLength, getCodepointAndLength
	getLength
	getStartOfCharacter

--============================================================]]

local utf8 = {
	CHARACTER_PATTERN = "[%z\1-\127\194-\244][\128-\191]*", -- @Doc
}

local stringByte  = string.byte
local stringChar  = string.char
local tableInsert = table.insert



-- string = codepointToString( codepoint )
-- codepointToString( codepoint, outputBuffer )
function utf8.codepointToString(cp, buffer)
	if cp < 0 or cp > 0x10ffff then
		errorf("Codepoint %d is outside the valid range (0..10FFFF).", cp)
	end

	if cp >= 128 then
		-- void
	elseif buffer then
		tableInsert(buffer, stringChar(cp))
		return
	else
		return stringChar(cp)
	end

	local suffix = cp % 64
	local c4     = 128 + suffix
	cp           = (cp - suffix) / 64

	if cp >= 32 then
		-- void
	elseif buffer then
		tableInsert(buffer, stringChar(192+cp))
		tableInsert(buffer, stringChar(c4))
		return
	else
		return stringChar(192+cp, c4) -- @Speed @Memory
	end

	suffix   = cp % 64
	local c3 = 128 + suffix
	cp       = (cp - suffix) / 64

	if cp >= 16 then
		-- void
	elseif buffer then
		tableInsert(buffer, stringChar(224+cp))
		tableInsert(buffer, stringChar(c3))
		tableInsert(buffer, stringChar(c4))
		return
	else
		return stringChar(224+cp, c3, c4) -- @Speed @Memory
	end

	suffix = cp % 64
	cp     = (cp - suffix) / 64

	if buffer then
		tableInsert(buffer, stringChar(240+cp))
		tableInsert(buffer, stringChar(128+suffix))
		tableInsert(buffer, stringChar(c3))
		tableInsert(buffer, stringChar(c4))
		return
	else
		return stringChar(240+cp, 128+suffix, c3, c4) -- @Speed @Memory
	end
end



-- length = getCharacterLength( string [, position=1 ] )
-- Returns nil if the string is invalid at the position.
function utf8.getCharacterLength(s, pos)
	pos                  = pos or 1
	local b1, b2, b3, b4 = stringByte(s, pos, pos+3)

	if b1 <= 127 then
		return 1

	elseif b1 >= 194 and b1 <= 223 then
		if not b2               then  return nil  end -- UTF-8 string terminated early.
		if b2 < 128 or b2 > 191 then  return nil  end -- Invalid UTF-8 character.
		return 2

	elseif b1 >= 224 and b1 <= 239 then
		if not b3                               then  return nil  end -- UTF-8 string terminated early.
		if b1 == 224 and (b2 < 160 or b2 > 191) then  return nil  end -- Invalid UTF-8 character.
		if b1 == 237 and (b2 < 128 or b2 > 159) then  return nil  end -- Invalid UTF-8 character.
		if               (b2 < 128 or b2 > 191) then  return nil  end -- Invalid UTF-8 character.
		if               (b3 < 128 or b3 > 191) then  return nil  end -- Invalid UTF-8 character.
		return 3

	elseif b1 >= 240 and b1 <= 244 then
		if not b4                               then  return nil  end -- UTF-8 string terminated early.
		if b1 == 240 and (b2 < 144 or b2 > 191) then  return nil  end -- Invalid UTF-8 character.
		if b1 == 244 and (b2 < 128 or b2 > 143) then  return nil  end -- Invalid UTF-8 character.
		if               (b2 < 128 or b2 > 191) then  return nil  end -- Invalid UTF-8 character.
		if               (b3 < 128 or b3 > 191) then  return nil  end -- Invalid UTF-8 character.
		if               (b4 < 128 or b4 > 191) then  return nil  end -- Invalid UTF-8 character.
		return 4
	end

	return nil -- Invalid UTF-8 character.
end

-- codepoint, length = getCodepointAndLength( string [, position=1 ] )
-- Returns nil if the string is invalid at the position.
function utf8.getCodepointAndLength(s, pos)
	pos       = pos or 1
	local len = utf8.getCharacterLength(s, pos)
	if not len then  return nil  end

	-- 2^6=64, 2^12=4096, 2^18=262144
	if len == 1 then                                                     return                                       stringByte(s, pos), len  end
	if len == 2 then  local b1, b2         = stringByte(s, pos, pos+1) ; return                                   (b1-192)*64 + (b2-128), len  end
	if len == 3 then  local b1, b2, b3     = stringByte(s, pos, pos+2) ; return                   (b1-224)*4096 + (b2-128)*64 + (b3-128), len  end
	do                local b1, b2, b3, b4 = stringByte(s, pos, pos+3) ; return (b1-240)*262144 + (b2-128)*4096 + (b3-128)*64 + (b4-128), len  end
end



-- length = getLength( string [, startPosition=1 ] )
-- Returns nil and the first error position if the string is invalid.
function utf8.getLength(s, pos)
	pos       = pos or 1
	local len = 0

	while pos <= #s do
		local charLen = utf8.getCharacterLength(s, pos)
		if not charLen then  return nil, pos  end

		len = len + 1
		pos = pos + charLen
	end

	return len
end



-- position = getStartOfCharacter( string, position )
-- Returns nil if the string is invalid at the position.
function utf8.getStartOfCharacter(s, pos)
	for pos = pos, math.max(pos-3, 1), -1 do
		local b = stringByte(s, pos)

		if b <= 127 or (b >= 194 and b <= 244) then
			-- @Robustness: Verify that the following bytes are valid.
			return pos
		end
	end

	return nil
end



return utf8
