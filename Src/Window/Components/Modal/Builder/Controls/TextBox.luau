--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")

local SettingSync = require(script.Parent.SettingSync)

local function NormalizeNumberText(Value: string): string
	if Value == "" then
		return ""
	end

	local Characters = table.create(#Value)
	local HasDigits = false
	local HasDecimal = false
	local SignApplied = false

	for Index = 1, #Value do
		local Char = string.sub(Value, Index, Index)
		local Byte = string.byte(Char)

		if Char == "-" and not SignApplied and not HasDigits and not HasDecimal then
			table.insert(Characters, Char)
			SignApplied = true
		elseif Char == "." and not HasDecimal then
			table.insert(Characters, Char)
			HasDecimal = true
			SignApplied = true
		elseif Byte and Byte >= 48 and Byte <= 57 then
			table.insert(Characters, Char)
			HasDigits = true
			SignApplied = true
		end
	end

	local Sanitized = table.concat(Characters)

	if Sanitized == "-" or Sanitized == "." or Sanitized == "-." then
		return ""
	end

	return Sanitized
end

return function(props: {
	Parent: GuiObject,
	Idx: string,
	Options: {
		Text: string,
		Callback: ((any) -> ())?,
		Default: any?,
		Placeholder: string?,
		ClearTextOnFocus: boolean?,
		Width: number?,
		NumericOnly: boolean?,
	},
})
	--// Props \\--
	local Idx = props.Idx
	local Options = props.Options
	local NumericOnly = Options.NumericOnly == true
	local TextBoxWidth = Options.Width or 160

	local function NormalizeValue(NewValue: any): string
		local Value = tostring(NewValue or "")
		return if NumericOnly then NormalizeNumberText(Value) else Value
	end

	local DefaultValue = NormalizeValue(Options.Default)
	local SavedValue = wax.shared.SaveManager:GetState(Idx)
	local InitialValue = NormalizeValue(if SavedValue ~= nil then SavedValue else DefaultValue)

	--// Setup \\--
	local TextSetting = {
		Idx = Idx,
		Default = DefaultValue,
		Value = InitialValue,
		Callback = Options.Callback,
	}

	local Container = Interface.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = props.Parent,

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
		},
	})

	Interface.New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -TextBoxWidth - 6, 1, 0),
		Text = Options.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Parent = Container,
	})

	local Input = Interface.New("TextBox", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(5, 5, 5),
		ClearTextOnFocus = Options.ClearTextOnFocus or false,
		PlaceholderColor3 = Color3.fromRGB(128, 128, 128),
		PlaceholderText = Options.Placeholder or "",
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, TextBoxWidth, 1, -2),
		Text = InitialValue,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Container,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIStroke"] = {
			Color = Color3.fromRGB(25, 25, 25),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		},
	})

	local function SyncValue(NewValue: string, FireCallback: boolean?)
		TextSetting.Value = NewValue
		Input.Text = NewValue

		if FireCallback ~= false and TextSetting.Callback then
			TextSetting.Callback(if NumericOnly then tonumber(NewValue) else NewValue)
		end
	end

	function TextSetting:Reset()
		TextSetting:SetValue(TextSetting.Default)
	end

	function TextSetting:SetValue(NewValue)
		local PreparedValue = NormalizeValue(NewValue)

		if PreparedValue == TextSetting.Value then
			SyncValue(PreparedValue, false)
			return
		end

		SettingSync.Save(Idx, PreparedValue)
		SyncValue(PreparedValue)
	end

	Input.FocusLost:Connect(function()
		TextSetting:SetValue(Input.Text)
	end)

	SyncValue(TextSetting.Value, false)
	SettingSync.Register(Idx, TextSetting)

	return TextSetting
end
