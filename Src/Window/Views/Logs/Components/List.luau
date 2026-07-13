--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Constants = require("@src/Window/Constants")
local Types = require("@src/Window/Types")

local DirectionTabs = require(script.Parent.DirectionTabs)
local Ratelimiter = require("@src/Utils/Ratelimiter")

--// UI \\--
return function(props: {
	MainFrame: GuiObject,
	LogsPage: Types.LogsPage,
	ContextMenu: any,
})
	local LogsPage = props.LogsPage
	local ContextMenu = props.ContextMenu

	local List = {
		CurrentTab = nil,
		PendingLogButtonUpdates = {},
		IsLogButtonUpdateQueued = false,
	}

	--// UI \\--
	local LeftList = Interface.New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.yAxis,
		Size = UDim2.new(0, 240, 1, -36),
		Position = UDim2.fromScale(0, 1),
		Parent = props.MainFrame,

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},
	})

	local RemoteTabContainer = Interface.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = LeftList,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		},
	})

	local RemoteListWrapper = Interface.New("Frame", {
		AnchorPoint = Vector2.yAxis,
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 1, -36),
		Parent = LeftList,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		},
	})

	local RemoteList = Interface.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 2,
		Parent = RemoteListWrapper,

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 6),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},
	})

	List.Frame = LeftList
	List.RemoteList = RemoteList

	--// Functions \\--
	local function EstimateCounterWidth(Text: string, TextSize: number): number
		return math.ceil(#Text * TextSize * 0.42)
	end

	local function UpdateLogNameSize(Log)
		local TextSizeX = EstimateCounterWidth(Log.Button.Calls.Text, Log.Button.Calls.TextSize)
		Log.Button.Name.Size = UDim2.new(1, -(TextSizeX + 24), 1, 0)
	end

	function List:CreateLogButton(Log): (TextButton, TextLabel, TextLabel)
		local Button = Interface.New("TextButton", {
			BackgroundColor3 = Color3.fromRGB(50, 50, 50),
			BackgroundTransparency = 1,
			LayoutOrder = Log.Index or 1,
			Size = UDim2.new(1, 0, 0, 30),
			Text = "",

			["ImageLabel"] = {
				Image = Constants.InstanceClassImages[Log.Instance.ClassName],
				Size = UDim2.fromScale(1, 1),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
			},

			["UICorner"] = {
				CornerRadius = UDim.new(0, 4),
			},

			["UIPadding"] = {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			},
		})

		local Name = Interface.New("TextLabel", {
			Position = UDim2.fromOffset(24, 0),
			Size = UDim2.new(1, -24, 1, 0),
			Text = "",
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,

			Parent = Button,
		})

		local Calls = Interface.New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,

			Parent = Button,
		})

		Button.MouseButton1Click:Connect(function()
			if LogsPage.GetCurrentLog() == Log then
				return
			end

			LogsPage.ShowLog(Log)
		end)

		local ContextMenuOptions = {
			{
				Text = function()
					return Log.Ignored and "Unignore" or "Ignore"
				end,
				Icon = function()
					return Log.Ignored and "eye" or "eye-off"
				end,
				Callback = function()
					Log:Ignore()
					wax.shared.Sonner.success(`{Log.Ignored and "Started" or "Stopped"} ignoring event`)
				end,
			},
			{
				Text = function()
					return Log.Blocked and "Unblock" or "Block"
				end,
				Icon = function()
					return Log.Blocked and "lock" or "lock-open"
				end,
				Callback = function()
					Log:Block()

					local BlockedRemoteList = wax.shared.Settings["BlockedRemotes"]
					if BlockedRemoteList then
						if Log.Blocked then
							BlockedRemoteList:AddToList(Log)
						else
							BlockedRemoteList:RemoveFromList(Log)
						end
					end

					wax.shared.Sonner.success(`{Log.Blocked and "Started" or "Stopped"} blocking event`)
				end,
			},
			{
				Text = "Clear Logs",
				Icon = "trash",
				Callback = function()
					LogsPage.ClearLogs(Log.Instance, Log.Type)
				end,
			},
		}

		local PluginManager = wax.shared.CobaltPluginManager
		if PluginManager and PluginManager.Registry.UIHooks.ContextMenus.RemoteList then
			for _, Option in PluginManager.Registry.UIHooks.ContextMenus.RemoteList do
				table.insert(ContextMenuOptions, {
					Text = Option.Text,
					Icon = Option.Icon,
					Callback = function()
						task.spawn(Option.Callback, Log)
					end,
				})
			end
		end

		local LogContextMenu = ContextMenu:Create(Button, ContextMenuOptions, true)
		Button.MouseButton2Click:Connect(LogContextMenu.Toggle)
		LogContextMenu:BindLongPress(Button)

		return Button, Name, Calls
	end

	function List:EnsureLogButton(Log)
		if Log.Button then
			return Log.Button
		end

		local Button, Name, Calls = self:CreateLogButton(Log)
		Log:SetButton(Button, Name, Calls)
		return Log.Button
	end

	function List:RemoveLogButton(Log)
		self.PendingLogButtonUpdates[Log] = nil

		if not Log.Button then
			return
		end

		Log.Button.Instance:Destroy()
		Log.Button = nil
	end

	function List:RefreshLogButton(Log)
		if not (Log.Button and self.CurrentTab and self.CurrentTab.Logs[Log.Instance] == Log) then
			return
		end

		Log.Button.Name.Text = Log.Instance.Name
		Log.Button.Calls.Text = "x" .. #Log.Calls
		UpdateLogNameSize(Log)

		Log.Button.Instance.Parent = if #Log.Calls == 0 then nil else RemoteList
	end

	local function FlushLogButtonUpdates()
		List.IsLogButtonUpdateQueued = false

		for Log in List.PendingLogButtonUpdates do
			List.PendingLogButtonUpdates[Log] = nil
			List:RefreshLogButton(Log)
		end
	end

	local LogButtonUpdateLimiter = Ratelimiter.new({
		Burst = {
			Time = 0.1,
			Max = 1,
		},
		MainCallback = FlushLogButtonUpdates,
	})

	function List:QueueLogButtonUpdate(Log)
		self.PendingLogButtonUpdates[Log] = true

		if self.IsLogButtonUpdateQueued then
			return
		end

		self.IsLogButtonUpdateQueued = true
		LogButtonUpdateLimiter:QueueOperation()
	end

	function List:ShowTab(Tab)
		for _, Object in pairs(RemoteList:GetChildren()) do
			if Object.ClassName == "TextButton" then
				Object.Parent = nil
			end
		end

		self.CurrentTab = Tab

		for _, Log in pairs(Tab.Logs) do
			if #Log.Calls == 0 then
				continue
			end

			self:EnsureLogButton(Log)
			self:RefreshLogButton(Log)
		end
	end

	local Tabs = DirectionTabs({
		Parent = RemoteTabContainer,
		OnSelected = function(Tab)
			List:ShowTab(Tab)
		end,
	})

	Tabs:Create("Outgoing", true, wax.shared.Logs.Outgoing)
	Tabs:Create("Incoming", false, wax.shared.Logs.Incoming)
	Tabs:Select(Tabs.Tabs.Outgoing, true)

	List.Tabs = Tabs

	return List
end
