local Input = {}

function Input.IsMouseOverFrame(Frame: GuiObject, Position: Vector3): boolean
	local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
	return Position.X >= AbsPos.X
		and Position.X <= AbsPos.X + AbsSize.X
		and Position.Y >= AbsPos.Y
		and Position.Y <= AbsPos.Y + AbsSize.Y
end

function Input.IsClickInput(InputObject: InputObject): boolean
	return InputObject.UserInputState == Enum.UserInputState.Begin
		and (
			InputObject.UserInputType == Enum.UserInputType.MouseButton1
			or InputObject.UserInputType == Enum.UserInputType.Touch
		)
end

function Input.IsMoveInput(InputObject: InputObject): boolean
	return InputObject.UserInputState == Enum.UserInputState.Change
		and (
			InputObject.UserInputType == Enum.UserInputType.MouseMovement
			or InputObject.UserInputType == Enum.UserInputType.Touch
		)
end

return Input
