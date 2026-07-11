local DecoderModule = {
	Type = 0x12,
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local number = buffer.readu16(data, offset)
	return {
		Result = BrickColor.new(number),
		Offset = offset + 2,
	}
end

return DecoderModule
