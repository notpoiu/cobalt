local ClassesToHook = {
	RemoteEvent = "OnClientEvent",
	RemoteFunction = "OnClientInvoke",
	UnreliableRemoteEvent = "OnClientEvent",
	BindableEvent = "Event",
	BindableFunction = "OnInvoke",
}

type InstancesToHook = RemoteEvent | UnreliableRemoteEvent | RemoteFunction | BindableEvent | BindableFunction
type MethodsToHook = "OnClientEvent" | "OnClientInvoke" | "Event" | "OnInvoke"

local LogConnectionFunctions = {}
local SignalMapping = setmetatable({}, { __mode = "kv" })

local function CreateLookupTable(table)
	local LookupTable = {}
	for _, Method in next, table do
		LookupTable[Method] = true
	end
	return LookupTable
end


--[[
	Individually logs an incoming remote call.

	@param Instance The instance that was called.
	@param Method The method that was called (e.g., "OnClientEvent").
	@param Function The function that was called, if applicable.
	@param Info The information about the call, including arguments and origin. Can be nil.
	@param ... The arguments passed from the server to the client.
	@return boolean Returns true if the call was blocked, false otherwise.
]]
local function LogRemote(
	Instance: InstancesToHook,
	Method: MethodsToHook,
	Function: (...any) -> ...any,
	Info: {
		Arguments: { [number]: any, n: number },
		Origin: Instance,
		Function: (...any) -> ...any,
		Line: number,
		IsExecutor: boolean,
	}
)
	if not wax.shared.ShouldIgnore(Instance, getcallingscript()) and not LogConnectionFunctions[Function] then
		local Log = wax.shared.Logs.Incoming[Instance]
		if not Log then
			Log = wax.shared.NewLog(Instance, "Incoming", Method, getcallingscript())
		end

		if Log.Blocked then
			return true
		elseif not Log.Ignored then
			Log:Call(Info)
		end
	end

	return false
end

--[[
	Creates a function that can be used to pass to `Connect` which will log all the incoming calls. It will additonally add the function to a ignore list (`LogConnectionFunctions`) to prevent unneccessary logging.
	
	@param Instance The instance to log.
	@param Method The method to log (e.g., "OnClientEvent").
	@return function Returns a function that logs all calls to the given instance and method.
]]
local function CreateConnectionFunction(Instance: InstancesToHook, Method: MethodsToHook)
	local ConnectionFunction = function(...)
		for _, Connection in pairs(getconnections((Instance :: any)[Method])) do
			if Connection.ForeignState then
				continue
			end

			local Function = typeof(Connection.Function) == "function" and Connection.Function or nil
			local Thread = Connection.Thread

			local Origin = nil

			if Thread and getscriptfromthread then
				Origin = getscriptfromthread(Thread)
			end

			if not Origin and Function then
				-- ts is unreliable because people could js set the script global to nil
				-- if only debug.getinfo(Function).source or debug.info(Function, "s") returned an Instance...

				local Script = rawget(getfenv(Function), "script")
				if typeof(Script) == "Instance" then
					Origin = Script
				end
			end

			LogRemote(Instance, Method, Function, {
				Arguments = table.pack(...),
				Origin = Origin,
				Function = Function,
				Line = nil,
				IsExecutor = Function and isexecutorclosure(Function) or false,
			})
		end
	end

	LogConnectionFunctions[ConnectionFunction] = true
	return ConnectionFunction
end

--[[
	Creates a function that can be used to pass to callbacks (.OnInvoke & .OnClientInvoke) which will log all the incoming calls.
	
	@param Instance The instance to log.
	@param Method The method to log (e.g., "OnClientEvent").
	@param Function The original callback of the RemoteFunction
	@return function Returns a function that logs all function calls to the given instance and method.
]]
local function CreateCallbackDetour(Instance: InstancesToHook, Method: MethodsToHook, Callback: (...any) -> ...any)
	local Detour = function(...)
		local Origin = nil

		-- May not exist in all executors
		if getscriptfromthread then
			Origin = getscriptfromthread(coroutine.running())
		end

		-- Unreliable method to get script.
		if not Origin then
			local Script = rawget(getfenv(Callback), "script")
			if typeof(Script) == "Instance" then
				Origin = Script
			end
		end

		local FunctionCaller = debug.info(2, "f")
		local IsExecutor = if typeof(FunctionCaller) == "function"
			then isexecutorclosure(FunctionCaller)
			else isexecutorclosure(Callback)

		if
			LogRemote(Instance, Method, Callback, {
				Arguments = table.pack(...),
				Origin = Origin,
				Function = Callback,
				Line = nil,
				IsExecutor = IsExecutor,
			})
		then
			return
		end

		return Callback(...)
	end

	if wax.shared.ExecutorSupport["setstackhidden"].IsWorking then
		setstackhidden(Detour, true)
	end

	return Detour
end

--[[
	Handles setting up logging for the appropriate instances.

	@param Instance The instance to handle.
]]
local function HandleInstance(Instance: any)
	if
		not ClassesToHook[Instance.ClassName]
		or Instance == wax.shared.Communicator
		or Instance == wax.shared.ActorCommunicator
	then
		return
	end

	local Method = ClassesToHook[Instance.ClassName]

	if Instance.ClassName == "RemoteEvent" or Instance.ClassName == "UnreliableRemoteEvent" then
		wax.shared.Connect(Instance.OnClientEvent:Connect(CreateConnectionFunction(Instance, Method)))

		SignalMapping[Instance.OnClientEvent] = Instance
	elseif Instance.ClassName == "BindableEvent" then
		wax.shared.Connect(Instance.Event:Connect(CreateConnectionFunction(Instance, Method)))

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

		Instance[Method] = CreateCallbackDetour(Instance, Method, Callback)
	end
end

wax.shared.Connect(game.DescendantAdded:Connect(HandleInstance))

local CategoryToSearch = { game:QueryDescendants("RemoteEvent, RemoteFunction, UnreliableRemoteEvent, BindableEvent, BindableFunction") }
if wax.shared.ExecutorSupport["getnilinstances"].IsWorking then
	table.insert(CategoryToSearch, getnilinstances())
end

for _, Category in CategoryToSearch do
	for _, Instance in next, Category do
		HandleInstance(Instance)
	end
end

wax.shared.NewIndexHook = wax.shared.Hooking.HookMetaMethod(game, "__newindex", function(...)
	local self, key, value = ...

	if typeof(self) ~= "Instance" or not ClassesToHook[self.ClassName] then
		return wax.shared.NewIndexHook(...)
	end

	if self.ClassName == "RemoteFunction" or self.ClassName == "BindableFunction" then
		local Method = ClassesToHook[self.ClassName]

		local IsCallable = (
			typeof(value) == "function"
			or wax.shared.getrawmetatable(value) ~= nil and typeof(wax.shared.getrawmetatable(value)["__call"]) == "function"
			or false
		)

		if key == Method and IsCallable then
			return wax.shared.NewIndexHook(self, key, CreateCallbackDetour(self :: InstancesToHook, Method, value))
		end
	end

	return wax.shared.NewIndexHook(...)
end)

local ConnectionKeys = CreateLookupTable({
	"Connect",
	"ConnectParallel",
	"connect",
	"connectParallel",
	"once",
	"Once",
})

local SignalMetatable = wax.shared.getrawmetatable(Instance.new("Part").Touched)
wax.shared.Hooks[SignalMetatable.__index] = wax.shared.Hooking.HookFunction(SignalMetatable.__index, function(...)
	local self, key = ...

	if ConnectionKeys[key] then
		local Instance = SignalMapping[self]
		local Connect = wax.shared.Hooks[SignalMetatable.__index](...)

		if not Instance then
			return Connect
		end

		local Method = ClassesToHook[Instance.ClassName]
		wax.shared.Hooks[Connect] = wax.shared.Hooking.HookFunction(Connect, function(...)
			local _self, callback = ...

			local Result = table.pack(wax.shared.Hooks[Connect](...))
			local Log = wax.shared.Logs.Incoming[Instance]

			if Log and Log.Blocked then
				for _, Connection in pairs(getconnections(Instance[Method])) do
					if not Connection.ForeignState and Connection.Function ~= callback then
						continue
					end

					Connection:Disable()
				end
			end

			return table.unpack(Result, 1, Result.n)
		end)

		return Connect
	end

	return wax.shared.Hooks[SignalMetatable.__index](...)
end)
