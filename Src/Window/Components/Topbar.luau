--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Constants = require("@src/Window/Constants")
local Drag = require("@src/Window/Utils/Input/Drag")
local ModalController = require("@src/Window/Components/Modal")

--// Component \\--
return function(props: {
	MainFrame: Frame,
	ShowButton: TextButton,
	CobaltLogo: string,
	Modals: {
		Controller: ModalController.Modal,
		[string]: any,
	},
	GetDPIScale: (() -> number)?,
})
	--// Props \\--
	local MainFrame = props.MainFrame
	local ShowButton = props.ShowButton
	local Modals = props.Modals

	--// UI \\--
	local TopBar = Interface.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Size = UDim2.new(1, 0, 0, 36),
		ZIndex = 0,
		Constants.MainUICorner,
		Parent = MainFrame,

		["TextLabel"] = {
			Text = "Cobalt",
			TextSize = 18,
			Position = UDim2.fromOffset(0, 1),
			Size = UDim2.new(1, 0, 1, -1),
		},

		["ImageLabel"] = {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.new(1, -12, 1, -12),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Image = props.CobaltLogo,
		},
	})
	Interface.HideCorner(TopBar, UDim2.fromScale(1, 0.5), Vector2.yAxis)

	local TopButtons = Interface.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		},

		["UIPadding"] = {
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
		},

		Parent = TopBar,
	})

	--// Functions \\--
	local function CreateTopButton(IconName: string, Order: number, Callback: (() -> ())?)
		local Button = Interface.New("ImageButton", {
			LayoutOrder = Order,
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,

			["UIPadding"] = {
				PaddingBottom = UDim.new(0, 3),
				PaddingLeft = UDim.new(0, 3),
				PaddingRight = UDim.new(0, 3),
				PaddingTop = UDim.new(0, 3),
			},

			Parent = TopButtons,
		})

		local Image = Interface.NewIcon(IconName, {
			ImageTransparency = 0.5,
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,

			Parent = Button,
		})

		Button.MouseEnter:Connect(function()
			wax.shared.TweenService
				:Create(Image, Constants.DefaultTweenInfo, {
					ImageTransparency = 0.25,
				})
				:Play()
		end)

		Button.MouseLeave:Connect(function()
			wax.shared.TweenService
				:Create(Image, Constants.DefaultTweenInfo, {
					ImageTransparency = 0.5,
				})
				:Play()
		end)

		if Callback then
			Button.MouseButton1Click:Connect(Callback)
		end

		return Button, Image
	end

	local function CreateTopSeparator(Order: number)
		Interface.New("ImageLabel", {
			LayoutOrder = Order,
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			Parent = TopButtons,

			["Frame"] = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(50, 50, 50),
				Size = UDim2.fromOffset(4, 4),
				Position = UDim2.fromScale(0.5, 0.5),

				["UICorner"] = {
					CornerRadius = UDim.new(1, 0),
				},
			},
		})
	end

	--// Right Side Layout \\--
	local TopButtonData = {}

	for _, ModalData in Modals do
		if typeof(ModalData) ~= "table" then
			continue
		end

		local TopButton = ModalData.TopButton
		if not TopButton or not ModalData.Frame then
			continue
		end

		table.insert(TopButtonData, {
			Type = "Button",
			Icon = TopButton.Icon,
			Order = TopButton.Order,
			Callback = function()
				if ModalData.Open then
					ModalData:Open()
				else
					Modals.Controller:Open(ModalData.Frame)
				end
			end,
		})
	end

	table.sort(TopButtonData, function(Left, Right)
		return (Left.Order or 0) < (Right.Order or 0)
	end)

	table.insert(TopButtonData, {
		Type = "Separator",
	})
	table.insert(TopButtonData, {
		Type = "Button",
		Icon = "minus",
		Callback = function()
			MainFrame.Visible = false
			ShowButton.Visible = true
		end,
	})
	table.insert(TopButtonData, {
		Type = "Button",
		Icon = "x",
		Callback = wax.shared.Unload,
	})

	for Order, Data in TopButtonData do
		if Data.Type == "Separator" then
			CreateTopSeparator(Order)
		else
			CreateTopButton(Data.Icon, Order, Data.Callback)
		end
	end

	Drag.Setup(MainFrame, TopBar, nil, {
		GetDPIScale = props.GetDPIScale,
	})
	Drag.Setup(ShowButton, ShowButton, nil, {
		GetDPIScale = props.GetDPIScale,
	})

	return {
		TopBar = TopBar,
		TopButtons = TopButtons,
		CreateTopButton = CreateTopButton,
		CreateTopSeparator = CreateTopSeparator,
	}
end
