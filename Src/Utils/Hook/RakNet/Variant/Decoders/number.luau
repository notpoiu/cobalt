--// Imports \\--
local Codec = require(script.Parent.Parent.Parent.Codec)

--// Constants \\--
local INT_TYPE = 0x0A
local FLOAT_TYPE = 0x0B
local DOUBLE_TYPE = 0x0C
local INT64_TYPE = 0x2C
local UINT_TYPE = 0x22

local DecoderModule = {
	Type = { INT_TYPE, FLOAT_TYPE, DOUBLE_TYPE, INT64_TYPE, UINT_TYPE },
}

local Router = {
	[INT_TYPE] = function(data: buffer, offset: number)
		local n, newOffset = Codec.LEB128(data, offset)
		return {
			Result = Codec.ZzDec(n),
			Offset = newOffset,
		}
	end,

	[FLOAT_TYPE] = function(data: buffer, offset: number)
		return {
			Result = buffer.readf32(data, offset),
			Offset = offset + 4,
		}
	end,

	[DOUBLE_TYPE] = function(data: buffer, offset: number)
		return {
			Result = buffer.readf64(data, offset),
			Offset = offset + 8,
		}
	end,

	[INT64_TYPE] = function(data: buffer, offset: number)
		local n, newOffset = Codec.LEB128(data, offset)
		return {
			Result = Codec.ZzDec(n),
			Offset = newOffset,
		}
	end,

	[UINT_TYPE] = function(data: buffer, offset: number)
		local n, newOffset = Codec.LEB128(data, offset)
		return {
			Result = n,
			Offset = newOffset,
		}
	end,
}

function DecoderModule.Parse(data: buffer, offset: number, t: number, _parser: any, _depth: number)
	return Router[t](data, offset)
end

return DecoderModule
