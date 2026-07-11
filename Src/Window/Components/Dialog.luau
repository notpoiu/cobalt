--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Icons = require("@src/Utils/UI/Assets/Icons")
local Constants = require("@src/Window/Constants")
local Types = require("@src/Window/Types")

--// Types \\--
type Dialog = Types.Dialog
type DialogDismissBehavior = Types.DialogDismissBehavior
type FooterButton = Types.DialogFooterButton
type DialogProps = Types.DialogProps

--// Animation \\--
local BackdropTransparency = 0.25
local ClosedDialogScale = 0.95
local BackdropTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local DialogTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

--// Setup \\--
local function SetupDialog(
	props: {
		MainFrame: Frame,
	},
	ZIndexOffset: number
)
	--// Props \\--
	local MainFrame = props.MainFrame

	--// UI \\--
	local Root = Interface.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 3 + ZIndexOffset,
		Parent = MainFrame,
	})

	local OverlayWrapper = Interface.New("TextButton", {
		Text = "",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = Root,

		Constants.MainUICorner,
	})

	local DialogFrame = Interface.New("CanvasGroup", {
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(11, 11, 11),
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.Y,
		GroupTransparency = 1,
		Size = UDim2.new(0.65, 0, 0, 120),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		ZIndex = 2,
		Parent = Root,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 8),
		},

		["UIStroke"] = {
			Color = Color3.fromRGB(26, 26, 26),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		},

		["UIScale"] = {
			Scale = ClosedDialogScale,
		},
	})

	local InputSink = Interface.New("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = DialogFrame,
	})

	local DialogBody = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = InputSink,

		["UIPadding"] = {
			PaddingTop = UDim.new(0, 15),
			PaddingRight = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 15),
			PaddingBottom = UDim.new(0, 47),
		},

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 5),
		},
	})

	--// Header \\--
	local Header = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = DialogBody,
	})

	--// Close Button \\--
	local CloseButton = Interface.New("ImageButton", {
		ImageTransparency = 0.5,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0, 15, 0, 15),
		Position = UDim2.new(1, 0, 0, 0),
		Parent = Header,
	})
	do
		Icons.SetIcon(CloseButton, "x")
	end

	--// Title Description \\--
	local TitleDescriptionContainer = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = Header,
	})

	local TitleWrapper = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Parent = TitleDescriptionContainer,

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 5),
		},
	})

	local TitleLabel = Interface.New("TextLabel", {
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
		Text = "<b>Title</b>",
		LayoutOrder = 1,

		Parent = TitleWrapper,
	})

	local HeaderIcon = Interface.New("ImageLabel", {
		Size = UDim2.new(0, 23, 0, 23),
		Visible = false,

		Parent = TitleWrapper,
	})

	local DescriptionLabel = Interface.New("TextLabel", {
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Description",
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 28),
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,

		Parent = TitleDescriptionContainer,
	})

	--// Main Content \\--
	local MainContent = Interface.New("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		Parent = DialogBody,
	})

	--// Footer \\--
	local Footer = Interface.New("Frame", {
		Parent = InputSink,
		BackgroundColor3 = Color3.fromRGB(36, 36, 36),
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundTransparency = 1,

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 10),
		},

		["UIPadding"] = {
			PaddingRight = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		},
	})

	--// Footer Button \\--
	local function CreateFooterButton(options: FooterButton)
		local ButtonType = options.Type or "Secondary"
		local ButtonText = options.Text or ""
		local ButtonIcon = options.Icon

		local ButtonBackground = ButtonType == "Primary" and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(21, 21, 21)
		local ButtonTextColor = ButtonType == "Primary" and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)

		local Button = Interface.New("ImageButton", {
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundColor3 = ButtonBackground,
			BackgroundTransparency = 0,
			ImageRectSize = Vector2.new(24, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			ImageRectOffset = Vector2.new(424, 325),
			["UICorner"] = {
				CornerRadius = UDim.new(0, 6),
			},

			["UIStroke"] = {
				Color = Color3.fromRGB(31, 31, 31),
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			},

			["UIPadding"] = {
				PaddingTop = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 6),
			},

			["UIListLayout"] = {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
			},

			Parent = Footer,
		})

		local Text = Interface.New("TextLabel", {
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = ButtonTextColor,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Text = ButtonText,
			LayoutOrder = 1,

			Parent = Button,
		})

		local Icon = Interface.New("ImageLabel", {
			Visible = false,
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Size = UDim2.fromScale(1, 1),

			Parent = Button,
		})
		if ButtonIcon then
			Icons.SetIcon(Icon, ButtonIcon)
			Icon.Visible = true
		end

		return Button, Text, Icon
	end

	return {
		Root = Root,
		Overlay = OverlayWrapper,
		Container = DialogFrame,
		Scale = DialogFrame.UIScale,
		CloseButton = CloseButton,
		Header = {
			TitleLabel = TitleLabel,
			DescriptionLabel = DescriptionLabel,
			HeaderIcon = HeaderIcon,
		},
		MainContent = MainContent,
		Footer = {
			CreateButton = CreateFooterButton,
			UI = Footer,
		},
	}
end

--// Component \\--
return function(ComponentProps: {
	MainFrame: Frame,
})
	--// Registry \\--
	local Registry = {}
	local NextDialogId = 0

	--// Dialog \\--
	local Dialog = {}
	Dialog.__index = Dialog

	--[[
        Create a new dialog.

        @param props - The props for the dialog.
    ]]
	function Dialog.new(props: DialogProps)
		local AutoShow = props.AutoShow == true or props.AutoShow == nil

		--// Constructor \\--
		local self = setmetatable({}, Dialog)

		NextDialogId += 1
		local DialogId = NextDialogId
		Registry[DialogId] = self

		--// State \\--
		self.DialogId = DialogId
		self.DismissBehavior = props.DismissBehavior or "Destroy"
		self.ActiveTweens = {}
		self.AnimationId = 0
		self.IsOpen = false
		self.DismissTween = nil
		self.Destroyed = false

		--// Setup \\--
		self:Setup(props, DialogId)

		if AutoShow then
			self:Show()
		end

		return self
	end

	--[[
        Setup the dialog with the given props and offset. Designed for internal use only.

        @param props - The props for the dialog.
        @param Offset - The offset for the dialog.
    ]]
	function Dialog:Setup(props: DialogProps, Offset: number)
		local RawDialog = SetupDialog(ComponentProps, Offset)
		self.RawDialog = RawDialog
		for Key, Value in RawDialog do
			self[Key] = Value
		end

		--// Header \\--
		self.Header.TitleLabel.Text = `<b>{props.Title}</b>`
		self.Header.DescriptionLabel.Text = props.Description
		if props.TitleColor then
			self.Header.TitleLabel.TextColor3 = props.TitleColor
			self.Header.HeaderIcon.ImageColor3 = props.TitleColor
		end

		if props.Icon then
			if props.Icon:find("rbxasset") then
				self.Header.HeaderIcon.Image = props.Icon
			else
				Icons.SetIcon(self.Header.HeaderIcon, props.Icon)
			end

			self.Header.TitleLabel.Size = UDim2.new(1, -28, 0, 20)
			self.Header.HeaderIcon.Visible = true
		end

		--// Footer \\--
		for _, Button in self.Footer.UI:QueryDescendants("ImageButton") do
			Button:Destroy()
		end

		for _, ButtonData in props.Footer do
			local Button, Text, Icon = self.Footer.CreateButton(ButtonData)

			Button.Parent = self.Footer.UI
			Text.Parent = Button
			Icon.Parent = Button

			--// Action \\--
			if not ButtonData.Action then
				continue
			end

			Button.MouseButton1Click:Connect(function()
				if ButtonData.Action == "Dismiss" then
					self:Dismiss(self.DismissBehavior)
				else
					ButtonData.Action(self)
				end
			end)
		end

		self.Overlay.MouseButton1Click:Connect(function()
			self:Dismiss(self.DismissBehavior)
		end)
		self.CloseButton.MouseButton1Click:Connect(function()
			self:Dismiss(self.DismissBehavior)
		end)
	end

	function Dialog:_CancelAnimation()
		self.AnimationId += 1

		for _, Tween in self.ActiveTweens do
			Tween:Cancel()
		end
		table.clear(self.ActiveTweens)

		return self.AnimationId
	end

	--[[
        Dismiss the dialog.
    ]]
	function Dialog:Dismiss(DismissBehavior: DialogDismissBehavior?)
		if self.Destroyed then
			return nil
		elseif not self.IsOpen then
			return self.DismissTween
		end

		local AnimationId = self:_CancelAnimation()
		local Behavior = DismissBehavior or self.DismissBehavior
		self.IsOpen = false
		self.Container.Interactable = false

		local BackdropTween = wax.shared.TweenService:Create(self.Overlay, BackdropTweenInfo, {
			BackgroundTransparency = 1,
		})
		local DialogFadeTween = wax.shared.TweenService:Create(self.Container, DialogTweenInfo, {
			GroupTransparency = 1,
		})
		local DialogScaleTween = wax.shared.TweenService:Create(self.Scale, DialogTweenInfo, {
			Scale = ClosedDialogScale,
		})
		self.DismissTween = DialogScaleTween

		self.ActiveTweens = { BackdropTween, DialogFadeTween, DialogScaleTween }
		DialogScaleTween.Completed:Once(function(PlaybackState)
			if PlaybackState ~= Enum.PlaybackState.Completed or self.AnimationId ~= AnimationId or self.IsOpen then
				return
			end

			self.DismissTween = nil
			table.clear(self.ActiveTweens)

			if Behavior == "Destroy" then
				self:Destroy()
				return
			end

			self.Root.Visible = false
			self.Overlay.Active = false
		end)

		BackdropTween:Play()
		DialogFadeTween:Play()
		DialogScaleTween:Play()

		return DialogScaleTween
	end

	--[[
        Show the dialog.
    ]]
	function Dialog:Show()
		if self.Destroyed or self.IsOpen then
			return
		end

		local WasHidden = not self.Root.Visible
		local AnimationId = self:_CancelAnimation()
		self.IsOpen = true
		self.DismissTween = nil

		if WasHidden then
			self.Overlay.BackgroundTransparency = 1
			self.Container.GroupTransparency = 1
			self.Scale.Scale = ClosedDialogScale
		end

		self.Root.Visible = true
		self.Overlay.Active = true
		self.Container.Interactable = true

		local BackdropTween = wax.shared.TweenService:Create(self.Overlay, BackdropTweenInfo, {
			BackgroundTransparency = BackdropTransparency,
		})
		local DialogFadeTween = wax.shared.TweenService:Create(self.Container, DialogTweenInfo, {
			GroupTransparency = 0,
		})
		local DialogScaleTween = wax.shared.TweenService:Create(self.Scale, DialogTweenInfo, {
			Scale = 1,
		})

		self.ActiveTweens = { BackdropTween, DialogFadeTween, DialogScaleTween }
		DialogScaleTween.Completed:Once(function(PlaybackState)
			if PlaybackState ~= Enum.PlaybackState.Completed or self.AnimationId ~= AnimationId or not self.IsOpen then
				return
			end

			table.clear(self.ActiveTweens)
		end)

		BackdropTween:Play()
		DialogFadeTween:Play()
		DialogScaleTween:Play()
	end

	--[[
        Destroy the dialog.
    ]]
	function Dialog:Destroy()
		if self.Destroyed then
			return
		end

		self.Destroyed = true
		self:_CancelAnimation()
		self.DismissTween = nil
		Registry[self.DialogId] = nil
		self.Root:Destroy()
	end

	return Dialog
end
