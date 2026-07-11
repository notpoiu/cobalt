local DecoderModule = {
	Type = 0x0F,
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local ox = buffer.readf32(data, offset)
	local oy = buffer.readf32(data, offset + 4)
	local oz = buffer.readf32(data, offset + 8)
	local dx = buffer.readf32(data, offset + 12)
	local dy = buffer.readf32(data, offset + 16)
	local dz = buffer.readf32(data, offset + 20)
	return {
		Result = Ray.new(Vector3.new(ox, oy, oz), Vector3.new(dx, dy, dz)),
		Offset = offset + 24,
	}
end

return DecoderModule
