local DecoderModule = {
	Type = 0x29,
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local hdr = buffer.readu8(data, offset)
	offset += 1

	local isCustom = bit32.band(hdr, 0x01) ~= 0
	local hasAA = bit32.band(hdr, 0x02) ~= 0

	if not isCustom then
		-- Stand-in: no material id on wire for default.
		return {
			Result = PhysicalProperties.new(Enum.Material.Plastic),
			Offset = offset,
		}
	end

	local density = buffer.readf32(data, offset)
	local friction = buffer.readf32(data, offset + 4)
	local elasticity = buffer.readf32(data, offset + 8)
	local frictionWeight = buffer.readf32(data, offset + 12)
	local elasticityWeight = buffer.readf32(data, offset + 16)
	offset += 20

	local acousticAbsorption = 1
	if hasAA then
		acousticAbsorption = buffer.readf32(data, offset)
		offset += 4
	end

	return {
		Result = PhysicalProperties.new(
			density,
			friction,
			elasticity,
			frictionWeight,
			elasticityWeight,
			acousticAbsorption
		),
		Offset = offset,
	}
end

return DecoderModule
