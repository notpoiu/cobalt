local Interface = require("@src/Utils/UI/Interface")
local Icons = require("@src/Utils/UI/Assets/Icons")
local Constants = require("@src/Window/Constants")
local Types = require("@src/Window/Types")
local Operators = require("@src/Utils/CallFilter/Operators")
local RemoteFields = require("@src/Utils/CallFilter/RemoteFields")

type CallFilter = Types.CallFilter
type CallFilterManager = Types.CallFilterManager

local ActionColors = {
	Ignore = Color3.fromRGB(105, 105, 105),
	Block = Color3.fromRGB(205, 75, 75),
	Highlight = Color3.fromRGB(230, 170, 65),
}

local function FormatDirection(Direction): string
	return if Direction == "Any" then "Any direction" else Direction
end

local function FormatTargetCondition(Condition): string
	return `{RemoteFields.GetText(Condition.Field)} {Operators.GetText(Condition.Operator, true)} {Operators.FormatValue(Condition.Value)}`
end

local function FormatTarget(Filter: CallFilter): (string, string?)
	if Filter.Target.Type == "Instance" then
		return Filter.Target.Remote.Name, Constants.InstanceClassImages[Filter.Target.Remote.ClassName]
	end

	return "Matching remotes", nil
end

local function FormatSummary(Filter: CallFilter): string
	local Parts = { FormatDirection(Filter.Direction) }
	if Filter.Target.Type == "Query" then
		local FirstTarget = Filter.Target.Conditions[1]
		if FirstTarget then
			local TargetSummary = FormatTargetCondition(FirstTarget)
			if #Filter.Target.Conditions > 1 then
				TargetSummary ..= ` · {#Filter.Target.Conditions} remote conditions`
			end
			table.insert(Parts, TargetSummary)
		end
	end

	local First = Filter.Conditions[1]
	if not First then
		table.insert(Parts, "All arguments")
		return table.concat(Parts, " · ")
	end

	local Subject = if First.Subject.Type == "ArgumentCount" then "#Arg" else `Arg[{First.Subject.Index}]`
	local Summary = `{Subject} {Operators.GetText(First.Operator, true)} {Operators.FormatValue(First.Value)}`
	if #Filter.Conditions > 1 then
		Summary ..= ` · {#Filter.Conditions} conditions`
	end
	table.insert(Parts, Summary)
	return table.concat(Parts, " · ")
end

return function(Props: {
	Parent: GuiObject,
	ContextMenu: any,
	Manager: CallFilterManager,
	OnEdit: (CallFilter) -> (),
	OnDuplicate: (CallFilter) -> (),
	OnDelete: (CallFilter) -> (),
})
	local Root = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		Parent = Props.Parent,
		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 6),
		},
	})

	local EmptyLabel = Interface.New("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		Size = UDim2.new(1, 0, 0, 70),
		Text = "No call filters have been created yet.\nRight-click a captured call to create one.",
		TextSize = 14,
		TextTransparency = 0.5,
		TextWrapped = true,
		Parent = Root,
		["UICorner"] = { CornerRadius = UDim.new(0, 6) },
		["UIStroke"] = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(25, 25, 25),
			Thickness = 1,
		},
	})

	local Rows = {}
	local Refresh
	local ActiveToggleAnimations = 0
	local DeferredFilters
	local function ClearRows()
		for _, Row in Rows do
			Row:Destroy()
		end
		table.clear(Rows)
	end

	local function CreateToggle(Parent: GuiObject, Filter: CallFilter)
		local Toggle = Interface.New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = if Filter.Enabled then Color3.fromRGB(52, 199, 89) else Color3.fromRGB(50, 50, 50),
			Position = UDim2.new(1, -38, 0.5, 0),
			Size = UDim2.fromOffset(32, 18),
			Text = "",
			Parent = Parent,
			["UICorner"] = { CornerRadius = UDim.new(1, 0) },
		})
		local Knob = Interface.New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Position = if Filter.Enabled then UDim2.new(1, -9, 0.5, 0) else UDim2.new(0, 9, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			Parent = Toggle,
			["UICorner"] = { CornerRadius = UDim.new(1, 0) },
		})

		Toggle.MouseButton1Click:Connect(function()
			Toggle.Interactable = false
			local Enabled = not Filter.Enabled
			ActiveToggleAnimations += 1
			Props.Manager:SetEnabled(Filter.Id, Enabled)
			wax.shared.TweenService
				:Create(Toggle, Constants.DefaultTweenInfo, {
					BackgroundColor3 = if Enabled then Color3.fromRGB(52, 199, 89) else Color3.fromRGB(50, 50, 50),
				})
				:Play()
			local KnobTween = wax.shared.TweenService:Create(Knob, Constants.DefaultTweenInfo, {
				Position = if Enabled then UDim2.new(1, -9, 0.5, 0) else UDim2.new(0, 9, 0.5, 0),
			})
			KnobTween:Play()
			KnobTween.Completed:Once(function()
				ActiveToggleAnimations -= 1
				if ActiveToggleAnimations == 0 and DeferredFilters then
					local Filters = DeferredFilters
					DeferredFilters = nil
					Refresh(Filters)
				end
			end)
		end)
	end

	local function CreateRow(Filter: CallFilter)
		local TargetName, TargetImage = FormatTarget(Filter)
		local Row = Interface.New("Frame", {
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			BackgroundTransparency = if Filter.Enabled then 0 else 0.35,
			Size = UDim2.new(1, 0, 0, 52),
			Parent = Root,
			["UICorner"] = { CornerRadius = UDim.new(0, 6) },
			["UIStroke"] = {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(25, 25, 25),
				Thickness = 1,
			},
		})
		table.insert(Rows, Row)

		local TargetIcon = Interface.New("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Image = TargetImage or "",
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			Parent = Row,
		})
		if Filter.Target.Type == "Query" then
			Icons.SetIcon(TargetIcon, "globe")
		end
		local Header = Interface.New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(42, 5),
			Size = UDim2.new(1, -200, 0, 21),
			Parent = Row,
			["UIListLayout"] = {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
			},
		})
		Interface.New("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 1, 0),
			Text = TargetName,
			TextSize = 16,
			TextTransparency = if Filter.Enabled then 0 else 0.4,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = Header,
			["UISizeConstraint"] = { MaxSize = Vector2.new(180, 21) },
		})
		Interface.New("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = ActionColors[Filter.Action] or Color3.fromRGB(75, 75, 75),
			BackgroundTransparency = 0.75,
			Size = UDim2.new(0, 0, 0, 20),
			Text = Filter.Action,
			TextSize = 12,
			Parent = Header,
			["UICorner"] = { CornerRadius = UDim.new(0, 4) },
			["UIPadding"] = { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) },
		})
		Interface.New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(42, 25),
			RichText = false,
			Size = UDim2.new(1, -200, 0, 18),
			Text = FormatSummary(Filter),
			TextSize = 13,
			TextTransparency = 0.55,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = Row,
		})

		CreateToggle(Row, Filter)

		local MoreButton = Interface.New("ImageButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			ImageTransparency = 0.5,
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(22, 22),
			Parent = Row,
		})
		Icons.SetIcon(MoreButton, "ellipsis")
		local Menu = Props.ContextMenu:Create(MoreButton, {
			{
				Text = "Edit",
				Icon = "pencil",
				Callback = function()
					Props.OnEdit(Filter)
				end,
			},
			{
				Text = "Duplicate",
				Icon = "copy",
				Callback = function()
					Props.OnDuplicate(Filter)
				end,
			},
			{
				Text = "Delete",
				Icon = "trash",
				Callback = function()
					Props.OnDelete(Filter)
				end,
			},
		})
		MoreButton.MouseButton1Click:Connect(Menu.Toggle)
	end

	Refresh = function(Filters: { CallFilter })
		ClearRows()
		EmptyLabel.Visible = #Filters == 0
		for _, Filter in Filters do
			CreateRow(Filter)
		end
	end

	local Subscription = Props.Manager:Subscribe(function(Filters)
		if ActiveToggleAnimations > 0 then
			DeferredFilters = Filters
			return
		end
		Refresh(Filters)
	end)
	return {
		Root = Root,
		Refresh = Refresh,
		Destroy = function()
			Subscription:Disconnect()
			Root:Destroy()
		end,
	}
end
