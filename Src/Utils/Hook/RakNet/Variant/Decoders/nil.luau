local NIL_TYPE = 0x00
local NIL_ALT_TYPE = 0x03

local DecoderModule = {
	Type = { NIL_TYPE, NIL_ALT_TYPE },
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	return {
		Result = nil,
		Offset = offset,
	}
end

return DecoderModule
