--[[
	Main Window Logic for cobalt, all UI elements are created and managed here.
]]

local AnticheatData = require(script.Parent.Utils.Anticheats.Main)
local LuaEncode = require(script.Parent.Utils.Serializer.LuaEncode)

local Utils = script.Parent.Utils

local Pagination = require(Utils.Pagination)
local CodeGen = require(Utils.CodeGen.Generator)
local SessionExporter = require(Utils.CodeGen.SessionExporter)

local UIUtils = script.Parent.Utils.UI

local SyntaxHighlighter = require(UIUtils.Highlighter)

local AssetManager = require(UIUtils.AssetManager)
local Icons = require(UIUtils.Icons)

local Interface = require(UIUtils.Interface)
local Helper = require(UIUtils.Helper)

local Resize = require(UIUtils.Resize)
local Drag = require(UIUtils.Drag)

local PaginationHelper = Pagination.new({
	ItemsPerPage = wax.shared.SaveManager:GetState("MaxItemPerPages", 20),
	TotalItems = 0,
})

local Tabs = {}
local CurrentPage = {}
local CurrentInfo, CurrentTab, CurrentLog, InfoButtons

local LogsList
local ShowPagination, ShowCalls, CreateCallFrame, ShowLog, CreateLogButton, CleanLogsList, UpdateSearch, SelectResult, EnterResult, OpenSearch

local DefaultTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Exponential)

type SupportedRemoteTypes = RemoteEvent | RemoteFunction | BindableEvent | BindableFunction | UnreliableRemoteEvent
local ClassOrder = {
	"RemoteEvent",
	"UnreliableRemoteEvent",
	"RemoteFunction",
	"BindableEvent",
	"BindableFunction",
}

local Images = {
	RemoteEvent = "rbxassetid://110803789420086",
	UnreliableRemoteEvent = "rbxassetid://126244162339059",
	RemoteFunction = "rbxassetid://108537517159060",
	BindableEvent = "rbxassetid://116839398727495",
	BindableFunction = "rbxassetid://112264959079193",
}

-- Functions
local function UpdateLogNameSize(Log)
	local TextSizeX, _TextSizeY =
		wax.shared.GetTextBounds("x" .. #Log.Calls, Log.Button.Calls.FontFace, Log.Button.Calls.TextSize)
	Log.Button.Name.Size = UDim2.new(1, -(TextSizeX + 24), 1, 0)
end

local function GetDPIScale()
	local Scale = wax.shared.SaveManager:GetState("WindowDPIScale", "100%")
	return (tonumber(Scale:sub(1, #Scale - 1)) or 100) / 100
end
wax.shared.GetDPIScale = GetDPIScale

-- ContentProvider PreloadAsync bypass
Images = AssetManager.GetRemoteImages(Images)

local CobaltLogo = AssetManager.GetImage("Logo")

local ScreenGui = Interface.New("ScreenGui", {
	Name = "Cobalt",
	ResetOnSpawn = false,
	Parent = Interface.GetScreenParent(),
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
wax.shared.ScreenGui = ScreenGui

local ScreenDPIScale = Interface.New("UIScale", {
	Parent = ScreenGui,
	Scale = GetDPIScale(),
})

local MainUICorner = Interface.New("UICorner", {
	CornerRadius = UDim.new(0, 6),
})

local MainFrame = Interface.New("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(15, 15, 15),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(640, 420),
	ZIndex = 0,

	MainUICorner,
	Parent = ScreenGui,
})

local ShowButton = Interface.New("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.fromRGB(15, 15, 15),
	Position = UDim2.new(0.5, 0, 0, 36),
	Size = UDim2.fromOffset(36, 36),
	Text = "",
	Visible = false,

	["ImageLabel"] = {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = CobaltLogo,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -10, 1, -10),
	},

	["UIStroke"] = {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.new(1, 1, 1),
	},

	MainUICorner,
	Parent = ScreenGui,
})
do
	ShowButton.MouseButton1Click:Connect(function()
		ShowButton.Visible = false
		MainFrame.Visible = true
	end)
end

-- Resizing
Resize.new({
	MainFrame = MainFrame,

	MinimumSize = Vector2.new(585, 220),

	CornerHandleSize = 20,
	HandleSize = 6,
})

-- Context Menus
local CurrentContext
local ContextMenu = Interface.New("Frame", {
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

	Parent = ScreenGui,
})

local function CreateContextMenu(Parent: GuiObject, Options: {}, MouseOnCursorPosition: boolean?)
	local ContextData = {
		Parent = Parent,
		Options = {},
	}

	local function BuildContextMenu(Options: {})
		for Order, Data in pairs(Options) do
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
					:Create(TextButton, DefaultTweenInfo, {
						BackgroundTransparency = 0,
					})
					:Play()
			end)
			TextButton.MouseLeave:Connect(function()
				wax.shared.TweenService
					:Create(TextButton, DefaultTweenInfo, {
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
					ContextData:Close()
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

	function ContextData:Open()
		if CurrentContext == ContextData then
			return
		end

		if CurrentContext then
			CurrentContext:Close()
		end

		CurrentContext = ContextData
		for Object, Data in pairs(ContextData.Options) do
			if Data.Condition and not Data.Condition() then
				continue
			end
			Object.Parent = ContextMenu
			Data:Display()
		end

		if MouseOnCursorPosition then
			ContextMenu.Position = UDim2.fromOffset(
				wax.shared.UserInputService:GetMouseLocation().X,
				wax.shared.UserInputService:GetMouseLocation().Y - (45 / GetDPIScale())
			)
		else
			ContextMenu.Position =
				UDim2.fromOffset(
					Parent.AbsolutePosition.X / GetDPIScale(),
					(Parent.AbsolutePosition.Y + Parent.AbsoluteSize.Y) / GetDPIScale()
				)
		end
		ContextMenu.Visible = true
	end

	function ContextData:Toggle()
		if CurrentContext == ContextData then
			ContextData:Close()
			return
		end

		ContextData:Open()
	end

	function ContextData:Close()
		if CurrentContext ~= ContextData then
			return
		end

		ContextMenu.Visible = false
		for Object, _ in pairs(ContextData.Options) do
			Object.Parent = nil
		end
		CurrentContext = nil
	end

	function ContextData:SetContextMenu(Options: { any })
		for Object, Data in pairs(ContextData.Options) do
			Object:Destroy()
		end
		ContextData.Options = {}
		BuildContextMenu(Options)
	end

	BuildContextMenu(Options)
	return ContextData
end

-- Sonner toast
local SonnerUI = Interface.New("ScrollingFrame", {
	Name = "Sonner",
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(285, 115),
	Position = UDim2.fromScale(1, 1),
	AnchorPoint = Vector2.new(1, 1),
	ZIndex = 5000,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ScrollingEnabled = false,
	ClipsDescendants = true,
	Parent = MainFrame,
})

wax.shared.Sonner.init(SonnerUI)

-- Modal
local OpenedModal
local ModalBackground = Interface.New("TextButton", {
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.5,
	Size = UDim2.fromScale(1, 1),
	Text = "",
	Visible = false,
	ZIndex = 2,

	MainUICorner,
	Parent = MainFrame,
})

local function OpenModal(Parent)
	OpenedModal = Parent

	OpenedModal.Visible = true
	ModalBackground.Visible = true
end

local function CloseModal()
	if OpenedModal then
		OpenedModal.Visible = false
		OpenedModal = nil
	end

	ModalBackground.Visible = false
end

ModalBackground.MouseButton1Click:Connect(CloseModal)

local function ConnectCloseButton(Button, Image, Parent)
	Button.MouseEnter:Connect(function()
		wax.shared.TweenService
			:Create(Image, DefaultTweenInfo, {
				ImageTransparency = 0.25,
			})
			:Play()
	end)
	Button.MouseLeave:Connect(function()
		wax.shared.TweenService
			:Create(Image, DefaultTweenInfo, {
				ImageTransparency = 0.5,
			})
			:Play()
	end)
	Button.MouseButton1Click:Connect(CloseModal)
end

local function CreateModalTop(Title: string, Icon: string, Parent: GuiObject)
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

	ConnectCloseButton(CloseButton, CloseImage, Parent)

	Interface.New("Frame", {
		Parent = Parent,
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 36),
	})

	return ModalTitle, ModalIcon
end

-- Settings
local SettingsFrame = Interface.New("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.65, 0, 0, 285),
	Text = "",
	Visible = false,
	Parent = ModalBackground,

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
	MainFrame = SettingsFrame,

	MaximumSize = UDim2.new(1, -2, 1, -2),
	MinimumSize = UDim2.fromScale(0.65, 0.712),
	Mirrored = true,
	LockedPosition = true,

	CornerHandleSize = 20,
	HandleSize = 6,
})

CreateModalTop("Settings", "settings", SettingsFrame)

local SettingsScrollingFrame = Interface.New("ScrollingFrame", {
	AnchorPoint = Vector2.new(0, 1),
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 1, -37),
	ClipsDescendants = true,
	ScrollBarThickness = 2,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.fromScale(0, 0),
	Parent = SettingsFrame,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 15),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
	},
})

-- Plugins
local PluginsFrame = Interface.New("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.65, 0, 0, 285),
	Text = "",
	Visible = false,
	Parent = ModalBackground,

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
	MainFrame = PluginsFrame,

	MaximumSize = UDim2.new(1, -2, 1, -2),
	MinimumSize = UDim2.fromScale(0.65, 0.712),
	Mirrored = true,
	LockedPosition = true,

	CornerHandleSize = 20,
	HandleSize = 6,
})

CreateModalTop("Plugins", "blocks", PluginsFrame)

local PluginsScrollingFrame = Interface.New("ScrollingFrame", {
	AnchorPoint = Vector2.new(0, 1),
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 1, -37),
	ClipsDescendants = true,
	ScrollBarThickness = 2,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.fromScale(0, 0),
	Parent = PluginsFrame,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 15),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
	},
})

local SettingsBuilder = {}
local SectionBuilder = {}
do
	-- Builders
	SettingsBuilder.__index = SettingsBuilder
	SectionBuilder.__index = SectionBuilder

	function SettingsBuilder.new(Parent: Frame)
		return setmetatable({
			Parent = Parent,
		}, SettingsBuilder)
	end

	function SectionBuilder.new(Parent: Frame, DataSavePrefix: string?)
		return setmetatable({
			Parent = Parent,
			DataSavePrefix = DataSavePrefix or "",
		}, SectionBuilder)
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
				Padding = UDim.new(0, 6),
			},

			["TextLabel"] = {
				Text = SectionName,
				FontFace = Font.fromId(12187365364, Enum.FontWeight.Bold),
				TextSize = 18,
				Size = UDim2.new(1, 0, 0, 18),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = -1,
			},
		})

		return SectionBuilder.new(Section, DataSavePrefix)
	end

	-- Creates a horizontal sub-row inside a section and returns a SectionBuilder for it.
	-- Use this when you want multiple elements side-by-side (e.g. two buttons in one row).
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
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Parent = self.Parent,
			TextWrapped = true,
		})
	end

	-- Section Element Constructors
	function SectionBuilder:CreateButton(Text: string, Callback: () -> (), TextSize: number?)
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

	function SectionBuilder:CreateCheckbox(
		Idx: string,
		Options: {
			Text: string,
			Callback: (boolean) -> () | nil,
			Default: boolean?,
		}
	)
		Idx = self.DataSavePrefix .. Idx
		local Checkbox = {
			Default = Options.Default or false,
			Value = wax.shared.SaveManager:GetState(Idx, Options.Default),
		}

		local CheckboxUI = Interface.New("TextButton", {
			Text = Options.Text,
			TextSize = 16,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = self.Parent,
		})

		local ToggleOnColor = Color3.fromRGB(52, 199, 89)
		local ToggleOffColor = Color3.fromRGB(50, 50, 50)

		local ToggleKnobOffSize = UDim2.fromOffset(16, 16)
		local ToggleKnobOnSize = UDim2.fromOffset(18, 18)
		local ToggleKnobInset = 10

		local ToggleTrack = Interface.New("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(36, 20),
			BackgroundColor3 = ToggleOffColor,
			Parent = CheckboxUI,

			["UICorner"] = {
				CornerRadius = UDim.new(1, 0),
			},
		})

		local ToggleKnob = Interface.New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = ToggleKnobOffSize,
			Parent = ToggleTrack,

			["UICorner"] = {
				CornerRadius = UDim.new(1, 0),
			},
		})

		local function UpdateToggleVisual(instant: boolean?)
			local TargetTrackColor = if Checkbox.Value then ToggleOnColor else ToggleOffColor
			local TargetKnobPosition = if Checkbox.Value
				then UDim2.new(1, -ToggleKnobInset, 0.5, 0)
				else UDim2.new(0, ToggleKnobInset, 0.5, 0)
			local TargetKnobSize = if Checkbox.Value then ToggleKnobOnSize else ToggleKnobOffSize

			if instant then
				ToggleTrack.BackgroundColor3 = TargetTrackColor
				ToggleKnob.Position = TargetKnobPosition
				ToggleKnob.Size = TargetKnobSize
			else
				wax.shared.TweenService
					:Create(ToggleTrack, DefaultTweenInfo, {
						BackgroundColor3 = TargetTrackColor,
					})
					:Play()

				wax.shared.TweenService
					:Create(ToggleKnob, DefaultTweenInfo, {
						Position = TargetKnobPosition,
						Size = TargetKnobSize,
					})
					:Play()
			end
		end

		UpdateToggleVisual(true)

		local function Toggle()
			Checkbox:SetValue(not Checkbox.Value)
		end

		CheckboxUI.MouseButton1Click:Connect(Toggle)

		function Checkbox:Reset()
			Checkbox:SetValue(Checkbox.Default)
		end

		function Checkbox:SetValue(NewValue)
			if wax.shared.ActorCommunicator then
				pcall(function()
					wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, NewValue)
				end)
			end

			wax.shared.SaveManager:SetState(Idx, NewValue)

			Checkbox.Value = NewValue
			UpdateToggleVisual()

			if Options.Callback then
				Options.Callback(Checkbox.Value)
			end
		end

		if wax.shared.ActorCommunicator then
			pcall(function()
				wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, Checkbox.Value)
			end)
		end
		wax.shared.Settings[Idx] = Checkbox
		return Checkbox
	end

	function SectionBuilder:CreateTextBox(
		Idx: string,
		Options: {
			Text: string,
			Callback: (string) -> () | nil,
			Default: string?,
			Placeholder: string?,
			ClearTextOnFocus: boolean?,
			Width: number?,
			NumericOnly: boolean?,
		}
	)
		Idx = self.DataSavePrefix .. Idx
		local NumericOnly = Options.NumericOnly == true
		local TextBoxWidth = Options.Width or 160

		local function NormalizeValue(NewValue: any): string
			local Value = tostring(NewValue or "")

			if not NumericOnly then
				return Value
			end

			if Value == "" then
				return ""
			end

			local Characters = table.create(#Value)
			local HasDigits = false
			local HasDecimal = false
			local SignApplied = false

			for Index = 1, #Value do
				local Char = string.sub(Value, Index, Index)
				local Byte = string.byte(Char)

				if Char == "-" and not SignApplied and not HasDigits and not HasDecimal then
					table.insert(Characters, Char)
					SignApplied = true
				elseif Char == "." and not HasDecimal then
					table.insert(Characters, Char)
					HasDecimal = true
					SignApplied = true
				elseif Byte and Byte >= 48 and Byte <= 57 then
					table.insert(Characters, Char)
					HasDigits = true
					SignApplied = true
				end
			end

			local Sanitized = table.concat(Characters)

			if Sanitized == "-" or Sanitized == "." or Sanitized == "-." then
				return ""
			end

			return Sanitized
		end

		local DefaultValue = NormalizeValue(Options.Default)
		local SavedValue = wax.shared.SaveManager:GetState(Idx)
		local InitialValue = NormalizeValue(if SavedValue ~= nil then SavedValue else DefaultValue)

		local TextSetting = {
			Default = DefaultValue,
			Value = InitialValue,
		}

		local Container = Interface.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 26),
			Parent = self.Parent,

			["UIPadding"] = {
				PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, 2),
			},
		})

		Interface.New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, -TextBoxWidth - 6, 1, 0),
			Text = Options.Text,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextWrapped = true,
			Parent = Container,
		})

		local Input = Interface.New("TextBox", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Color3.fromRGB(5, 5, 5),
			ClearTextOnFocus = Options.ClearTextOnFocus or false,
			PlaceholderColor3 = Color3.fromRGB(128, 128, 128),
			PlaceholderText = Options.Placeholder or "",
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, TextBoxWidth, 1, -2),
			Text = InitialValue,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = Container,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 4),
			},

			["UIStroke"] = {
				Color = Color3.fromRGB(25, 25, 25),
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			},

			["UIPadding"] = {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			},
		})

		local function SyncValue(NewValue: string, FireCallback: boolean?)
			TextSetting.Value = NewValue
			Input.Text = NewValue

			if FireCallback ~= false and Options.Callback then
				local ArgumentToPass = NewValue
				if NumericOnly then
					ArgumentToPass = tonumber(ArgumentToPass)
				end

				Options.Callback(ArgumentToPass)
			end
		end

		function TextSetting:Reset()
			TextSetting:SetValue(TextSetting.Default)
		end

		function TextSetting:SetValue(NewValue)
			local PreparedValue = NormalizeValue(NewValue)

			if PreparedValue == TextSetting.Value then
				SyncValue(PreparedValue, false)
				return
			end

			if wax.shared.ActorCommunicator then
				pcall(function()
					wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, PreparedValue)
				end)
			end

			wax.shared.SaveManager:SetState(Idx, PreparedValue)
			SyncValue(PreparedValue)
		end

		Input.FocusLost:Connect(function()
			TextSetting:SetValue(Input.Text)
		end)

		if wax.shared.ActorCommunicator then
			pcall(function()
				wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, TextSetting.Value)
			end)
		end

		SyncValue(TextSetting.Value, false)

		wax.shared.Settings[Idx] = TextSetting
		return TextSetting
	end

	function SectionBuilder:CreateDropdown(
		Idx: string,
		Options: {
			Multi: boolean?,
			AllowNull: boolean?,
			Values: { [any]: any },
			Default: any | { [any]: any },
			Callback: (any) -> () | nil,
			Text: string,
		}
	)
		Idx = self.DataSavePrefix .. Idx
		local AllowNull = Options.AllowNull or false
		assert(AllowNull or Options.Default ~= nil, "Default value must be provided when AllowNull is false")

		local function CreateLookupTable(Values: { any } | any)
			if typeof(Values) ~= "table" then
				return Values
			end

			local LookupTable = {}
			for _, Value in Values do
				LookupTable[Value] = true
			end
			return LookupTable
		end

		local Dropdown = {
			Values = Options.Values or {},
			Default = Options.Default and CreateLookupTable(Options.Default)
				or Options.AllowNull and (Options.Multi and {} or Options.Values[1])
				or {},
			Value = wax.shared.SaveManager:GetState(
				Idx,
				Options.Default and CreateLookupTable(Options.Default)
					or Options.AllowNull and (Options.Multi and {} or Options.Values[1])
					or {}
			),
			Multi = Options.Multi or false,
			Callback = Options.Callback,
		}

		local DropdownUI = Interface.New("TextButton", {
			Text = Options.Text,
			TextSize = 16,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Parent = self.Parent,
		})

		DropdownUI.AutoButtonColor = false

		local DropdownDisplay = Interface.New("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(180, 24),
			Parent = DropdownUI,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 4),
			},

			["UIStroke"] = {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(25, 25, 25),
				Thickness = 1,
			},

			["UIPadding"] = {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			},
		})

		local ValueLabel = Interface.New("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -16, 1, 0),
			Text = "Select...",
			TextSize = 16,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextTransparency = 0.45,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Parent = DropdownDisplay,
		})

		local DropdownIcon = Interface.NewIcon("chevron-down", {
			AnchorPoint = Vector2.new(1, 0.5),
			ImageTransparency = 0.2,
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(12, 12),
			Parent = DropdownDisplay,
		})

		local DisplayDefaultColor = DropdownDisplay.BackgroundColor3
		local DisplayHoverColor = Color3.fromRGB(12, 12, 12)

		local function TweenDisplayColor(TargetColor, TargetTransparency)
			wax.shared.TweenService
				:Create(DropdownDisplay, DefaultTweenInfo, {
					BackgroundColor3 = TargetColor,
				})
				:Play()

			if TargetTransparency then
				wax.shared.TweenService
					:Create(DropdownIcon, DefaultTweenInfo, {
						ImageTransparency = TargetTransparency,
					})
					:Play()
			end
		end

		DropdownUI.MouseEnter:Connect(function()
			TweenDisplayColor(DisplayHoverColor, 0.05)
		end)

		DropdownUI.MouseLeave:Connect(function()
			TweenDisplayColor(DisplayDefaultColor, 0.2)
		end)

		local function IterateValues(Callback: (any, string) -> ())
			for Index, Object in Dropdown.Values do
				local ActualValue = typeof(Index) == "number" and Object or Index
				local DisplayText = typeof(Index) == "number" and tostring(Object) or tostring(Index)
				Callback(ActualValue, DisplayText)
			end
		end

		local function ResolveValueText(Value)
			local Resolved
			IterateValues(function(ActualValue, DisplayText)
				if ActualValue == Value then
					Resolved = DisplayText
				end
			end)
			return Resolved or (Value ~= nil and tostring(Value) or "")
		end

		local function UpdateValueLabel()
			local DisplayText = "Select..."
			local Transparency = 0.45

			if Dropdown.Multi then
				local SelectedTexts = {}
				IterateValues(function(Value, Text)
					if Dropdown.Value[Value] then
						table.insert(SelectedTexts, Text)
					end
				end)

				if #SelectedTexts == 0 then
					DisplayText = "None"
					Transparency = 0.45
				else
					table.sort(SelectedTexts)
					if #SelectedTexts <= 2 then
						DisplayText = table.concat(SelectedTexts, ", ")
					else
						DisplayText = string.format("%s, +%d", SelectedTexts[1], #SelectedTexts - 1)
					end
					Transparency = 0
				end
			else
				local CurrentValue = Dropdown.Value
				if CurrentValue == nil or CurrentValue == "" then
					DisplayText = "None"
					Transparency = 0.45
				else
					local Resolved = ResolveValueText(CurrentValue)
					if Resolved == "" then
						DisplayText = tostring(CurrentValue)
					else
						DisplayText = Resolved
					end
					Transparency = 0
				end
			end

			ValueLabel.Text = DisplayText
			ValueLabel.TextTransparency = Transparency
		end

		local function BuildDropdownContext()
			local Options = {}
			for Index, Object in Dropdown.Values do
				local IsArray = typeof(Index) == "number"

				local ContextOption = {
					Text = tostring(Object),
					CloseOnClick = not Dropdown.Multi,
					Callback = function()
						local Value = IsArray and Object or Index

						if Dropdown.Multi then
							Dropdown.Value[Value] = not (Dropdown.Value[Value] or false)
						else
							Dropdown.Value = Value
						end

						if wax.shared.ActorCommunicator then
							pcall(function()
								wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, Dropdown.Value)
							end)
						end

						wax.shared.SaveManager:SetState(Idx, Dropdown.Value)

						UpdateValueLabel()

						if Dropdown.Callback then
							Dropdown.Callback(Dropdown.Value)
						end
					end,
					TextProperties = function()
						local Value = IsArray and Object or Index

						if Dropdown.Multi and Dropdown.Value[Value] then
							return {
								TextTransparency = 0,
							}
						elseif not Dropdown.Multi and Dropdown.Value == Value then
							return {
								TextTransparency = 0,
							}
						end

						return {
							TextTransparency = 0.5,
						}
					end,
				}

				if not IsArray then
					ContextOption.Text = Index
					ContextOption.Icon = Object
				end

				table.insert(Options, ContextOption)
			end
			return Options
		end

		local ContextMenu = CreateContextMenu(DropdownDisplay, BuildDropdownContext())

		DropdownUI.MouseButton1Click:Connect(ContextMenu.Toggle)
		function Dropdown:Reset()
			if Dropdown.Multi then
				local Cloned = {}
				for Key, Value in pairs(Dropdown.Default) do
					Cloned[Key] = Value
				end
				Dropdown:SetValue(Cloned)
			else
				Dropdown:SetValue(Dropdown.Default)
			end

			UpdateValueLabel()
		end

		function Dropdown:SetValue(NewValue)
			if wax.shared.ActorCommunicator then
				pcall(function()
					wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, NewValue)
				end)
			end

			wax.shared.SaveManager:SetState(Idx, NewValue)

			ContextMenu:Close()

			for Image, Object in pairs(Dropdown.Values) do
				local IsArray = typeof(Image) == "number"
				local Value = IsArray and Object or Image

				if Dropdown.Multi then
					Dropdown.Value[Value] = NewValue[Value]
				else
					Dropdown.Value = NewValue
				end
			end

			UpdateValueLabel()
		end

		if wax.shared.ActorCommunicator then
			pcall(function()
				wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, Dropdown.Value)
			end)
		end

		UpdateValueLabel()

		wax.shared.Settings[Idx] = Dropdown
		return Dropdown
	end

	function SectionBuilder:CreateRemoteList(
		Idx: string,
		Options: {
			Text: string,
			Callback: (any) -> () | nil,
			NullMessage: string,
		}
	)
		Idx = self.DataSavePrefix .. Idx
		local RemoteList = {
			Value = {},
			InfoMapping = {},
		}

		local RemoveIgnored

		local RemoteListContainer = Interface.New("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			Parent = self.Parent,

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

		function RemoteList:Display()
			for _, Object in pairs(RemoteListContainer:GetChildren()) do
				if not Object:IsA("Frame") then
					continue
				end
				Object:Destroy()
			end

			NoRemotesText.Visible = (#self.Value == 0)
			RemoveIgnored.Visible = (#self.Value > 0)

			for _, remoteData in self.Value do
				local remote = remoteData.Instance
				if not remote then
					continue
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
							Image = Images[remote.ClassName],
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundTransparency = 1,
							LayoutOrder = 1,
						},

						["TextLabel"] = {
							Text = `{remote.Name} ({remoteData.Type})`,
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
						:Create(RemoveButton, DefaultTweenInfo, {
							ImageTransparency = 0,
						})
						:Play()
				end)

				RemoveButton.MouseLeave:Connect(function()
					wax.shared.TweenService
						:Create(RemoveButton, DefaultTweenInfo, {
							ImageTransparency = 0.5,
						})
						:Play()
				end)

				RemoveButton.MouseButton1Click:Connect(function()
					self:RemoveFromList(remoteData)
					if Options.Callback then
						Options.Callback(remoteData)
					end
				end)
			end
		end

		function RemoteList:AddToList(remote)
			table.insert(self.Value, remote)

			self:Display()
		end

		function RemoteList:RemoveFromList(remote)
			local index = table.find(self.Value, remote)
			if not index then
				return
			end

			table.remove(self.Value, index)

			self:Display()
		end

		function RemoteList:SetList(remotes: { SupportedRemoteTypes })
			self.Value = remotes

			self:Display()
		end

		RemoveIgnored = self:CreateButton("Remove All", function()
			if not Options.Callback then
				return
			end

			local ToRemove = {}
			for _, remote in RemoteList.Value do
				Options.Callback(remote)
				table.insert(ToRemove, remote)
			end

			for _, remote in ToRemove do
				RemoteList:RemoveFromList(remote)
			end
			wax.shared.Sonner.success("Removed all remotes")
		end)
		RemoveIgnored.Visible = false

		RemoteList:Display()

		wax.shared.Settings[Idx] = RemoteList
		return RemoteList
	end
end

local PluginSettings = SettingsBuilder.new(PluginsScrollingFrame)
wax.shared.PluginSettings = PluginSettings

local PluginsSection = PluginSettings:CreateSection("Plugins")
do
	local HeaderLabel = PluginsSection.Parent:FindFirstChildWhichIsA("TextLabel")
	local SummaryLabel = Interface.New("TextLabel", {
		Text = `<font transparency="0.5">Waiting for plugins...</font>`,
		RichText = true,
		TextSize = 13,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundTransparency = 1,
		Parent = HeaderLabel,
	})

	-- Container that holds all per-plugin cards
	local PluginCardsContainer = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		Parent = PluginsSection.Parent,

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 5),
		},
	})

	local function CreatePluginCard(IsError: boolean, Title: string, Meta: string, Body: string)
		local AccentColor = IsError and Color3.fromRGB(220, 55, 55) or Color3.fromRGB(55, 185, 100)

		local Card = Interface.New("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(18, 18, 18),
			Size = UDim2.fromScale(1, 0),
			Parent = PluginCardsContainer,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 6),
			},

			["UIStroke"] = {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(35, 35, 35),
				Thickness = 1,
			},
		})

		-- Left accent bar
		Interface.New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = AccentColor,
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 3, 1, -8),
			BorderSizePixel = 0,
			Parent = Card,
		})


		local Content = Interface.New("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			Parent = Card,

			["UIPadding"] = {
				PaddingLeft  = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingTop   = UDim.new(0, 7),
				PaddingBottom = UDim.new(0, 7),
			},

			["UIListLayout"] = {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				Padding = UDim.new(0, 2),
			},
		})

		-- Title row: name + badge
		local TitleRow = Interface.New("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			Parent = Content,

			["UIListLayout"] = {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
			},
		})

		Interface.New("TextLabel", {
			Text = Title,
			RichText = false,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = TitleRow,
		})

		-- Status badge (only shown for errors)
		if IsError then
			local Badge = Interface.New("Frame", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = AccentColor,
				BackgroundTransparency = 0.75,
				LayoutOrder = 2,
				Parent = TitleRow,

				["UICorner"] = {
					CornerRadius = UDim.new(1, 0),
				},

				["UIPadding"] = {
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 6),
					PaddingTop = UDim.new(0, 2),
					PaddingBottom = UDim.new(0, 2),
				},
			})

			Interface.New("TextLabel", {
				Text = "ERROR",
				Font = Enum.Font.GothamBold,
				TextColor3 = AccentColor,
				TextSize = 10,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Parent = Badge,
			})
		end

		-- Meta line (version · author  OR  file path)
		if Meta ~= "" then
			Interface.New("TextLabel", {
				Text = Meta,
				RichText = false,
				Font = Enum.Font.Gotham,
				TextColor3 = Color3.fromRGB(160, 160, 160),
				TextSize = 12,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				TextWrapped = true,
				Parent = Content,
			})
		end

		-- Body (description or error message)
		if Body ~= "" then
			Interface.New("TextLabel", {
				Text = Body,
				RichText = false,
				Font = Enum.Font.Gotham,
				TextColor3 = IsError and Color3.fromRGB(210, 120, 120) or Color3.fromRGB(140, 140, 140),
				TextSize = 12,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				TextWrapped = true,
				Parent = Content,
			})
		end
	end

	task.spawn(function()
		while not wax.shared.CobaltPluginManager or not wax.shared.CobaltPluginManager.Initialized do
			task.wait()
		end

		local Registry = wax.shared.CobaltPluginManager.Registry
		local LoadedCount = #Registry.Plugins
		local ErrorCount  = #Registry.Errored

		-- Update summary label
		local SummaryParts = {}
		if LoadedCount > 0 then
			table.insert(SummaryParts, `<font color="#37b964"><b>{LoadedCount}</b></font> loaded`)
		end
		if ErrorCount > 0 then
			table.insert(SummaryParts, `<font color="#dc3737"><b>{ErrorCount}</b></font> errored`)
		end
		if #SummaryParts == 0 then
			table.insert(SummaryParts, `<font transparency="0.5">No plugins installed.</font>`)
		end
		SummaryLabel.RichText = true
		SummaryLabel.Text = table.concat(SummaryParts, `<font transparency="0.6"> · </font>`)

		-- Errored plugins first (most actionable)
		for _, ErrorInfo in Registry.Errored do
			local FileName = string.match(ErrorInfo.FilePath, "([^/]+)$") or ErrorInfo.FilePath
			local Title = ErrorInfo.Name or FileName
			local Meta = if ErrorInfo.Name
				then `v{ErrorInfo.Version or "1.0.0"}  ·  by {ErrorInfo.Author or "Unknown"}  ·  {FileName}`
				else ErrorInfo.FilePath
			CreatePluginCard(true, Title, Meta, ErrorInfo.Error)
		end

		-- Loaded plugins
		for _, PluginInfo in Registry.Plugins do
			local Data = PluginInfo.PluginData
			local Name = Data.Name or "Unknown"
			local Version = Data.Version or "1.0.0"
			local Author = Data.Author or "Unknown"
			local Desc = Data.Description or "No description."
			CreatePluginCard(false, Name, `v{Version}  ·  by {Author}`, Desc)
		end
	end)
end

-- Main Settings
-- God this warning box code is so ass 🥀
if #wax.shared.ExecutorSupport.FailedChecks.NonEssential > 0 then
	local WarningDisplay = Interface.New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.fromRGB(245, 60, 54),
		BackgroundTransparency = 0.75,
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = SettingsScrollingFrame,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIStroke"] = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(245, 60, 54),
			Thickness = 1,
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
	})

	local function CreatePaddingText(size: number)
		return `<font size="{size}"> \n</font>`
	end

	local NoticeTitleInfoSeperator = CreatePaddingText(4)

	Interface.New("TextLabel", {
		Text = `<font size="16"><b>DETECTION NOTICE ⚠️</b></font>\n{NoticeTitleInfoSeperator}Cobalt can get detected because your executor does not support the following functions/libraries:`,
		TextSize = 15,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		BackgroundTransparency = 1,
		Parent = WarningDisplay,
		TextWrapped = true,
	})

	local NonEssentialFailures = wax.shared.ExecutorSupport.FailedChecks.NonEssential
	local DetectionDetails = CreatePaddingText(6)
	local DetectionSuffix = `\n{CreatePaddingText(7)}`
	for _, Name in NonEssentialFailures do
		DetectionDetails ..= `⚠️ <b><font color="#ff9900">{Name}</font></b>\n<i><font size="14" transparency="0.5">{wax.shared.ExecutorSupport[Name].Details}</font></i>{DetectionSuffix}`
	end

	DetectionDetails = DetectionDetails:sub(1, (#DetectionSuffix * -1) - 1)

	Interface.New("TextLabel", {
		Text = DetectionDetails,
		TextSize = 15,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = WarningDisplay,
		TextWrapped = true,
	})
end

local MainSettings = SettingsBuilder.new(SettingsScrollingFrame)
local ExecSupportSection = MainSettings:CreateSection("Support Info")
do
	ExecSupportSection:AddLabel(table.concat({
		`Executor: <b>{wax.shared.ExecutorName}</b>`,
		`Support: {#wax.shared.ExecutorSupport.FailedChecks.Essential == 0 and "<b>Full</b>" or "<b>Partial</b> (" .. #wax.shared.ExecutorSupport.FailedChecks.Essential .. " check(s) failed)"}`,
	}, "\n"))

	local PartialSupportText = ""
	local SupportSuffix = "\n\n"
	for _, Name in wax.shared.ExecutorSupport.FailedChecks.Essential do
		PartialSupportText ..= `❌ <b><font color="#ff0000">{Name}</font></b>\n<i><font size="14" transparency="0.5">{wax.shared.ExecutorSupport[Name].Details}</font></i>{SupportSuffix}`
	end

	PartialSupportText = PartialSupportText:sub(1, (#SupportSuffix * -1) - 1)

	if #wax.shared.ExecutorSupport.FailedChecks.Essential > 0 then
		ExecSupportSection:AddLabel(PartialSupportText)
	end
end

local CodeGenSection = MainSettings:CreateSection("Code Generation")

CodeGenSection:CreateDropdown("InstancePathLookupChain", {
	Text = "Instance Path Lookup Chain",
	Values = {
		["Index"] = "file",
		["WaitForChild"] = "file-clock",
		["FindFirstChild"] = "file-search",
	},
	Default = "Index",
})

CodeGenSection:CreateDropdown("EventReferenceStrategy", {
	Text = "Fallback Event Ref Strategy",
	Values = {
		["GetNil"] = "bug",
		["Upvalue Lookup"] = "circle-fading-arrow-up",
	},
	Default = "GetNil",
})

CodeGenSection:CreateCheckbox("PreferBufferFromString", {
	Text = "Prefer buffer.fromstring",
	Default = false,
})

CodeGenSection:CreateCheckbox("CacheInstancePaths", {
	Text = "Cache Event Instance Paths",
	Default = false,
})

CodeGenSection:CreateCheckbox("ShowWatermark", {
	Text = "Show Cobalt Watermark",
	Default = true,
})

local MainSection = MainSettings:CreateSection("Main")

MainSection:CreateDropdown("WindowDPIScale", {
	Text = "DPI Scale",
	Values = {
		"50%",
		"75%",
		"100%",
		"125%",
		"150%"
	},
	Default = "100%",

	Callback = function(value)
		ScreenDPIScale.Scale = GetDPIScale()
	end
})

MainSection:CreateTextBox("MaxItemPerPages", {
	Text = "Logs Per Page",
	Default = 20,
	NumericOnly = true,

	Callback = function(max)
		PaginationHelper:SetItemsPerPage(max)

		if not CurrentLog then
			return
		end

		PaginationHelper:Update(#CurrentLog.Calls)
		PaginationHelper:SetPage(1)
		CurrentPage[CurrentLog] = 1

		ShowLog(CurrentLog)
	end,
})

MainSection:CreateCheckbox("ExecuteOnTeleport", {
	Text = "Execute On Teleport",
	Default = false,
})

MainSection:CreateCheckbox("UseAlternativeHooks", {
	Text = "Use alternative metamethod hook",
	Default = false,
})

MainSection:CreateCheckbox("AnticheatBypass", {
	Text = "Built-in Anticheat Bypass",
	Default = false,
})

if AnticheatData.Disabled then
	MainSection:AddLabel(`Anticheat Detected: <b>{AnticheatData.Name}</b>`)
end

wax.shared.ClearLogs = function(FilterInstance: Instance?, FilterType: string?)
	local ClearedAny = false
	for Type, LogCategory in pairs(wax.shared.Logs) do
		if FilterType and Type ~= FilterType then
			continue
		end

		for Index, Log in pairs(LogCategory) do
			if FilterInstance and Log.Instance ~= FilterInstance then
				continue
			end

			if Log.Button then
				Log.Button.Instance:Destroy()
				Log.Button = nil
			end

			CurrentPage[Log] = nil

			table.clear(Log.Calls)
			table.clear(Log.GameCalls)
			Log.Index = 0
			ClearedAny = true
		end
	end

	CleanLogsList()
	if not FilterInstance then
		CurrentLog = nil
	elseif CurrentLog and CurrentLog.Instance == FilterInstance then
		CurrentLog = nil
	end

	if ClearedAny then
		wax.shared.Sonner.success(`Successfully Cleared {FilterInstance and FilterInstance.Name .. " " or ""}{FilterType or "All"} Logs`)
	end
end