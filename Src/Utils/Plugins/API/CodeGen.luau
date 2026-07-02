--// Imports \\--
local Formatter = require("@src/Utils/CodeGen/Formatter")
local InstanceSerializer = require("@src/Utils/CodeGen/Serializer/Instance")
local LazySerializer = require("@src/Window/Utils/Text/LazySerializer")

local CodeGen = {}

function CodeGen.Apply(Cobalt, Manager)
	function Cobalt.CodeGen:InterceptGeneration(
		Type: "Call" | "Hook" | "InstancePath",
		Callback: (Info: any, ...any) -> ...any
	)
		Manager.HasCodeGenInterceptors = true

		local Interceptors = Manager.Registry.UIHooks.CodeGen[Type]
		assert(Interceptors, "Invalid Code Generation Type")

		table.insert(Interceptors, Callback)

		return function()
			local Index = table.find(Interceptors, Callback)
			if Index then
				table.remove(Interceptors, Index)
			end
		end
	end

	function Cobalt.CodeGen.Serialize(data, options)
		if typeof(data) == "table" then
			return wax.shared.LuaEncode(data, options)
		elseif typeof(data) == "Instance" then
			return InstanceSerializer.Serialize(data, options)
		end

		return LazySerializer.QuickSerializeArgument(data)
	end

	function Cobalt.CodeGen.Indent(str: string, indent: number)
		return Formatter.IndentCode(str, indent)
	end
end

return CodeGen
