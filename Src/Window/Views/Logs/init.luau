--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Constants = require("@src/Window/Constants")
local Types = require("@src/Window/Types")

local Drag = require("@src/Window/Utils/Input/Drag")
local Input = require("@src/Window/Utils/Input/Input")

--// UI \\--
return function(props: {
	MainFrame: GuiObject,
	Window: Types.Window,
	ContextMenu: any,
	PaginationManager: Types.PaginationManager,
	GetDPIScale: () -> number,
})
    --// Props \\--
	local MainFrame = props.MainFrame
	local Window = props.Window
	local ContextMenu = props.ContextMenu

    --// Components \\--
	local LogList = require(script.Components.List){
		MainFrame = MainFrame,
		Window = Window,
		ContextMenu = ContextMenu,
	}

	local LogCalls = require(script.Components.Calls){
		MainFrame = MainFrame,
		Window = Window,
		ContextMenu = ContextMenu,
		PaginationManager = props.PaginationManager,
		GetCurrentTab = function()
			return LogList.CurrentTab
		end,
	}

	--// Resizer \\--
	local RemoteListLine = Interface.New("Frame", {
		AnchorPoint = Vector2.yAxis,
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Position = UDim2.new(0, 240, 1, 0),
		Size = UDim2.new(0, 2, 1, -36),
		Parent = MainFrame,
	})

	local RemoteListResize = Interface.New("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 4, 1, 0),
		Text = "",

		Parent = RemoteListLine,
	})
	do
		RemoteListResize.MouseEnter:Connect(function()
			wax.shared.TweenService
				:Create(RemoteListLine, Constants.DefaultTweenInfo, {
					BackgroundColor3 = Color3.fromRGB(50, 50, 50),
				})
				:Play()
		end)
		RemoteListResize.MouseLeave:Connect(function()
			wax.shared.TweenService
				:Create(RemoteListLine, Constants.DefaultTweenInfo, {
					BackgroundColor3 = Color3.fromRGB(25, 25, 25),
				})
				:Play()
		end)
        
        Drag.Setup(RemoteListLine, RemoteListResize, function(Info, InputObject: InputObject)
            local Delta = (InputObject.Position - Info.StartPosition) / props.GetDPIScale()
            local FramePosition: UDim2 = Info.FramePosition
            local Offset = math.clamp(FramePosition.X.Offset + Delta.X, 120, (MainFrame.AbsoluteSize.X - 2) / 2)
    
            Info.Frame.Position = UDim2.new(FramePosition.X.Scale, Offset, FramePosition.Y.Scale, FramePosition.Y.Offset)
    
            LogList.Frame.Size = UDim2.new(0, Offset, 1, -36)
            LogCalls.Wrapper.Size = UDim2.new(1, -(Offset + 2), 1, -36)
        end, {
            GetDPIScale = props.GetDPIScale,
        })
	end

	local LogsView = {
		LogList = LogList,
		LogCalls = LogCalls,
	}

	function LogsView.CleanLogsList()
		LogCalls:CleanLogsList()
	end

	function LogsView.ShowLog(Log)
		return LogCalls:ShowLog(Log)
	end

	Window.Functions.BindListView(LogsView)

	wax.shared.Connect(wax.shared.Communicator.Event:Connect(function(Instance, Type, CallIndex)
		local CurrentTab = LogList.CurrentTab
		if not (CurrentTab and CurrentTab.Name == Type) then
			return
		end

		local Log = wax.shared.Logs[Type][Instance]
		if not Log or #Log.Calls == 0 then
			return
		end

		LogList:EnsureLogButton(Log)
		LogList:QueueLogButtonUpdate(Log)
		LogCalls:HandleCallAdded(Log, CallIndex)
	end))

	wax.shared.Connect(wax.shared.UserInputService.InputBegan:Connect(function(InputObject: InputObject)
		if not Input.IsClickInput(InputObject) then
			return
		end

		local CurrentContext = ContextMenu.CurrentContext
		if
			CurrentContext
			and not (
				Input.IsMouseOverFrame(ContextMenu.Frame, InputObject.Position)
				or Input.IsMouseOverFrame(CurrentContext.Parent, InputObject.Position)
			)
		then
			CurrentContext:Close()
		end
	end))

	return LogsView
end
