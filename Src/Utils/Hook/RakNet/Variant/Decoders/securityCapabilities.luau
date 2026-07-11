-- Enum.SecurityCapability.Value is NOT the bit index — engine uses a sparse map.
local BIT_TO_CAPABILITY: { [number]: string } = {
	[0] = "Plugin",
	[1] = "LocalUser",
	[2] = "WritePlayer",
	[3] = "RobloxScript",
	[4] = "RobloxEngine",
	[8] = "RunClientScript",
	[9] = "RunServerScript",
	[11] = "AccessOutsideWrite",
	[15] = "Unassigned",
	[16] = "LoadUnownedAsset", -- AssetRequire alias
	[17] = "LoadString",
	[18] = "ScriptGlobals",
	[19] = "CreateInstances",
	[20] = "Basic",
	[21] = "Audio",
	[22] = "DataStore",
	[23] = "Network",
	[24] = "Physics",
	[25] = "UI",
	[26] = "CSG",
	[27] = "Chat",
	[28] = "Animation",
	[29] = "AvatarAppearance", -- Avatar alias
	[30] = "Input",
	[31] = "Environment",
	[32] = "RemoteEvent",
	[33] = "LegacySound",
	[34] = "Players",
	[35] = "CapabilityControl",
	[36] = "AssetRead",
	[37] = "AssetManagement",
	[38] = "DynamicGeneration",
	[39] = "PlatformAvatarEditing",
	[40] = "AssetCreateUpdate",
	[41] = "Capture",
	[42] = "SensitiveInput",
	[43] = "Monetization",
	[44] = "LoadOwnedAsset",
	[45] = "Social",
	[46] = "ServerCommunication",
	[47] = "Logging",
	[48] = "PromptExternalPurchase",
	[49] = "Groups",
	[50] = "Teleport",
	[51] = "Consequences",
	[52] = "Material",
	[53] = "AvatarBehavior",
	[59] = "RemoteCommand",
	[60] = "InternalTest",
	[61] = "PluginOrOpenCloud",
	[62] = "Assistant",
}

local DecoderModule = {
	Type = 0x37,
}

local function fromBitmask(lo: number, hi: number): SecurityCapabilities
	local caps: { Enum.SecurityCapability } = {}
	for bit = 0, 63 do
		local word = if bit < 32 then lo else hi
		local bitInWord = bit % 32
		if bit32.band(word, bit32.lshift(1, bitInWord)) ~= 0 then
			local name = BIT_TO_CAPABILITY[bit]
			if name then
				local ok, item = pcall(function()
					return (Enum.SecurityCapability :: any)[name]
				end)
				if ok and item then
					table.insert(caps, item)
				end
			end
		end
	end

	if #caps == 0 then
		return SecurityCapabilities.new()
	end
	return SecurityCapabilities.new(table.unpack(caps))
end

function DecoderModule.Parse(data: buffer, offset: number, _t: number, _parser: any, _depth: number)
	local lo = buffer.readu32(data, offset)
	local hi = buffer.readu32(data, offset + 4)
	return {
		Result = fromBitmask(lo, hi),
		Offset = offset + 8,
	}
end

return DecoderModule
