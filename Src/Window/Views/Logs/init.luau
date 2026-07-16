--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Constants = require("@src/Window/Constants")
local Types = require("@src/Window/Types")
local LogStore = require("@src/Utils/LogStore")

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
	local LogsPage = {
		State = {
			SelectedPageByLog = {},
			CurrentLog = nil,
		},
	}

	local LogList
	local LogCalls

	function LogsPage.CleanLogsList()
		LogCalls:CleanLogsList()
	end

	function LogsPage.ShowLog(Log)
		return LogCalls:ShowLog(Log)
	end

	function LogsPage.GetCurrentLog()
		return LogsPage.State.CurrentLog
	end

	function LogsPage.RefreshCurrentLog()
		local CurrentLog = LogsPage.GetCurrentLog()
		if not CurrentLog then
			return
		end

		props.PaginationManager:SetPage(1)
		LogsPage.State.SelectedPageByLog[CurrentLog] = 1
		LogsPage.ShowLog(CurrentLog)
	end

	function LogsPage.ClearLogs(FilterInstance: Instance?, FilterType: Types.LogDirection?)
		local ClearedLogs = LogStore.Clear(FilterInstance, FilterType)
		for _, Log in ClearedLogs do
			LogList:RemoveLogButton(Log)
			LogsPage.State.SelectedPageByLog[Log] = nil
		end

		LogCalls:CleanLogsList()

		local CurrentLog = LogsPage.GetCurrentLog()
		if not FilterInstance or (CurrentLog and CurrentLog.Instance == FilterInstance) then
			LogsPage.State.CurrentLog = nil
		end

		if #ClearedLogs > 0 then
			wax.shared.Sonner.success(
				`Successfully Cleared {FilterInstance and FilterInstance.Name .. " " or ""}{FilterType or "All"} Logs`
			)
		end
	end

	--// Components \\--
	LogList = require(script.Components.List)({
		MainFrame = MainFrame,
		LogsPage = LogsPage,
		ContextMenu = ContextMenu,
	})

	LogCalls = require(script.Components.Calls)({
		MainFrame = MainFrame,
		Window = Window,
		LogsPage = LogsPage,
		ContextMenu = ContextMenu,
		PaginationManager = props.PaginationManager,
		GetCurrentTab = function()
			return LogList.CurrentTab
		end,
	})

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

			Info.Frame.Position =
				UDim2.new(FramePosition.X.Scale, Offset, FramePosition.Y.Scale, FramePosition.Y.Offset)

			LogList.Frame.Size = UDim2.new(0, Offset, 1, -36)
			LogCalls.Wrapper.Size = UDim2.new(1, -(Offset + 2), 1, -36)
		end, {
			GetDPIScale = props.GetDPIScale,
		})
	end

	LogsPage.LogList = LogList
	LogsPage.LogCalls = LogCalls

	wax.shared.Connect(wax.shared.Communicator.Event:Connect(function(Batch)
		if typeof(Batch) ~= "table" then
			return
		end

		local CurrentTab = LogList.CurrentTab
		if not CurrentTab then
			return
		end

		for _, Notification in Batch do
			local Type = Notification.Type
			if CurrentTab.Name ~= Type then
				continue
			end

			local Instance = Notification.Instance
			local CallIndex = Notification.CallIndex
			local LogIndex = Notification.LogIndex

			-- RakNet callbacks can expose an equivalent Instance through a different
			-- userdata identity. BindableEvents also strip table metatables, so pass a
			-- scalar index and resolve the original Log in this context instead.
			local Log = wax.shared.Logs[Type][Instance]
			if not Log and LogIndex ~= nil then
				for _, Candidate in wax.shared.Logs[Type] do
					if Candidate.Index == LogIndex then
						Log = Candidate
						break
					end
				end
			end

			if not Log or #Log.Calls == 0 then
				continue
			end

			LogList:EnsureLogButton(Log)
			LogList:QueueLogButtonUpdate(Log)
			LogCalls:HandleCallAdded(Log, CallIndex)
		end
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

	return LogsPage
end
