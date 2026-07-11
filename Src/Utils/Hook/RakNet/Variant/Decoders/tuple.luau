--// Imports \\--
local Codec = require(script.Parent.Parent.Parent.Codec)

--// Constants \\--
local TUPLE_TYPE = 0x1D
local ARRAY_TYPE = 0x1E

local MAX_DEPTH = 4
local MAX_COUNT = 64

local DecoderModule = {
	Type = { TUPLE_TYPE, ARRAY_TYPE },
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, parser: any, depth: number)
	if depth >= MAX_DEPTH then
		return { Result = {}, Offset = offset }
	end

	local count, nextOffset = Codec.LEB128(data, offset)
	if count > MAX_COUNT then
		return { Result = {}, Offset = -1 }
	end

	local values = table.create(count)
	offset = nextOffset
	for i = 1, count do
		local parsed = parser:Parse(offset, depth + 1)
		if parsed.Offset < 0 then
			return { Result = values, Offset = -1 }
		end
		values[i] = parsed.Result
		offset = parsed.Offset
	end

	return {
		Result = values,
		Offset = offset,
	}
end

return DecoderModule
