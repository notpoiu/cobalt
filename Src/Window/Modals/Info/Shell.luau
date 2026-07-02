--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Constants = require("@src/Window/Constants")

local ModalController = require("@src/Window/Components/Modal")
local ContextMenu = require("@src/Window/Components/ContextMenu")

local Resize = require("@src/Window/Utils/Input/Resize")

return function(props: {
	ModalController: ModalController.Modal,
	ContextMenu: ContextMenu.ContextMenu,
	GetDPIScale: (() -> number)?,
})
	local ModalController = props.ModalController
	local ContextMenu = props.ContextMenu

	local Modal = {
		CurrentInfo = nil,
		Footer = {
			BuiltInButtons = {},
		},
		Tabs = {
			CurrentTab = nil,
		},
	}

	--// UI \\--
	local LeftGradient

	local InfoFrame = Interface.New("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.65, 0.712),
		Text = "",
		Visible = false,
		Parent = ModalController.Background,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 8),
		},

		["UIStroke"] = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(25, 25, 25),
			Thickness = 1,
		},
	})
	do
		--// Right Gradient \\--
		Interface.New("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 44),
			Size = UDim2.new(0, 30, 0, 36),
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			BorderSizePixel = 0,
			ZIndex = 10,
			Parent = InfoFrame,

			["UIGradient"] = {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0),
				}),
			},
		})

		--// Left Gradient \\--
		LeftGradient = Interface.New("Frame", {
			Position = UDim2.new(0, 4, 0, 44),
			Size = UDim2.new(0, 30, 0, 36),
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			BorderSizePixel = 0,
			ZIndex = 10,
			Visible = false,
			Parent = InfoFrame,

			["UIGradient"] = {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			},
		})

		Resize.new({
			MainFrame = InfoFrame,

			MaximumSize = UDim2.new(1, -2, 1, -2),
			MinimumSize = UDim2.fromScale(0.65, 0.712),
			Mirrored = true,
			LockedPosition = true,

			CornerHandleSize = 20,
			HandleSize = 6,
			GetDPIScale = props.GetDPIScale,
		})
	end

	--// Modal Top \\--
	local InfoTitle, InfoIcon = ModalController:CreateTop("...", Constants.InstanceClassImages["RemoteEvent"], InfoFrame)
	do
		Modal.Frame = InfoFrame
		Modal.Title = InfoTitle
		Modal.Icon = InfoIcon
		Modal.Controller = ModalController
		Modal.Background = ModalController.Background
	end

	--// Tabs Scrolling Frame \\--
	local TabsScroller: ScrollingFrame = Interface.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 4, 0, 44),
		Size = UDim2.new(1, -10, 0, 36),
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ClipsDescendants = true,
		Parent = InfoFrame,
	})
	do
		--// Left Gradient \\--
		TabsScroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			LeftGradient.Visible = TabsScroller.CanvasPosition.X > 2
		end)
	end

	--// Tabs Container \\--
	local InfoTabs = Interface.New("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Parent = TabsScroller,

		["UIListLayout"] = {
			Padding = UDim.new(0, 6),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		},

		["UIPadding"] = {
			PaddingRight = UDim.new(0, 20),
			PaddingTop = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 2),
		},
	})
	Modal.TabsContainer = InfoTabs

	--// Footer \\--
	local InfoButtons = Interface.New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 6, 1, -7),
		Size = UDim2.new(1, -12, 0, 32),
		Parent = InfoFrame,

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		},
	})
	Modal.Footer.Frame = InfoButtons

	--// Functions \\--
	--[[
        Creates a dropdown button for the footer.

        @param Icon: The icon of the button.
        @param Title: The title of the button.
        @param Options: The options for the button.
        @return: The button.
    ]]
	function Modal.Footer:CreateDropdownButton(Icon: string, Title: string, Options: {})
		local Button = Interface.New("TextButton", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromRGB(20, 20, 20),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0, 1),
			Text = "",

			["UICorner"] = {
				CornerRadius = UDim.new(0, 6),
			},

			["UIPadding"] = {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			},

			["UIStroke"] = {
				Color = Color3.fromRGB(25, 25, 25),
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			},

			["TextLabel"] = {
				Text = Title,
				TextSize = 15,
				Size = UDim2.fromScale(0, 1),
				Position = UDim2.fromOffset(28, 0),
				AutomaticSize = Enum.AutomaticSize.X,
			},

			Parent = InfoButtons,
		})

		Interface.NewIcon(Icon, {
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,

			Parent = Button,
		})

		local Menu = ContextMenu:Create(Button, Options)

		Button.MouseEnter:Connect(function()
			wax.shared.TweenService
				:Create(Button, Constants.DefaultTweenInfo, {
					BackgroundTransparency = 0,
				})
				:Play()
		end)
		Button.MouseLeave:Connect(function()
			wax.shared.TweenService
				:Create(Button, Constants.DefaultTweenInfo, {
					BackgroundTransparency = 1,
				})
				:Play()
		end)
		Button.MouseButton1Click:Connect(Menu.Toggle)
		return Button
	end

	--[[
        Updates the dropdown buttons in the footer.
    ]]
	function Modal.Footer:UpdateDropdownButtons()
		for _, Element in InfoButtons:GetChildren() do
			if Element:IsA("TextButton") then
				Element.Parent = nil
			end
		end

		local PluginManager = wax.shared.CobaltPluginManager
		local PluginTabRegistry = PluginManager
				and PluginManager.Registry.UIHooks.RemoteInfo.Tabs[Modal.Tabs.CurrentTab]
			or nil

		local DidPluginDisableDefaults = (PluginTabRegistry and PluginTabRegistry.DisableDefaults)

		local PluginButtons = (PluginTabRegistry and PluginTabRegistry.Buttons)

		if not DidPluginDisableDefaults then
			for _, ButtonDef in self.BuiltInButtons do
				if not ButtonDef.Instance then
					ButtonDef.Instance = self:CreateDropdownButton(ButtonDef.Icon, ButtonDef.Title, ButtonDef.Options)
				end
				ButtonDef.Instance.Parent = InfoButtons
			end
		end

		if PluginButtons then
			for _, ButtonDef in PluginButtons do
				if not ButtonDef.Instance then
					ButtonDef.Instance = self:CreateDropdownButton(ButtonDef.Icon, ButtonDef.Title, ButtonDef.Options)
				end
				ButtonDef.Instance.Parent = InfoButtons
			end
		end
	end

	--[[
        Selects a tab.

        @param Title: The title of the tab to select.
    ]]
	function Modal.Tabs:Select(Title: string)
		if not self[Title] then
			return
		end

		for _, TabName in ipairs(self) do
			local Tab = self[TabName]
			local IsSelected = TabName == Title and Tab.TabButton.Parent ~= nil
			local ButtonColor = if IsSelected then Color3.fromRGB(25, 25, 25) else Color3.fromRGB(0, 0, 0)

			Tab.TabButton.BackgroundColor3 = ButtonColor
			Tab.TabButton.Frame.BackgroundColor3 = ButtonColor

			if Tab.TabContents then
				Tab.TabContents.Visible = IsSelected
			end
		end

		self.CurrentTab = Title
		Modal.Footer:UpdateDropdownButtons()
	end

	--[[
        Creates a tab for the modal.

        @param Icon: The icon of the tab.
        @param Title: The title of the tab.
        @param TabContents: The contents of the tab.
        @return: The tab.
    ]]
	function Modal.Tabs:CreateTab(Icon: string, Title: string, TabContents: Frame?)
		if not self.CurrentTab then
			self.CurrentTab = Title
		end

		local IsTabSelected = self.CurrentTab == Title

		if TabContents then
			TabContents.Parent = InfoFrame
			TabContents.Visible = IsTabSelected
		end

		local ButtonColor = IsTabSelected and Color3.fromRGB(25, 25, 25) or Color3.fromRGB(0, 0, 0)
		local TabButton = Interface.New("TextButton", {
			BackgroundColor3 = ButtonColor,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = #self,
			Text = "",
			Parent = InfoTabs,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 8),
			},

			["UIStroke"] = {
				Color = Color3.fromRGB(25, 25, 25),
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			},

			["Frame"] = {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(1, 0.5),
				BackgroundColor3 = ButtonColor,
			},
		})

		local TextWrapper = Interface.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			Parent = TabButton,

			["UIListLayout"] = {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 5),
			},

			["UIPadding"] = {
				PaddingRight = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
			},
		})

		local TabLabel = Interface.New("TextLabel", {
			Text = Title,
			TextSize = 15,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 2,
			ZIndex = 2,

			Parent = TextWrapper,
		})

		Interface.NewIcon(Icon, {
			Position = UDim2.fromOffset(8, 5),
			Size = UDim2.fromOffset(16, 16),
			LayoutOrder = 1,
			ZIndex = 2,

			Parent = TextWrapper,
		})

		self[Title] = {
			TabButton = TabButton,
			TabContents = TabContents,
			TextLabel = TabLabel,
		}
		table.insert(self, Title)

		wax.shared.Connect(TabButton.MouseButton1Click:Connect(function()
			self:Select(Title)
		end))
	end

	--[[
        Creates the content container for a tab.

        @return: The container and scrolling frame.
    ]]
	function Modal.Tabs:CreateTabContent()
		local Container = Interface.New("Frame", {
			Position = UDim2.fromOffset(6, 71),
			Size = UDim2.new(1, -12, 1, -118),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),

			["UICorner"] = {
				CornerRadius = UDim.new(0, 6),
			},

			["UIPadding"] = {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			},

			["UIStroke"] = {
				Color = Color3.fromRGB(25, 25, 25),
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			},
		})

		return Container,
			Interface.New("ScrollingFrame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				AutomaticCanvasSize = Enum.AutomaticSize.XY,
				CanvasSize = UDim2.fromScale(0, 0),
				ScrollBarThickness = 0,
				HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				ScrollingDirection = Enum.ScrollingDirection.XY,
				Parent = Container,
			})
	end

	--[[
        Sets the mounted state of a tab.

        @param Title: The title of the tab.
        @param Mounted: Whether the tab should be mounted.
    ]]
	function Modal.Tabs:SetMounted(Title: string, Visible: boolean)
		local Tab = self[Title]
		if not Tab then
			return
		end

		Tab.TabButton.Parent = if Visible then InfoTabs else nil
		if not Visible and Tab.TabContents then
			Tab.TabContents.Visible = false
		end

		if Visible or self.CurrentTab ~= Title then
			return
		end
		
		for _, TabName in self do
			if TabName == Title or self[TabName].TabButton.Parent == nil then
				continue
			end
			
			self:Select(TabName)
			break
		end
	end

	return Modal
end
