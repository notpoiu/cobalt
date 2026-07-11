--// Constants \\--
local NUMBER_SEQUENCE_TYPE = 0x23
local NUMBER_SEQUENCE_KEYPOINT_TYPE = 0x24

local DecoderModule = {
	Type = { NUMBER_SEQUENCE_TYPE, NUMBER_SEQUENCE_KEYPOINT_TYPE },
}

local function readKeypoint(data: buffer, offset: number): (NumberSequenceKeypoint, number)
	local time = buffer.readf32(data, offset)
	local value = buffer.readf32(data, offset + 4)
	local envelope = buffer.readf32(data, offset + 8)
	return NumberSequenceKeypoint.new(time, value, envelope), offset + 12
end

local Router = {
	[NUMBER_SEQUENCE_TYPE] = function(data: buffer, offset: number)
		local count = buffer.readu32(data, offset)
		offset += 4
		if count > 100 then
			return { Result = NumberSequence.new(0), Offset = -1 }
		end

		local keypoints = table.create(count)
		for i = 1, count do
			local kp
			kp, offset = readKeypoint(data, offset)
			keypoints[i] = kp
		end

		if count == 0 then
			return { Result = NumberSequence.new(0), Offset = offset }
		end

		return {
			Result = NumberSequence.new(keypoints),
			Offset = offset,
		}
	end,

	[NUMBER_SEQUENCE_KEYPOINT_TYPE] = function(data: buffer, offset: number)
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
