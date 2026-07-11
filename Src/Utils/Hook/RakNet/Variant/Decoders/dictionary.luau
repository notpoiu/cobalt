--// Imports \\--
local Codec = require(script.Parent.Parent.Parent.Codec)

--// Constants \\--
local DICTIONARY_TYPE = 0x1F
local MAP_TYPE = 0x20

local MAX_DEPTH = 4
local MAX_COUNT = 64

local DecoderModule = {
	Type = { DICTIONARY_TYPE, MAP_TYPE },
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, parser: any, depth: number)
	if depth >= MAX_DEPTH then
		return { Result = {}, Offset = offset }
	end

	local length = buffer.len(data)
	local count, nextOffset = Codec.LEB128(data, offset)
	if count > MAX_COUNT then
		return { Result = {}, Offset = -1 }
	end

	local dict = {}
	offset = nextOffset
	for _ = 1, count do
		local keyLen, keyOffset = Codec.LEB128(data, offset)
		if keyOffset + keyLen > length then
			return { Result = dict, Offset = -1 }
		end

		local key = buffer.readstring(data, keyOffset, keyLen)
		local parsed = parser:Parse(keyOffset + keyLen, depth + 1)
		if parsed.Offset < 0 then
			return { Result = dict, Offset = -1 }
		end

		dict[key] = parsed.Result
		offset = parsed.Offset
	end

	return {
		Result = dict,
		Offset = offset,
	}
end

return DecoderModule
