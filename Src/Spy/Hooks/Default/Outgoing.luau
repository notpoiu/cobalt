local NamecallMethods = {
	"FireServer",
	"InvokeServer",
	"Fire",
	"Invoke",
	"fireServer",
	"invokeServer",
	"fire",
	"invoke",
}
local AllowedClassNames =
	{ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent", "BindableFunction" }

--[[
	Returns the calling function via `debug.info`

	@return `function | nil` The calling function or nil if not found.
]]
local function getcallingfunction()
	for i = 4, 10 do
		local Function, Source = debug.info(i, "fs")
		if not Function or not Source then
			break
		end

		if Source == "[C]" then
			continue
		end

		return Function
	end

	return debug.info(4, "f")
end

--[[
	Returns the calling line of the script that called the function via `debug.info`

	@return number Returns the line number of the calling script.
]]
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

-- metamethod hooks
wax.shared.NamecallHook = wax.shared.Hooking.HookMetaMethod(
	game,
	"__namecall",
	wax.shared.newcclosure(function(...)
		local self = ...
		local Method = getnamecallmethod()

		if
			typeof(self) == "Instance"
			and table.find(AllowedClassNames, self.ClassName)
			and not rawequal(self, wax.shared.Communicator)
			and not rawequal(self, wax.shared.ActorCommunicator)
			and table.find(NamecallMethods, Method)
			and not wax.shared.ShouldIgnore(self, getcallingscript())
		then
			local Log = wax.shared.Logs.Outgoing[self]
			if not Log then
				Log = wax.shared.NewLog(self, "Outgoing", Method, getcallingscript())
			end

			if Log.Blocked then
				return
			elseif not Log.Ignored then
				local Info = {
					Arguments = table.pack(select(2, ...)),
					Time = os.date("%X"),
					Origin = getcallingscript(),
					Function = getcallingfunction(),
					Line = getcallingline(),
					IsExecutor = checkcaller(),
				}
				Log:Call(Info)

				-- For RemoteFunction return value (ex: local result = RemoteFunction:InvokeServer())
				if self.ClassName == "RemoteFunction" and (Method == "InvokeServer" or Method == "invokeServer") then
					Log = wax.shared.Logs.Incoming[self]
					if not Log then
						Log = wax.shared.NewLog(self, "Incoming", Method, getcallingscript())
					end

					if Log.Blocked then
						return
					end

					local Result = table.pack(wax.shared.NamecallHook(...))
					if not Log.Ignored then
						local RFResultInfo = {
							Arguments = Result,
							Time = os.date("%X"),
							Origin = getcallingscript(),
							Function = getcallingfunction(),
							Line = getcallingline(),
							IsExecutor = checkcaller(),
							OriginalInvokeArgs = table.pack(select(2, ...)),
						}
						Log:Call(RFResultInfo)
					end

					return table.unpack(Result, 1, Result.n)
				end
			end
		end

		return wax.shared.NamecallHook(...)
	end)
)

-- function hooks
local FunctionsToHook = {
	Instance.new("BindableFunction").Invoke,
	Instance.new("RemoteFunction").InvokeServer,
	Instance.new("BindableEvent").Fire,
	Instance.new("RemoteEvent").FireServer,
	Instance.new("UnreliableRemoteEvent").FireServer,
}

for _, Function in pairs(FunctionsToHook) do
	local Method = debug.info(Function, "n")

	wax.shared.Hooks[Function] = wax.shared.Hooking.HookFunction(
		Function,
		wax.shared.newcclosure(function(...)
			local self = ...

			if
				typeof(self) == "Instance"
				and table.find(AllowedClassNames, self.ClassName)
				and not rawequal(self, wax.shared.Communicator)
				and not wax.shared.ShouldIgnore(self, getcallingscript())
			then
				local Log = wax.shared.Logs.Outgoing[self]
				if not Log then
					Log = wax.shared.NewLog(self, "Outgoing", Method, getcallingscript())
				end

				if Log.Blocked then
					return
				elseif not Log.Ignored then
					local Info = {
						Arguments = table.pack(select(2, ...)),
						Time = os.date("%X"),
						Origin = getcallingscript(),
						Function = getcallingfunction(),
						Line = getcallingline(),
						IsExecutor = checkcaller(),
					}
					Log:Call(Info)

					-- For RemoteFunction return value (ex: local result = RemoteFunction:InvokeServer())
					if
						self.ClassName == "RemoteFunction"
						and (Method == "InvokeServer" or Method == "invokeServer")
					then
						Log = wax.shared.Logs.Incoming[self]
						if not Log then
							Log = wax.shared.NewLog(self, "Incoming", Method, getcallingscript())
						end

						if Log.Blocked then
							return
						end

						local Result = table.pack(wax.shared.Hooks[Function](...))
						if not Log.Ignored then
							local RFResultInfo = {
								Arguments = Result,
								Time = os.date("%X"),
								Origin = getcallingscript(),
								Function = getcallingfunction(),
								Line = getcallingline(),
								IsExecutor = checkcaller(),
								OriginalInvokeArgs = table.pack(select(2, ...)),
							}
							Log:Call(RFResultInfo)
						end

						return table.unpack(Result, 1, Result.n)
					end
				end
			end

			return wax.shared.Hooks[Function](...)
		end)
	)
end
