--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Icons = require("@src/Utils/UI/Assets/Icons")
local Constants = require("@src/Window/Constants")
local Types = require("@src/Window/Types")

return function(props: {
	Parent: GuiObject,
	Idx: string,
	CreateButton: (string, () -> ()) -> TextButton,
	Options: {
		Text: string,
		Callback: ((any) -> ())?,
		NullMessage: string,
	},
})
	--// Props \\--
	local Options = props.Options

	--// Setup \\--
	local RemoteList = {
		Idx = props.Idx,
		Value = {},
		InfoMapping = {},
	}

	local RemoveIgnored

	local RemoteListContainer = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		Parent = props.Parent,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 8),
		},

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 6),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		},

		["UIStroke"] = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(25, 25, 25),
			Thickness = 1,
		},
	})

	local NoRemotesText = Interface.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 100),
		TextTransparency = 0.5,
		Text = Options.NullMessage,
		TextSize = 14,
		Visible = true,
		Parent = RemoteListContainer,
	})

	local function CreateListElement(RemoteData)
		local Remote = RemoteData.Instance
		if not Remote then
			return
		end

		local ListElement = Interface.New("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			Size = UDim2.new(1, 0, 0, 32),
			Parent = RemoteListContainer,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 4),
			},

			["UIStroke"] = {
				Color = Color3.fromRGB(25, 25, 25),
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			},

			["Frame"] = {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				["UIListLayout"] = {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 4),
				},

				["UIPadding"] = {
					PaddingLeft = UDim.new(0, 5),
				},

				["ImageLabel"] = {
					Size = UDim2.new(1, -8, 1, -8),
					SizeConstraint = Enum.SizeConstraint.RelativeYY,
					Image = Constants.InstanceClassImages[Remote.ClassName],
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				},

				["TextLabel"] = {
					Text = `{Remote.Name} ({RemoteData.Type})`,
					Size = UDim2.fromScale(1, 1),
					AutomaticSize = Enum.AutomaticSize.X,
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
				},
			},
		})

		local RemoveButton = Interface.New("ImageButton", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(1, -12, 1, -12),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ImageTransparency = 0.5,
			Parent = ListElement,
		})

		Icons.SetIcon(RemoveButton, "trash")

		RemoveButton.MouseEnter:Connect(function()
			wax.shared.TweenService
				:Create(RemoveButton, Constants.DefaultTweenInfo, {
					ImageTransparency = 0,
				})
				:Play()
		end)

		RemoveButton.MouseLeave:Connect(function()
			wax.shared.TweenService
				:Create(RemoveButton, Constants.DefaultTweenInfo, {
					ImageTransparency = 0.5,
				})
				:Play()
		end)

		RemoveButton.MouseButton1Click:Connect(function()
			RemoteList:RemoveFromList(RemoteData)

			if Options.Callback then
				Options.Callback(RemoteData)
			end
		end)
	end

	function RemoteList:Display()
		for _, Object in pairs(RemoteListContainer:GetChildren()) do
			if Object:IsA("Frame") then
				Object:Destroy()
			end
		end

		NoRemotesText.Visible = #self.Value == 0
		RemoveIgnored.Visible = #self.Value > 0

		for _, RemoteData in self.Value do
			CreateListElement(RemoteData)
		end
	end

	function RemoteList:AddToList(Remote)
		table.insert(self.Value, Remote)
		self:Display()
	end

	function RemoteList:RemoveFromList(Remote)
		local Index = table.find(self.Value, Remote)
		if not Index then
			return
		end

		table.remove(self.Value, Index)
		self:Display()
	end

	function RemoteList:SetList(Remotes: { Types.SupportedRemoteTypes })
		self.Value = Remotes
		self:Display()
	end

	RemoveIgnored = props.CreateButton("Remove All", function()
		if not Options.Callback then
			return
		end

		local ToRemove = {}
		for _, Remote in RemoteList.Value do
			Options.Callback(Remote)
			table.insert(ToRemove, Remote)
		end

		for _, Remote in ToRemove do
			RemoteList:RemoveFromList(Remote)
		end

		wax.shared.Sonner.success("Removed all remotes")
	end)
	RemoveIgnored.Visible = false

	RemoteList:Display()
	wax.shared.Settings[props.Idx] = RemoteList

	return RemoteList
end
