--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Constants = require("@src/Window/Constants")
local Types = require("@src/Window/Types")

local ArgumentList = require("@src/Window/Modals/Info/Components/ArgumentList")
local CodeGen = require("@src/Utils/CodeGen/Generator")
local InstanceSerializer = require("@src/Utils/CodeGen/Serializer/Instance")
local Ratelimiter = require("@src/Utils/Ratelimiter")

--// UI \\--
return function(props: {
	MainFrame: GuiObject,
	Window: Types.Window,
	ContextMenu: any,
	PaginationManager: Types.PaginationManager,
	GetCurrentTab: () -> Types.LogDirectionTab?,
})
	local Window = props.Window
	local ContextMenu = props.ContextMenu
	local PaginationManager = props.PaginationManager

	local Calls = {
		ActiveCallInfo = nil,
		SharedCallContextMenu = nil,
		CallFramePool = {},
		CallFrameData = setmetatable({}, { __mode = "k" }),
		CurrentCallFrameRenderGeneration = 0,
	}

	--// UI \\--
	local LogsWrapper = Interface.New("Frame", {
		AnchorPoint = Vector2.one,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(1, -242, 1, -36),
		Parent = props.MainFrame,

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 6),
		},
	})

	local LogsList = Interface.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -38),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 2,
		Parent = LogsWrapper,

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 6),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		},
	})

	local LogsPagination = Interface.New("Frame", {
		AnchorPoint = Vector2.yAxis,
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 32),
		Parent = LogsWrapper,

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		},
	})

	Calls.Wrapper = LogsWrapper
	Calls.List = LogsList
	Calls.Pagination = LogsPagination

	--// Helpers \\--
	local function IsShowingExecutorLogs(): boolean
		local Setting = wax.shared.Settings.ShowExecutorLogs
		return not Setting or Setting.Value == true
	end

	local function GetVisibleCallCount(Log): number
		return if IsShowingExecutorLogs() then #Log.Calls else #Log.GameCalls
	end

	local function GetCallByVisibleIndex(Log, VisibleIndex: number)
		local CallIndex = if IsShowingExecutorLogs() then VisibleIndex else Log.GameCalls[VisibleIndex]
		if not CallIndex then
			return nil, nil
		end

		return Log.Calls[CallIndex], CallIndex
	end

	local function GetVisibleIndexForCall(Log, CallIndex: number): number?
		if IsShowingExecutorLogs() then
			return CallIndex
		end

		return table.find(Log.GameCalls, CallIndex)
	end

	local function CopyToClipboard(Text: string, SuccessMessage: string, ErrorMessage: string)
		local Success, Error = pcall(setclipboard, Text)
		if Success then
			wax.shared.Sonner.success(SuccessMessage)
		else
			wax.shared.Sonner.error(ErrorMessage)
			warn(ErrorMessage, Error)
		end
	end

	local function GetActiveCallInfo()
		return Calls.ActiveCallInfo
	end

	local function BuildCallContextMenuOptions()
		local ContextMenuOptions = {
			{
				Text = "Copy Calling Code",
				Icon = "forward",
				Callback = function()
					local CallInfo = GetActiveCallInfo()
					if not CallInfo then
						return
					end

					CopyToClipboard(
						CodeGen:BuildCallCode(CallInfo),
						"Copied code to clipboard",
						"Failed to copy code to clipboard"
					)
				end,
			},
			{
				Text = "Copy Intercept Code",
				Icon = "shield-alert",
				Callback = function()
					local CallInfo = GetActiveCallInfo()
					local CurrentTab = props.GetCurrentTab()
					if not (CallInfo and CurrentTab) then
						return
					end

					CopyToClipboard(
						CodeGen:BuildHookCode(CallInfo, CurrentTab.Name),
						"Copied code to clipboard",
						"Failed to copy code to clipboard"
					)
				end,
			},
			{
				Text = "Copy Remote Path",
				Icon = "package-search",
				Callback = function()
					local CallInfo = GetActiveCallInfo()
					if not CallInfo then
						return
					end

					CopyToClipboard(
						InstanceSerializer.Serialize(CallInfo.Instance, {
							VariableName = "Event",
							DisableNilParentHandler = false,
						}),
						"Copied remote path to clipboard",
						"Failed to copy remote path to clipboard"
					)
				end,
			},
			{
				Text = "Copy Script Path",
				Icon = "file-search",
				Condition = function()
					local CallInfo = GetActiveCallInfo()
					return CallInfo and typeof(CallInfo.Origin) == "Instance"
				end,
				Callback = function()
					local CallInfo = GetActiveCallInfo()
					if not (CallInfo and typeof(CallInfo.Origin) == "Instance") then
						return
					end

					CopyToClipboard(
						InstanceSerializer.Serialize(CallInfo.Origin),
						"Copied script path to clipboard",
						"Failed to copy script path to clipboard"
					)
				end,
			},
			{
				Text = "Replay",
				Icon = "play",
				Callback = function()
					local CallInfo = GetActiveCallInfo()
					if not CallInfo then
						return
					end

					wax.shared.Sonner.promise(function()
						CodeGen:ReplayCallInfo(CallInfo)
					end, {
						loadingText = "Replaying event...",
						successText = "Replayed event successfully!",
						errorText = "Failed to replay event",
						time = 4.5,
					})
				end,
			},
		}

		local PluginManager = wax.shared.CobaltPluginManager
		if PluginManager and PluginManager.Registry.UIHooks.ContextMenus.CallList then
			for _, Option in PluginManager.Registry.UIHooks.ContextMenus.CallList do
				table.insert(ContextMenuOptions, {
					Text = Option.Text,
					Icon = Option.Icon,
					Callback = function()
						local CallInfo = GetActiveCallInfo()
						if CallInfo then
							task.spawn(Option.Callback, CallInfo)
						end
					end,
				})
			end
		end

		return ContextMenuOptions
	end

	local function GetSharedCallContextMenu()
		if not Calls.SharedCallContextMenu then
			Calls.SharedCallContextMenu = ContextMenu:Create(LogsList, BuildCallContextMenuOptions(), true)
		end

		return Calls.SharedCallContextMenu
	end

	local function ClearCallFrameContent(CallFrame)
		for _, Child in CallFrame:GetChildren() do
			if Child:IsA("UIListLayout") or Child:IsA("UIPadding") or Child:IsA("UICorner") or Child:IsA("UIStroke") then
				continue
			end

			Child:Destroy()
		end
	end

	function Calls:ReleaseCallFrame(CallFrame)
		CallFrame.Parent = nil
		table.insert(self.CallFramePool, CallFrame)
	end

	function Calls:AcquireCallFrame()
		local CallFrame = table.remove(self.CallFramePool)
		if CallFrame then
			ClearCallFrameContent(CallFrame)
			return CallFrame
		end

		CallFrame = Interface.New("TextButton", {
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),
			Text = "",

			["UIListLayout"] = {
				Padding = UDim.new(0, 6),
			},

			["UIPadding"] = {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			},

			Constants.MainUICorner,
		})

		local HighlightStroke = Interface.New("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 2,
			Transparency = 1,

			Parent = CallFrame,
		})

		self.CallFrameData[CallFrame] = {
			HighlightStroke = HighlightStroke,
		}

		CallFrame.MouseEnter:Connect(function()
			local Data = self.CallFrameData[CallFrame]
			if not Data then
				return
			end

			wax.shared.TweenService
				:Create(Data.HighlightStroke, Constants.DefaultTweenInfo, {
					Transparency = 0,
				})
				:Play()
		end)

		CallFrame.MouseLeave:Connect(function()
			local Data = self.CallFrameData[CallFrame]
			if not Data then
				return
			end

			wax.shared.TweenService
				:Create(Data.HighlightStroke, Constants.DefaultTweenInfo, {
					Transparency = if Data.IsBlockedCall then 0.5 else 1,
				})
				:Play()
		end)

		CallFrame.MouseButton1Click:Connect(function()
			local Data = self.CallFrameData[CallFrame]
			if Data and Data.CallInfo and wax.shared.OpenRemoteInfo then
				wax.shared.OpenRemoteInfo(Data.CallInfo)
			end
		end)

		CallFrame.MouseButton2Click:Connect(function()
			local Data = self.CallFrameData[CallFrame]
			if not (Data and Data.CallInfo) then
				return
			end

			self.ActiveCallInfo = Data.CallInfo
			GetSharedCallContextMenu().Open()
		end)

		return CallFrame
	end

	function Calls:CreateCallFrame(CallInfo)
		if not IsShowingExecutorLogs() and not CallInfo.Origin then
			return
		end

		local IsBlockedCall = CallInfo.Blocked == true
		local CallFrame = self:AcquireCallFrame()
		local Data = self.CallFrameData[CallFrame]
		Data.CallInfo = CallInfo
		Data.IsBlockedCall = IsBlockedCall

		CallFrame.BackgroundColor3 = if IsBlockedCall then Color3.fromRGB(34, 18, 18) else Color3.fromRGB(25, 25, 25)
		CallFrame.LayoutOrder = CallInfo.Order
		Data.HighlightStroke.Color = if IsBlockedCall then Color3.fromRGB(222, 82, 82) else Color3.fromRGB(75, 75, 75)
		Data.HighlightStroke.Transparency = if IsBlockedCall then 0.5 else 1
		CallFrame.Parent = LogsList

		local InitialDataView = if CallInfo.Type == "Incoming" and CallInfo.InvokeResult then "InvokeResult" else "Arguments"
		local CallInfoValues = CallInfo[InitialDataView] or {}
		local CallInfoValueCount = wax.shared.GetTableLength(CallInfoValues)

		local ArgumentsFrame = Interface.New("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = if IsBlockedCall then Color3.fromRGB(24, 13, 13) else Color3.fromRGB(15, 15, 15),
			Size = UDim2.fromScale(1, 0),
			Visible = CallInfoValueCount > 0,

			["UIListLayout"] = {
				Padding = UDim.new(0, 6),
			},

			["UIPadding"] = {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			},

			Constants.MainUICorner,

			Parent = CallFrame,
		})
		do
			for Index = 1, CallInfoValueCount do
				if Index % 25 == 0 then
					task.wait()
				end

				ArgumentList.CreateHolder(Index, CallInfoValues[Index], ArgumentsFrame, IsBlockedCall)
			end
		end

		local OriginText = CallInfo.IsExecutor and wax.shared.ExecutorName
			or CallInfo.Origin and CallInfo.Origin.Name
			or "Unknown"

		Interface.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),

			Interface.NewIcon(IsBlockedCall and "ban" or CallInfo.IsExecutor and "terminal" or "gamepad-2", {
				AnchorPoint = Vector2.yAxis,
				ImageColor3 = if IsBlockedCall then Color3.fromRGB(255, 151, 151) else Color3.new(1, 1, 1),
				ImageTransparency = 0.5,
				Position = UDim2.new(0, 2, 1, 0),
				Size = UDim2.fromOffset(22, 22),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
			}),

			Interface.New("TextLabel", {
				AnchorPoint = Vector2.yAxis,
				Position = UDim2.new(0, 30, 1, 0),
				Size = UDim2.new(0.5, -24, 0, 22),
				BackgroundTransparency = 1,
				Text = if IsBlockedCall then `{OriginText} (Blocked)` else OriginText,
				TextColor3 = if IsBlockedCall then Color3.fromRGB(255, 190, 190) else Color3.new(1, 1, 1),
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTransparency = 0.5,
			}),

			Interface.New("TextLabel", {
				AnchorPoint = Vector2.one,
				Position = UDim2.new(1, -2, 1, 0),
				Size = UDim2.new(0.5, -2, 0, 22),
				BackgroundTransparency = 1,
				Text = "Time: " .. os.date("%X", CallInfo.CreationTime),
				TextColor3 = if IsBlockedCall then Color3.fromRGB(255, 190, 190) else Color3.new(1, 1, 1),
				TextSize = 16,
				TextTransparency = 0.5,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),

			Parent = CallFrame,
		})

		return CallFrame
	end

	local CreateCallFrameLimiter = Ratelimiter.new({
		Burst = {
			Time = 0.1,
			Max = 5,
		},
		MainCallback = function(Data)
			if Data.RenderGeneration and Data.RenderGeneration ~= Calls.CurrentCallFrameRenderGeneration then
				return
			end

			Calls:CreateCallFrame(Data)
		end,
	})

	function Calls:CleanLogsList()
		self.CurrentCallFrameRenderGeneration += 1
		for _, Object in pairs(LogsList:GetChildren()) do
			if Object.ClassName == "TextButton" then
				self:ReleaseCallFrame(Object)
			end
		end
	end

	function Calls:ShowCalls(Log, Page)
		self.CurrentCallFrameRenderGeneration += 1
		local RenderGeneration = self.CurrentCallFrameRenderGeneration
		local Start, End = PaginationManager:GetIndexRanges(Page)

		for VisibleIndex = Start, End do
			local Call = GetCallByVisibleIndex(Log, VisibleIndex)
			if not Call then
				break
			end

			local Data = setmetatable({
				Instance = Log.Instance,
				Type = Log.Type,
				Order = VisibleIndex,
				RenderGeneration = RenderGeneration,
			}, {
				__index = Call,
			})

			CreateCallFrameLimiter:QueueOperation(Data)
		end
	end

	function Calls:CreatePaginationEllipsis(Order: number, Visible: boolean)
		local Ellipsis = {
			Ellipsis = Interface.New("TextBox", {
				BackgroundColor3 = Color3.fromRGB(25, 25, 25),
				Size = UDim2.fromScale(1, 1),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = Order,
				PlaceholderText = "-",
				Text = "",
				TextSize = 15,
				RichText = false,
				Parent = Visible and LogsPagination or nil,

				["UICorner"] = {
					CornerRadius = UDim.new(0, 4),
				},
			}),
		}

		function Ellipsis:SetVisible(Visible: boolean)
			if not Visible then
				self.Ellipsis.Text = ""
			end

			self.Ellipsis.Parent = Visible and LogsPagination or nil
		end

		Ellipsis.Ellipsis.FocusLost:Connect(function(EnterPressed)
			if not EnterPressed then
				return
			end

			local Page = tonumber(Ellipsis.Ellipsis.Text)
			local CurrentLog = Window.State.CurrentLog
			if not (Page and CurrentLog and math.floor(Page) == Page and math.abs(Page) == Page and Page ~= 0) then
				wax.shared.Sonner.error("Invalid page number provided!")
				Ellipsis.Ellipsis.Text = ""
				return
			end

			local Success = pcall(function()
				PaginationManager:SetPage(Page)
				Window.State.SelectedPageByLog[CurrentLog] = Page
				self:ShowLog(CurrentLog)
			end)

			if not Success then
				wax.shared.Sonner.error("Invalid page number provided!")
			end

			Ellipsis.Ellipsis.Text = ""
		end)

		return Ellipsis
	end

	function Calls:CreatePaginationButton(Order: number, Active: boolean, Visible: boolean)
		local ButtonData = {
			Button = Interface.New("TextButton", {
				BackgroundColor3 = Active and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25),
				Size = UDim2.fromScale(1, 1),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Text = tostring(1),
				LayoutOrder = Order,
				TextSize = 15,
				Parent = Visible and LogsPagination or nil,

				["UICorner"] = {
					CornerRadius = UDim.new(0, 4),
				},
			}),
		}

		function ButtonData:SetActive(Active: boolean)
			self.Button.BackgroundColor3 = Active and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
		end

		function ButtonData:SetText(Text: string)
			self.Button.Text = Text
		end

		function ButtonData:SetVisible(Visible: boolean)
			self.Button.Parent = Visible and LogsPagination or nil
		end

		ButtonData.Button.MouseButton1Click:Connect(function()
			local CurrentLog = Window.State.CurrentLog
			local Page = tonumber(ButtonData.Button.Text)
			if not (CurrentLog and Page) then
				return
			end

			PaginationManager:SetPage(Page)
			Window.State.SelectedPageByLog[CurrentLog] = Page
			self:ShowLog(CurrentLog)
		end)

		return ButtonData
	end

	local MaxButtons = 5 + ((PaginationManager.Helper and PaginationManager.Helper.SiblingCount) or 2) * 2
	local PaginationElements = {
		Buttons = {},
		Ellipsis = {
			[2] = Calls:CreatePaginationEllipsis(1, false),
			[MaxButtons - 1] = Calls:CreatePaginationEllipsis(MaxButtons - 1, false),
		},
	}
	for Index = 1, MaxButtons do
		table.insert(PaginationElements.Buttons, Calls:CreatePaginationButton(Index, false, false))
	end

	function Calls:ShowPagination(Log)
		local Pages = PaginationManager:GetVisualInfo()
		for Order, Info in pairs(Pages) do
			if Info == "none" then
				local Ellipsis = PaginationElements.Ellipsis[Order]
				if Ellipsis then
					Ellipsis:SetVisible(false)
				end

				local Button = PaginationElements.Buttons[Order]
				if Button then
					Button:SetVisible(false)
				end

				continue
			elseif Info == "ellipsis" then
				local Ellipsis = PaginationElements.Ellipsis[Order]
				if Ellipsis then
					Ellipsis:SetVisible(true)
				end

				local Button = PaginationElements.Buttons[Order]
				if Button then
					Button:SetVisible(false)
				end

				continue
			end

			local Ellipsis = PaginationElements.Ellipsis[Order]
			if Ellipsis then
				Ellipsis:SetVisible(false)
			end

			local Button = PaginationElements.Buttons[Order]
			if Button then
				Button:SetVisible(true)
				Button:SetText(tostring(Info))
				Button:SetActive(Window.State.SelectedPageByLog[Log] == Info)
			end
		end
	end

	function Calls:ShowLog(Log)
		self:CleanLogsList()
		if not Log then
			return
		end

		local CurrentLog = Window.State.CurrentLog
		if CurrentLog ~= Log then
			if CurrentLog and CurrentLog.Button then
				wax.shared.TweenService
					:Create(CurrentLog.Button.Instance, Constants.DefaultTweenInfo, {
						BackgroundTransparency = 1,
					})
					:Play()
			end

			Window.State.CurrentLog = Log
			if Log.Button then
				wax.shared.TweenService
					:Create(Log.Button.Instance, Constants.DefaultTweenInfo, {
						BackgroundTransparency = 0,
					})
					:Play()
			end
		end

		local VisibleCount = GetVisibleCallCount(Log)
		local Page = Window.State.SelectedPageByLog[Log] or 1
		Window.State.SelectedPageByLog[Log] = Page

		PaginationManager:Update(VisibleCount)
		local PageSet = pcall(function()
			PaginationManager:SetPage(Page)
		end)
		if not PageSet then
			Page = 1
			Window.State.SelectedPageByLog[Log] = Page
			PaginationManager:SetPage(Page)
		end

		LogsList.CanvasPosition = Vector2.zero
		self:ShowPagination(Log)
		self:ShowCalls(Log, Page)
	end

	function Calls:HandleCallAdded(Log, CallIndex: number)
		if Window.State.CurrentLog ~= Log then
			return
		end

		local VisibleIndex = GetVisibleIndexForCall(Log, CallIndex)
		if not VisibleIndex then
			return
		end

		local Page = Window.State.SelectedPageByLog[Log] or 1
		Window.State.SelectedPageByLog[Log] = Page
		PaginationManager:Update(GetVisibleCallCount(Log))

		local Start, End = PaginationManager:GetIndexRanges(Page)
		if VisibleIndex < Start or VisibleIndex > End then
			self:ShowPagination(Log)
			return
		end

		local Call = Log.Calls[CallIndex]
		if not Call then
			return
		end

		local Data = setmetatable({
			Instance = Log.Instance,
			Type = Log.Type,
			Order = VisibleIndex,
		}, {
			__index = Call,
		})

		CreateCallFrameLimiter:QueueOperation(Data)
	end

	return Calls
end
