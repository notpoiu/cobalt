--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Constants = require("@src/Window/Constants")

local SettingSync = require(script.Parent.SettingSync)

local function CreateLookupTable(Values: { any } | any)
	if typeof(Values) ~= "table" then
		return Values
	end

	local LookupTable = {}
	for Key, Value in Values do
		if type(Key) == "number" then
			LookupTable[Value] = true
		else
			LookupTable[Key] = Value
		end
	end

	return LookupTable
end

local function CloneDictionary(Source: { [any]: any })
	local Copy = {}
	for Key, Value in pairs(Source) do
		Copy[Key] = Value
	end

	return Copy
end

return function(props: {
	Parent: GuiObject,
	Idx: string,
	ContextMenu: any,
	Options: {
		Multi: boolean?,
		AllowNull: boolean?,
		Values: { [any]: any },
		Default: any | { [any]: any },
		Callback: ((any) -> ())?,
		Text: string,
	},
})
	--// Props \\--
	local Idx = props.Idx
	local Options = props.Options
	local AllowNull = Options.AllowNull or false

	assert(AllowNull or Options.Default ~= nil, "Default value must be provided when AllowNull is false")

	local Default = Options.Default and CreateLookupTable(Options.Default)
		or Options.AllowNull and (Options.Multi and {} or Options.Values[1])
		or {}

	--// Setup \\--
	local Dropdown = {
		Idx = Idx,
		Values = Options.Values or {},
		Default = Default,
		Value = wax.shared.SaveManager:GetState(Idx, Default),
		Multi = Options.Multi or false,
		Callback = Options.Callback,
	}

	local DropdownUI = Interface.New("TextButton", {
		Text = Options.Text,
		TextSize = 16,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = props.Parent,
	})

	DropdownUI.AutoButtonColor = false

	local DropdownDisplay = Interface.New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(180, 24),
		Parent = DropdownUI,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIStroke"] = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(25, 25, 25),
			Thickness = 1,
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		},
	})

	local ValueLabel = Interface.New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 1, 0),
		Text = "Select...",
		TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextTransparency = 0.45,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = DropdownDisplay,
	})

	local DropdownIcon = Interface.NewIcon("chevron-down", {
		AnchorPoint = Vector2.new(1, 0.5),
		ImageTransparency = 0.2,
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		Parent = DropdownDisplay,
	})

	local DisplayDefaultColor = DropdownDisplay.BackgroundColor3
	local DisplayHoverColor = Color3.fromRGB(12, 12, 12)

	local function TweenDisplayColor(TargetColor: Color3, TargetTransparency: number?)
		wax.shared.TweenService
			:Create(DropdownDisplay, Constants.DefaultTweenInfo, {
				BackgroundColor3 = TargetColor,
			})
			:Play()

		if TargetTransparency then
			wax.shared.TweenService
				:Create(DropdownIcon, Constants.DefaultTweenInfo, {
					ImageTransparency = TargetTransparency,
				})
				:Play()
		end
	end

	local function IterateValues(Callback: (any, string) -> ())
		for Index, Object in Dropdown.Values do
			local ActualValue = typeof(Index) == "number" and Object or Index
			local DisplayText = typeof(Index) == "number" and tostring(Object) or tostring(Index)
			Callback(ActualValue, DisplayText)
		end
	end

	local function ResolveValueText(Value)
		local Resolved
		IterateValues(function(ActualValue, DisplayText)
			if ActualValue == Value then
				Resolved = DisplayText
			end
		end)

		return Resolved or (Value ~= nil and tostring(Value) or "")
	end

	local function UpdateValueLabel()
		local DisplayText = "Select..."
		local Transparency = 0.45

		if Dropdown.Multi then
			local SelectedTexts = {}
			IterateValues(function(Value, Text)
				if Dropdown.Value[Value] then
					table.insert(SelectedTexts, Text)
				end
			end)

			if #SelectedTexts == 0 then
				DisplayText = "None"
			else
				table.sort(SelectedTexts)
				DisplayText = if #SelectedTexts <= 2
					then table.concat(SelectedTexts, ", ")
					else string.format("%s, +%d", SelectedTexts[1], #SelectedTexts - 1)
				Transparency = 0
			end
		elseif Dropdown.Value == nil or Dropdown.Value == "" then
			DisplayText = "None"
		else
			local Resolved = ResolveValueText(Dropdown.Value)
			DisplayText = if Resolved == "" then tostring(Dropdown.Value) else Resolved
			Transparency = 0
		end

		ValueLabel.Text = DisplayText
		ValueLabel.TextTransparency = Transparency
	end

	local DropdownContext

	local function SetValue(NewValue, CloseMenu: boolean?)
		SettingSync.Save(Idx, NewValue)

		if CloseMenu ~= false and DropdownContext then
			DropdownContext:Close()
		end

		if Dropdown.Multi then
			for Image, Object in pairs(Dropdown.Values) do
				local Value = if typeof(Image) == "number" then Object else Image
				Dropdown.Value[Value] = NewValue[Value]
			end
		else
			Dropdown.Value = NewValue
		end

		UpdateValueLabel()

		if Dropdown.Callback then
			Dropdown.Callback(Dropdown.Value)
		end
	end

	local function BuildDropdownContext()
		local MenuOptions = {}
		for Index, Object in Dropdown.Values do
			local IsArray = typeof(Index) == "number"

			local ContextOption = {
				Text = tostring(Object),
				CloseOnClick = not Dropdown.Multi,
				Callback = function()
					local Value = if IsArray then Object else Index

					if Dropdown.Multi then
						local NewValue = CloneDictionary(Dropdown.Value)
						NewValue[Value] = not (NewValue[Value] or false)
						SetValue(NewValue, false)
					else
						SetValue(Value)
					end
				end,
				TextProperties = function()
					local Value = if IsArray then Object else Index
					local IsSelected = if Dropdown.Multi then Dropdown.Value[Value] else Dropdown.Value == Value

					return {
						TextTransparency = if IsSelected then 0 else 0.5,
					}
				end,
			}

			if not IsArray then
				ContextOption.Text = Index
				ContextOption.Icon = Object
			end

			table.insert(MenuOptions, ContextOption)
		end

		return MenuOptions
	end

	function Dropdown:Reset()
		Dropdown:SetValue(if Dropdown.Multi then CloneDictionary(Dropdown.Default) else Dropdown.Default)
	end

	function Dropdown:SetValue(NewValue)
		SetValue(NewValue)
	end

	DropdownUI.MouseEnter:Connect(function()
		TweenDisplayColor(DisplayHoverColor, 0.05)
	end)

	DropdownUI.MouseLeave:Connect(function()
		TweenDisplayColor(DisplayDefaultColor, 0.2)
	end)

	DropdownContext = props.ContextMenu:Create(DropdownDisplay, BuildDropdownContext())
	DropdownUI.MouseButton1Click:Connect(DropdownContext.Toggle)

	UpdateValueLabel()
	SettingSync.Register(Idx, Dropdown)

	return Dropdown
end
