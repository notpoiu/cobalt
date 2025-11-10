local Log = {}
Log.__index = Log

function Log.new(Instance, Type, Method, Index, CallingScript)
	local NewLog = setmetatable({
		Instance = Instance,
		Type = Type,
		Method = Method,
		Index = Index,
		Calls = {},
		GameCalls = {},
		Ignored = false,
		Blocked = false,
		Button = nil,
	}, Log)

	return NewLog
end

function DeepClone(orig, copies)
	copies = copies or {}

	if typeof(orig) == "Instance" then
		return cloneref(orig)
	elseif typeof(orig) == "userdata" then
		if getmetatable(orig) then
			return newproxy(true)
		else
			return newproxy()
		end
	elseif typeof(orig) == "function" then
		if clonefunction then
			return clonefunction(orig)
		end

		return orig
	elseif type(orig) ~= "table" then
		return orig
	elseif copies[orig] then
		return copies[orig]
	end

	local copy = {}
	copies[orig] = copy
	for k, v in pairs(orig) do
		copy[DeepClone(k, copies)] = DeepClone(v, copies)
	end
	return copy
end

function Log:Call(RawInfo)
	local Info = DeepClone(RawInfo)
	local Index = #self.Calls + 1
	self.Calls[Index] = Info
	if not Info.IsExecutor then
		table.insert(self.GameCalls, Index)
	end

	if wax.shared.Communicator then
		wax.shared.Communicator.Fire(wax.shared.Communicator, self.Instance, self.Type, #self.Calls)
	end
end

function Log:Ignore()
	if wax.shared.ActorCommunicator then
		pcall(function()
			wax.shared.ActorCommunicator:Fire("MainIgnore", self.Instance, self.Type)
		end)
	end

	self.Ignored = not self.Ignored
end

local ClassesConnectionsToggle = {
	RemoteEvent = "OnClientEvent",
	UnreliableRemoteEvent = "OnClientEvent",
	BindableEvent = "Event",
}

function Log:SetConnectionsEnabled(enabled: boolean)
	if not self.Instance or not ClassesConnectionsToggle[self.Instance.ClassName] then
		return
	end

	local ConnectionName = ClassesConnectionsToggle[self.Instance.ClassName]
	if self.Type ~= "Incoming" or not ConnectionName then
		return
	end

	for _, Connection in pairs(getconnections(self.Instance[ConnectionName])) do
		if enabled then
			Connection:Enable()
		else
			Connection:Disable()
		end
	end
end

function Log:Block()
	if wax.shared.ActorCommunicator then
		pcall(function()
			wax.shared.ActorCommunicator:Fire("MainBlock", self.Instance, self.Type)
		end)
	end

	self.Blocked = not self.Blocked
	Log:SetConnectionsEnabled(not self.Blocked)
end

function Log:SetButton(Instance, Name, Calls)
	self.Button = {
		Instance = Instance,
		Name = Name,
		Calls = Calls,
	}
end

return Log
