local DecoderModule = {
	Type = 0x09,
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	return {
		Result = buffer.readu8(data, offset) ~= 0,
		Offset = offset + 1,
	}
end

return DecoderModule
