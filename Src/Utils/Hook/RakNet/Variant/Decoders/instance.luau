--// Imports \\--
local RakNet = script:FindFirstAncestor("RakNet")

local Codec = require(RakNet.Codec)
local Lookup = require(RakNet.Lookup)

--// Constants \\--
local INSTANCE_TYPE = 0x06
local INSTANCE_REF_TYPE = 0x1C
local INSTANCE_ALT_TYPE = 0x2F

local DecoderModule = {
	Type = { INSTANCE_TYPE, INSTANCE_REF_TYPE, INSTANCE_ALT_TYPE },
}

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local ref, newOffset = Codec.ReadInstanceRef(data, offset)
	if ref.is_null then
		return {
			Result = nil,
			Offset = newOffset,
		}
	end

	return {
		Result = Lookup.Instance.ByRef(ref),
		Offset = newOffset,
	}
end

return DecoderModule
