--// Helpers \\--
local function CreateLookupTable(table)
	local LookupTable = {}
	for _, Method in next, table do
		LookupTable[Method] = true
	end
	return LookupTable
end

--// Variables \\--
local setfenv = setfenv
local getconnections = wax.shared.ExecutorSupport["getconnections"].IsWorking and getconnections or function() return {} end

local ClassesToHook = {
	RemoteEvent = "OnClientEvent",
	RemoteFunction = "OnClientInvoke",
	UnreliableRemoteEvent = "OnClientEvent",
	BindableEvent = "Event",
	BindableFunction = "OnInvoke",
}

local ConnectionKeys = CreateLookupTable({
	"Connect",
	"ConnectParallel",
	"connect",
	"connectParallel",
	"Once",
})

--// State \\--
local ConnectionsEnabled = false
local CallbacksEnabled = false
local ConnectionHookEnabled = false

--// Signals & Detours \\--
local LogConnectionFunctions = {}
local CallbackOwners = setmetatable({}, { __mode = "k" })
local SignalMapping = setmetatable({}, { __mode = "kv" })
local ObservedConnectionInstances = setmetatable({}, { __mode = "k" })
wax.shared.IncomingLogConnectionFunctions = LogConnectionFunctions

local CobaltObserverEnvironmentKey = "__CobaltIncomingObserver"

--// Types \\--
type InstancesToHook = RemoteEvent | UnreliableRemoteEvent | RemoteFunction | BindableEvent | BindableFunction
type MethodsToHook = "OnClientEvent" | "OnClientInvoke" | "Event" | "OnInvoke"
export type Options = {
	Connections: boolean?,
	Callbacks: boolean?,
	HookConnections: boolean?,
}

--// Functions \\--
local function GetLog(Instance: InstancesToHook, Function: (...any) -> ...any)
	if wax.shared.ShouldIgnore(Instance, getcallingscript()) or LogConnectionFunctions[Function] then
		return nil
	end

	local Log = wax.shared.Logs.Incoming[Instance]
	if not Log then
		Log = wax.shared.NewLog(Instance, "Incoming", getcallingscript())
	end

	return Log
end

--[[
	Individually logs an incoming remote call.

	@param Instance The instance that was called.
	@param Function The function that was called, if applicable.
	@param Info The information about the call, including arguments and origin. Can be nil.
	@param ... The arguments passed from the server to the client.
	@return boolean, Log? Returns true if the call was blocked, plus the log when one was used.
]]
local function LogRemote(
	Instance: InstancesToHook,
	Function: (...any) -> ...any,
	Info: {
		Arguments: { [number]: any, n: number },
		Origin: Instance,
		Function: (...any) -> ...any,
		Line: number,
		IsExecutor: boolean,
		Blocked: boolean?,
	}
)
	local Log = GetLog(Instance, Function)
	if not Log then
		return false, nil
	end

	local ShouldBlock = Log:ShouldBlock(Info)
	local CallIndex = Log:Call(Info)
	return ShouldBlock, Log, CallIndex
end

--#region Incoming Connection Stuff
local function IsCobaltConnectionFunction(Function): boolean
	if not Function then
		return false
	end

	if LogConnectionFunctions[Function] then
		return true
	end

	local Success, Environment = pcall(getfenv, Function)
	local VerificationToken = wax.shared.CobaltVerificationToken
	return (
		Success
		and VerificationToken ~= nil
		and typeof(Environment) == "table"
		and rawget(Environment, CobaltObserverEnvironmentKey) == VerificationToken
	)
end

--[[
	Creates a function that can be used to pass to `Connect` which will log all the incoming calls. It will additonally add the function to a ignore list (`LogConnectionFunctions`) to prevent unneccessary logging.
	
	@param Instance The instance to log.
	@param Method The method to log (e.g., "OnClientEvent").
	@return function Returns a function that logs all calls to the given instance and method.
]]
local function CreateConnectionFunction(Instance: InstancesToHook, Method: MethodsToHook)
	local ConnectionFunction = function(...)
		local HasValidConnections = false
		local HasForeignLuaConnections = false

		local Arguments = wax.shared.SafePack.Pack(...)

		local TargetLog, TargetCallIndex
		for _, Connection in getconnections((Instance :: any)[Method]) do
			--// Foreign State Connections \\--
			if Connection.ForeignState then
				--// It is a Lua Connection - Other Actor's Connections \\--
				if Connection.LuaConnection then
					HasForeignLuaConnections = true
				end

				continue
			end

			--// Get Function \\--
			local Function = typeof(Connection.Function) == "function" and Connection.Function or nil
			local IsCobaltConnection = IsCobaltConnectionFunction(Function)

			if IsCobaltConnection then
				continue
			end

			HasValidConnections = true

			--// Get Origin \\--
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

			--// Log Remote \\--
			TargetLog, TargetCallIndex = select(2, LogRemote(Instance, Function, {
				Arguments = Arguments,
				Origin = Origin,
				Function = Function,
				Line = nil,
				IsExecutor = Function and isexecutorclosure(Function) or false,
			}))
		end
		
		if not HasValidConnections and not wax.shared.IS_ACTOR then
			TargetLog, TargetCallIndex = select(2, LogRemote(Instance, nil, {
				Arguments = Arguments,
				Origin = nil,
				Function = nil,
				Line = nil,
				IsExecutor = false,
			}))
		end

		if
			not wax.shared.IS_ACTOR
			and HasForeignLuaConnections
			and TargetLog
			and TargetCallIndex
			and wax.shared.ActorCommunicator
		then
			wax.shared.ActorCommunicator:Fire(
				"InspectIncomingConnections",
				Instance,
				Method,
				TargetLog.Index,
				TargetCallIndex
			)
		end
	end

	local OriginalEnvironment = getfenv(ConnectionFunction)
	setfenv(ConnectionFunction, setmetatable({
		[CobaltObserverEnvironmentKey] = wax.shared.CobaltVerificationToken,
	}, {
		__index = OriginalEnvironment,
		__newindex = OriginalEnvironment,
	}))

	LogConnectionFunctions[ConnectionFunction] = true
	return ConnectionFunction
end

--#endregion

--#region Incoming Callback Stuff
--[[
	Handles logging for a callback.

	@param Log The log to use.
	@param Info The pending callback call information.
	@param InitialEnv The initial environment to use.
	@param InitialIdentity The initial identity to use.
	@param ... The result of the callback.

	@return The result of the callback.
]]
local function HandleCallbackLogging(Log, Info, InitialEnv, InitialIdentity, ...)
	setfenv(0, InitialEnv)
	setthreadidentity(InitialIdentity)

	if Log then
		Info.InvokeResult = wax.shared.SafePack.Pack(...)
		Log:Call(Info)
	end

	return ...
end

--[[
	Creates a function that can be used to pass to callbacks (.OnInvoke & .OnClientInvoke) which will log all the incoming calls.
	
	@param Instance The instance to log.
	@param Function The original callback of the RemoteFunction
	@return function Returns a function that logs all function calls to the given instance.
]]
local function CreateCallbackDetour(Instance: InstancesToHook, Callback: (...any) -> ...any)
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

		local Arguments = wax.shared.SafePack.Pack(...)
		local Log = GetLog(Instance, Callback)
		local Info = {
			Arguments = Arguments,
			Origin = Origin,
			Function = Callback,
			Line = nil,
			IsExecutor = IsExecutor,
			InvokeKind = "Callback",
		}
		if Log and Log:ShouldBlock(Info) then
			Log:Call(Info)
			return
		end

		local InitialEnv, InitialIdentity = getfenv(CreateCallbackDetour), getthreadidentity()

		setthreadidentity(2)
		setfenv(0, getfenv(Callback))
		return HandleCallbackLogging(
			Log,
			Info,
			InitialEnv,
			InitialIdentity,
			Callback(...)
		)
	end

	if wax.shared.ExecutorSupport["setstackhidden"].IsWorking then
		setstackhidden(Detour, true)
	end

	CallbackOwners[Detour] = {
		Original = Callback,
		Method = ClassesToHook[Instance.ClassName],
		Instance = Instance,
	}
	return Detour
end

--[[
	Restores the callback detours for the given instances. Used for cobalt unloading.
	NOTE: Keep this in here so Actors can rely on wax.shared.RestoreCallbackDetours
]]
wax.shared.RestoreCallbackDetours = function()
	for Detour, Owner in CallbackOwners do
		local Success, CurrentCallback = pcall(getcallbackvalue, Owner.Instance, Owner.Method)
		if not (Success and rawequal(CurrentCallback, Detour)) then
			continue
		end

		pcall(function()
			if wax.shared.trampoline_call then
				wax.shared.trampoline_call(function()
					Owner.Instance[Owner.Method] = Owner.Original
				end, {}, {})
			else
				Owner.Instance[Owner.Method] = Owner.Original
			end
		end)
	end

	table.clear(CallbackOwners)
end

--#endregion

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

	if ConnectionsEnabled and not ObservedConnectionInstances[Instance] then
		if Instance.ClassName == "RemoteEvent" or Instance.ClassName == "UnreliableRemoteEvent" then
			wax.shared.Connect(Instance.OnClientEvent:Connect(CreateConnectionFunction(Instance, Method)))

			SignalMapping[Instance.OnClientEvent] = Instance
			ObservedConnectionInstances[Instance] = true
		elseif Instance.ClassName == "BindableEvent" then
			wax.shared.Connect(Instance.Event:Connect(CreateConnectionFunction(Instance, Method)))

			SignalMapping[Instance.Event] = Instance
			ObservedConnectionInstances[Instance] = true
		end
	end

	if CallbacksEnabled then
		if Instance.ClassName == "RemoteFunction" or Instance.ClassName == "BindableFunction" then
			local Success, Callback = pcall(getcallbackvalue, Instance, Method)
			local IsCallable = (
				typeof(Callback) == "function"
				or wax.shared.getrawmetatable(Callback) ~= nil and typeof(
					wax.shared.getrawmetatable(Callback)["__call"]
				) == "function"
				or false
			)

			if not Success or not IsCallable or CallbackOwners[Callback] then
				return
			end

			--// Use trampoline_call so error redirection dosent occur \\--
			if wax.shared.trampoline_call then
				wax.shared.trampoline_call(function()
					Instance[Method] = CreateCallbackDetour(Instance, Callback)
				end, {}, {})
			else
				Instance[Method] = CreateCallbackDetour(Instance, Callback)
			end
		end
	end
end

--[[
	Creates a hook that intercepts .OnInvoke & .OnClientInvoke assignments and detours them to log the calls.
]]
local function SetupCallbackAssignmentHook()
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
				if CallbackOwners[value] then
					return wax.shared.NewIndexHook(...)
				end

				return wax.shared.NewIndexHook(self, key, CreateCallbackDetour(self :: InstancesToHook, value))
			end
		end

		return wax.shared.NewIndexHook(...)
	end)
end

--[[
	Handles logging for a connection.

	@param Method The method to log.
	@param callback The callback to log.
	@param ... The arguments to log.

	@return The result of the connection.
]]
local function HandleConnectionLogging(Instance, Method, callback, ...)
	local Log = wax.shared.Logs.Incoming[Instance]

	if Log and Log.Blocked then
		for _, Connection in getconnections(Instance[Method]) do
			if not Connection.ForeignState and Connection.Function ~= callback then
				continue
			end

			Connection:Disable()
		end
	end

	return ...
end

--[[
	Creates a hook that disables connections for blocked instances on creation.
]]
local function SetupConnectionAssignmentHook()
	local SignalMetatable = wax.shared.getrawmetatable(Instance.new("Part").Touched)
	wax.shared.Hooks[SignalMetatable.__index] = wax.shared.Hooking.HookFunction(SignalMetatable.__index, function(...)
		local self, key = ...

		if not wax.shared.Unloaded and ConnectionKeys[key] then
			local Instance = SignalMapping[self]
			local Connect = wax.shared.Hooks[SignalMetatable.__index](...)

			if not Instance then
				return Connect
			end

			local Method = ClassesToHook[Instance.ClassName]
			return wax.shared.newcclosure(function(...)
				local _self, callback = ...
				return HandleConnectionLogging(Instance, Method, callback, Connect(...))
			end, debug.info(Connect, "n"))
		end

		return wax.shared.Hooks[SignalMetatable.__index](...)
	end)
end

local Started = false
return function(Options: Options?)
	if Started then
		return
	end

	--// Validation \\--
	Options = Options or {}
	do
		ConnectionsEnabled = Options.Connections ~= false
		CallbacksEnabled = Options.Callbacks ~= false
		ConnectionHookEnabled = Options.HookConnections ~= false
	end

	if not ConnectionsEnabled and not CallbacksEnabled then
		return
	end

	Started = true

	--// Listeners \\--
	if CallbacksEnabled then
		if wax.shared.ExecutorSupport["setstackhidden"].IsWorking then
			setstackhidden(HandleCallbackLogging, true)
		end

		SetupCallbackAssignmentHook()
	end

	if ConnectionsEnabled and ConnectionHookEnabled then
		SetupConnectionAssignmentHook()
	end

	wax.shared.Connect(game.DescendantAdded:Connect(HandleInstance))

	--// Initialization \\--
	local ClassesToSearch = {}
	do
		if ConnectionsEnabled then
			table.insert(ClassesToSearch, "RemoteEvent")
			table.insert(ClassesToSearch, "UnreliableRemoteEvent")
			table.insert(ClassesToSearch, "BindableEvent")
		end
		if CallbacksEnabled then
			table.insert(ClassesToSearch, "RemoteFunction")
			table.insert(ClassesToSearch, "BindableFunction")
		end
	end

	local Categories = {
		game:QueryDescendants(table.concat(ClassesToSearch, ", ")),
	}
	if wax.shared.ExecutorSupport["getnilinstances"].IsWorking then
		table.insert(Categories, getnilinstances())
	end

	for _, Category in Categories do
		for _, TargetInstance in next, Category do
			HandleInstance(TargetInstance)
		end
	end
end
