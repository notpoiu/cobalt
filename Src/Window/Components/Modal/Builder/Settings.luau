--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local SectionBuilder = require(script.Parent.Section)

local ContextMenu = require("@src/Window/Components/ContextMenu")

--// Builder \\--
local SettingsBuilder = {}
export type Builder = typeof(SettingsBuilder)
SettingsBuilder.__index = SettingsBuilder

return function(props: {
	ContextMenu: ContextMenu.ContextMenu,
})
	local ContextMenu = props.ContextMenu

	--// Section Builder \\--
	local SectionBuilder = SectionBuilder({
		ContextMenu = ContextMenu,
	})

	--// Settings Builder \\--
	function SettingsBuilder.new(Parent: Frame)
		return setmetatable({
			Parent = Parent,
		}, SettingsBuilder)
	end

	-- Sections Constructor
	function SettingsBuilder:CreateSection(SectionName: string, DataSavePrefix: string?)
		local Section = Interface.New("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			Parent = self.Parent,

			["UIListLayout"] = {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				Padding = UDim.new(0, 4),
			},

			["TextLabel"] = {
				Text = `<b>{SectionName}</b>`,
				RichText = true,
				TextSize = 18,
				Size = UDim2.new(1, 0, 0, 18),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = -1,
			},
		})

		return SectionBuilder.new(Section, DataSavePrefix)
	end

	return SettingsBuilder
end
