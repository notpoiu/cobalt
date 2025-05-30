local ClassesToHook = {
	RemoteEvent = "OnClientEvent",
	RemoteFunction = "OnClientInvoke",
	UnreliableRemoteEvent = "OnClientEvent",
	BindableEvent = "Event",
	BindableFunction = "OnInvoke",
}

local SignalMapping = {}
local HookedFunctions = {}

local function getcallingline()
	for i = 4, 10 do
		local Source, Line = debug.info(i, "sl")
		if not Source then
			break
		end

		if Source == "[C]" then
			continue
		end

		return Line
	end

	return debug.info(4, "l")
end

local function ListenToFunction(Instance, Function, Method)
	if HookedFunctions[Function] then
		return
	end
	HookedFunctions[Function] = true

	wax.shared.Hooks[Function] = wax.shared.Hooking.HookFunction(
		Function,
		wax.shared.newcclosure(function(...)
			if not wax.shared.ShouldIgnore(Instance, getcallingscript()) then
				local Log = wax.shared.Logs.Incoming[Instance]
				if not Log then
					Log = wax.shared.NewLog(Instance, "Incoming", Method, getcallingscript())
				end

				if Log.Blocked then
					return
				elseif not Log.Ignored then
					local Info = {
						Arguments = { ... },
						Time = os.date("%X"),
						Origin = getcallingscript(),
						Function = Function,
						Line = getcallingline(),
						IsExecutor = checkcaller(),
					}
					Log:Call(Info)
					wax.shared.Communicator:Fire(Log.Instance, "Incoming", Info, #Log.Calls)
				end
			end

			return wax.shared.Hooks[Function](...)
		end)
	)
end

local function HandleInstance(Instance: any)
	if not ClassesToHook[Instance.ClassName] or Instance == wax.shared.Communicator then
		return
	end

	local Method = ClassesToHook[Instance.ClassName]

	if Instance.ClassName == "RemoteEvent" or Instance.ClassName == "UnreliableRemoteEvent" then
		for _, Connection in pairs(getconnections(Instance.OnClientEvent)) do
			local Function = Connection.Function
			if typeof(Function) ~= "function" then
				continue
			end

			ListenToFunction(Instance, Function, Method)
		end

		SignalMapping[Instance.OnClientEvent] = Instance
	elseif Instance.ClassName == "BindableEvent" then
		for _, Connection in pairs(getconnections(Instance.Event)) do
			local Function = Connection.Function
			if typeof(Function) ~= "function" then
				continue
			end

			ListenToFunction(Instance, Function, Method)
		end

		SignalMapping[Instance.Event] = Instance
	elseif Instance.ClassName == "RemoteFunction" or Instance.ClassName == "BindableFunction" then
		local Success, Callback = pcall(getcallbackvalue, Instance, Method)
		local IsCallable = (
			typeof(Callback) == "function"
			or wax.shared.getrawmetatable(Callback) ~= nil and typeof(wax.shared.getrawmetatable(Callback)["__call"]) == "function"
			or false
		)

		if not Success or not IsCallable then
			return
		end

		Instance[Method] = function(...)
			if wax.shared.Unloaded or wax.shared.ShouldIgnore(Instance, getcallingscript()) then
				return Callback(...)
			end

			local Log = wax.shared.Logs.Incoming[Instance]
			if not Log then
				Log = wax.shared.NewLog(Instance, "Incoming", Method, getcallingscript())
			end

			if Log.Blocked then
				return
			elseif not Log.Ignored then
				local Info = {
					Arguments = { ... },
					Time = os.date("%X"),
					Origin = getcallingscript(),
					Function = Callback,
					Line = getcallingline(),
					IsExecutor = checkcaller(),
				}
				Log:Call(Info)
				wax.shared.Communicator:Fire(Log.Instance, "Incoming", Info, #Log.Calls)
			end

			return Callback(...)
		end
	end
end

wax.shared.Connect(game.DescendantAdded:Connect(HandleInstance))

-- getinstances() was unreliable and failed to find some instances... ts pmo bro..
for _, Category in pairs({ getnilinstances(), game:GetDescendants() }) do
	for _, Instance in pairs(Category) do
		HandleInstance(Instance)
	end
end

wax.shared.NewIndexHook = wax.shared.Hooking.HookMetaMethod(
	game,
	"__newindex",
	wax.shared.newcclosure(function(self, key, value)
		if typeof(self) ~= "Instance" or not ClassesToHook[self.ClassName] then
			return wax.shared.NewIndexHook(self, key, value)
		end

		if self.ClassName == "RemoteFunction" or self.ClassName == "BindableFunction" then
			local Method = ClassesToHook[self.ClassName]

			local IsCallable = (
				typeof(value) == "function"
				or wax.shared.getrawmetatable(value) ~= nil and typeof(wax.shared.getrawmetatable(value)["__call"]) == "function"
				or false
			)

			if key == Method and IsCallable then
				return wax.shared.NewIndexHook(self, key, function(...)
					if wax.shared.Unloaded or wax.shared.ShouldIgnore(self, getcallingscript()) then
						return value(...)
					end

					local Log = wax.shared.Logs.Incoming[self]
					if not Log then
						Log = wax.shared.NewLog(self, "Incoming", Method, getcallingscript())
					end

					if Log.Blocked then
						return
					elseif not Log.Ignored then
						local Info = {
							Arguments = { ... },
							Time = os.date("%X"),
							Origin = getcallingscript(),
							Function = value,
							Line = getcallingline(),
							IsExecutor = checkcaller(),
						}
						Log:Call(Info)
						wax.shared.Communicator:Fire(Log.Instance, "Incoming", Info, #Log.Calls)
					end

					return value(...)
				end)
			end
		end

		return wax.shared.NewIndexHook(self, key, value)
	end)
)

local ConnectionKeys = {
	"Connect",
	"ConnectParallel",
	"connect",
	"connectParallel",
	"once",
	"Once",
}

local SignalMetatable = wax.shared.getrawmetatable(Instance.new("Part").Touched)
wax.shared.Hooks[SignalMetatable.__index] = wax.shared.Hooking.HookFunction(SignalMetatable.__index, function(self, key)
	if table.find(ConnectionKeys, key) then
		local Instance = SignalMapping[self]
		local Connect = wax.shared.Hooks[SignalMetatable.__index](self, key)

		if not Instance then
			return Connect
		end

		local Method = ClassesToHook[Instance.ClassName]
		wax.shared.Hooks[Connect] = wax.shared.Hooking.HookFunction(
			Connect,
			wax.shared.newcclosure(function(self, callback)
				ListenToFunction(Instance, callback, Method)
				return wax.shared.Hooks[Connect](self, callback)
			end)
		)

		return Connect
	end

	return wax.shared.Hooks[SignalMetatable.__index](self, key)
end)
