local FACE_NORMALS = {
	Enum.NormalId.Right,
	Enum.NormalId.Top,
	Enum.NormalId.Back,
	Enum.NormalId.Left,
	Enum.NormalId.Bottom,
	Enum.NormalId.Front,
}

local DecoderModule = {
	Type = 0x10,
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local mask = buffer.readu32(data, offset)
	local faces = {}
	for i, normal in FACE_NORMALS do
		if bit32.band(mask, bit32.lshift(1, i - 1)) ~= 0 then
			table.insert(faces, normal)
		end
	end
	return {
		Result = Faces.new(table.unpack(faces)),
		Offset = offset + 4,
	}
end

return DecoderModule
