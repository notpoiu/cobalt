local Drag = {
	Dragging = false,
	Frame = nil,
	FramePosition = nil,
	FrameSize = nil, -- Added to store initial frame size
	StartPosition = nil,
	ChangedConnection = nil,
	Callback = nil,
}

local Helper = require(script.Parent.Helper)

local function DefaultCallback(_, Input: InputObject)
	local Delta = Input.Position - Drag.StartPosition
	local FramePosition: UDim2 = Drag.FramePosition

	Drag.Frame.Position = UDim2.new(
		FramePosition.X.Scale,
		FramePosition.X.Offset + Delta.X,
		FramePosition.Y.Scale,
		FramePosition.Y.Offset + Delta.Y
	)
end

function Drag.Setup(Frame: GuiObject, DragFrame: GuiObject, Callback: (Info: {}, Input: InputObject) -> () | nil)
	Callback = Callback or DefaultCallback

	DragFrame.InputBegan:Connect(function(Input: InputObject)
		if not Helper.IsClickInput(Input) then
			return
		end

		Drag.Dragging = true
		Drag.Frame = Frame
		Drag.FramePosition = Frame.Position
		Drag.StartPosition = Input.Position
		Drag.FrameSize = Frame.Size
		Drag.Callback = Callback

		Drag.ChangedConnection = Input.Changed:Connect(function()
			if Input.UserInputState ~= Enum.UserInputState.End then
				return
			end

			Drag.Dragging = false
			Drag.Frame = nil
			Drag.Callback = nil

			if Drag.ChangedConnection and Drag.ChangedConnection.Connected then
				Drag.ChangedConnection:Disconnect()
				Drag.ChangedConnection = nil
			end
		end)
	end)
end

wax.shared.Connect(wax.shared.UserInputService.InputChanged:Connect(function(Input: InputObject)
	if Drag.Dragging and Drag.Callback and Helper.IsMoveInput(Input) then
		Drag.Callback(Drag, Input)
	end
end))

return Drag
