--// Imports \\--
local Codec = require(script.Parent.Parent.Parent.Codec)

--// Constants \\--
local STRING_TYPE = 0x02
local BINARY_STRING_TYPE = 0x08

local DecoderModule = {
	Type = { STRING_TYPE, BINARY_STRING_TYPE },
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local length, newOffset = Codec.LEB128(data, offset)
	return {
		Result = buffer.readstring(data, newOffset, length),
		Offset = newOffset + length,
	}
end

return DecoderModule
