--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Constants = require("@src/Window/Constants")

local SettingSync = require(script.Parent.SettingSync)

return function(props: {
	Parent: GuiObject,
	Idx: string,
	Options: {
		Text: string,
		Callback: ((boolean) -> ())?,
		PreSetCallback: ((boolean) -> ())?,
		Default: boolean?,
	},
})
	--// Props \\--
	local Idx = props.Idx
	local Options = props.Options

	--// Setup \\--
	local Checkbox = {
		Idx = Idx,
		Default = Options.Default or false,
		Value = wax.shared.SaveManager:GetState(Idx, Options.Default or false),
		Risky = Options.Risky or false,
	}

	local ToggleTextRiskyColor = Color3.fromRGB(255, 125, 0)

	local CheckboxUI = Interface.New("TextButton", {
		Text = Options.Text,
		TextSize = 16,
		TextColor3 = if Checkbox.Risky then ToggleTextRiskyColor else Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = props.Parent,
	})

	local ToggleOnColor = Color3.fromRGB(52, 199, 89)
	local ToggleOffColor = Color3.fromRGB(50, 50, 50)

	local ToggleKnobOffSize = UDim2.fromOffset(16, 16)
	local ToggleKnobOnSize = UDim2.fromOffset(18, 18)
	local ToggleKnobInset = 10

	local ToggleTrack = Interface.New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(36, 20),
		BackgroundColor3 = ToggleOffColor,
		Parent = CheckboxUI,

		["UICorner"] = {
			CornerRadius = UDim.new(1, 0),
		},
	})

	local ToggleKnob = Interface.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = ToggleKnobOffSize,
		Parent = ToggleTrack,

		["UICorner"] = {
			CornerRadius = UDim.new(1, 0),
		},
	})

	local function UpdateToggleVisual(instant: boolean?)
		local TargetTrackColor = if Checkbox.Value then ToggleOnColor else ToggleOffColor
		local TargetKnobPosition = if Checkbox.Value
			then UDim2.new(1, -ToggleKnobInset, 0.5, 0)
			else UDim2.new(0, ToggleKnobInset, 0.5, 0)
		local TargetKnobSize = if Checkbox.Value then ToggleKnobOnSize else ToggleKnobOffSize

		if instant then
			ToggleTrack.BackgroundColor3 = TargetTrackColor
			ToggleKnob.Position = TargetKnobPosition
			ToggleKnob.Size = TargetKnobSize
			return
		end

		wax.shared.TweenService
			:Create(ToggleTrack, Constants.DefaultTweenInfo, {
				BackgroundColor3 = TargetTrackColor,
			})
			:Play()

		wax.shared.TweenService
			:Create(ToggleKnob, Constants.DefaultTweenInfo, {
				Position = TargetKnobPosition,
				Size = TargetKnobSize,
			})
			:Play()
	end

	function Checkbox:Reset()
		Checkbox:SetValue(Checkbox.Default)
	end

	function Checkbox:SetValue(NewValue)
		if Options.PreSetCallback then
			local Result = Options.PreSetCallback(NewValue)
			if Result == false then return end
		end

		SettingSync.Save(Idx, NewValue)

		Checkbox.Value = NewValue
		UpdateToggleVisual()

		if Options.Callback then
			Options.Callback(Checkbox.Value)
		end
	end

	CheckboxUI.MouseButton1Click:Connect(function()
		Checkbox:SetValue(not Checkbox.Value)
	end)

	UpdateToggleVisual(true)
	SettingSync.Register(Idx, Checkbox)

	return Checkbox
end
