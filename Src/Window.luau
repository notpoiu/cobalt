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

local ImageFetcher = require(UIUtils.ImageFetch)
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
local CurrentInfo, CurrentTab, CurrentLog

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
Images = ImageFetcher.GetRemoteImages(Images)

local CobaltLogo = ImageFetcher.GetImage("Logo")

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

local function CreateSettingsSection(SectionName: string)
	local Section = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		Parent = SettingsScrollingFrame,

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

	return Section
end

local function CreateSettingsButton(Text: string, Callback: () -> (), Section: Frame, TextSize: number?)
	local Button = Interface.New("TextButton", {
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 15,
		Text = "",
		Parent = Section,

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

local function CreateSettingsCheckbox(
	Idx: string,
	Options: {
		Text: string,
		Callback: (boolean) -> () | nil,
		Default: boolean?,
		Section: Frame,
	}
)
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
		Parent = Options.Section,
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

local function CreateSettingsTextBox(
	Idx: string,
	Options: {
		Text: string,
		Section: Frame,
		Callback: (string) -> () | nil,
		Default: string?,
		Placeholder: string?,
		ClearTextOnFocus: boolean?,
		Width: number?,
		NumericOnly: boolean?,
	}
)
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
		Parent = Options.Section,

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

local function CreateSettingsDropdown(
	Idx: string,
	Options: {
		Multi: boolean?,
		AllowNull: boolean?,
		Values: { any },
		Default: any | { any },
		Callback: (any) -> () | nil,
		Text: string,
		Section: Frame,
	}
)
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
		Parent = Options.Section,
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
			wax.shared.ActorCommunicator:Fire("MainSettingsSync", Idx, Dropdown.Default)
		end)
	end

	UpdateValueLabel()

	wax.shared.Settings[Idx] = Dropdown
	return Dropdown
end

local function CreateSettingsRemoteList(
	Idx: string,
	Options: {
		Text: string,
		Callback: (any) -> () | nil,
		Section: Frame,
		NullMessage: string,
	}
)
	local RemoteList = {
		Value = {},
		InfoMapping = {},
	}

	local RemoveIgnored

	local RemoteListContainer = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		Parent = Options.Section,

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

	RemoveIgnored = CreateSettingsButton("Remove All", function()
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
	end, Options.Section)
	RemoveIgnored.Visible = false

	RemoteList:Display()

	wax.shared.Settings[Idx] = RemoteList
	return RemoteList
end

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

local ExecSupportSection = CreateSettingsSection("Support Info")
do
	Interface.New("TextLabel", {
		Text = table.concat({
			`Executor: <b>{wax.shared.ExecutorName}</b>`,
			`Support: {#wax.shared.ExecutorSupport.FailedChecks.Essential == 0 and "<b>Full</b>" or "<b>Partial</b> (" .. #wax.shared.ExecutorSupport.FailedChecks.Essential .. " check(s) failed)"}`,
		}, "\n"),
		TextSize = 16,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = ExecSupportSection,
		TextWrapped = true,

		["UIPadding"] = {
			PaddingBottom = UDim.new(0, 2),
		},
	})

	local PartialSupportText = ""
	local SupportSuffix = "\n\n"
	for _, Name in wax.shared.ExecutorSupport.FailedChecks.Essential do
		PartialSupportText ..= `❌ <b><font color="#ff0000">{Name}</font></b>\n<i><font size="14" transparency="0.5">{wax.shared.ExecutorSupport[Name].Details}</font></i>{SupportSuffix}`
	end

	PartialSupportText = PartialSupportText:sub(1, (#SupportSuffix * -1) - 1)

	if #wax.shared.ExecutorSupport.FailedChecks.Essential > 0 then
		Interface.New("TextLabel", {
			Text = PartialSupportText,
			TextSize = 16,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Parent = ExecSupportSection,
			TextWrapped = true,
		})
	end
end

local CodeGenSection = CreateSettingsSection("Code Generation")

CreateSettingsDropdown("InstancePathLookupChain", {
	Text = "Instance Path Lookup Chain",
	Values = {
		["Index"] = "file",
		["WaitForChild"] = "file-clock",
		["FindFirstChild"] = "file-search",
	},
	Default = "Index",
	Section = CodeGenSection,
})

CreateSettingsCheckbox("PreferBufferFromString", {
	Text = "Prefer buffer.fromstring",
	Default = false,
	Section = CodeGenSection,
})

CreateSettingsCheckbox("ShowWatermark", {
	Text = "Show Cobalt Watermark",
	Default = true,
	Section = CodeGenSection,
})

local MainSection = CreateSettingsSection("Main")

CreateSettingsDropdown("WindowDPIScale", {
	Text = "DPI Scale",
	Values = {
		"50%",
		"75%",
		"100%",
		"125%",
		"150%"
	},
	Default = "100%",
	Section = MainSection,

	Callback = function(value)
		ScreenDPIScale.Scale = GetDPIScale()
	end
})

CreateSettingsTextBox("MaxItemPerPages", {
	Text = "Logs Per Page",
	Section = MainSection,
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

CreateSettingsCheckbox("ExecuteOnTeleport", {
	Text = "Execute On Teleport",
	Default = false,
	Section = MainSection,
})

CreateSettingsCheckbox("UseAlternativeHooks", {
	Text = "Use alternative metamethod hook",
	Default = false,
	Section = MainSection,
})

CreateSettingsCheckbox("AnticheatBypass", {
	Text = "Built-in Anticheat Bypass",
	Default = true,
	Section = MainSection,
})

if AnticheatData.Disabled then
	Interface.New("TextLabel", {
		Text = `Anticheat Detected: <b>{AnticheatData.Name}</b>`,
		TextSize = 16,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = MainSection,
		TextWrapped = true,
	})
end

wax.shared.ClearLogs = function()
	for _, LogCategory in pairs(wax.shared.Logs) do
		for Index, Log in pairs(LogCategory) do
			if Log.Button then
				Log.Button.Instance:Destroy()
				Log.Button = nil
			end

			CurrentPage[Log] = nil

			table.clear(Log.Calls)
			table.clear(Log.GameCalls)
			Log.Index = 0
		end
	end

	CleanLogsList()
	CurrentLog = nil

	wax.shared.Sonner.success("Successfully Cleared All Logs")
end

CreateSettingsButton("Clear All Logs", wax.shared.ClearLogs, MainSection)

local FilterSection = CreateSettingsSection("Filter")

CreateSettingsDropdown("IgnoredRemotesDropdown", {
	Text = "Ignore Remotes",
	Values = Images,
	Default = { "BindableEvent", "BindableFunction" },
	AllowNull = true,
	Multi = true,
	Section = FilterSection,
})

CreateSettingsCheckbox("AutoIgnoreSpammyEvents", {
	Text = "Auto Ignore Spammy Events",
	Default = false,
	Section = FilterSection,
})

CreateSettingsCheckbox("LogActors", {
	Text = "Log Events from Actors",
	Default = true,
	Section = FilterSection,
})

CreateSettingsCheckbox("IgnorePlayerModule", {
	Text = "Ignore Player Module Remotes",
	Default = true,
	Section = FilterSection,
})
CreateSettingsCheckbox("ShowExecutorLogs", {
	Text = `Show {wax.shared.ExecutorName} Remote Logs`,
	Default = true,
	Section = FilterSection,
	Callback = function()
		if not CurrentLog then
			return
		end

		PaginationHelper:Update(#CurrentLog.Calls)
		PaginationHelper:SetPage(1)
		CurrentPage[CurrentLog] = 1

		ShowLog(CurrentLog)
	end,
})
CreateSettingsButton("Reset Filtering to Default", function()
	wax.shared.Settings.IgnoredRemotesDropdown:Reset()
	wax.shared.Settings.IgnoreSpammyRemotes:Reset()
	wax.shared.Settings.IgnorePlayerModule:Reset()
	wax.shared.Settings.ShowExecutorLogs:Reset()

	wax.shared.Sonner.success("Successfully reset remote filtering to default")
end, FilterSection)

local IgnoredSection = CreateSettingsSection("Ignored")

CreateSettingsRemoteList("IgnoredRemotes", {
	Text = "Ignored Remotes",
	NullMessage = "No remotes have been ignored yet.",
	Section = IgnoredSection,
	Callback = function(Remote)
		Remote.Ignored = false
	end,
})

local BlockedSection = CreateSettingsSection("Blocked")

CreateSettingsRemoteList("BlockedRemotes", {
	Text = "Blocked Remotes",
	NullMessage = "No remotes have been blocked yet.",
	Section = BlockedSection,
	Callback = function(Remote)
		Remote.Blocked = false
	end,
})

local LoggingSection = CreateSettingsSection("Logging")
local SessionLog

CreateSettingsCheckbox("EnableLogging", {
	Text = `Enable File Logs`,
	Default = false,
	Section = LoggingSection,
	Callback = function(value)
		if not value then
			wax.shared.LogConnection:Disconnect()
			wax.shared.LogConnection = nil
			wax.shared.LogFileName = nil
			SessionLog.Text = `Current Session Log: <b>Not Logging</b>`
			wax.shared.Sonner.success("Successfully disabled file logging")
			return
		end

		local LogConnection = wax.shared.SetupLoggingConnection()
		SessionLog.Text = `Current Session Log: <b>{wax.shared.LogFileName:gsub("Cobalt/Logs/", "")}</b>`
		wax.shared.LogConnection = wax.shared.Connect(wax.shared.Communicator.Event:Connect(LogConnection))

		wax.shared.Sonner.success("Successfully enabled file logging")
	end,
})

SessionLog = Interface.New("TextLabel", {
	Text = `Current Session Log: <b>{wax.shared.Settings.EnableLogging.Value and wax.shared.LogFileName:gsub(
		"Cobalt/Logs/",
		""
	) or "Not Logging"}</b>`,
	TextSize = 16,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundTransparency = 1,
	Parent = LoggingSection,
	TextWrapped = true,
})

Interface.New("TextLabel", {
	Text = `Logs Path: <b>Cobalt/Logs</b>`,
	TextSize = 16,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundTransparency = 1,
	Parent = LoggingSection,
	TextWrapped = true,
})

local SessionButtonsContainer = Interface.New("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = LoggingSection,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
	},

	["UIPadding"] = {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
	},
})

local SessionButtons = Interface.New("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = SessionButtonsContainer,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 8),
	},
})
local CopySessionName = CreateSettingsButton("Copy Session Name", function()
	if not wax.shared.Settings.EnableLogging.Value then
		wax.shared.Sonner.error("File logging is not enabled")
		return
	end

	local ActualLogFileName = wax.shared.LogFileName:gsub("Cobalt/Logs/", "")
	local Success, Error = pcall(setclipboard, ActualLogFileName)

	if not Success then
		warn(Error)
		wax.shared.Sonner.error("Failed to copy session name")
		return
	end

	wax.shared.Sonner.success("Successfully copied session name to clipboard")
end, SessionButtons, 14)
CopySessionName.Size = UDim2.new(0.5, -4, 0, 24)

local CopyFullSessionPath = CreateSettingsButton("Copy Full Path", function()
	if not wax.shared.Settings.EnableLogging.Value then
		wax.shared.Sonner.error("File logging is not enabled")
		return
	end

	local Success, Error = pcall(setclipboard, wax.shared.LogFileName)

	if not Success then
		warn(Error)
		wax.shared.Sonner.error("Failed to copy log path")
		return
	end

	wax.shared.Sonner.success("Successfully copied log path to clipboard")
end, SessionButtons, 14)
CopyFullSessionPath.Size = UDim2.new(0.5, -4, 0, 24)

local ExportLogsButton = CreateSettingsButton("Export Logs to HTML", function()
	wax.shared.Sonner.promise(function(UpdateProgress)
		assert(typeof(writefile) == "function", "Exploit does not support writefile")
		
		--// Collect all logs \\--
		local AllCalls = SessionExporter:FetchAllLogs()
		local SessionData = SessionExporter:GetSessionData(AllCalls)

		--// Data Processing \\--
		UpdateProgress("Sorting calls...")
		SessionExporter:SortCalls(AllCalls)
		local Events, StringMap = SessionExporter:ProcessCalls(
			AllCalls,
			SessionData,
			UpdateProgress
		)

		--// Export \\--
		local FileName = `Cobalt_Session_{os.time()}.html`
		writefile(
			FileName,
			SessionExporter:ExportSessionToHTML(Events, StringMap, SessionData)
		)
		return FileName
	end, {
		loadingText = "Starting Export...",
		successText = function(fileName) return `Successfully exported trace to {fileName}` end,
		errorText = function(err) return `Export Failed: {err}` end,
	})
end, SessionButtonsContainer, 14)

ExportLogsButton.Size = UDim2.new(1, 0, 0, 24)

local CreditsSection = CreateSettingsSection("Credits")

local Credits = {
	{
		Credit = "upio",
		Description = "Cobalt Developer",
	},
	{
		Credit = "deivid",
		Description = "Cobalt Developer",
	},
	{
		Credit = "shadcn",
		Description = 'UI Design Insipration (<font color="#3798ff">https://ui.shadcn.com/</font>)',
	},
	{
		Credit = "lucide",
		Description = 'Consistent and clean icons (<font color="#3798ff">https://lucide.dev/</font>)',
	},
	{
		Credit = "Emil Kowalski",
		Description = 'Creator of Sonner component (<font color="#3798ff">https://sonner.emilkowal.ski/</font>)',
	},
}

local CreditsWrapper = Interface.New("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = CreditsSection,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 10),
	},
})

for Order, Data in pairs(Credits) do
	Interface.New("TextLabel", {
		Text = `<b>{Data.Credit}</b>\n{Data.Description}`,
		Size = UDim2.fromScale(1, 0),
		TextSize = 14,
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = Order,
		Parent = CreditsWrapper,
	})
end

-- Info
local InfoFrame = Interface.New("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.65, 0.712),
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
	MainFrame = InfoFrame,

	MaximumSize = UDim2.new(1, -2, 1, -2),
	MinimumSize = UDim2.fromScale(0.65, 0.712),
	Mirrored = true,
	LockedPosition = true,

	CornerHandleSize = 20,
	HandleSize = 6,
})

local InfoTitle, InfoIcon = CreateModalTop("...", Images["RemoteEvent"], InfoFrame)
local InfoModalTab = {}

local InfoTabs = Interface.New("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 6, 0, 44),
	Size = UDim2.new(1, -12, 0, 36),
	Parent = InfoFrame,

	["UIListLayout"] = {
		Padding = UDim.new(0, 6),
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	},
})

local CurrentInfoTab = nil
local function CreateInfoTab(Icon: string, Title: string, TabContents: Frame?)
	if not CurrentInfoTab then
		CurrentInfoTab = Title
	end

	local IsTabSelected = CurrentInfoTab == Title

	if TabContents then
		TabContents.Parent = InfoFrame
		TabContents.Visible = IsTabSelected
	end

	local ButtonColor = IsTabSelected and Color3.fromRGB(25, 25, 25) or Color3.fromRGB(0, 0, 0)
	local TabButton = Interface.New("TextButton", {
		BackgroundColor3 = ButtonColor,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
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

	InfoModalTab[Title] = {
		TabButton = TabButton,
		TabContents = TabContents,
	}

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

		["TextLabel"] = {
			Text = Title,
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

	wax.shared.Connect(TabButton.MouseButton1Click:Connect(function()
		local OldTab = InfoModalTab[CurrentInfoTab]
		local OldTabButton = OldTab.TabButton
		local OldTabContents = OldTab.TabContents

		OldTabButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		OldTabButton.Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		OldTabContents.Visible = false

		CurrentInfoTab = Title

		TabButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		TabButton.Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)

		if TabContents then
			TabContents.Visible = true
		end
	end))
end

local function CreateTabContent()
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

local ArgumentInfoUI, ArgumentScrollingFrame = CreateTabContent()
CreateInfoTab("ellipsis", "Arguments", ArgumentInfoUI)
ArgumentScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local ArgumentsInfoFrame = Interface.New("Frame", {
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),

	["UIListLayout"] = {
		Padding = UDim.new(0, 6),
	},

	MainUICorner,

	Parent = ArgumentScrollingFrame,
})

local CodeInfoUI, CodeScrollingFrame = CreateTabContent()
CreateInfoTab("code", "Code", CodeInfoUI)
CodeScrollingFrame.ScrollBarThickness = 3
CodeScrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.None

local CodeTextLabels = {}
for i = 1, 5 do
	CodeTextLabels[i] = Interface.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		FontFace = Font.fromId(16658246179),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Text = "",
		Parent = CodeScrollingFrame,
	})
end

function SetCodeText(Code: string)
	for _, Label in CodeTextLabels do
		Label.Text = ""
	end

	local HighlightedCode = SyntaxHighlighter.Run(Code)
	local Lines = HighlightedCode:split("\n")
	local CurrentCharacterCount = 0
	local TextContents = {}
	local CurrentLabel = 1

	for _, Line in Lines do
		if CurrentCharacterCount + #Line > 200000 then
			CurrentLabel += 1
			CurrentCharacterCount = 0
			continue
		end

		CurrentCharacterCount += #Line
		if not TextContents[CurrentLabel] then
			TextContents[CurrentLabel] = {}
		end

		table.insert(TextContents[CurrentLabel], Line)
	end

	for Idx, Content in TextContents do
		if not CodeTextLabels[Idx] then
			CodeTextLabels[Idx] = Interface.New("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				TextSize = 16,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				FontFace = Font.fromId(16658246179),
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				Text = SyntaxHighlighter.Run("-- Loading..."),
				Parent = CodeScrollingFrame,
			})
		end

		CodeTextLabels[Idx].Text = table.concat(Content, "\n")
	end
end

local FunctionInfoUI, FunctionScrollingFrame = CreateTabContent()
CreateInfoTab("parentheses", "Function Info", FunctionInfoUI)

local FunctionInfoText = Interface.New("TextLabel", {
	AutomaticSize = Enum.AutomaticSize.XY,
	TextSize = 16,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	FontFace = Font.fromId(16658246179),
	TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundTransparency = 1,
	Text = "",
	Parent = FunctionScrollingFrame,
})

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

local function CreateInfoDropdownButton(Icon: string, Title: string, Options: {})
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

	local Menu = CreateContextMenu(Button, Options)

	Button.MouseEnter:Connect(function()
		wax.shared.TweenService
			:Create(Button, DefaultTweenInfo, {
				BackgroundTransparency = 0,
			})
			:Play()
	end)
	Button.MouseLeave:Connect(function()
		wax.shared.TweenService
			:Create(Button, DefaultTweenInfo, {
				BackgroundTransparency = 1,
			})
			:Play()
	end)
	Button.MouseButton1Click:Connect(Menu.Toggle)
	return Menu
end

CreateInfoDropdownButton("code", "Code", {
	{
		Text = "Calling Code",
		Icon = "forward",
		Callback = function()
			if not CurrentInfo then
				return
			end

			local Code = CodeGen:BuildCallCode(CurrentInfo)
			local Success, Error = pcall(setclipboard, Code)

			if Success then
				wax.shared.Sonner.success("Copied code to clipboard")
			else
				wax.shared.Sonner.error("Failed to copy code to clipboard")
				warn("Failed to copy code to clipboard", Error)
			end
		end,
	},
	{
		Text = "Intercept Code",
		Icon = "shield-alert",
		Callback = function()
			if not CurrentInfo then
				return
			end

			local Code = CodeGen:BuildHookCode(CurrentInfo)
			local Success, Error = pcall(setclipboard, Code)

			if Success then
				wax.shared.Sonner.success("Copied code to clipboard")
			else
				wax.shared.Sonner.error("Failed to copy code to clipboard")
				warn("Failed to copy code to clipboard", Error)
			end
		end,
	},
	{
		Text = "Function Info",
		Icon = "parentheses",
		Callback = function()
			if not CurrentInfo then
				return
			end

			local Info = {
				Function = typeof(CurrentInfo.Function) == "function" and {
					Name = CurrentInfo.Function and debug.info(CurrentInfo.Function, "n") or "Unknown",
					Source = CurrentInfo.Source
						or (CurrentInfo.Function and debug.info(CurrentInfo.Function, "s"))
						or "Unknown",
					Type = CurrentInfo.Function
							and (iscclosure(CurrentInfo.Function) and "C Closure" or "Luau function")
						or "N/A",
					Address = tostring(CurrentInfo.Function),
					Arguments = table.unpack(
						CurrentInfo.Arguments,
						1,
						wax.shared.GetTableLength(CurrentInfo.Arguments)
					),
				} or CurrentInfo.Function,
				Script = CurrentInfo.Origin,
				Line = CurrentInfo.Line,
			}

			if typeof(CurrentInfo.Function) == "function" and islclosure(CurrentInfo.Function) then
				local FunctionInfo = {
					Constants = debug.getconstants,
					Upvalues = debug.getupvalues,
					Protos = debug.getprotos,
				}

				for Type, Func in pairs(FunctionInfo) do
					if not Func then
						continue
					end

					Info.Function[Type] = Func(CurrentInfo.Function)
				end
			end

			local Success, Error = pcall(setclipboard, `local Info = {LuaEncode(Info, { Prettify = true, DisableNilParentHandler = true })}`)
			if Success then
				wax.shared.Sonner.success("Copied function info to clipboard")
			else
				wax.shared.Sonner.error("Failed to copy function info to clipboard")
				warn("Failed to copy function info to clipboard", Error)
			end
		end,
	},
})

CreateInfoDropdownButton("scroll-text", "Origin", {
	{
		Text = "Remote Path",
		Icon = "package-search",
		Callback = function()
			if not CurrentInfo then
				return
			end

			local Success, Error = pcall(setclipboard, CodeGen.GetFullPath(CurrentInfo.Instance, {
				VariableName = "Event",
				DisableNilParentHandler = false
			}))
			if Success then
				wax.shared.Sonner.success("Copied remote path to clipboard")
			else
				wax.shared.Sonner.error("Failed to copy remote path to clipboard")
				warn("Failed to copy remote path to clipboard", Error)
			end
		end,
	},
	{
		Text = "Script Path",
		Icon = "file-search",
		Condition = function()
			return CurrentInfo and typeof(CurrentInfo.Origin) == "Instance"
		end,
		Callback = function()
			if not (CurrentInfo and typeof(CurrentInfo.Origin) == "Instance") then
				return
			end

			local Success, Error = pcall(setclipboard, CodeGen.GetFullPath(CurrentInfo.Origin))
			if Success then
				wax.shared.Sonner.success("Copied script path to clipboard")
			else
				wax.shared.Sonner.error("Failed to copy script path to clipboard")
				warn("Failed to copy script path to clipboard", Error)
			end
		end,
	},
	{
		Text = "Decompiled Script",
		Icon = "file-text",
		Condition = function()
			return CurrentInfo and typeof(CurrentInfo.Origin) == "Instance" and typeof(decompile) == "function"
		end,
		Callback = function()
			if not (CurrentInfo and typeof(CurrentInfo.Origin) == "Instance" and typeof(decompile) == "function") then
				return
			end

			local Decompiled, Result = pcall(decompile, CurrentInfo.Origin)
			if Decompiled then
				local Success, Error = pcall(setclipboard, Result)
				if Success then
					wax.shared.Sonner.success("Copied decompiled script to clipboard")
				else
					wax.shared.Sonner.error("Failed to copy decompiled script to clipboard")
					warn("Failed to copy decompield script to clipboard", Error)
				end
			else
				wax.shared.Sonner.error("Failed to decompile script")
				warn("Failed to decompile script", Result)
			end
		end,
	},
})

CreateInfoDropdownButton("network", "Event", {
	{
		Text = "Replay",
		Icon = "play",
		Callback = function()
			if not CurrentInfo then
				return
			end

			wax.shared.Sonner.promise(function()
				wax.shared.ReplayCallInfo(CurrentInfo, CurrentTab.Name)
			end, {
				loadingText = "Replaying event...",
				successText = "Replayed event successfully!",
				errorText = "Failed to replay event",
				time = 4.5,
			})
		end,
	},
	{
		Text = function()
			if not CurrentLog then
				return "Ignore"
			end

			return CurrentLog.Ignored and "Unignore" or "Ignore"
		end,
		Icon = function()
			if not CurrentLog then
				return "eye"
			end

			return CurrentLog.Ignored and "eye" or "eye-off"
		end,
		Callback = function()
			if not CurrentLog then
				return
			end

			CurrentLog:Ignore()
			wax.shared.Sonner.success(`{CurrentLog.Ignored and "Started" or "Stopped"} ignoring event`)
		end,
	},
	{
		Text = function()
			if not CurrentLog then
				return "Block"
			end

			return CurrentLog.Blocked and "Unblock" or "Block"
		end,
		Icon = function()
			if not CurrentLog then
				return "lock"
			end

			return CurrentLog.Blocked and "lock" or "lock-open"
		end,
		Callback = function()
			if not CurrentLog then
				return
			end

			CurrentLog:Block()

			local BlockedRemoteList = wax.shared.Settings["BlockedRemotes"]
			if BlockedRemoteList then
				if CurrentLog.Blocked then
					BlockedRemoteList:AddToList(CurrentLog)
				else
					BlockedRemoteList:RemoveFromList(CurrentLog)
				end
			end

			wax.shared.Sonner.success(`{CurrentLog.Blocked and "Started" or "Stopped"} blocking event`)
		end,
	},
	{
		Text = "Clear Logs",
		Icon = "trash",
		Callback = function()
			if not CurrentLog then
				return
			end

			CurrentLog.Calls = {}
			PaginationHelper:Update(#CurrentLog.Calls)
			PaginationHelper:SetPage(1)
			CurrentPage[CurrentLog] = 1

			CleanLogsList()

			CurrentLog.Button.Calls.Text = "x" .. #CurrentLog.Calls
			UpdateLogNameSize(CurrentLog)

			ShowPagination(CurrentLog)
			ShowCalls(CurrentLog, 1)

			CloseModal()

			wax.shared.Sonner.success("Cleared logs for event successfully!")

			if #CurrentLog.Calls == 0 then
				CurrentLog.Button.Instance.Parent = nil
			end
		end,
	},
})

-- Search
local ResultInfo = {}
local CurrentResults = {}
local SelectedResult = -1

local SearchFrame = Interface.New("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.5, 0, 0.8, 0),
	Text = "",
	Visible = false,
	Parent = ModalBackground,

	["UICorner"] = {
		CornerRadius = UDim.new(0, 6),
	},

	["UIStroke"] = {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(25, 25, 25),
		Thickness = 1,
	},
})

local SearchTop = Interface.New("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 36),
	Parent = SearchFrame,

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	},
})

local SearchBox = Interface.New("TextBox", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -30, 1, 0),
	PlaceholderText = "Search for logs...",
	TextXAlignment = Enum.TextXAlignment.Left,
	PlaceholderColor3 = Color3.fromRGB(127, 127, 127),
	Text = "",
	TextSize = 17,
	Parent = SearchTop,
})

local SearchCloseButton = Interface.New("ImageButton", {
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.fromScale(1, 0),
	AnchorPoint = Vector2.new(1, 0),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	Parent = SearchTop,
})
local SearchCloseImage = Interface.NewIcon("x", {
	ImageTransparency = 0.5,
	Size = UDim2.fromOffset(22, 22),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,

	Parent = SearchCloseButton,
})

ConnectCloseButton(SearchCloseButton, SearchCloseImage, SearchFrame)

Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.new(1, 0, 0, 1),
	Position = UDim2.fromOffset(0, 36),
	Parent = SearchFrame,
})

local SearchFilterList = Interface.New("ScrollingFrame", {
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.fromOffset(0, 0),
	ScrollBarThickness = 2,
	Position = UDim2.fromOffset(0, 37),
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundTransparency = 1,
	Parent = SearchFrame,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 6),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	},
})

-- Search Filter
local ExcludeSearchClass = {}
local SearchFilterButtons = {}

local FilterAllButton = Interface.New("TextButton", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.fromScale(0, 1),
	AutomaticSize = Enum.AutomaticSize.X,
	TextSize = 15,
	Text = "All",
	Parent = SearchFilterList,

	["UICorner"] = {
		CornerRadius = UDim.new(0, 4),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 0),
		PaddingBottom = UDim.new(0, 0),
	},
})

FilterAllButton.MouseButton1Click:Connect(function()
	ExcludeSearchClass = {}
	FilterAllButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	for _, Button in pairs(SearchFilterButtons) do
		Button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	end
	UpdateSearch()
end)

for Order, ClassName in pairs(ClassOrder) do
	local ClassNameFilterButton = Interface.New("TextButton", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 15,
		Text = "",
		LayoutOrder = Order,
		Parent = SearchFilterList,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 0),
			PaddingBottom = UDim.new(0, 0),
		},

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		},

		["TextLabel"] = {
			LayoutOrder = 1,
			Text = ClassName,
			TextSize = 15,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
		},
	})

	local ImageLabel = Interface.New("ImageLabel", {
		Image = Images[ClassName],
		Size = UDim2.new(1, -8, 1, -8),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(0.5, 0),
		Parent = ClassNameFilterButton,
	})

	ClassNameFilterButton.MouseButton1Click:Connect(function()
		local FoundIndex = table.find(ExcludeSearchClass, ClassName)
		if FoundIndex then
			table.remove(ExcludeSearchClass, FoundIndex)
			ClassNameFilterButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)

			if #ExcludeSearchClass == 0 then
				FilterAllButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			end

			UpdateSearch()
			return
		end

		table.insert(ExcludeSearchClass, ClassName)
		ClassNameFilterButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
		FilterAllButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
		UpdateSearch()
	end)

	table.insert(SearchFilterButtons, ClassNameFilterButton)
end

Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.new(1, 0, 0, 1),
	Position = UDim2.fromOffset(0, 72),
	Parent = SearchFrame,
})

local SearchResults = Interface.New("ScrollingFrame", {
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	Position = UDim2.fromOffset(0, 73),
	ScrollBarThickness = 3,
	Size = UDim2.new(1, 0, 1, -73),

	Parent = SearchFrame,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.Name,
	},

	["UIPadding"] = {
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
	},
})

local function CreateSearchResult(Instance: Instance, Type: string)
	local SearchResult = Interface.New("TextButton", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		BackgroundTransparency = 1,
		Name = Instance.Name,
		Size = UDim2.new(1, 0, 0, 36),
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

		["TextLabel"] = {
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.new(1, -30, 1, 0),
			Text = Instance.Name,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
		},
	})
	do
		SearchResult.MouseEnter:Connect(function()
			local Index = table.find(CurrentResults, SearchResult)
			if Index then
				SelectResult(Index)
			end
		end)
		SearchResult.MouseButton1Click:Connect(function()
			local Index = table.find(CurrentResults, SearchResult)
			if Index then
				EnterResult(Index)
			end
		end)
	end

	local Image = Interface.New("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Images[Instance.ClassName],
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Parent = SearchResult,
	})

	local TypeLabel = Interface.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = Type,
		TextSize = 15,
		TextTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Right,

		Parent = SearchResult,
	})

	return SearchResult
end

-- Topbar
local TopBar = Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.new(1, 0, 0, 36),
	ZIndex = 0,
	MainUICorner,
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
		Image = CobaltLogo,
	},
})
Interface.HideCorner(TopBar, UDim2.fromScale(1, 0.5), Vector2.yAxis)

-- Topbar Buttons
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

local function CreateTopButton(IconName, Order: number, Callback: () -> ()?)
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
	if Callback then
		Button.MouseButton1Click:Connect(Callback)
	end

	return Button, Image
end

local function CreateTopSeperator(Order: number)
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

CreateTopButton("x", 4, wax.shared.Unload)
CreateTopButton("minus", 3, function()
	MainFrame.Visible = false
	ShowButton.Visible = true
end)
CreateTopSeperator(2)
CreateTopButton("settings", 1, function()
	OpenModal(SettingsFrame)
end)
CreateTopButton("search", 0, function()
	OpenSearch()
end)

Drag.Setup(MainFrame, TopBar)
Drag.Setup(ShowButton, ShowButton)

-- Remote List
local LeftList = Interface.New("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.yAxis,
	Size = UDim2.new(0, 240, 1, -36),
	Position = UDim2.fromScale(0, 1),
	Parent = MainFrame,

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	},
})

-- Tabs
local RemoteTabContainer = Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.new(1, 0, 0, 30),
	Parent = LeftList,

	["UICorner"] = {
		CornerRadius = UDim.new(0, 4),
	},

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
	},
})

-- Remote List
local RemoteListWrapper = Interface.New("Frame", {
	AnchorPoint = Vector2.yAxis,
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 1, -36),
	Parent = LeftList,

	["UICorner"] = {
		CornerRadius = UDim.new(0, 4),
	},

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	},
})

local RemoteList = Interface.New("ScrollingFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ScrollBarThickness = 2,
	Parent = RemoteListWrapper,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 6),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	},
})

local RemoteListLine = Interface.New("Frame", {
	AnchorPoint = Vector2.yAxis,
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Position = UDim2.new(0, 240, 1, 0),
	Size = UDim2.new(0, 2, 1, -36),
	Parent = MainFrame,
})

local RemoteListResize = Interface.New("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.new(1, 4, 1, 0),
	Text = "",

	Parent = RemoteListLine,
})
do
	RemoteListResize.MouseEnter:Connect(function()
		wax.shared.TweenService
			:Create(RemoteListLine, DefaultTweenInfo, {
				BackgroundColor3 = Color3.fromRGB(50, 50, 50),
			})
			:Play()
	end)
	RemoteListResize.MouseLeave:Connect(function()
		wax.shared.TweenService
			:Create(RemoteListLine, DefaultTweenInfo, {
				BackgroundColor3 = Color3.fromRGB(25, 25, 25),
			})
			:Play()
	end)
end

-- Main Remote thing
local LogsWrapper = Interface.New("Frame", {
	AnchorPoint = Vector2.one,
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(1, 1),
	Size = UDim2.new(1, -242, 1, -36),
	Parent = MainFrame,

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 6),
	},
})

LogsList = Interface.New("ScrollingFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, -38),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ScrollBarThickness = 2,
	Parent = LogsWrapper,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 6),
	},

	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
	},
})

local LogsPagination = Interface.New("Frame", {
	AnchorPoint = Vector2.yAxis,
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 32),
	Parent = LogsWrapper,

	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
	},
})

-- Functions

function ShowTab(Tab)
	for _, Object in pairs(RemoteList:GetChildren()) do
		if Object.ClassName == "TextButton" then
			Object.Parent = nil
		end
	end

	if CurrentTab then
		wax.shared.TweenService
			:Create(CurrentTab.Instance, DefaultTweenInfo, {
				BackgroundTransparency = 1,
			})
			:Play()
	end

	CurrentTab = Tab
	wax.shared.TweenService
		:Create(CurrentTab.Instance, DefaultTweenInfo, {
			BackgroundTransparency = 0,
		})
		:Play()

	for _, Log in pairs(Tab.Logs) do
		if #Log.Calls == 0 then
			continue
		end

		if not Log.Button then
			local Button, Name, Calls = CreateLogButton(Log)
			Log:SetButton(Button, Name, Calls)
		end

		Log.Button.Name.Text = Log.Instance.Name
		Log.Button.Calls.Text = "x" .. #Log.Calls
		UpdateLogNameSize(Log)
		Log.Button.Instance.Parent = RemoteList
	end
end

function CleanLogsList()
	for _, Object in pairs(LogsList:GetChildren()) do
		if Object.ClassName == "TextButton" then
			Object:Destroy()
		end
	end
end

function ShowLog(Log)
	CleanLogsList()
	if not Log then
		return
	end

	if CurrentLog ~= Log then
		if CurrentLog then
			wax.shared.TweenService
				:Create(CurrentLog.Button.Instance, DefaultTweenInfo, {
					BackgroundTransparency = 1,
				})
				:Play()
		end

		CurrentLog = Log
		wax.shared.TweenService
			:Create(CurrentLog.Button.Instance, DefaultTweenInfo, {
				BackgroundTransparency = 0,
			})
			:Play()
	end

	local Page = CurrentPage[Log]
	if not Page then
		CurrentPage[Log] = 1
		Page = 1
	end

	PaginationHelper:Update(#Log.Calls)
	PaginationHelper:SetPage(Page)

	LogsList.CanvasPosition = Vector2.zero
	ShowPagination(Log)
	ShowCalls(Log, Page)
end

ShowCalls = function(Log, Page)
	local Start, End = PaginationHelper:GetIndexRanges(Page)

	for Index = Start, End do
		local Call
		if wax.shared.Settings.ShowExecutorLogs.Value then
			Call = Log.Calls[Index]
		else
			Call = Log.Calls[Log.GameCalls[Index]]
		end

		if not Call then
			break
		end

		local Data = setmetatable({
			Instance = Log.Instance,
			Type = Log.Type,
			Order = Index,
		}, {
			__index = Call,
		})

		CreateCallFrame(Data)
	end
end

function CreatePaginationEllipsis(Order: number, Visible: boolean)
	local Ellipsis = {
		Ellipsis = Interface.New("TextBox", {
			BackgroundColor3 = Color3.fromRGB(25, 25, 25),
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			LayoutOrder = Order,
			PlaceholderText = "-",
			Text = "",
			TextSize = 15,
			RichText = false,
			Parent = Visible and LogsPagination or nil,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 4),
			},
		}),
	}

	function Ellipsis:SetVisible(Visible: boolean)
		if not Visible then
			self.Ellipsis.Text = ""
		end
		self.Ellipsis.Parent = Visible and LogsPagination or nil
	end

	Ellipsis.Ellipsis.FocusLost:Connect(function(EnterPressed)
		if not EnterPressed then
			return
		end

		local Page = tonumber(Ellipsis.Ellipsis.Text)
		if not Page then
			wax.shared.Sonner.error("Invalid page number provided!")
			Ellipsis.Text = ""
			return
		end

		if math.floor(Page) ~= Page then
			wax.shared.Sonner.error("Invalid page number provided!")
			Ellipsis.Ellipsis.Text = ""
			return
		end

		if math.abs(Page) ~= Page or Page == 0 then
			wax.shared.Sonner.error("Invalid page number provided!")
			Ellipsis.Ellipsis.Text = ""
			return
		end

		local Success = pcall(function()
			PaginationHelper:SetPage(Page)
			CurrentPage[CurrentLog] = Page
			ShowLog(CurrentLog)
		end)

		if not Success then
			wax.shared.Sonner.error("Invalid page number provided!")
		end

		Ellipsis.Ellipsis.Text = ""
	end)

	return Ellipsis
end

function CreatePaginationButton(Order: number, Active: boolean, Visible: boolean)
	local ButtonData = {
		Button = Interface.New("TextButton", {
			BackgroundColor3 = Active and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25),
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Text = tostring(1),
			LayoutOrder = Order,
			TextSize = 15,
			Parent = Visible and LogsPagination or nil,

			["UICorner"] = {
				CornerRadius = UDim.new(0, 4),
			},
		}),
	}

	function ButtonData:SetActive(Active: boolean)
		self.Button.BackgroundColor3 = Active and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
	end

	function ButtonData:SetText(Text: string)
		self.Button.Text = Text
	end

	function ButtonData:SetVisible(Visible: boolean)
		self.Button.Parent = Visible and LogsPagination or nil
	end

	ButtonData.Button.MouseButton1Click:Connect(function()
		local Page = tonumber(ButtonData.Button.Text)

		PaginationHelper:SetPage(Page)
		CurrentPage[CurrentLog] = Page
		ShowLog(CurrentLog)
	end)

	return ButtonData
end

local MaxButtons = (5 + PaginationHelper.SiblingCount * 2)
local PaginationElements = {
	Buttons = {},
	Ellipsis = {
		[2] = CreatePaginationEllipsis(1, false),
		[MaxButtons - 1] = CreatePaginationEllipsis(MaxButtons - 1, false),
	},
}

for i = 1, MaxButtons do
	table.insert(PaginationElements.Buttons, CreatePaginationButton(i, false, false))
end

ShowPagination = function(Log)
	local Pages = PaginationHelper:GetVisualInfo(nil, LogsList.AbsoluteSize.X)
	for Order, Info in pairs(Pages) do
		if Info == "none" then
			local Ellipsis = PaginationElements.Ellipsis[Order]
			if Ellipsis then
				Ellipsis:SetVisible(false)
			end

			local Button = PaginationElements.Buttons[Order]
			if Button then
				Button:SetVisible(false)
			end

			continue
		elseif Info == "ellipsis" then
			local Ellipsis = PaginationElements.Ellipsis[Order]
			if Ellipsis and Ellipsis.Parent == nil then
				Ellipsis:SetVisible(true)
			end

			local Button = PaginationElements.Buttons[Order]
			if Button then
				Button:SetVisible(false)
			end

			continue
		end

		local Ellipsis = PaginationElements.Ellipsis[Order]
		if Ellipsis then
			Ellipsis:SetVisible(false)
		end

		local Button = PaginationElements.Buttons[Order]
		if Button then
			Button:SetVisible(true)
			Button:SetText(tostring(Info))
			Button:SetActive(CurrentPage[Log] == Info)
		end
	end
end

function CreateRemoteTab(TabName: string, Active: boolean, Logs)
	local Button = Interface.New("TextButton", {
		BackgroundColor3 = Color3.fromRGB(50, 50, 50),
		BackgroundTransparency = Active and 0 or 1,
		Size = UDim2.fromScale(0, 1),
		TextSize = 15,
		Text = TabName,
		Parent = RemoteTabContainer,

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},
	})

	local Tab = {
		Name = TabName,
		Logs = Logs,
		Instance = Button,
	}
	Tabs[TabName] = Tab

	if Active then
		CurrentTab = Tab
	end

	Button.MouseButton1Click:Connect(function()
		if CurrentTab == Tab then
			return
		end

		ShowTab(Tab)
	end)

	return Button
end

function CreateLogButton(Log): (TextButton, TextLabel, TextLabel)
	local Button = Interface.New("TextButton", {
		BackgroundColor3 = Color3.fromRGB(50, 50, 50),
		BackgroundTransparency = 1,
		LayoutOrder = Log.Index or 1,
		Size = UDim2.new(1, 0, 0, 30),
		Text = "",

		["ImageLabel"] = {
			Image = Images[Log.Instance.ClassName],
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
		},

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},
	})

	local Text = Interface.New("TextLabel", {
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,

		Parent = Button,
	})

	local Amount = Interface.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,

		Parent = Button,
	})

	Button.MouseButton1Click:Connect(function()
		if CurrentLog == Log then
			return
		end

		ShowLog(Log)
	end)

	local LogContextMenu = CreateContextMenu(Button, {
		{
			Text = function()
				if not Log then
					return "Ignore"
				end

				return Log.Ignored and "Unignore" or "Ignore"
			end,
			Icon = function()
				if not Log then
					return "eye"
				end

				return Log.Ignored and "eye" or "eye-off"
			end,
			Callback = function()
				Log:Ignore()

				wax.shared.Sonner.success(`{Log.Ignored and "Started" or "Stopped"} ignoring event`)
			end,
		},
		{
			Text = function()
				if not Log then
					return "Block"
				end

				return Log.Blocked and "Unblock" or "Block"
			end,
			Icon = function()
				if not Log then
					return "lock"
				end

				return Log.Blocked and "lock" or "lock-open"
			end,
			Callback = function()
				Log:Block()

				local BlockedRemoteList = wax.shared.Settings["BlockedRemotes"]
				if BlockedRemoteList then
					if Log.Blocked then
						BlockedRemoteList:AddToList(Log)
					else
						BlockedRemoteList:RemoveFromList(Log)
					end
				end

				wax.shared.Sonner.success(`{Log.Blocked and "Started" or "Stopped"} blocking event`)
			end,
		},
		{
			Text = "Clear Logs",
			Icon = "trash",
			Callback = function()
				if not Log then
					return
				end

				Log.Calls = {}
				CurrentPage[Log] = 1
				Log.Button.Calls.Text = "x" .. #Log.Calls
				UpdateLogNameSize(Log)

				if CurrentLog == Log then
					PaginationHelper:Update(#Log.Calls)
					PaginationHelper:SetPage(1)

					CleanLogsList()

					ShowPagination(Log)
					ShowCalls(Log, 1)
				end

				wax.shared.Sonner.success("Cleared logs for event successfully!")

				if #Log.Calls == 0 then
					Log.Button.Instance.Parent = nil
				end
			end,
		},
	}, true)

	Button.MouseButton2Click:Connect(LogContextMenu.Toggle)

	return Button, Text, Amount
end

function CreateArgHolder(Index: number, Value: any, Parent: GuiObject)
	local Holder = Interface.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		LayoutOrder = Index,
		Size = UDim2.new(1, 0, 0, 27),

		["UICorner"] = {
			CornerRadius = UDim.new(0, 4),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},

		Parent = Parent,
	})

	Interface.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = Index,
		TextSize = 15,
		TextTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,

		Parent = Holder,
	})

	local TypeLabel = Interface.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = typeof(Value),
		TextSize = 15,
		TextTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,

		Parent = Holder,
	})
	local TypeX = wax.shared.GetTextBounds(TypeLabel.Text, TypeLabel.FontFace, TypeLabel.TextSize)

	local TextLabel = Interface.New("TextLabel", {
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -(TypeX + 22), 1, 0),
		TextColor3 = Color3.fromHex(SyntaxHighlighter.GetArgumentColor(Value)),
		Text = tostring(Helper.QuickSerializeArgument(Value)):gsub("<", "&lt;"):gsub(">", "&gt;"),
		RichText = true,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,

		Parent = Holder,
	})
	local _, TextY =
		wax.shared.GetTextBounds(TextLabel.Text, TextLabel.FontFace, TextLabel.TextSize, TextLabel.AbsoluteSize.X)
	Holder.Size = UDim2.new(1, 0, 0, TextY + 12)

	return Holder
end

function CreateCallFrame(CallInfo)
	if not wax.shared.Settings.ShowExecutorLogs.Value and not CallInfo.Origin then
		return
	end

	local CallFrame = Interface.New("TextButton", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		LayoutOrder = CallInfo.Order,
		Size = UDim2.fromScale(1, 0),
		Text = "",

		["UIListLayout"] = {
			Padding = UDim.new(0, 6),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},

		MainUICorner,

		Parent = LogsList,
	})

	local HighlightStroke = Interface.New("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(75, 75, 75),
		Thickness = 2,
		Transparency = 1,

		Parent = CallFrame,
	})
	do
		local CallFrameContextMenu = CreateContextMenu(CallFrame, {
			{
				Text = "Copy Calling Code",
				Icon = "forward",
				Callback = function()
					local Code = CodeGen:BuildCallCode(CallInfo)
					local Success, Error = pcall(setclipboard, Code)

					if Success then
						wax.shared.Sonner.success("Copied code to clipboard")
					else
						wax.shared.Sonner.error("Failed to copy code to clipboard")
						warn("Failed to copy code to clipboard", Error)
					end
				end,
			},
			{
				Text = "Copy Intercept Code",
				Icon = "shield-alert",
				Callback = function()
					local Code = CodeGen:BuildHookCode(CallInfo, CurrentTab.Name)
					local Success, Error = pcall(setclipboard, Code)

					if Success then
						wax.shared.Sonner.success("Copied code to clipboard")
					else
						wax.shared.Sonner.error("Failed to copy code to clipboard")
						warn("Failed to copy code to clipboard", Error)
					end
				end,
			},
			{
				Text = "Copy Remote Path",
				Icon = "package-search",
				Callback = function()
					if not CallInfo then
						return
					end

					local Success, Error = pcall(setclipboard, CodeGen.GetFullPath(CallInfo.Instance, {
						VariableName = "Event",
						DisableNilParentHandler = false,
					}))

					if Success then
						wax.shared.Sonner.success("Copied remote path to clipboard")
					else
						wax.shared.Sonner.error("Failed to copy remote path to clipboard")
						warn("Failed to copy remote path to clipboard", Error)
					end
				end,
			},
			{
				Text = "Copy Script Path",
				Icon = "file-search",
				Condition = function()
					return CallInfo and typeof(CallInfo.Origin) == "Instance"
				end,
				Callback = function()
					if not CallInfo then
						return
					end

					local Success, Error = pcall(setclipboard, CodeGen.GetFullPath(CallInfo.Origin))
					if Success then
						wax.shared.Sonner.success("Copied script path to clipboard")
					else
						wax.shared.Sonner.error("Failed to copy script path to clipboard")
						warn("Failed to copy script path to clipboard", Error)
					end
				end,
			},
			{
				Text = "Replay",
				Icon = "play",
				Callback = function()
					if not CallInfo then
						return
					end

					wax.shared.Sonner.promise(function()
						wax.shared.ReplayCallInfo(CallInfo, CurrentTab.Name)
					end, {
						loadingText = "Replaying event...",
						successText = "Replayed event successfully!",
						errorText = "Failed to replay event",
						time = 4.5,
					})
				end,
			},
		}, true)

		CallFrame.MouseEnter:Connect(function()
			wax.shared.TweenService
				:Create(HighlightStroke, DefaultTweenInfo, {
					Transparency = 0,
				})
				:Play()
		end)
		CallFrame.MouseLeave:Connect(function()
			wax.shared.TweenService
				:Create(HighlightStroke, DefaultTweenInfo, {
					Transparency = 1,
				})
				:Play()
		end)
		CallFrame.MouseButton1Click:Connect(function()
			OpenInfo(CallInfo)
		end)
		CallFrame.MouseButton2Click:Connect(CallFrameContextMenu.Open)
	end

	local ArgumentsFrame = Interface.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		Size = UDim2.fromScale(1, 0),
		Visible = wax.shared.GetTableLength(CallInfo.Arguments) > 0,

		["UIListLayout"] = {
			Padding = UDim.new(0, 6),
		},

		["UIPadding"] = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},

		MainUICorner,

		Parent = CallFrame,
	})
	do
		for Index = 1, wax.shared.GetTableLength(CallInfo.Arguments) do
			if Index % 15 == 0 then
				task.wait()
			end

			local Value = CallInfo.Arguments[Index]
			CreateArgHolder(Index, Value, ArgumentsFrame)
		end
	end

	Interface.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),

		Interface.NewIcon(CallInfo.IsExecutor and "terminal" or "gamepad-2", {
			AnchorPoint = Vector2.yAxis,
			ImageTransparency = 0.5,
			Position = UDim2.new(0, 2, 1, 0),
			Size = UDim2.fromOffset(22, 22),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
		}),

		Interface.New("TextLabel", {
			AnchorPoint = Vector2.yAxis,
			Position = UDim2.new(0, 30, 1, 0),
			Size = UDim2.new(0.5, -24, 0, 22),
			BackgroundTransparency = 1,
			Text = CallInfo.IsExecutor and wax.shared.ExecutorName
				or CallInfo.Origin and CallInfo.Origin.Name
				or "Unknown",
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 0.5,
		}),

		Interface.New("TextLabel", {
			AnchorPoint = Vector2.one,
			Position = UDim2.new(1, -2, 1, 0),
			Size = UDim2.new(0.5, -2, 0, 22),
			BackgroundTransparency = 1,
			Text = "Time: " .. os.date("%X", CallInfo.CreationTime),
			TextSize = 16,
			TextTransparency = 0.5,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),

		Parent = CallFrame,
	})

	return CallFrame
end

-- UI Handling
CreateRemoteTab("Outgoing", true, wax.shared.Logs.Outgoing)
CreateRemoteTab("Incoming", false, wax.shared.Logs.Incoming)

-- Search Functions
function OpenSearch()
	OpenModal(SearchFrame)
	UpdateSearch()
	SearchBox:CaptureFocus()
end
function HandleSearch(Text, Type)
	for Instance, Log in pairs(wax.shared.Logs[Type]) do
		if not Log.SearchResult then
			local SearchResult = CreateSearchResult(Instance, Type)
			Log.SearchResult = SearchResult
			ResultInfo[SearchResult] = {
				Type = Type,
				Callback = function()
					ShowLog(Log)
				end,
			}
		end

		local LoweredName = string.lower(Instance.Name)
		if not LoweredName:match(Text) or table.find(ExcludeSearchClass, Instance.ClassName) then
			Log.SearchResult.Parent = nil
			continue
		end

		Log.SearchResult.BackgroundTransparency = 1
		Log.SearchResult.Parent = SearchResults
		table.insert(CurrentResults, Log.SearchResult)
	end
end

function SelectResult(NewResult, UpdateCanvasPosition)
	if SelectedResult > 0 and CurrentResults[SelectedResult] then
		CurrentResults[SelectedResult].BackgroundTransparency = 1
	end
	if NewResult == -1 or #CurrentResults == 0 then
		SelectedResult = -1
		return
	end

	SelectedResult = math.clamp(NewResult, 1, #CurrentResults)
	CurrentResults[SelectedResult].BackgroundTransparency = 0

	if UpdateCanvasPosition then
		local ScrollSize = SearchResults.AbsoluteSize.Y

		local SelectedMin = CurrentResults[SelectedResult].AbsolutePosition.Y - SearchResults.AbsolutePosition.Y
		local SelectedMax = SelectedMin + CurrentResults[SelectedResult].AbsoluteSize.Y

		if SelectedMin < 0 then
			SearchResults.CanvasPosition += Vector2.new(0, SelectedMin - 6)
		elseif SelectedMax > ScrollSize then
			SearchResults.CanvasPosition += Vector2.new(0, SelectedMax - ScrollSize + 6)
		end
	end
end
function EnterResult(ResultIndex)
	local Info = ResultInfo[CurrentResults[SelectedResult]]
	if not Info then
		CloseModal()
		return
	end

	pcall(ShowTab, Tabs[Info.Type])
	pcall(Info.Callback)

	CloseModal()
end
function HandleResults()
	if #CurrentResults == 0 then
		return
	end

	table.sort(CurrentResults, function(a, b)
		return a.AbsolutePosition.Y < b.AbsolutePosition.Y
	end)

	SelectResult(1, true)
end
function UpdateSearch()
	table.clear(CurrentResults)
	SelectResult(-1)

	local Text = string.lower(SearchBox.Text)
	HandleSearch(Text, "Outgoing")
	HandleSearch(Text, "Incoming")

	HandleResults()
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(UpdateSearch)

-- Call Functions
function OpenInfo(CallInfo)
	InfoTitle.Text = CallInfo.Instance.Name
	InfoIcon.Image = Images[CallInfo.Instance.ClassName]

	CurrentInfo = CallInfo

	SetCodeText(CodeGen:BuildCallCode(CallInfo))

	xpcall(function()
		FunctionInfoText.Text = CodeGen:BuildFunctionInfo(CallInfo)
	end, function(Error)
		FunctionInfoText.Text =
			`Error while fetching function data.\nCalling Function: {CallInfo.Function} (type: {typeof(
				CallInfo.Function
			)})\n\nError: {Error}`
	end)
	do
		for _, Object in pairs(ArgumentsInfoFrame:GetChildren()) do
			if Object.ClassName ~= "Frame" then
				continue
			end
			Object:Destroy()
		end

		for Index = 1, wax.shared.GetTableLength(CallInfo.Arguments) do
			if Index % 25 == 0 then
				task.wait()
			end

			local Value = CallInfo.Arguments[Index]
			CreateArgHolder(Index, Value, ArgumentsInfoFrame)
		end
	end

	for _, tab in pairs({ "Function Info", "Code" }) do
		local OldTab = InfoModalTab[tab]
		if not OldTab then
			continue
		end

		local OldTabButton = OldTab.TabButton
		local OldTabContent = OldTab.TabContents

		OldTabButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		OldTabButton.Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

		OldTabContent.Visible = false
	end

	CurrentInfoTab = "Arguments"
	if InfoModalTab["Arguments"] then
		local TabButton = InfoModalTab["Arguments"].TabButton
		local TabContent = InfoModalTab["Arguments"].TabContents

		TabButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		TabButton.Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		TabContent.Visible = true
	end

	if CurrentContext then
		CurrentContext:Close()
	end

	OpenModal(InfoFrame)
end

Drag.Setup(RemoteListLine, RemoteListResize, function(Info, Input: InputObject)
	local Delta = (Input.Position - Info.StartPosition) / GetDPIScale() 
	local FramePosition: UDim2 = Info.FramePosition
	local Offset = math.clamp(FramePosition.X.Offset + Delta.X, 120, (MainFrame.AbsoluteSize.X - 2) / 2)

	Info.Frame.Position = UDim2.new(FramePosition.X.Scale, Offset, FramePosition.Y.Scale, FramePosition.Y.Offset)

	LeftList.Size = UDim2.new(0, Offset, 1, -36)
	LogsWrapper.Size = UDim2.new(1, -(Offset + 2), 1, -36)
end)

wax.shared.Connect(wax.shared.Communicator.Event:Connect(function(Instance, Type, CallIndex)
	if not (CurrentTab and CurrentTab.Name == Type) then
		return
	end

	local Log = wax.shared.Logs[Type][Instance]
	if not Log then
		return
	end

	if #Log.Calls == 0 then
		return
	end

	local CallInfo = Log.Calls[CallIndex]

	local Page = CurrentPage[Log]
	if not Page then
		Page = 1
		CurrentPage[Log] = Page
	end

	if not Log.Button then
		local Button, Name, Calls = CreateLogButton(Log)
		Log:SetButton(Button, Name, Calls)
	end

	Log.Button.Name.Text = Log.Instance.Name
	UpdateLogNameSize(Log)
	Log.Button.Calls.Text = "x" .. #Log.Calls
	Log.Button.Instance.Parent = RemoteList

	if CurrentLog == Log then
		PaginationHelper:Update(#Log.Calls)

		local Start, End = PaginationHelper:GetIndexRanges(Page)
		if not wax.shared.Settings.ShowExecutorLogs.Value then
			CallIndex = Log.GameCalls[CallIndex]
			if not CallIndex then
				return
			end
		end

		if CallIndex < Start or CallIndex > End then
			ShowPagination(Log)
			return
		end

		local Data = setmetatable({
			Instance = Instance,
			Type = Type,
			Order = CallIndex,
		}, {
			__index = CallInfo,
		})

		CreateCallFrame(Data)
	end
end))

wax.shared.Connect(wax.shared.UserInputService.InputBegan:Connect(function(Input: InputObject)
	if Helper.IsClickInput(Input) then
		if
			CurrentContext
			and not (
				Helper.IsMouseOverFrame(ContextMenu, Input.Position)
				or Helper.IsMouseOverFrame(CurrentContext.Parent, Input.Position)
			)
		then
			CurrentContext:Close()
		end
	elseif Input.KeyCode == Enum.KeyCode.K and wax.shared.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		OpenSearch()
	elseif OpenedModal == SearchFrame then
		if Input.KeyCode == Enum.KeyCode.Escape then
			CloseModal()
		elseif Input.KeyCode == Enum.KeyCode.Return then
			EnterResult(SelectedResult)
		elseif Input.KeyCode == Enum.KeyCode.Up then
			SelectResult(SelectedResult - 1, true)
		elseif Input.KeyCode == Enum.KeyCode.Down then
			SelectResult(SelectedResult + 1, true)
		end
	end
end))

return {}
