local function CreateLookupTable(table)
	local LookupTable = {}
	for _, Method in next, table do
		LookupTable[Method] = true
	end
	return LookupTable
end

local NamecallMethods = CreateLookupTable({
	"FireServer",
	"InvokeServer",
	"Fire",
	"Invoke",
	"fireServer",
	"invokeServer",
	"fire",
	"invoke",
})
local AllowedClassNames =
	CreateLookupTable({ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent", "BindableFunction" })

--[[
	Returns the calling function via `debug.info`

	@return `function | nil` The calling function or nil if not found.
]]
local function getcallingfunction()
	local BaseLevel = if wax.shared.ExecutorSupport["oth"].IsWorking then 3 else 5

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
	local BaseLevel = if wax.shared.ExecutorSupport["oth"].IsWorking then 3 else 5

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
	local BaseLevel = if wax.shared.ExecutorSupport["oth"].IsWorking then 3 else 5

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
	Gets the log for a specific instance and method.

	@param Instance: The instance that was called.
	@param Direction: The direction of the log (Outgoing, Incoming).
	@param Method: The method that was called (e.g., "OnClientEvent").
	@return Log: The log for the instance and method.
]]
local function GetLog(Instance: Instance, Direction: "Outgoing" | "Incoming", Method: string)
	local Log = wax.shared.Logs[Direction][Instance]
	if not Log then
		Log = wax.shared.NewLog(Instance, Direction, Method, getcallingscript())
	end

	return Log
end

--[[
	Handles the logging for a specific instance and method.

	@param Instance: The instance that was called.
	@param Method: The method that was called (e.g., "OnClientEvent").
	@param ... The arguments passed from the server to the client.
]]
local function HandleLogging(TargetInstance: Instance, Method: string, OldFunction: (...any) -> ...any, ...)
	local Log = GetLog(TargetInstance, "Outgoing", Method)

	local Info = {
		Arguments = table.pack(select(2, ...)),
		Origin = getcallingscript(),
		Function = getcallingfunction(),
		Line = getcallingline(),
		Source = getcallingsource(),
		IsExecutor = checkcaller(),
	}

	if Log.Blocked then
		if wax.shared.SaveManager:GetState("LogBlockedRemotes", false) then
			Info.Blocked = true
			Log:Call(Info)
		end

		return true
	end

	if not Log.Ignored then
		Log:Call(Info)

		-- For RemoteFunction return value (ex: local result = RemoteFunction:InvokeServer())
		if TargetInstance.ClassName == "RemoteFunction" and (Method == "InvokeServer" or Method == "invokeServer") then
			Log = GetLog(TargetInstance, "Incoming", Method)

			if Log.Blocked then
				if wax.shared.SaveManager:GetState("LogBlockedRemotes", false) then
					Log:Call({
						Arguments = table.pack(select(2, ...)),
						Origin = getcallingscript(),
						Function = getcallingfunction(),
						Line = getcallingline(),
						Source = getcallingsource(),
						IsExecutor = checkcaller(),
						InvokeKind = "Request",
						Blocked = true,
					})
				end

				return true
			end

			local Result = table.pack(OldFunction(...))
			if not Log.Ignored then
				local RFResultInfo = {
					Arguments = table.pack(select(2, ...)),
					InvokeResult = Result,
					Origin = getcallingscript(),
					Function = getcallingfunction(),
					Line = getcallingline(),
					Source = getcallingsource(),
					IsExecutor = checkcaller(),
					InvokeKind = "Request",
				}
				Log:Call(RFResultInfo)
			end

			return false, Result
		end
	end

	return false, table.pack(OldFunction(...))
end

-- metamethod hooks
wax.shared.NamecallHook = wax.shared.Hooking.HookMetaMethod(game, "__namecall", function(...)
	local self = ...
	local Method = getnamecallmethod()

	if
		typeof(self) == "Instance"
		and AllowedClassNames[self.ClassName]
		and not rawequal(self, wax.shared.Communicator)
		and not rawequal(self, wax.shared.ActorCommunicator)
		and NamecallMethods[Method]
		and not wax.shared.ShouldIgnore(self, getcallingscript())
	then
		local WasBlocked, Result = HandleLogging(self, Method, wax.shared.NamecallHook, ...)
		if WasBlocked then
			return
		end

		return table.unpack(Result, 1, Result.n)
	end

	return wax.shared.NamecallHook(...)
end)

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
			local WasBlocked, Result = HandleLogging(self, Method, wax.shared.Hooks[Function], ...)
			if WasBlocked then
				return
			end

			return table.unpack(Result, 1, Result.n)
		end

		return wax.shared.Hooks[Function](...)
	end)
end
