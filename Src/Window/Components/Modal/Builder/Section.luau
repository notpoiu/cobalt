--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")

local ContextMenuController = require("@src/Window/Components/ContextMenu")

local CreateCheckbox = require(script.Parent.Controls.Checkbox)
local CreateDropdown = require(script.Parent.Controls.Dropdown)
local CreateRemoteList = require(script.Parent.Controls.RemoteList)
local CreateTextBox = require(script.Parent.Controls.TextBox)

--// Builder \\--
return function(props: {
	ContextMenu: ContextMenuController.ContextMenu,
})
	local ContextMenu = props.ContextMenu

	local SectionBuilder = {}
	SectionBuilder.__index = SectionBuilder

	function SectionBuilder.new(Parent: Frame, DataSavePrefix: string?)
		return setmetatable({
			Parent = Parent,
			DataSavePrefix = DataSavePrefix or "",
		}, SectionBuilder)
	end

	function SectionBuilder:CreateRow(Padding: UDim?)
		local Row = Interface.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = self.Parent,

			["UIListLayout"] = {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				Padding = Padding or UDim.new(0, 8),
			},
		})

		return SectionBuilder.new(Row, self.DataSavePrefix)
	end

	function SectionBuilder:AddLabel(Text: string, TextSize: number?)
		return Interface.New("TextLabel", {
			Text = Text,
			TextSize = TextSize or 16,
			Size = UDim2.new(1, 0, 0, 20),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Parent = self.Parent,
			TextWrapped = true,
		})
	end

	function SectionBuilder:AddSpacer(Height: number?)
		return Interface.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Height or 0),
			Parent = self.Parent,
		})
	end

	function SectionBuilder:CreateButton(Text: string, Callback: (() -> ())?, TextSize: number?)
		local Button = Interface.New("TextButton", {
			BackgroundColor3 = Color3.fromRGB(15, 15, 15),
			Size = UDim2.new(1, 0, 0, 24),
			TextSize = 15,
			Text = "",
			Parent = self.Parent,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 4),
			},

			["UIStroke"] = {
				Color = Color3.fromRGB(25, 25, 25),
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			},

			["TextLabel"] = {
				Text = Text,
				TextSize = TextSize or 16,
				TextTransparency = 0.5,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromOffset(0, -1),
			},
		})

		Button.MouseButton1Click:Connect(function()
			if Callback then
				Callback()
			end
		end)

		return Button
	end

	function SectionBuilder:CreateCheckbox(Idx: string, Options)
		return CreateCheckbox({
			Parent = self.Parent,
			Idx = self.DataSavePrefix .. Idx,
			Options = Options,
		})
	end

	function SectionBuilder:CreateTextBox(Idx: string, Options)
		return CreateTextBox({
			Parent = self.Parent,
			Idx = self.DataSavePrefix .. Idx,
			Options = Options,
		})
	end

	function SectionBuilder:CreateDropdown(Idx: string, Options)
		return CreateDropdown({
			Parent = self.Parent,
			Idx = self.DataSavePrefix .. Idx,
			Options = Options,
			ContextMenu = ContextMenu,
		})
	end

	function SectionBuilder:CreateRemoteList(Idx: string, Options)
		return CreateRemoteList({
			Parent = self.Parent,
			Idx = self.DataSavePrefix .. Idx,
			Options = Options,
			CreateButton = function(Text, Callback)
				return self:CreateButton(Text, Callback)
			end,
		})
	end

	return SectionBuilder
end
