local Interface = require("@src/Utils/UI/Interface")
local Icons = require("@src/Utils/UI/Assets/Icons")

local ContextMenu = {}
export type ContextMenu = {
	CurrentContext: {
		Parent: GuiObject,
		Options: { GuiObject },
		Owner: ContextMenu,
		MouseOnCursorPosition: boolean?,
	}?,
} & typeof(setmetatable({}, ContextMenu))
ContextMenu.__index = ContextMenu

local DefaultTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Exponential)

function ContextMenu.new(
	Parent: GuiObject,
	Options: {
		GetDPIScale: (() -> number)?,
		TweenInfo: TweenInfo?,
	}?
)
	local self = setmetatable({
		CurrentContext = nil,
		GetDPIScale = Options and Options.GetDPIScale or function()
			return 1
		end,
		TweenInfo = Options and Options.TweenInfo or DefaultTweenInfo,
	}, ContextMenu)

	self.Frame = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		Size = UDim2.fromScale(0, 0),
		ZIndex = 10000,
		Visible = false,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 6),
		},

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 0),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},

		["UIStroke"] = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(25, 25, 25),
			Thickness = 1,
		},

		Parent = Parent,
	})

	return self
end

function ContextMenu:Create(Parent: GuiObject, Options: {}, MouseOnCursorPosition: boolean?)
	local ContextData = {
		Parent = Parent,
		Options = {},
		Owner = self,
		MouseOnCursorPosition = MouseOnCursorPosition,
	}

	local function BuildContextMenu(MenuOptions: {})
		for Order, Data in pairs(MenuOptions) do
			local TextButton = Interface.New("TextButton", {
				BackgroundColor3 = Color3.fromRGB(25, 25, 25),
				BackgroundTransparency = 1,
				LayoutOrder = Order,
				Size = UDim2.new(1, 0, 0, 30),
				Text = "",

				["UICorner"] = {
					CornerRadius = UDim.new(0, 6),
				},

				["UIPadding"] = {
					PaddingBottom = UDim.new(0, 6),
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 6),
					PaddingTop = UDim.new(0, 6),
				},
			})

			local IconToSet = Data.Icon
			if typeof(IconToSet) == "function" then
				IconToSet = IconToSet()
			end

			local ItemIcon
			if tostring(IconToSet):match("rbxasset") then
				ItemIcon = Interface.New("ImageLabel", {
					Image = IconToSet,
					Size = UDim2.fromScale(1, 1),
					SizeConstraint = Enum.SizeConstraint.RelativeYY,

					Parent = TextButton,
				})
			else
				ItemIcon = Interface.NewIcon(IconToSet, {
					Size = UDim2.fromScale(1, 1),
					SizeConstraint = Enum.SizeConstraint.RelativeYY,

					Parent = TextButton,
				})
			end

			local TextToSet = Data.Text
			if typeof(TextToSet) == "function" then
				TextToSet = TextToSet()
			end

			local ItemText = Interface.New("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromOffset(Data.Icon == nil and 0 or 26, 0),
				Size = UDim2.fromScale(0, 1),
				Text = TextToSet,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,

				Parent = TextButton,
			})

			if Data.TextProperties then
				local Properties = typeof(Data.TextProperties) == "function" and Data.TextProperties()
					or Data.TextProperties
				for Property, Value in pairs(Properties) do
					ItemText[Property] = Value
				end
			end

			TextButton.MouseEnter:Connect(function()
				wax.shared.TweenService
					:Create(TextButton, self.TweenInfo, {
						BackgroundTransparency = 0,
					})
					:Play()
			end)

			TextButton.MouseLeave:Connect(function()
				wax.shared.TweenService
					:Create(TextButton, self.TweenInfo, {
						BackgroundTransparency = 1,
					})
					:Play()
			end)

			TextButton.MouseButton1Click:Connect(function()
				TextButton.BackgroundTransparency = 1

				if Data.Callback then
					Data.Callback()
				end

				if Data.CloseOnClick ~= false then
					ContextData.Close()
				else
					for _, Option in pairs(ContextData.Options) do
						Option:Display()
					end
				end
			end)

			function Data:Display()
				if typeof(Data.Text) == "function" then
					ItemText.Text = Data.Text()
				end

				if typeof(Data.Icon) == "function" then
					IconToSet = Data.Icon()

					if tostring(IconToSet):match("rbxasset") then
						ItemIcon.ImageRectOffset = Vector2.new(0, 0)
						ItemIcon.ImageRectSize = Vector2.new(0, 0)
						ItemIcon.Image = IconToSet
					else
						Icons.SetIcon(ItemIcon, IconToSet)
					end
				end

				if Data.TextProperties then
					local Properties = typeof(Data.TextProperties) == "function" and Data.TextProperties()
						or Data.TextProperties
					for Property, Value in pairs(Properties) do
						ItemText[Property] = Value
					end
				end
			end

			ContextData.Options[TextButton] = Data
		end
	end

	function ContextData.Open()
		local Owner = ContextData.Owner
		if Owner.CurrentContext == ContextData then
			return
		end

		if Owner.CurrentContext then
			Owner.CurrentContext.Close()
		end

		Owner.CurrentContext = ContextData
		for Object, Data in pairs(ContextData.Options) do
			if Data.Condition and not Data.Condition() then
				continue
			end
			Object.Parent = Owner.Frame
			Data:Display()
		end

		local DPIScale = Owner.GetDPIScale()
		if ContextData.MouseOnCursorPosition then
			Owner.Frame.Position = UDim2.fromOffset(
				wax.shared.UserInputService:GetMouseLocation().X,
				wax.shared.UserInputService:GetMouseLocation().Y - (45 / DPIScale)
			)
		else
			Owner.Frame.Position = UDim2.fromOffset(
				Parent.AbsolutePosition.X / DPIScale,
				(Parent.AbsolutePosition.Y + Parent.AbsoluteSize.Y) / DPIScale
			)
		end

		Owner.Frame.Visible = true
	end

	function ContextData.Toggle()
		if ContextData.Owner.CurrentContext == ContextData then
			ContextData.Close()
			return
		end

		ContextData.Open()
	end

	function ContextData.Close()
		if ContextData.Owner.CurrentContext ~= ContextData then
			return
		end

		ContextData.Owner.Frame.Visible = false
		for Object, _ in pairs(ContextData.Options) do
			Object.Parent = nil
		end
		ContextData.Owner.CurrentContext = nil
	end

	function ContextData:SetContextMenu(MenuOptions: { any })
		for Object, _Data in pairs(self.Options) do
			Object:Destroy()
		end
		self.Options = {}
		BuildContextMenu(MenuOptions)
	end

	BuildContextMenu(Options)
	return ContextData
end

return ContextMenu
