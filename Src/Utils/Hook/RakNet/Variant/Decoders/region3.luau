--// Constants \\--
local REGION3_TYPE = 0x2A
local REGION3INT16_TYPE = 0x2B

local DecoderModule = {
	Type = { REGION3_TYPE, REGION3INT16_TYPE },
}

local Router = {
	[REGION3_TYPE] = function(data: buffer, offset: number)
		local x0 = buffer.readf32(data, offset)
		local y0 = buffer.readf32(data, offset + 4)
		local z0 = buffer.readf32(data, offset + 8)
		local x1 = buffer.readf32(data, offset + 12)
		local y1 = buffer.readf32(data, offset + 16)
		local z1 = buffer.readf32(data, offset + 20)
		return {
			Result = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x1, y1, z1)),
			Offset = offset + 24,
		}
	end,

	[REGION3INT16_TYPE] = function(data: buffer, offset: number)
		local x0 = buffer.readi16(data, offset)
		local y0 = buffer.readi16(data, offset + 2)
		local z0 = buffer.readi16(data, offset + 4)
		local x1 = buffer.readi16(data, offset + 6)
		local y1 = buffer.readi16(data, offset + 8)
		local z1 = buffer.readi16(data, offset + 10)
		return {
			Result = Region3int16.new(Vector3int16.new(x0, y0, z0), Vector3int16.new(x1, y1, z1)),
			Offset = offset + 12,
		}
	end,
}

function DecoderModule.Parse(data: buffer, offset: number, t: number, _parser: any, _depth: number)
	return Router[t](data, offset)
end

return DecoderModule
