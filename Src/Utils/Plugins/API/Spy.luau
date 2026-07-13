--// Imports \\--
local Types = require("@src/Utils/CodeGen/Types")

local Bridge = require(script.Parent.Parent.Bridge)

local Spy = {}

function Spy.Apply(Cobalt, Manager)
	type InterceptorFunction = (Info: Types.CallInfo, Instance: Instance, Type: "Incoming" | "Outgoing") -> ...any

	function Cobalt.Spy:InterceptExecutedCalls(
		Type: "Incoming" | "Outgoing" | "All",
		Data: {
			Callback: InterceptorFunction,
			Instance: Instance | nil,
		} | InterceptorFunction
	)
		Manager.HasInterceptors = true

		local Options = typeof(Data) == "table" and setmetatable(Data, { __mode = "v" })
			or setmetatable({
				Callback = Data,
				Instance = nil,
			}, { __mode = "v" })

		local IsInstanceSpecific = Options.Instance ~= nil

		if IsInstanceSpecific then
			local InstanceInterceptors = Manager.Registry.Interceptors.Instance[Options.Instance]
			if not InstanceInterceptors then
				Manager.Registry.Interceptors.Instance[Options.Instance] = {}
				InstanceInterceptors = Manager.Registry.Interceptors.Instance[Options.Instance]
			end

			if not InstanceInterceptors[Type] then
				InstanceInterceptors[Type] = {}
			end

			table.insert(InstanceInterceptors[Type], Options.Callback)
		else
			local GlobalInterceptors = Manager.Registry.Interceptors.Global[Type]
			if not GlobalInterceptors then
				Manager.Registry.Interceptors.Global[Type] = {}
				GlobalInterceptors = Manager.Registry.Interceptors.Global[Type]
			end

			table.insert(GlobalInterceptors, Options.Callback)
		end

		return function()
			if IsInstanceSpecific then
				if not Options.Instance then
					return
				end

				local InstanceInterceptors = Manager.Registry.Interceptors.Instance[Options.Instance]
				if not InstanceInterceptors then
					return
				end

				local Interceptors = InstanceInterceptors[Type]
				if not Interceptors then
					return
				end

				local Index = table.find(Interceptors, Options.Callback)
				if Index then
					table.remove(Interceptors, Index)
				end
			else
				local GlobalInterceptors = Manager.Registry.Interceptors.Global[Type]
				if not GlobalInterceptors then
					return
				end

				local Index = table.find(GlobalInterceptors, Options.Callback)
				if Index then
					table.remove(GlobalInterceptors, Index)
				end
			end
		end
	end

	function Cobalt.Spy:ClearLogs(Instance: Instance?, Type: string?)
		Bridge.Get().ClearLogs(Instance, if Type == "All" then nil else Type)
	end

	function Cobalt.Spy:AppendLog(Instance: Instance, Type: "Incoming" | "Outgoing", Data: {})
		local Log = wax.shared.Logs[Type][Instance] or wax.shared.NewLog(Instance, Type, nil)
		Log:Call(Data)
	end

	function Cobalt:GetLog(instance: Instance, type: "Incoming" | "Outgoing")
		return wax.shared.Logs[type][instance]
	end
end

return Spy
