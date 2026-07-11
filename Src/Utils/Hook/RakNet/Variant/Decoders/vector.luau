--// Constants \\--
local VECTOR2_TYPE = 0x15
local VECTOR3_TYPE = 0x16
local VECTOR2INT16_TYPE = 0x18
local VECTOR3INT16_TYPE = 0x19

local DecoderModule = {
	Type = { VECTOR2_TYPE, VECTOR3_TYPE, VECTOR2INT16_TYPE, VECTOR3INT16_TYPE },
}

local Router = {
	[VECTOR2_TYPE] = function(data: buffer, offset: number)
		local x = buffer.readf32(data, offset)
		local y = buffer.readf32(data, offset + 4)
		return {
			Result = Vector2.new(x, y),
			Offset = offset + 8,
		}
	end,

	[VECTOR3_TYPE] = function(data: buffer, offset: number)
		local x = buffer.readf32(data, offset)
		local y = buffer.readf32(data, offset + 4)
		local z = buffer.readf32(data, offset + 8)
		return {
			Result = Vector3.new(x, y, z),
			Offset = offset + 12,
		}
	end,

	[VECTOR2INT16_TYPE] = function(data: buffer, offset: number)
		local x = buffer.readi16(data, offset)
		local y = buffer.readi16(data, offset + 2)
		return {
			Result = Vector2int16.new(x, y),
			Offset = offset + 4,
		}
	end,

	[VECTOR3INT16_TYPE] = function(data: buffer, offset: number)
		local x = buffer.readi16(data, offset)
		local y = buffer.readi16(data, offset + 2)
		local z = buffer.readi16(data, offset + 4)
		return {
			Result = Vector3int16.new(x, y, z),
			Offset = offset + 6,
		}
	end,
}

function DecoderModule.Parse(data: buffer, offset: number, t: number, _parser: any, _depth: number)
	return Router[t](data, offset)
end

return DecoderModule
