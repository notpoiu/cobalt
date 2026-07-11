--// Imports \\--
local Codec = require(script.Parent.Parent.Parent.Codec)

--// Constants \\--
local FONT31_TYPE = 0x31
local FONT36_TYPE = 0x36

local DecoderModule = {
	Type = { FONT31_TYPE, FONT36_TYPE },
}

local function parseFont36(data: buffer, offset: number)
	local weight = buffer.readu16(data, offset)
	local style = buffer.readu8(data, offset + 2)
	offset += 3

	local nameLen = buffer.readu32(data, offset)
	offset += 4
	local name = buffer.readstring(data, offset, nameLen)
	offset += nameLen

	local fbLen = buffer.readu32(data, offset)
	offset += 4
	-- CachedFaceId is on the wire (often empty); Font.new only takes family.
	offset += fbLen

	local fontStyle = if style == 1 then Enum.FontStyle.Italic else Enum.FontStyle.Normal
	local fontWeight = Enum.FontWeight.Regular
	for _, item in Enum.FontWeight:GetEnumItems() do
		if item.Value == weight then
			fontWeight = item
			break
		end
	end

	return {
		Result = Font.new(name, fontWeight, fontStyle),
		Offset = offset,
	}
end

-- Speculative: IDA schema lists a string/id font encoding at 0x31.
-- Unobserved on remotes for Font values.
local function parseFont31(data: buffer, offset: number)
	local hdr = buffer.readu8(data, offset)
	offset += 1

	if hdr == 0xFF then
		local id, newOffset = Codec.LEB128(data, offset)
		return {
			Result = { fontId = id + 127 },
			Offset = newOffset,
		}
	elseif bit32.band(hdr, 0x80) ~= 0 then
		return {
			Result = { fontId = bit32.band(hdr, 0x7F) + 127 },
			Offset = offset,
		}
	elseif hdr == 0x7F then
		local nameLen, nameOffset = Codec.LEB128(data, offset)
		local name = buffer.readstring(data, nameOffset, nameLen)
		return {
			Result = Font.new(name),
			Offset = nameOffset + nameLen,
		}
	else
		local name = buffer.readstring(data, offset, hdr)
		return {
			Result = Font.new(name),
			Offset = offset + hdr,
		}
	end
end

local Router = {
	[FONT31_TYPE] = parseFont31,
	[FONT36_TYPE] = parseFont36,
}

function DecoderModule.Parse(data: buffer, offset: number, t: number, _parser: any, _depth: number)
	return Router[t](data, offset)
end

return DecoderModule
