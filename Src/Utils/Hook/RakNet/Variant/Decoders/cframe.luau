--// Imports \\--
local Codec = require(script.Parent.Parent.Parent.Codec)

--// Constants \\--
local CFRAME_V1_TYPE = 0x1A
local CFRAME_TYPE = 0x1B

local DecoderModule = {
	Type = { CFRAME_V1_TYPE, CFRAME_TYPE },
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local cf, newOffset = Codec.ReadCFrameV1(data, offset)
	return {
		Result = cf,
		Offset = newOffset,
	}
end

return DecoderModule
