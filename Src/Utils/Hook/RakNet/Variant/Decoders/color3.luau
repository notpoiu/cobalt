--// Constants \\--
local COLOR3_TYPE = 0x13
local COLOR3UINT8_TYPE = 0x14

local DecoderModule = {
	Type = { COLOR3_TYPE, COLOR3UINT8_TYPE },
}

local Router = {
	[COLOR3_TYPE] = function(data: buffer, offset: number)
		local r = buffer.readf32(data, offset)
		local g = buffer.readf32(data, offset + 4)
		local b = buffer.readf32(data, offset + 8)
		return {
			Result = Color3.new(r, g, b),
			Offset = offset + 12,
		}
	end,

	[COLOR3UINT8_TYPE] = function(data: buffer, offset: number)
		local r = buffer.readu8(data, offset)
		local g = buffer.readu8(data, offset + 1)
		local b = buffer.readu8(data, offset + 2)
		return {
			Result = Color3.fromRGB(r, g, b),
			Offset = offset + 3,
		}
	end,
}

function DecoderModule.Parse(data: buffer, offset: number, t: number, _parser: any, _depth: number)
	return Router[t](data, offset)
end

return DecoderModule
