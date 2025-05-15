local NamecallMethods = { "fireserver", "invokeserver", "fire", "invoke" }
local AllowedClassNames =
	{ "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent", "BindableFunction" }

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
	wax.shared.newcclosure(function(self, ...)
		local Method = getnamecallmethod()

		if
			table.find(AllowedClassNames, self.ClassName)
			and self ~= wax.shared.Communicator
			and table.find(NamecallMethods, string.lower(Method))
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
					Arguments = { ... },
					Time = os.date("%X"),
					Origin = getcallingscript(),
					Function = getcallingfunction(),
					Line = getcallingline(),
					IsExecutor = checkcaller(),
				}
				Log:Call(Info)
				wax.shared.Communicator.Fire(wax.shared.Communicator, Log.Instance, "Outgoing", Info, #Log.Calls)

				-- For RemoteFunction return value (ex: local result = RemoteFunction:InvokeServer())
				if self.ClassName == "RemoteFunction" and Method == "InvokeServer" then
					Log = wax.shared.Logs.Incoming[self]
					if not Log then
						Log = wax.shared.NewLog(self, "Incoming", Method, getcallingscript())
					end

					if Log.Blocked then
						return
					end

					local Result = { wax.shared.NamecallHook(self, ...) }
					if not Log.Ignored then
						local RFResultInfo = {
							Arguments = Result,
							Time = os.date("%X"),
							Origin = getcallingscript(),
							Function = getcallingfunction(),
							Line = getcallingline(),
							IsExecutor = checkcaller(),
							OriginalInvokeArgs = { ... },
						}
						Log:Call(RFResultInfo)
						wax.shared.Communicator:Fire(Log.Instance, "Incoming", RFResultInfo, #Log.Calls)
					end

					return table.unpack(Result)
				end
			end
		end

		return wax.shared.NamecallHook(self, ...)
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
		wax.shared.newcclosure(function(self, ...)
			if self ~= wax.shared.Communicator and not wax.shared.ShouldIgnore(self, getcallingscript()) then
				local Log = wax.shared.Logs.Outgoing[self]
				if not Log then
					Log = wax.shared.NewLog(self, "Outgoing", Method, getcallingscript())
				end

				if Log.Blocked then
					return
				elseif not Log.Ignored then
					local Info = {
						Arguments = { ... },
						Time = os.date("%X"),
						Origin = getcallingscript(),
						Function = getcallingfunction(),
						Line = getcallingline(),
						IsExecutor = checkcaller(),
					}
					Log:Call(Info)
					wax.shared.Communicator:Fire(Log.Instance, "Outgoing", Info, #Log.Calls)

					-- For RemoteFunction return value (ex: local result = RemoteFunction:InvokeServer())
					if self.ClassName == "RemoteFunction" and Method == "InvokeServer" then
						Log = wax.shared.Logs.Incoming[self]
						if not Log then
							Log = wax.shared.NewLog(self, "Incoming", Method, getcallingscript())
						end

						if Log.Blocked then
							return
						end

						local Result = { wax.shared.Hooks[Function](self, ...) }
						if not Log.Ignored then
							local RFResultInfo = {
								Arguments = Result,
								Time = os.date("%X"),
								Origin = getcallingscript(),
								Function = getcallingfunction(),
								Line = getcallingline(),
								IsExecutor = checkcaller(),
								OriginalInvokeArgs = { ... },
							}
							Log:Call(RFResultInfo)
							wax.shared.Communicator:Fire(Log.Instance, "Incoming", RFResultInfo, #Log.Calls)
						end

						return table.unpack(Result)
					end
				end
			end

			return wax.shared.Hooks[Function](self, ...)
		end)
	)
end
