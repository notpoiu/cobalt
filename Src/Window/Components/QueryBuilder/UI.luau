--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Icons = require("@src/Utils/UI/Assets/Icons")
local Constants = require("@src/Window/Constants")
local Types = require("@src/Window/Types")
local RemoteFields = require("@src/Utils/CallFilter/RemoteFields")

--// Types \\--
type Dialog = Types.Dialog
type QueryBuilder = Types.QueryBuilder
type QueryBuilderCondition = Types.QueryBuilderCondition
type QueryBuilderProps = Types.QueryBuilderProps
type QueryFilterAction = Types.QueryFilterAction
type QueryFilterJoin = Types.QueryFilterJoin
type QueryFilterOperator = Types.QueryFilterOperator
type QueryRemoteCondition = Types.QueryRemoteCondition
type QueryRemoteTarget = Types.QueryRemoteTarget

type Select = {
	Container: Frame,
	Value: any,
	SetValue: (Select, any, boolean?) -> (),
}

type Validator = {
	Validate: ({ QueryBuilderCondition }) -> (boolean, { string }, { [number]: boolean }),
	GetConditionType: ({ QueryBuilderCondition }, QueryBuilderCondition) -> string?,
	IsAllowed: ({ QueryBuilderCondition }, QueryBuilderCondition, QueryFilterOperator) -> boolean,
	GetOptions: () -> { { Value: QueryFilterOperator, Text: string } },
	GetTypeNames: () -> { string },
}

--// Constants \\--
local BackgroundColor = Color3.fromRGB(15, 15, 15)
local BorderColor = Color3.fromRGB(35, 35, 35)
local LineColor = Color3.fromRGB(60, 60, 60)
local ErrorColor = Color3.fromRGB(245, 60, 54)

local Actions = {
	{ Value = "Ignore", Text = "Ignore matching calls" },
	{ Value = "Block", Text = "Block matching calls" },
	{ Value = "Highlight", Text = "Highlight matching calls" },
}

local Joins = {
	{ Value = "And", Text = "AND" },
	{ Value = "Or", Text = "OR" },
}

local Scopes = {
	{ Value = "Instance", Text = "This remote" },
	{ Value = "Query", Text = "Matching remotes" },
}

local Directions = {
	{ Value = "Outgoing", Text = "Outgoing" },
	{ Value = "Incoming", Text = "Incoming" },
	{ Value = "Any", Text = "Any direction" },
}

local function EscapeRichText(Text: string): string
	return Text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
end

local UI = {}

local function CopyCondition(Condition: QueryBuilderCondition): QueryBuilderCondition
	return {
		Subject = table.clone(Condition.Subject),
		Operator = Condition.Operator,
		Value = Condition.Value,
		Join = Condition.Join,
	}
end

local function CopyRemoteCondition(Condition: QueryRemoteCondition): QueryRemoteCondition
	return table.clone(Condition)
end

local function CopyTarget(Target: QueryRemoteTarget): QueryRemoteTarget
	local Copy = table.clone(Target)
	if Target.Type == "Query" then
		Copy.Conditions = {}
		for _, Condition in Target.Conditions do
			table.insert(Copy.Conditions, CopyRemoteCondition(Condition))
		end
	end
	return Copy :: any
end

local function GetSubjectValue(Subject): string
	return if Subject.Type == "ArgumentCount" then "ArgumentCount" else `Argument:{Subject.Index}`
end

local function CreateSubject(Value: string)
	if Value == "ArgumentCount" then
		return { Type = "ArgumentCount" }
	end

	return {
		Type = "Argument",
		Index = tonumber(string.match(Value, "^Argument:(%d+)$")) or 1,
	}
end

local function GetRemoteValueOptions(Field)
	local Options = RemoteFields.GetValueOptions(Field)
	if Options and Field == "ClassName" then
		for _, Option in Options do
			Option.Icon = Constants.InstanceClassImages[Option.Value]
		end
	end
	return Options
end

local function CreateMain(Parent: GuiObject)
	return Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = Parent,

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		},
	})
end

local function CreateStage(Main: Frame, LayoutOrder: number, AutomaticSize: Enum.AutomaticSize, Height: number)
	local Stage = Interface.New("Frame", {
		AutomaticSize = AutomaticSize,
		BackgroundTransparency = 1,
		LayoutOrder = LayoutOrder,
		Size = UDim2.new(1, 0, 0, Height),
		Parent = Main,

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		},
	})

	return Stage
end

local function CreateRemoteLeft(Stage: Frame)
	local Left = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = Stage,
	})

	Interface.New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 17),
		Rotation = 45,
		Size = UDim2.fromOffset(11, 11),
		Parent = Left,

		["UIStroke"] = {
			Color = LineColor,
			Thickness = 1,
		},
	})

	Interface.New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = LineColor,
		Position = UDim2.new(0, 5, 1, 0),
		Size = UDim2.new(0, 1, 1, -24),
		Parent = Left,
	})

	Interface.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(23, 17),
		Size = UDim2.new(0, 60, 0, 25),
		Text = "Remote",
		TextSize = 14,
		TextTransparency = 0.25,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Left,
	})

	return Left
end

local function CreateBranchLeft(Stage: Frame, Label: string, Height: number, IsLast: boolean)
	local Left = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, Height),
		Parent = Stage,
	})

	Interface.New("Frame", {
		BackgroundColor3 = LineColor,
		Position = UDim2.fromOffset(5, 0),
		Size = if IsLast then UDim2.new(0, 1, 0.5, 0) else UDim2.new(0, 1, 1, 0),
		Parent = Left,
	})

	Interface.New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = LineColor,
		Position = if IsLast then UDim2.new(0, 6, 0.5, 0) else UDim2.fromOffset(6, 17),
		Size = UDim2.fromOffset(10, 1),
		Parent = Left,
	})

	Interface.New("TextLabel", {
		AutomaticSize = if IsLast then Enum.AutomaticSize.X else Enum.AutomaticSize.XY,
		AnchorPoint = if IsLast then Vector2.new(0, 0.5) else Vector2.zero,
		Position = if IsLast then UDim2.new(0, 23, 0.5, 0) else UDim2.fromOffset(23, 10),
		Size = if IsLast then UDim2.new(0, 60, 1, 0) else UDim2.new(0, 60, 0, 0),
		Text = Label,
		TextSize = 14,
		TextTransparency = 0.25,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Left,
	})

	return Left
end

local function CreateRight(Stage: Frame, AutomaticSize: Enum.AutomaticSize)
	return Interface.New("Frame", {
		AutomaticSize = AutomaticSize,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Size = if AutomaticSize == Enum.AutomaticSize.Y then UDim2.new(1, -83, 0, 0) else UDim2.new(1, -83, 1, 0),
		Parent = Stage,

		["UIPadding"] = {
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		},
	})
end

local function CreateSelect(props: {
	Parent: GuiObject,
	ContextMenu: any,
	Options: { { Value: any, Text: string, Icon: string? } },
	Default: any,
	LayoutOrder: number,
	Text: ((any, string) -> string)?,
	IsOptionAllowed: ((any) -> boolean)?,
	MaxMenuHeight: number?,
	OnChanged: ((any) -> ())?,
}): Select
	local Container = Interface.New("TextButton", {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(0, 0, 1, 0),
		Text = "",
		Parent = props.Parent,

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
		},

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 3),
		},
	})

	local Label = Interface.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 0,
		Size = UDim2.new(0, 0, 1, 0),
		Text = "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Container,
	})
	local SelectedIcon = Interface.New("ImageLabel", {
		LayoutOrder = -1,
		Size = UDim2.fromOffset(15, 15),
		Visible = false,
		Parent = Container,
	})

	Interface.NewIcon("chevron-down", {
		ImageTransparency = 0.5,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(15, 15),
		Parent = Container,
	})

	local Select = {
		Container = Container,
		Value = props.Default,
	} :: Select

	local function FindOption(Value: any)
		for _, Option in props.Options do
			if Option.Value == Value then
				return Option
			end
		end
		return nil
	end

	local Context
	function Select:SetValue(Value: any, SkipCallback: boolean?)
		self.Value = Value
		local Option = FindOption(Value)
		local Text = Option and Option.Text or tostring(Value)
		Label.Text = if props.Text then props.Text(Value, Text) else Text
		SelectedIcon.Visible = Option ~= nil and Option.Icon ~= nil
		if SelectedIcon.Visible then
			SelectedIcon.ImageRectOffset = Vector2.zero
			SelectedIcon.ImageRectSize = Vector2.zero
			if tostring(Option.Icon):match("rbxasset") then
				SelectedIcon.Image = Option.Icon
			else
				Icons.SetIcon(SelectedIcon, Option.Icon)
			end
		end
		if Context then
			Context:Close()
		end
		if not SkipCallback and props.OnChanged then
			props.OnChanged(Value)
		end
	end

	local MenuOptions = {}
	for _, Option in props.Options do
		table.insert(MenuOptions, {
			Text = EscapeRichText(Option.Text),
			Icon = Option.Icon,
			Condition = function()
				return not props.IsOptionAllowed or props.IsOptionAllowed(Option.Value)
			end,
			Callback = function()
				Select:SetValue(Option.Value)
			end,
			TextProperties = function()
				return { TextTransparency = if Select.Value == Option.Value then 0 else 0.5 }
			end,
		})
	end

	Context = props.ContextMenu:Create(
		Container,
		MenuOptions,
		nil,
		if props.MaxMenuHeight then { MaxHeight = props.MaxMenuHeight } else nil
	)
	Container.MouseButton1Click:Connect(Context.Toggle)
	Select:SetValue(props.Default, true)
	return Select
end

local function CreateSeparator(Parent: GuiObject, LayoutOrder: number)
	return Interface.New("Frame", {
		BackgroundColor3 = BorderColor,
		LayoutOrder = LayoutOrder,
		Size = UDim2.new(0, 1, 1, 0),
		Parent = Parent,
	})
end

local function CreateScrollableRow(Parent: GuiObject, LayoutOrder: number)
	local Row = Interface.New("ScrollingFrame", {
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		LayoutOrder = LayoutOrder,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Size = UDim2.new(0, 1, 0, 25),
		Parent = Parent,
	})

	local Content = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = BackgroundColor,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(0, 0, 0, 23),
		Parent = Row,
		["UICorner"] = { CornerRadius = UDim.new(0, 4) },
		["UIStroke"] = { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = BorderColor, Thickness = 1 },
		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 2),
		},
		["UIPadding"] = { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 2) },
	})

	local function UpdateCanvasSize()
		local Layout = Content.UIListLayout
		local Padding = Content.UIPadding
		local CanvasWidth = Content.Position.X.Offset
			+ Layout.AbsoluteContentSize.X
			+ Padding.PaddingLeft.Offset
			+ Padding.PaddingRight.Offset
			+ 1
		local AvailableWidth = math.max(1, Parent.AbsoluteSize.X - 2)
		local ViewportWidth = math.min(CanvasWidth, AvailableWidth)
		Row.Size = UDim2.fromOffset(ViewportWidth, 25)
		Row.CanvasSize = UDim2.fromOffset(CanvasWidth, 0)

		local MaximumX = math.max(0, CanvasWidth - ViewportWidth)
		Row.ScrollingEnabled = MaximumX > 1
		if not Row.ScrollingEnabled then
			Row.CanvasPosition = Vector2.zero
		elseif Row.CanvasPosition.X > MaximumX then
			Row.CanvasPosition = Vector2.new(MaximumX, 0)
		end
	end

	Content.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvasSize)
	Row:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(UpdateCanvasSize)
	Row.InputChanged:Connect(function(Input: InputObject)
		if Input.UserInputType ~= Enum.UserInputType.MouseWheel or not Row.ScrollingEnabled then
			return
		end

		local MaximumX = math.max(0, Row.AbsoluteCanvasSize.X - Row.AbsoluteWindowSize.X)
		Row.CanvasPosition = Vector2.new(math.clamp(Row.CanvasPosition.X - Input.Position.Z * 28, 0, MaximumX), 0)
	end)

	UpdateCanvasSize()
	return Row, Content, Content.UIStroke, UpdateCanvasSize
end

function UI.new(Dialog: Dialog, props: QueryBuilderProps, ContextMenu: any, Operators: Validator): QueryBuilder
	assert(not Dialog.Destroyed, "Cannot create a query builder on a destroyed dialog")
	local TypeofValues = Operators.GetTypeNames()

	local Builder = {
		Target = CopyTarget(props.Target),
		Conditions = {},
		ConditionRows = {},
		Direction = props.Direction,
		Action = props.Action or "Ignore",
		Destroyed = false,
		IsValid = true,
		ValidationErrors = {},
	}

	local Main = CreateMain(Dialog.MainContent)
	Builder.Root = Main
	local EmitChanged

	--// Remote \\--
	local RemoteStage = CreateStage(Main, 0, Enum.AutomaticSize.Y, 0)
	CreateRemoteLeft(RemoteStage)
	local RemoteRight = CreateRight(RemoteStage, Enum.AutomaticSize.Y)
	Interface.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 6),
		Parent = RemoteRight,
	})
	local _, RemoteDisplay, _, UpdateRemoteDisplay = CreateScrollableRow(RemoteRight, 0)

	local ExactRemote = if props.Target.Type == "Instance" then props.Target.Remote else props.SampleRemote
	local ScopeOptions = table.clone(Scopes)
	ScopeOptions[1] = table.clone(ScopeOptions[1])
	ScopeOptions[1].Icon = ExactRemote and Constants.InstanceClassImages[ExactRemote.ClassName] or nil

	local RefreshTargetUI
	CreateSelect({
		Parent = RemoteDisplay,
		ContextMenu = ContextMenu,
		Options = ScopeOptions,
		Default = Builder.Target.Type,
		LayoutOrder = -4,
		Text = function(Value, Text)
			return if Value == "Instance" then ExactRemote and ExactRemote.Name or "No remote selected" else Text
		end,
		IsOptionAllowed = function(Value)
			return Value == "Query" or ExactRemote ~= nil
		end,
		OnChanged = function(Value)
			if Value == "Instance" then
				Builder.Target = { Type = "Instance", Remote = ExactRemote }
			else
				local Conditions = if Builder.Target.Type == "Query" then Builder.Target.Conditions else {}
				if #Conditions == 0 then
					table.insert(Conditions, {
						Field = "Name",
						Operator = "Equals",
						Value = ExactRemote and ExactRemote.Name or "",
						Join = "And",
					})
				end
				Builder.Target = { Type = "Query", Conditions = Conditions }
			end
			if RefreshTargetUI then RefreshTargetUI() end
			if EmitChanged then EmitChanged() end
		end,
	})
	local ScopeSeparator = CreateSeparator(RemoteDisplay, -3)
	CreateSelect({
		Parent = RemoteDisplay,
		ContextMenu = ContextMenu,
		Options = Directions,
		Default = Builder.Direction,
		LayoutOrder = 3,
		OnChanged = function(Value)
			Builder.Direction = Value
			if EmitChanged then EmitChanged() end
		end,
	})

	local TargetRows = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = RemoteRight,
		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 6),
		},
	})

	--// Where \\--
	local WhereStage = CreateStage(Main, 1, Enum.AutomaticSize.Y, 0)
	local WhereLeft = CreateBranchLeft(WhereStage, "Where", 70, false)
	local WhereRight = CreateRight(WhereStage, Enum.AutomaticSize.Y)
	local Rows = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = WhereRight,

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 10),
		},
		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 1),
			PaddingRight = UDim.new(0, 1),
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 1),
		},
	})
	local ValidationLabel = Interface.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		LayoutOrder = 999,
		Size = UDim2.fromScale(0, 0),
		Text = "",
		TextColor3 = ErrorColor,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		Parent = Rows,
	})

	local ConflictingRows = {}
	local TargetConflictingRows = {}
	local TargetConditionRows = {}
	function Builder:Validate(): (boolean, { string })
		local IsValid, Errors, Conflicts = Operators.Validate(self.Conditions)
		ConflictingRows = Conflicts

		if self.Target.Type == "Query" then
			if #self.Target.Conditions == 0 then
				IsValid = false
				table.insert(Errors, "Matching remotes require at least one remote condition.")
				TargetConflictingRows = {}
			else
				local TargetValid, TargetErrors, TargetConflicts = RemoteFields.Validate(self.Target.Conditions)
				IsValid = IsValid and TargetValid
				TargetConflictingRows = TargetConflicts
				for _, Error in TargetErrors do
					table.insert(Errors, Error)
				end
			end
		else
			TargetConflictingRows = {}
		end

		self.IsValid = IsValid
		self.ValidationErrors = Errors
		return self.IsValid, table.clone(Errors)
	end

	local function ApplyValidation()
		ValidationLabel.Visible = not Builder.IsValid
		ValidationLabel.Text = Builder.ValidationErrors[1] or ""
		WhereLeft.Size = UDim2.new(0, 0, 0, 35 * (#Builder.Conditions + 1) + (Builder.IsValid and 0 or 28))

		for Index, RowData in Builder.ConditionRows do
			RowData.Stroke.Color = if ConflictingRows[Index] then ErrorColor else BorderColor
		end
		for Index, RowData in TargetConditionRows do
			RowData.Stroke.Color = if TargetConflictingRows[Index] then ErrorColor else BorderColor
		end

		if props.OnValidationChanged then
			props.OnValidationChanged(Builder.IsValid, table.clone(Builder.ValidationErrors))
		end
	end

	EmitChanged = function()
		Builder:Validate()
		ApplyValidation()
		if props.OnChanged then
			props.OnChanged(Builder:GetValue())
		end
	end

	local function RefreshRows()
		Builder:Validate()
		local Count = #Builder.Conditions
		for Index, RowData in Builder.ConditionRows do
			RowData.JoinContainer.Visible = Index > 1
			RowData.JoinSeparator.Visible = Index > 1
			RowData.RemoveContainer.Visible = Count > 0
			RowData.RemoveSeparator.Visible = Count > 0
			RowData.Row.LayoutOrder = Index - 1
			RowData.Content.UIPadding.PaddingRight = UDim.new(0, if Count > 0 then 2 else 0)
			RowData.UpdateCanvasSize()
			if RowData.UpdateValueMode then
				RowData.UpdateValueMode()
			end
		end
		Builder:Validate()
		ApplyValidation()
	end

	local TargetAddCondition = Interface.New("TextButton", {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = 1000,
		Size = UDim2.new(0, 0, 0, 25),
		Text = "Add remote condition",
		TextSize = 14,
		TextTransparency = 0.5,
		Parent = TargetRows,
		["UIPadding"] = { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 5) },
	})
	Interface.NewIcon("plus", {
		AnchorPoint = Vector2.new(0, 0.5),
		ImageTransparency = 0.5,
		Position = UDim2.new(0, -17, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		Parent = TargetAddCondition,
	})

	local function CreateTargetConditionRow(Data: QueryRemoteCondition, Index: number)
		local Row, Content, Stroke, UpdateCanvasSize = CreateScrollableRow(TargetRows, Index)

		local JoinSeparator = CreateSeparator(Content, -1)
		local Join = CreateSelect({
			Parent = Content,
			ContextMenu = ContextMenu,
			Options = Joins,
			Default = Data.Join or "And",
			LayoutOrder = -2,
			OnChanged = function(Value)
				Data.Join = Value
				EmitChanged()
			end,
		})
		Join.Container.Visible = Index > 1
		JoinSeparator.Visible = Index > 1

		CreateSelect({
			Parent = Content,
			ContextMenu = ContextMenu,
			Options = RemoteFields.GetOptions(),
			Default = Data.Field,
			LayoutOrder = 0,
			OnChanged = function(Value)
				Data.Field = Value
				if not RemoteFields.IsOperatorAllowed(Data.Operator, Value) then
					Data.Operator = "Equals"
				end
				local ValueOptions = RemoteFields.GetValueOptions(Value)
				if ValueOptions and not RemoteFields.IsValueAllowed(Value, Data.Value) then
					Data.Value = ValueOptions[1].Value
				end
				RefreshTargetUI()
				EmitChanged()
			end,
		})

		CreateSeparator(Content, 1)
		CreateSelect({
			Parent = Content,
			ContextMenu = ContextMenu,
			Options = Operators.GetOptions(),
			Default = Data.Operator,
			LayoutOrder = 2,
			IsOptionAllowed = function(Value)
				return RemoteFields.IsOperatorAllowed(Value, Data.Field)
			end,
			MaxMenuHeight = 150,
			Text = function(_, Text)
				return `<font transparency="0.5">{EscapeRichText(Text)}</font>`
			end,
			OnChanged = function(Value)
				Data.Operator = Value
				EmitChanged()
			end,
		})

		CreateSeparator(Content, 3)
		local TargetValueContainer = Interface.New("Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = 4,
			Size = UDim2.new(0, 0, 1, 0),
			Parent = Content,
			["UIPadding"] = { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 2) },
			["UIListLayout"] = {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			},
		})
		local ValueOptions = GetRemoteValueOptions(Data.Field)
		if ValueOptions then
			if not RemoteFields.IsValueAllowed(Data.Field, Data.Value) then
				Data.Value = ValueOptions[1].Value
			end
			CreateSelect({
				Parent = TargetValueContainer,
				ContextMenu = ContextMenu,
				Options = ValueOptions,
				Default = Data.Value,
				LayoutOrder = 0,
				MaxMenuHeight = 150,
				OnChanged = function(Value)
					Data.Value = Value
					EmitChanged()
				end,
			})
		else
			local TargetValueBox = Interface.New("TextBox", {
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				ClearTextOnFocus = false,
				LayoutOrder = 0,
				Size = UDim2.new(0, 0, 1, 0),
				Text = Data.Value,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = TargetValueContainer,
				["UISizeConstraint"] = { MinSize = Vector2.new(35, 0) },
			})
			TargetValueBox:GetPropertyChangedSignal("Text"):Connect(function()
				Data.Value = TargetValueBox.Text
				EmitChanged()
			end)
		end

		local RemoveSeparator = CreateSeparator(Content, 5)
		local RemoveContainer = Interface.New("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 6,
			Size = UDim2.new(0, 20, 1, 0),
			Parent = Content,
			["UIListLayout"] = {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			},
		})
		local Remove = Interface.New("ImageButton", {
			ImageTransparency = 0.5,
			Size = UDim2.fromOffset(14, 14),
			Parent = RemoveContainer,
		})
		Icons.SetIcon(Remove, "x")
		local CanRemove = Builder.Target.Type == "Query" and #Builder.Target.Conditions > 1
		RemoveContainer.Visible = CanRemove
		RemoveSeparator.Visible = CanRemove
		Remove.MouseButton1Click:Connect(function()
			if Builder.Target.Type == "Query" and #Builder.Target.Conditions > 1 then
				table.remove(Builder.Target.Conditions, Index)
				RefreshTargetUI()
				EmitChanged()
			end
		end)

		table.insert(TargetConditionRows, {
			Row = Row,
			Stroke = Stroke,
			UpdateCanvasSize = UpdateCanvasSize,
		})
		UpdateCanvasSize()
	end

	RefreshTargetUI = function()
		for _, RowData in TargetConditionRows do
			RowData.Row:Destroy()
		end
		table.clear(TargetConditionRows)

		local IsQuery = Builder.Target.Type == "Query"
		ScopeSeparator.Visible = true
		TargetRows.Visible = IsQuery
		TargetAddCondition.Visible = IsQuery
		UpdateRemoteDisplay()

		if IsQuery then
			for Index, Condition in Builder.Target.Conditions do
				CreateTargetConditionRow(Condition, Index)
			end
		end
		Builder:Validate()
		ApplyValidation()
	end
	RemoteRight:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateRemoteDisplay)

	TargetAddCondition.MouseButton1Click:Connect(function()
		if Builder.Target.Type ~= "Query" then
			return
		end
		table.insert(Builder.Target.Conditions, {
			Field = "Name",
			Operator = "Equals",
			Value = "",
			Join = "And",
		})
		RefreshTargetUI()
		EmitChanged()
	end)

	RefreshTargetUI()
	Rows:GetPropertyChangedSignal("AbsoluteSize"):Connect(RefreshRows)

	function Builder:AddCondition(Condition: QueryBuilderCondition?)
		local Data = CopyCondition(Condition or {
			Subject = { Type = "Argument", Index = 1 },
			Operator = "Equals",
			Value = "",
			Join = "And",
		})
		table.insert(self.Conditions, Data)

		local Row, Content, ContentStroke, UpdateCanvasSize = CreateScrollableRow(Rows, #self.Conditions - 1)

		local JoinSeparator = CreateSeparator(Content, -1)
		local Join = CreateSelect({
			Parent = Content,
			ContextMenu = ContextMenu,
			Options = Joins,
			Default = Data.Join or "And",
			LayoutOrder = -2,
			OnChanged = function(Value: QueryFilterJoin)
				Data.Join = Value
				EmitChanged()
			end,
		})
		local JoinContainer = Join.Container

		local SubjectOptions = {
			{ Value = "ArgumentCount", Text = "#Arg" },
		}
		for Index, Label in props.ArgumentLabels or { "Argument 1", "Argument 2", "Argument 3" } do
			table.insert(SubjectOptions, { Value = `Argument:{Index}`, Text = Label })
		end
		local Operator
		local Subject = CreateSelect({
			Parent = Content,
			ContextMenu = ContextMenu,
			Options = SubjectOptions,
			Default = GetSubjectValue(Data.Subject),
			LayoutOrder = 0,
			Text = function(Value)
				if Value == "ArgumentCount" then
					return `<font transparency="0.5">#Arg</font>`
				end
				local Index = string.match(Value, "^Argument:(%d+)$") or "1"
				return `<font transparency="0.5">Arg</font>[<font color="rgb(255,255,255)">{Index}</font>]`
			end,
			OnChanged = function(Value: string)
				Data.Subject = CreateSubject(Value)
				if not Operators.IsAllowed(Builder.Conditions, Data, Data.Operator) then
					Data.Operator = "Equals"
					if Operator then
						Operator:SetValue("Equals", true)
					end
				end
				RefreshRows()
				EmitChanged()
			end,
		})

		CreateSeparator(Content, 1)
		local UpdateValueMode
		local CurrentArgumentType
		local function IsOperatorAllowed(Value: QueryFilterOperator): boolean
			return Operators.IsAllowed(Builder.Conditions, Data, Value)
		end
		Operator = CreateSelect({
			Parent = Content,
			ContextMenu = ContextMenu,
			Options = Operators.GetOptions(),
			Default = Data.Operator,
			LayoutOrder = 2,
			IsOptionAllowed = IsOperatorAllowed,
			MaxMenuHeight = 150,
			Text = function(_, Text)
				return `<font transparency="0.5">{EscapeRichText(Text)}</font>`
			end,
			OnChanged = function(Value: QueryFilterOperator)
				Data.Operator = Value
				if UpdateValueMode then
					UpdateValueMode()
				end
				RefreshRows()
				EmitChanged()
			end,
		})

		CreateSeparator(Content, 3)
		local ValueContainer = Interface.New("Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = 4,
			Size = UDim2.new(0, 0, 1, 0),
			Parent = Content,
			["UIPadding"] = { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 2) },
			["UIListLayout"] = {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 1),
			},
		})
		local ValueBox = Interface.New("TextBox", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			Size = UDim2.new(0, 0, 1, 0),
			Text = tostring(Data.Value),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = ValueContainer,
			["UISizeConstraint"] = {
				MinSize = Vector2.new(35, 0),
			},
		})
		local TypeLabel = Interface.New("TextLabel", {
			Active = true,
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 0,
			Size = UDim2.new(0, 0, 1, 0),
			Text = tostring(Data.Value),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = false,
			Parent = ValueContainer,
		})
		local ValueChevron = Interface.NewIcon("chevron-down", {
			Active = true,
			ImageTransparency = 0.5,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(12, 12),
			Parent = ValueContainer,
		})

		local TypeOptions = {}
		local TypeContext
		for _, TypeName in TypeofValues do
			table.insert(TypeOptions, {
				Text = TypeName,
				Callback = function()
					Data.Value = TypeName
					TypeLabel.Text = TypeName
					TypeContext:Close()
					RefreshRows()
					EmitChanged()
				end,
				TextProperties = function()
					return { TextTransparency = if Data.Value == TypeName then 0 else 0.5 }
				end,
			})
		end
		TypeContext = ContextMenu:Create(ValueContainer, TypeOptions, nil, {
			MaxHeight = 180,
		})

		local BooleanContext = ContextMenu:Create(ValueContainer, {
			{
				Text = "true",
				Callback = function()
					Data.Value = true
					TypeLabel.Text = "true"
					EmitChanged()
				end,
			},
			{
				Text = "false",
				Callback = function()
					Data.Value = false
					TypeLabel.Text = "false"
					EmitChanged()
				end,
			},
		})

		local ValueMode = "Text"
		local function ToggleValueContext(Input: InputObject)
			if
				Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				if ValueMode == "Type" then
					TypeContext:Toggle()
				elseif ValueMode == "Boolean" then
					BooleanContext:Toggle()
				end
			end
		end
		TypeLabel.InputBegan:Connect(ToggleValueContext)
		ValueChevron.InputBegan:Connect(ToggleValueContext)

		UpdateValueMode = function()
			CurrentArgumentType = Operators.GetConditionType(Builder.Conditions, Data)
			local IsType = Data.Operator == "TypeIs"
			local IsBoolean = not IsType and CurrentArgumentType == "boolean"
			ValueMode = if IsType then "Type" elseif IsBoolean then "Boolean" else "Text"

			if not IsType then
				TypeContext:Close()
			end
			if not IsBoolean then
				BooleanContext:Close()
			end
			if IsType then
				if not table.find(TypeofValues, tostring(Data.Value)) then
					local InferredType = CurrentArgumentType or typeof(Data.Value)
					Data.Value = if table.find(TypeofValues, InferredType) then InferredType else "Instance"
				end
				TypeLabel.Text = tostring(Data.Value)
			elseif IsBoolean then
				if typeof(Data.Value) ~= "boolean" then
					Data.Value = true
				end
				TypeLabel.Text = tostring(Data.Value)
			end
			if ValueMode == "Text" and ValueBox.Text ~= tostring(Data.Value) then
				ValueBox.Text = tostring(Data.Value)
			end
			ValueBox.Visible = ValueMode == "Text"
			TypeLabel.Visible = ValueMode ~= "Text"
			ValueChevron.Visible = ValueMode ~= "Text"
			ValueChevron.Active = ValueMode ~= "Text"
		end
		UpdateValueMode()
		ValueBox:GetPropertyChangedSignal("Text"):Connect(function()
			Data.Value = if CurrentArgumentType == "number"
				then tonumber(ValueBox.Text) or ValueBox.Text
				else ValueBox.Text
			EmitChanged()
		end)

		local RemoveSeparator = CreateSeparator(Content, 5)
		local RemoveContainer = Interface.New("Frame", {
			AutomaticSize = Enum.AutomaticSize.None,
			BackgroundTransparency = 1,
			LayoutOrder = 6,
			Size = UDim2.new(0, 20, 1, 0),
			Parent = Content,
			["UIListLayout"] = {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			},
		})
		local Remove = Interface.New("ImageButton", {
			ImageTransparency = 0.5,
			Size = UDim2.fromOffset(14, 14),
			Parent = RemoveContainer,
		})
			Icons.SetIcon(Remove, "x")

		local RowData = {
			Row = Row,
			Content = Content,
			Stroke = ContentStroke,
			Join = Join,
			JoinContainer = JoinContainer,
			JoinSeparator = JoinSeparator,
			Subject = Subject,
			Operator = Operator,
			ValueBox = ValueBox,
			RemoveContainer = RemoveContainer,
			RemoveSeparator = RemoveSeparator,
			UpdateCanvasSize = UpdateCanvasSize,
			UpdateValueMode = UpdateValueMode,
		}
		table.insert(self.ConditionRows, RowData)

		Remove.MouseButton1Click:Connect(function()
			local Index = table.find(self.ConditionRows, RowData)
			if Index then
				self:RemoveCondition(Index)
			end
		end)

		RefreshRows()
		EmitChanged()
		return Data
	end

	function Builder:RemoveCondition(Index: number)
		local RowData = table.remove(self.ConditionRows, Index)
		table.remove(self.Conditions, Index)
		if RowData then
			RowData.Row:Destroy()
		end
		RefreshRows()
		EmitChanged()
	end

	local AddCondition = Interface.New("TextButton", {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = 1000,
		Size = UDim2.new(0, 0, 0, 25),
		Text = "Add Condition",
		TextSize = 14,
		TextTransparency = 0.5,
		Parent = Rows,
		["UICorner"] = { CornerRadius = UDim.new(0, 4) },
		["UIPadding"] = { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 5) },
	})
	Interface.NewIcon("plus", {
		AnchorPoint = Vector2.new(0, 0.5),
		ImageTransparency = 0.5,
		Position = UDim2.new(0, -17, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		Parent = AddCondition,
	})
	AddCondition.MouseButton1Click:Connect(function()
		Builder:AddCondition()
	end)

	--// Action \\--
	local ActionStage = CreateStage(Main, 3, Enum.AutomaticSize.None, 35)
	CreateBranchLeft(ActionStage, "Action", 35, true)
	local ActionRight = CreateRight(ActionStage, Enum.AutomaticSize.None)
	local ActionFrame = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = BackgroundColor,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = ActionRight,
		["UICorner"] = { CornerRadius = UDim.new(0, 4) },
		["UIStroke"] = { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = BorderColor, Thickness = 1 },
		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 2),
		},
		["UIPadding"] = { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) },
	})
	local Action = CreateSelect({
		Parent = ActionFrame,
		ContextMenu = ContextMenu,
		Options = Actions,
		Default = Builder.Action,
		LayoutOrder = 0,
		OnChanged = function(Value: QueryFilterAction)
			Builder.Action = Value
			EmitChanged()
		end,
	})

	function Builder:GetValue()
		local Conditions = {}
		for _, Condition in self.Conditions do
			table.insert(Conditions, CopyCondition(Condition))
		end
		return {
			Target = CopyTarget(self.Target),
			Direction = self.Direction,
			Conditions = Conditions,
			Action = self.Action,
		}
	end

	function Builder:SetAction(Value: QueryFilterAction)
		Action:SetValue(Value)
	end

	function Builder:Destroy()
		if self.Destroyed then
			return
		end
		self.Destroyed = true
		Main:Destroy()
	end

	for _, Condition in props.Conditions or {} do
		Builder:AddCondition(Condition)
	end

	return Builder :: any
end

return UI
