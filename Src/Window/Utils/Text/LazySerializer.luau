local LazySerializer = {}

local InstanceSerializer = require("@src/Utils/CodeGen/Serializer/Instance")

function LazySerializer.QuickSerializeNumber(Number: number)
	if Number % 1 ~= 0 then
		return string.format("%.3f", Number)
	elseif Number == 1 / 0 then
		return "math.huge"
	elseif Number == -1 / 0 then
		return "-math.huge"
	end

	return Number
end

function LazySerializer.QuickSerializeArgument(Argument)
	if typeof(Argument) == "string" then
		return string.format('"%s"', (Argument :: string))
	elseif typeof(Argument) == "number" then
		return LazySerializer.QuickSerializeNumber(Argument)
	elseif typeof(Argument) == "Vector2" then
		return string.format(
			"%s, %s",
			LazySerializer.QuickSerializeNumber(Argument.X),
			LazySerializer.QuickSerializeNumber(Argument.Y)
		)
	elseif typeof(Argument) == "Vector3" then
		return string.format(
			"%s, %s, %s",
			LazySerializer.QuickSerializeNumber(Argument.X),
			LazySerializer.QuickSerializeNumber(Argument.Y),
			LazySerializer.QuickSerializeNumber(Argument.Z)
		)
	elseif typeof(Argument) == "CFrame" then
		local Components = { Argument:GetComponents() }
		for Index, Value in pairs(Components) do
			Components[Index] = LazySerializer.QuickSerializeNumber(Value)
		end
		return table.concat(Components, ", ")
	elseif typeof(Argument) == "table" then
		return "{...}"
	elseif typeof(Argument) == "Instance" then
		return InstanceSerializer.Serialize(Argument, { DisableNilParentHandler = true })
	elseif typeof(Argument) == "userdata" then
		return "newproxy(" .. getmetatable(Argument) and "true" or "false" .. ")"
	end

	return tostring(Argument)
end

return LazySerializer
