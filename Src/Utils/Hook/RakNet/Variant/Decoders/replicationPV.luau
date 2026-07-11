local Codec = require(script.Parent.Parent.Parent.Codec)

local DecoderModule = {
	Type = 0x39,
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local flags = buffer.readu8(data, offset)
	offset += 1

	local result = {
		flags = flags,
		position = nil :: Vector3?,
		rotationId = bit32.band(flags, 0x1F),
		rotation = nil :: CFrame?,
		velocity = nil :: Vector3?,
		angularVelocity = nil :: Vector3?,
	}

	if flags >= 0x80 then
		local px = buffer.readf32(data, offset)
		local py = buffer.readf32(data, offset + 4)
		local pz = buffer.readf32(data, offset + 8)
		result.position = Vector3.new(px, py, pz)
		offset += 12
	end

	if result.rotationId == 0 then
		local qx, qy, qz, qw
		qx, qy, qz, qw, offset = Codec.ReadCompressedRotation(data, offset)
		result.rotation = CFrame.new(0, 0, 0, qx, qy, qz, qw)
	end

	if bit32.band(flags, 0x40) == 0 then
		local vx = buffer.readf32(data, offset)
		local vy = buffer.readf32(data, offset + 4)
		local vz = buffer.readf32(data, offset + 8)
		result.velocity = Vector3.new(vx, vy, vz)
		offset += 12
	end

	if bit32.band(flags, 0x20) == 0 then
		local ax = buffer.readf32(data, offset)
		local ay = buffer.readf32(data, offset + 4)
		local az = buffer.readf32(data, offset + 8)
		result.angularVelocity = Vector3.new(ax, ay, az)
		offset += 12
	end

	return {
		Result = result,
		Offset = offset,
	}
end

return DecoderModule
