local Codec = require(script.Parent.Codec)

local LookupModule = {
	Instance = {
		Lookup = {},
	},
}

local GetInstanceIdBrokenExecutors = {
    ["Synapse Z"] = true,
}

local GetInstanceByID = (
	not GetInstanceIdBrokenExecutors[wax.shared.ExecutorName] and
	(raknet and raknet.get_instance_by_id)
)

local function IsSupportedRemote(instance: Instance): boolean
	return instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") or instance:IsA("UnreliableRemoteEvent")
end

local function IndexInstance(instance: Instance)
	if not IsSupportedRemote(instance) then
		return
	end

	local Success, InstanceID = pcall(instance.GetDebugId, instance, math.huge)
	if not Success then
		return
	end

	local ID = tonumber(InstanceID)
	if not ID then
		return
	end

	LookupModule.Instance.Lookup[ID] = cloneref(instance)
end

local function UnindexInstance(instance: Instance)
	if not IsSupportedRemote(instance) then
		return
	end

	local Success, InstanceID = pcall(instance.GetDebugId, instance, math.huge)
	if not Success then
		return
	end

	local ID = tonumber(InstanceID)
	if not ID then
		return
	end

	LookupModule.Instance.Lookup[ID] = nil
end

function LookupModule.Instance.ByRef(ref: Codec.InstanceRef): Instance?
	if ref.is_null then
		return nil
	end

	if GetInstanceByID then
		return GetInstanceByID(ref.peer_id, ref.instance_id)
	end

	return LookupModule.Instance.Lookup[ref.instance_id]
end

function LookupModule.Instance.Build()
	if GetInstanceByID then
		return
	end

	for _, category in { game:GetDescendants(), getnilinstances and getnilinstances() } do
		for _, instance in category do
			IndexInstance(instance)
		end
	end

	LookupModule.DescendantAdded = wax.shared.Connect(game.DescendantAdded:Connect(IndexInstance))
	LookupModule.DescendantRemoving = wax.shared.Connect(game.DescendantRemoving:Connect(UnindexInstance))
end

function LookupModule.Instance.Destroy()
	if GetInstanceByID then
		return
	end

	--// Connections \\--
	if LookupModule.DescendantAdded then
		wax.shared.Disconnect(LookupModule.DescendantAdded)
		LookupModule.DescendantAdded = nil
	end

	if LookupModule.DescendantRemoving then
		wax.shared.Disconnect(LookupModule.DescendantRemoving)
		LookupModule.DescendantRemoving = nil
	end

	--// Lookup \\--
	table.clear(LookupModule.Instance.Lookup)
end

return LookupModule
