local DecoderModule = {
	Type = 0x35,
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local x = buffer.readf32(data, offset)
	local y = buffer.readf32(data, offset + 4)
	local z = buffer.readf32(data, offset + 8)
	local action = buffer.readu8(data, offset + 12)
	offset += 13

	local labelLen = buffer.readu32(data, offset)
	offset += 4
	local label = buffer.readstring(data, offset, labelLen)
	offset += labelLen

	local actionEnum = Enum.PathWaypointAction.Walk
	for _, item in Enum.PathWaypointAction:GetEnumItems() do
		if item.Value == action then
			actionEnum = item
			break
		end
	end

	return {
		Result = PathWaypoint.new(Vector3.new(x, y, z), actionEnum, label),
		Offset = offset,
	}
end

return DecoderModule
