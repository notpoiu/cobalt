local AXIS_VALUES = {
	Enum.Axis.X,
	Enum.Axis.Y,
	Enum.Axis.Z,
}

local DecoderModule = {
	Type = 0x11,
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local mask = buffer.readu32(data, offset)
	local axes = {}
	for i, axis in AXIS_VALUES do
		if bit32.band(mask, bit32.lshift(1, i - 1)) ~= 0 then
			table.insert(axes, axis)
		end
	end
	return {
		Result = Axes.new(table.unpack(axes)),
		Offset = offset + 4,
	}
end

return DecoderModule
