local Interface = require("@src/Utils/UI/Interface")

local Modal = {}
Modal.__index = Modal

export type Modal = {
	OpenedModal: GuiObject?,
	Background: GuiObject,
	TweenInfo: TweenInfo,
} & typeof(setmetatable({}, Modal))

local DefaultTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Exponential)

function Modal.new(
	Parent: GuiObject,
	Options: {
		TweenInfo: TweenInfo?,
	}?
)
	local self = setmetatable({
		OpenedModal = nil,
		Background = nil,
		TweenInfo = Options and Options.TweenInfo or DefaultTweenInfo,
	}, Modal)

	self.Background = Interface.New("TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Visible = false,
		ZIndex = 2,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 6),
		},

		Parent = Parent,
	})

	self.Background.MouseButton1Click:Connect(function()
		self:Close()
	end)

	return self
end

function Modal:Open(Parent)
	self.OpenedModal = Parent

	self.OpenedModal.Visible = true
	self.Background.Visible = true
end

function Modal:Close()
	if self.OpenedModal then
		self.OpenedModal.Visible = false
		self.OpenedModal = nil
	end

	self.Background.Visible = false
end

function Modal:ConnectCloseButton(Button, Image)
	Button.MouseEnter:Connect(function()
		wax.shared.TweenService
			:Create(Image, self.TweenInfo, {
				ImageTransparency = 0.25,
			})
			:Play()
	end)

	Button.MouseLeave:Connect(function()
		wax.shared.TweenService
			:Create(Image, self.TweenInfo, {
				ImageTransparency = 0.5,
			})
			:Play()
	end)

	Button.MouseButton1Click:Connect(function()
		self:Close()
	end)
end

function Modal:CreateTop(Title: string, Icon: string, Parent: GuiObject)
	local ModalTop = Interface.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = Parent,

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},
	})

	local ModalTitle = Interface.New("TextLabel", {
		Text = Title,
		TextSize = 17,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = ModalTop,
	})

	local ModalIcon
	if Icon:match("rbxasset") then
		ModalIcon = Interface.New("ImageLabel", {
			Image = Icon,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(4, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,

			Parent = ModalTop,
		})
	else
		ModalIcon = Interface.NewIcon(Icon, {
			ImageTransparency = 0.5,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(4, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,

			Parent = ModalTop,
		})
	end

	local CloseButton = Interface.New("ImageButton", {
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = ModalTop,
	})

	local CloseImage = Interface.NewIcon("x", {
		ImageTransparency = 0.5,
		Size = UDim2.fromOffset(22, 22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		Parent = CloseButton,
	})

	self:ConnectCloseButton(CloseButton, CloseImage)

	Interface.New("Frame", {
		Parent = Parent,
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 36),
	})

	return ModalTitle, ModalIcon
end

return Modal
