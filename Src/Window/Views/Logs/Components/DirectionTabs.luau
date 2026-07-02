--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Constants = require("@src/Window/Constants")
local Types = require("@src/Window/Types")

--// UI \\--
return function(props: {
	Parent: GuiObject,
	OnSelected: (Tab: Types.LogDirectionTab) -> (),
})
	local DirectionTabs = {
		Tabs = {},
		CurrentTab = nil,
	}

	function DirectionTabs:Select(Tab, Force: boolean?)
		if self.CurrentTab == Tab and not Force then
			return
		end

		if self.CurrentTab then
			wax.shared.TweenService
				:Create(self.CurrentTab.Instance, Constants.DefaultTweenInfo, {
					BackgroundTransparency = 1,
				})
				:Play()
		end

		self.CurrentTab = Tab
		wax.shared.TweenService
			:Create(Tab.Instance, Constants.DefaultTweenInfo, {
				BackgroundTransparency = 0,
			})
			:Play()

		props.OnSelected(Tab)
	end

	function DirectionTabs:Create(TabName: Types.LogDirection, Active: boolean, Logs)
		local Button = Interface.New("TextButton", {
			BackgroundColor3 = Color3.fromRGB(50, 50, 50),
			BackgroundTransparency = Active and 0 or 1,
			Size = UDim2.fromScale(0, 1),
			TextSize = 15,
			Text = TabName,
			Parent = props.Parent,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 4),
			},
		})

		local Tab = {
			Name = TabName,
			Logs = Logs,
			Instance = Button,
		}
		self.Tabs[TabName] = Tab

		Button.MouseButton1Click:Connect(function()
			self:Select(Tab)
		end)

		if Active then
			self.CurrentTab = Tab
		end

		return Tab
	end

	return DirectionTabs
end
