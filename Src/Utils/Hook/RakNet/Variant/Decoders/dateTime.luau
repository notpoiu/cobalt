--// Imports \\--
local Codec = require(script.Parent.Parent.Parent.Codec)

local DecoderModule = {
	Type = 0x30,
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local ms, newOffset = Codec.ReadUInt64(data, offset)
	return {
		Result = DateTime.fromUnixTimestampMillis(ms),
		Offset = newOffset,
	}
end

return DecoderModule
