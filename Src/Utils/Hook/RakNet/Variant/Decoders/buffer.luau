--// Imports \\--
local Codec = require(script.Parent.Parent.Parent.Codec)

local DecoderModule = {
	Type = 0x38,
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	-- u8(flags/reserved) + LEB128(len) + bytes
	offset += 1

	local length, newOffset = Codec.LEB128(data, offset)
	local result = buffer.create(length)

	buffer.copy(result, 0, data, newOffset, length)

	return {
		Result = result,
		Offset = newOffset + length,
	}
end

return DecoderModule
