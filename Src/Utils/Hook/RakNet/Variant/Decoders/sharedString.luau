local DecoderModule = {
	Type = 0x2E,
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	return {
		Result = buffer.readstring(data, offset, 16),
		Offset = offset + 16,
	}
end

return DecoderModule
