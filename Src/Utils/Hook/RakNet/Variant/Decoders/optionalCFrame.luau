--// Imports \\--
local Codec = require(script.Parent.Parent.Parent.Codec)

--// Constants \\--
local OPTIONAL_CFRAME_ALT_TYPE = 0x32
local OPTIONAL_CFRAME_TYPE = 0x33

local DecoderModule = {
	Type = { OPTIONAL_CFRAME_ALT_TYPE, OPTIONAL_CFRAME_TYPE },
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local cf, newOffset = Codec.ReadOptCFrame(data, offset)
	return {
		Result = cf,
		Offset = newOffset,
	}
end

return DecoderModule
