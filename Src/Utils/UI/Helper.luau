local UIHelper = {}

local CodeGen = require(script.Parent.Parent.CodeGen.Generator)

function UIHelper.IsMouseOverFrame(Frame: GuiObject, Position: Vector3): boolean
	local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
	return Position.X >= AbsPos.X
		and Position.X <= AbsPos.X + AbsSize.X
		and Position.Y >= AbsPos.Y
		and Position.Y <= AbsPos.Y + AbsSize.Y
end

function UIHelper.IsClickInput(Input: InputObject): boolean
	return Input.UserInputState == Enum.UserInputState.Begin
		and (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
end

function UIHelper.IsMoveInput(Input: InputObject): boolean
	return Input.UserInputState == Enum.UserInputState.Change
		and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch)
end

function UIHelper.QuickSerializeNumber(Number: number)
	if Number % 1 ~= 0 then
		return string.format("%.3f", Number)
	elseif Number == 1 / 0 then
		return "math.huge"
	elseif Number == -1 / 0 then
		return "-math.huge"
	end

	return Number
end

function UIHelper.QuickSerializeArgument(Argument)
	if typeof(Argument) == "string" then
		return string.format('"%s"', Argument)
	elseif typeof(Argument) == "number" then
		return UIHelper.QuickSerializeNumber(Argument)
	elseif typeof(Argument) == "Vector2" then
		return string.format(
			"%s, %s",
			UIHelper.QuickSerializeNumber(Argument.X),
			UIHelper.QuickSerializeNumber(Argument.Y)
		)
	elseif typeof(Argument) == "Vector3" then
		return string.format(
			"%s, %s, %s",
			UIHelper.QuickSerializeNumber(Argument.X),
			UIHelper.QuickSerializeNumber(Argument.Y),
			UIHelper.QuickSerializeNumber(Argument.Z)
		)
	elseif typeof(Argument) == "CFrame" then
		local Components = { Argument:GetComponents() }
		for Index, Value in pairs(Components) do
			Components[Index] = UIHelper.QuickSerializeNumber(Value)
		end
		return table.concat(Components, ", ")
	elseif typeof(Argument) == "table" then
		return "{...}"
	elseif typeof(Argument) == "Instance" then
		return CodeGen.GetFullPath(Argument, { DisableNilParentHandler = true })
	elseif typeof(Argument) == "userdata" then
		return "newproxy(" .. getmetatable(Argument) and "true" or "false" .. ")"
	end

	return tostring(Argument)
end

return UIHelper
