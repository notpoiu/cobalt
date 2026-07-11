--// Constants \\--
local COLOR_SEQUENCE_TYPE = 0x26
local COLOR_SEQUENCE_KEYPOINT_TYPE = 0x27

local DecoderModule = {
	Type = { COLOR_SEQUENCE_TYPE, COLOR_SEQUENCE_KEYPOINT_TYPE },
}

local function readKeypoint(data: buffer, offset: number): (ColorSequenceKeypoint, number)
	local time = buffer.readf32(data, offset)
	local r = buffer.readf32(data, offset + 4)
	local g = buffer.readf32(data, offset + 8)
	local b = buffer.readf32(data, offset + 12)
	-- envelope at +16 is present on wire but unused by ColorSequenceKeypoint.new
	return ColorSequenceKeypoint.new(time, Color3.new(r, g, b)), offset + 20
end

local Router = {
	[COLOR_SEQUENCE_TYPE] = function(data: buffer, offset: number)
		local count = buffer.readu32(data, offset)
		offset += 4
		if count > 100 then
			return { Result = ColorSequence.new(Color3.new()), Offset = -1 }
		end

		local keypoints = table.create(count)
		for i = 1, count do
			local kp
			kp, offset = readKeypoint(data, offset)
			keypoints[i] = kp
		end

		if count == 0 then
			return { Result = ColorSequence.new(Color3.new()), Offset = offset }
		end

		return {
			Result = ColorSequence.new(keypoints),
			Offset = offset,
		}
	end,

	[COLOR_SEQUENCE_KEYPOINT_TYPE] = function(data: buffer, offset: number)
		local kp, newOffset = readKeypoint(data, offset)
		return {
			Result = kp,
			Offset = newOffset,
		}
	end,
}

function DecoderModule.Parse(data: buffer, offset: number, t: number, _parser: any, _depth: number)
	return Router[t](data, offset)
end

return DecoderModule
