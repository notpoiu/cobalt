--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Resize = require("@src/Window/Utils/Input/Resize")
local Highlighter = require("@src/Window/Utils/Text/Highlighter")

local Signals = require("@src/Utils/Signal")
local Types = require("@src/Utils/CodeGen/Types")

local Bridge = require(script.Parent.Parent.Bridge)

local UI = {}

function UI.Apply(Cobalt, Manager, State)
	function Cobalt.UI:GetSelectedRemote()
		local Log = Bridge.Get().GetCurrentLog()
		return Log and Log.Instance or nil, Log and Log.Type or nil
	end

	function Cobalt.UI:CreateModal(Title: string, Icon: string)
		local WindowBridge = Bridge.Get()
		local ModalController = WindowBridge.ModalController

		local ModalFrame: TextButton = Interface.New("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.65, 0, 0, 285),
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

		Resize.new({
			MainFrame = ModalFrame,

			MaximumSize = UDim2.new(1, -2, 1, -2),
			MinimumSize = UDim2.fromScale(0.65, 0.712),
			Mirrored = true,
			LockedPosition = true,

			CornerHandleSize = 20,
			HandleSize = 6,
			GetDPIScale = WindowBridge.GetDPIScale,
		})

		ModalController:CreateTop(Title, Icon, ModalFrame)

		local ContentFrame = Interface.New("ScrollingFrame", {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 1, -37),
			AutomaticCanvasSize = Enum.AutomaticSize.XY,
			CanvasSize = UDim2.fromScale(0, 0),
			ScrollBarThickness = 0,
			HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = ModalFrame,
		})

		local OnCloseEvent = Signals:New()
		local ClosedByInternal = false

		ModalFrame:GetPropertyChangedSignal("Visible"):Connect(function()
			if not ModalFrame.Visible and not ClosedByInternal then
				OnCloseEvent:Fire()
			end
			ClosedByInternal = false
		end)

		local TabsState = {
			Container = nil,
			Scroller = nil,
			FooterContainer = nil,
			CurrentTab = nil,
			Buttons = {},
			Contents = {},
		}

		local ModalInterface = {
			Container = ContentFrame,
			Open = function()
				ModalController:Open(ModalFrame)
			end,
			Close = function()
				ClosedByInternal = true
				ModalController:Close()
				OnCloseEvent:Fire()
			end,
			OnClose = OnCloseEvent,
		}

		function ModalInterface:SelectTab(TabName: string)
			if not TabsState.Buttons[TabName] then
				return
			end

			for _, Button in pairs(TabsState.Buttons) do
				Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				Button.Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			end
			for _, Content in pairs(TabsState.Contents) do
				Content.Visible = false
			end

			TabsState.Buttons[TabName].BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			TabsState.Buttons[TabName].Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			TabsState.Contents[TabName].Visible = true
			TabsState.CurrentTab = TabName
		end

		function ModalInterface:AddTab(TabName: string, Icon: string)
			if not TabsState.Container then
				ContentFrame.Visible = false

				TabsState.Scroller = Interface.New("ScrollingFrame", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 4, 0, 44),
					Size = UDim2.new(1, -10, 0, 36),
					CanvasSize = UDim2.fromScale(0, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.X,
					ScrollBarThickness = 0,
					ScrollingDirection = Enum.ScrollingDirection.X,
					ClipsDescendants = false,
					Parent = ModalFrame,
				})

				TabsState.Container = Interface.New("Frame", {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromScale(0, 1),
					Parent = TabsState.Scroller,

					["UIListLayout"] = {
						Padding = UDim.new(0, 6),
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Top,
					},

					["UIPadding"] = {
						PaddingRight = UDim.new(0, 20),
						PaddingTop = UDim.new(0, 2),
						PaddingLeft = UDim.new(0, 2),
					},
				})
			end

			local TabUI, TabContent = WindowBridge.InfoModal.Tabs:CreateTabContent()

			if TabsState.FooterContainer then
				TabUI.Size = UDim2.new(1, -12, 1, -118)
			else
				TabUI.Size = UDim2.new(1, -12, 1, -79)
			end

			TabUI.Parent = ModalFrame
			TabUI.Visible = false

			local TextWrapper = Interface.New("Frame", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 24),
				ZIndex = 2,

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

				["TextLabel"] = {
					Text = TabName,
					TextSize = 15,
					Size = UDim2.fromScale(0, 1),
					AutomaticSize = Enum.AutomaticSize.X,
					LayoutOrder = 2,
					ZIndex = 2,
				},
			})

			Interface.NewIcon(Icon, {
				Position = UDim2.fromOffset(8, 5),
				Size = UDim2.fromOffset(16, 16),
				LayoutOrder = 1,
				ZIndex = 2,
				Parent = TextWrapper,
			})

			local ButtonColor = TabsState.CurrentTab == TabName and Color3.fromRGB(25, 25, 25)
				or Color3.fromRGB(0, 0, 0)
			local TabButton = Interface.New("TextButton", {
				BackgroundColor3 = ButtonColor,
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = "",
				Parent = TabsState.Container,

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
					Size = UDim2.fromScale(1, 0.6),
					BackgroundColor3 = ButtonColor,
					BorderSizePixel = 0,
				},

				TextWrapper,
			})

			TabsState.Buttons[TabName] = TabButton
			TabsState.Contents[TabName] = TabUI

			TabButton.MouseButton1Click:Connect(function()
				ModalInterface:SelectTab(TabName)
			end)

			if not TabsState.CurrentTab then
				ModalInterface:SelectTab(TabName)
			end

			return TabContent
		end

		function ModalInterface:AddFooterButton(Icon: string, Title: string, Options: {})
			if not TabsState.FooterContainer then
				TabsState.FooterContainer = Interface.New("Frame", {
					AnchorPoint = Vector2.new(0, 1),
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 6, 1, -7),
					Size = UDim2.new(1, -12, 0, 32),
					Parent = ModalFrame,

					["UIListLayout"] = {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 6),
					},
				})

				ContentFrame.Size = UDim2.new(1, 0, 1, -69)
				for _, Content in pairs(TabsState.Contents) do
					Content.Size = UDim2.new(1, -12, 1, -118)
				end
			end

			local Button = WindowBridge.InfoModal.Footer:CreateDropdownButton(Icon, Title, Options)
			Button.Parent = TabsState.FooterContainer

			return Button
		end

		return ModalInterface
	end

	function Cobalt.UI:CreatePluginSettings()
		if not State.CurrentPluginSettings then
			State.CurrentPluginSettings = Bridge.Get().PluginsModal.Settings:CreateSection(
				State.CurrentPluginData.Name,
				`PluginSettings-{State.CurrentPluginData.Name}-`
			)
		end

		return State.CurrentPluginSettings
	end

	function Cobalt.UI.RemoteInfo:CreateTab(TabName: string, Icon: string)
		local InfoModal = Bridge.Get().InfoModal
		local TabUI, TabContent = InfoModal.Tabs:CreateTabContent()
		InfoModal.Tabs:CreateTab(Icon, TabName, TabUI)

		return TabContent, TabUI
	end

	function Cobalt.UI.RemoteInfo:DisableDefaultButtons(TabName: string)
		local TabRegistry = Manager.Registry.UIHooks.RemoteInfo.Tabs[TabName]
		if not TabRegistry then
			Manager.Registry.UIHooks.RemoteInfo.Tabs[TabName] = { DisableDefaults = true, Buttons = {} }
		else
			TabRegistry.DisableDefaults = true
		end

		Cobalt.UI.RemoteInfo.UpdateFooterButtons()
	end

	function Cobalt.UI.RemoteInfo.UpdateFooterButtons()
		local WindowBridge = Bridge.GetOptional()
		if WindowBridge and WindowBridge.InfoModal and WindowBridge.InfoModal.Footer then
			WindowBridge.InfoModal.Footer:UpdateDropdownButtons()
		end
	end

	function Cobalt.UI.RemoteInfo:AddFooterButton(TabName: string, Icon: string, Title: string, Options: {})
		local TabRegistry = Manager.Registry.UIHooks.RemoteInfo.Tabs[TabName]
		if not TabRegistry then
			TabRegistry = { DisableDefaults = false, Buttons = {} }
			Manager.Registry.UIHooks.RemoteInfo.Tabs[TabName] = TabRegistry
		end

		local ButtonDefinition: { [any]: any } = {
			Icon = Icon,
			Title = Title,
			Options = Options,
		}

		table.insert(TabRegistry.Buttons, ButtonDefinition)
		Cobalt.UI.RemoteInfo.UpdateFooterButtons()

		return function()
			local Index = table.find(TabRegistry.Buttons, ButtonDefinition)
			if Index then
				table.remove(TabRegistry.Buttons, Index)

				if ButtonDefinition.Instance then
					ButtonDefinition.Instance.Parent = nil
				end

				Cobalt.UI.RemoteInfo.UpdateFooterButtons()
			end
		end
	end

	function Cobalt.UI.RemoteInfo:BindToModalOpen(Callback: (CallInfo: Types.CallInfo) -> ...any)
		table.insert(Manager.Registry.UIHooks.RemoteInfo.Open, Callback)

		return function()
			local Index = table.find(Manager.Registry.UIHooks.RemoteInfo.Open, Callback)
			if Index then
				table.remove(Manager.Registry.UIHooks.RemoteInfo.Open, Index)
			end
		end
	end

	function Cobalt.UI.RemoteInfo:InterceptModalOpen(Callback: (CallInfo: Types.CallInfo) -> boolean?)
		table.insert(Manager.Registry.UIHooks.RemoteInfo.Intercept, Callback)

		return function()
			local Index = table.find(Manager.Registry.UIHooks.RemoteInfo.Intercept, Callback)
			if Index then
				table.remove(Manager.Registry.UIHooks.RemoteInfo.Intercept, Index)
			end
		end
	end

	function Cobalt.UI.ContextMenu:AddOption(
		MenuType: "RemoteList" | "CallList",
		Icon: string,
		Title: string,
		Callback: (InteractionData: any) -> ()
	)
		if not Manager.Registry.UIHooks.ContextMenus[MenuType] then
			warn(
				`[Cobalt] Invalid MenuType provided to ContextMenu:AddOption. Expected RemoteList | CallList, got {tostring(
					MenuType
				)}`
			)
			return function() end
		end

		local OptionDefinition = {
			Icon = Icon,
			Text = Title,
			Callback = Callback,
		}

		table.insert(Manager.Registry.UIHooks.ContextMenus[MenuType], OptionDefinition)

		return function()
			local Index = table.find(Manager.Registry.UIHooks.ContextMenus[MenuType], OptionDefinition)
			if Index then
				table.remove(Manager.Registry.UIHooks.ContextMenus[MenuType], Index)
			end
		end
	end

	function Cobalt.UI.ColorizeLuauCode(code: string)
		return Highlighter.Run(code)
	end

	for Idx, Value in Interface do
		Cobalt.UI[Idx] = Value
	end
end

return UI
