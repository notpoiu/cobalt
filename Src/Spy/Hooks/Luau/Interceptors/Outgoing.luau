local function CreateLookupTable(table)
	local LookupTable = {}
	for _, Method in next, table do
		LookupTable[Method] = true
	end
	return LookupTable
end

local NamecallMethods = {
	["FireServer"] = CreateLookupTable({"RemoteEvent", "UnreliableRemoteEvent"}),
	["fireServer"] = CreateLookupTable({"RemoteEvent", "UnreliableRemoteEvent"}),
	
	["InvokeServer"] = CreateLookupTable({"RemoteFunction"}),
	["invokeServer"] = CreateLookupTable({"RemoteFunction"}),

	["Fire"] = CreateLookupTable({"BindableEvent"}),
	["fire"] = CreateLookupTable({"BindableEvent"}),
	
	["Invoke"] = CreateLookupTable({"BindableFunction"}),
	["invoke"] = CreateLookupTable({"BindableFunction"}),
}
local AllowedClassNames =
	CreateLookupTable({ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent", "BindableFunction" })

--[[
	Returns the calling function via `debug.info`

	@return `function | nil` The calling function or nil if not found.
]]
local function getcallingfunction()
	local BaseLevel = if wax.shared.IsUsingOthHooks then 3 else 5

	for i = BaseLevel, 10 do
		local Function, Source = debug.info(i, "fs")
		if not Function or not Source then
			break
		end

		if Source == "[C]" then
			continue
		end

		return Function
	end

	return debug.info(BaseLevel, "f")
end

--[[
	Returns the calling line of the script that called the function via `debug.info`

	@return number Returns the line number of the calling script.
]]
local function getcallingline()
	local BaseLevel = if wax.shared.IsUsingOthHooks then 3 else 5

	for i = BaseLevel, 10 do
		local Source, Line = debug.info(i, "sl")
		if not Source then
			break
		end

		if Source == "[C]" then
			continue
		end

		return Line
	end

	return debug.info(BaseLevel, "l")
end

--[[
	Returns the calling source of the script that called the function via `debug.info`

	@return string Returns the source of the calling script.
]]
local function getcallingsource()
	local BaseLevel = if wax.shared.IsUsingOthHooks then 3 else 5

	for i = BaseLevel, 10 do
		local Source = debug.info(i, "s")
		if not Source then
			break
		end

		if Source == "[C]" then
			continue
		end

		return Source
	end

	return debug.info(BaseLevel, "s")
end

--[[
	Gets the log for a specific instance and direction.

	@param Instance: The instance that was called.
	@param Direction: The direction of the log (Outgoing, Incoming).
	@return Log: The log for the instance and direction.
]]
local function GetLog(Instance: Instance, Direction: "Outgoing" | "Incoming")
	local Log = wax.shared.Logs[Direction][Instance]
	if not Log then
		Log = wax.shared.NewLog(Instance, Direction, getcallingscript())
	end

	return Log
end

--[[
	Handles logging for a result of a remote function.
	@param Log The log to use.
	@param Arguments The arguments to use.
	@param ... The result to log.
	@return The result.
]]
local function HandleLoggingResult(Log, Info, ResultKey, ...)
	local Result = wax.shared.SafePack.Pack(...)
	Info[ResultKey] = Result
	Log:Call(Info)

	return ...
end

--[[
	Handles the logging for a specific instance and method.

	@param Instance: The instance that was called.
	@param Method: The method that was called (e.g., "OnClientEvent").
	@param ... The arguments passed from the server to the client.
]]
local function HandleLogging(TargetInstance: Instance, Method: string, OldFunction: (...any) -> ...any, ...)
	local Log = GetLog(TargetInstance, "Outgoing")
	local Arguments = wax.shared.SafePack.Pack(select(2, ...))

	local Info = {
		Arguments = Arguments,
		Origin = getcallingscript(),
		Function = getcallingfunction(),
		Line = getcallingline(),
		Source = getcallingsource(),
		IsExecutor = checkcaller(),
	}
	local ShouldBlock = Log:ShouldBlock(Info)
	Log:Call(Info)
	if ShouldBlock then
		return
	end

	local IsRemoteFunctionInvoke = (
		TargetInstance.ClassName == "RemoteFunction" and (Method == "InvokeServer" or Method == "invokeServer")
	)

	local IsBindableFunctionInvoke = (
		TargetInstance.ClassName == "BindableFunction" and (Method == "Invoke" or Method == "invoke")
	)

	if IsRemoteFunctionInvoke or IsBindableFunctionInvoke then
		--// Handle Incoming Log \\--
		Log = GetLog(TargetInstance, "Incoming")
		local RFResultInfo = {
			Arguments = Arguments,
			InvokeResult = nil,
			Origin = getcallingscript(),
			Function = getcallingfunction(),
			Line = getcallingline(),
			Source = getcallingsource(),
			IsExecutor = checkcaller(),
			InvokeKind = "Request",
		}

		if Log:ShouldBlock(RFResultInfo) then
			Log:Call(RFResultInfo)
			return
		end

		return HandleLoggingResult(Log, RFResultInfo, "InvokeResult", OldFunction(...))
	end

	return OldFunction(...)
end

--#region Hook Filters
local SupportsFilters = wax.shared.ExecutorSupport["FilterBase"].IsWorking

--[[
	Creates a base filter for the outgoing hooks.

	@return `table` The base filter.
]]
local function CreateBaseFilter()
	local Filters = {}
	if not SupportsFilters then
		return Filters
	end

	--// ignore communicator \\--
	table.insert(Filters, NotFilter.new(ArgumentFilter.new(1, wax.shared.Communicator)))
	table.insert(Filters, NotFilter.new(ArgumentFilter.new(1, wax.shared.ActorCommunicator)))

	return Filters
end

local NamecallHookFilter = SupportsFilters and AllFilter.new((function()
	local Filters = CreateBaseFilter()

	--[[
		AllFilter:
			not communicator
			not actor communicator
			AnyFilter:
				RemoteEvent
				...
			AnyFilter:
				FireServer
				invokeServer
				...
	--]]

	--// classnames \\--
	local AnyClassNameFilters = {}
	for ClassName in AllowedClassNames do
		table.insert(AnyClassNameFilters, InstanceTypeFilter.new(1, ClassName))
	end
	
	--// methods \\--
	local AnyNamecallMethoFilters = {}
    for Method in NamecallMethods do
        table.insert(AnyNamecallMethoFilters, NamecallFilter.new(Method))
    end

	table.insert(Filters, AnyFilter.new(AnyClassNameFilters))
	table.insert(Filters, AnyFilter.new(AnyNamecallMethoFilters))
    return Filters
end)())
--#endregion

-- namecall hook
wax.shared.NamecallHook = wax.shared.Hooking.HookMetaMethod(game, "__namecall", function(...)
	local self = ...
	local Method = getnamecallmethod()

	if
		typeof(self) == "Instance"
		and AllowedClassNames[self.ClassName]
		and not rawequal(self, wax.shared.Communicator)
		and not rawequal(self, wax.shared.ActorCommunicator)
		and (NamecallMethods[Method] and NamecallMethods[Method][self.ClassName])
		and not wax.shared.ShouldIgnore(self, getcallingscript())
	then
		return HandleLogging(self, Method, wax.shared.NamecallHook, ...)
	end

	return wax.shared.NamecallHook(...)
end, NamecallHookFilter)

-- function hooks
local FunctionsToHook
do
	local BindableFunction = Instance.new("BindableFunction")
	local BindableEvent = Instance.new("BindableEvent")

	local RemoteFunction = Instance.new("RemoteFunction")
	local RemoteEvent = Instance.new("RemoteEvent")
	local UnreliableRemoteEvent = Instance.new("UnreliableRemoteEvent")

	FunctionsToHook = {
		BindableFunction.Invoke,
		BindableEvent.Fire,

		RemoteFunction.InvokeServer,
		RemoteEvent.FireServer,
		UnreliableRemoteEvent.FireServer,
	}

	BindableFunction:Destroy()
	BindableEvent:Destroy()

	RemoteFunction:Destroy()
	RemoteEvent:Destroy()
	UnreliableRemoteEvent:Destroy()
end

local FunctionHookFilter = SupportsFilters and AllFilter.new((function()
	local Filters = CreateBaseFilter()

	--[[
		AllFilter:
			not communicator
			not actor communicator
			AnyFilter:
				RemoteEvent
				RemoteFunction
				UnreliableRemoteEvent
				BindableEvent
				BindableFunction
	--]]

	local ClassFilters = {}
	for ClassName in AllowedClassNames do
		table.insert(ClassFilters, InstanceTypeFilter.new(1, ClassName))
	end

	table.insert(Filters, AnyFilter.new(ClassFilters))
	return Filters
end)())

for _, Function in next, FunctionsToHook do
	local Method = debug.info(Function, "n")

	wax.shared.Hooks[Function] = wax.shared.Hooking.HookFunction(Function, function(...)
		local self = ...

		if
			typeof(self) == "Instance"
			and AllowedClassNames[self.ClassName]
			and not rawequal(self, wax.shared.Communicator)
			and not wax.shared.ShouldIgnore(self, getcallingscript())
		then
			return HandleLogging(self, Method, wax.shared.Hooks[Function], ...)
		end

		return wax.shared.Hooks[Function](...)
	end, FunctionHookFilter)
end
