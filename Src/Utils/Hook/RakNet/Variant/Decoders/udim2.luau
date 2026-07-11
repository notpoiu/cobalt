local DecoderModule = {
	Type = 0x0E,
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local xs = buffer.readf32(data, offset)
	local xo = buffer.readi32(data, offset + 4)
	local ys = buffer.readf32(data, offset + 8)
	local yo = buffer.readi32(data, offset + 12)
	return {
		Result = UDim2.new(xs, xo, ys, yo),
		Offset = offset + 16,
	}
end

return DecoderModule
