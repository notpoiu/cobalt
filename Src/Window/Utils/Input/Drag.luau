local Drag = {
	Dragging = false,
	Frame = nil,
	FramePosition = nil,
	FrameSize = nil, -- Added to store initial frame size
	StartPosition = nil,
	ChangedConnection = nil,
	Callback = nil,
	GetDPIScale = nil,
}

local InputUtils = require(script.Parent.Input)

local function GetDPIScale()
	if Drag.GetDPIScale then
		return Drag.GetDPIScale()
	end

	return 1
end

local function DefaultCallback(_, Input: InputObject)
	local Delta = Input.Position - Drag.StartPosition
	local FramePosition: UDim2 = Drag.FramePosition

	Delta = Delta / GetDPIScale()

	Drag.Frame.Position = UDim2.new(
		FramePosition.X.Scale,
		FramePosition.X.Offset + Delta.X,
		FramePosition.Y.Scale,
		FramePosition.Y.Offset + Delta.Y
	)
end

function Drag.Setup(
	Frame: GuiObject,
	DragFrame: GuiObject,
	Callback: ((Info: {}, Input: InputObject) -> ())?,
	Options: {
		GetDPIScale: (() -> number)?,
	}?
)
	Callback = Callback or DefaultCallback
	Options = Options or {}

	DragFrame.InputBegan:Connect(function(Input: InputObject)
		if not InputUtils.IsClickInput(Input) then
			return
		end

		Drag.Dragging = true
		Drag.Frame = Frame
		Drag.FramePosition = Frame.Position
		Drag.StartPosition = Input.Position
		Drag.FrameSize = Frame.Size
		Drag.Callback = Callback
		Drag.GetDPIScale = Options.GetDPIScale

		Drag.ChangedConnection = Input.Changed:Connect(function()
			if Input.UserInputState ~= Enum.UserInputState.End then
				return
			end

			Drag.Dragging = false
			Drag.Frame = nil
			Drag.Callback = nil
			Drag.GetDPIScale = nil

			if Drag.ChangedConnection and Drag.ChangedConnection.Connected then
				Drag.ChangedConnection:Disconnect()
				Drag.ChangedConnection = nil
			end
		end)
	end)
end

wax.shared.Connect(wax.shared.UserInputService.InputChanged:Connect(function(Input: InputObject)
	if Drag.Dragging and Drag.Callback and InputUtils.IsMoveInput(Input) then
		Drag.Callback(Drag, Input)
	end
end))

return Drag
