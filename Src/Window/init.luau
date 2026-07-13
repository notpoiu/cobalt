--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Constants = require("@src/Window/Constants")

local DPI = require("@src/Window/Utils/DPI")
local Resize = require("@src/Window/Utils/Input/Resize")

local AssetManager = require("@src/Utils/UI/Assets/Manager")
local PluginManager = require("@src/Utils/Plugins/Manager")

--// Components \\--
local ModalController = require("@src/Window/Components/Modal")
local ContextMenuController = require("@src/Window/Components/ContextMenu")

--// Variables \\--
local Window = {
	Dialogs = {},
	Modals = {},
}

--// Assets \\--
local CobaltLogo = AssetManager.GetImage("Logo")

local DPIHandler
local function GetDPIScale()
	return DPIHandler and DPIHandler:GetDPIScale() or 1
end

--// UI \\--
local ScreenGui = Interface.New("ScreenGui", {
	Name = "Cobalt",
	ResetOnSpawn = false,
	Parent = Interface.GetScreenParent(),
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
wax.shared.ScreenGui = ScreenGui

local MainFrame = Interface.New("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(15, 15, 15),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(640, 420),
	ZIndex = 0,

	Constants.MainUICorner,
	Parent = ScreenGui,
})
do
	Resize.new({
		MainFrame = MainFrame,

		MinimumSize = Vector2.new(585, 220),

		CornerHandleSize = 20,
		HandleSize = 6,
		GetDPIScale = GetDPIScale,
	})
end

--// Minimized \\--
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

	Constants.MainUICorner,
	Parent = ScreenGui,
})
do
	ShowButton.MouseButton1Click:Connect(function()
		ShowButton.Visible = false
		MainFrame.Visible = true
	end)
end

--// Sonner (Notifications) \\--
local NotificationWrapper = Interface.New("ScrollingFrame", {
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
do
	wax.shared.Sonner.init(NotificationWrapper)
end

--// Pagination \\--
local PaginationFactory = require(script.Utils.Pagination)

local PaginationManager = PaginationFactory.new({
	TotalItems = 0,
})

--// DPI \\--
DPIHandler = DPI.new({
	Scale = Interface.New("UIScale", {
		Parent = ScreenGui,
	}),
	SaveKey = "WindowDPIScale",
})

--// ContextMenus \\--
local ContextMenus = ContextMenuController.new(ScreenGui, {
	GetDPIScale = GetDPIScale,

	TweenInfo = Constants.DefaultTweenInfo,
})

--// Dialogs \\--
Window.Dialog = require(script.Components.Dialog)({
	MainFrame = MainFrame,
})

local QueryBuilder = require(script.Components.QueryBuilder)
do
	QueryBuilder.ContextMenu = ContextMenus
	Window.QueryBuilder = QueryBuilder
end

Window.Dialogs = require(script.Components.Dialogs)

--// Modal Controller \\--
Window.Modals.Controller = ModalController.new(MainFrame, {
	TweenInfo = Constants.DefaultTweenInfo,
})

--// Views \\--
local LogsPage = require(script.Views.Logs)({
	MainFrame = MainFrame,
	Window = Window,
	ContextMenu = ContextMenus,
	PaginationManager = PaginationManager,
	GetDPIScale = GetDPIScale,
})
Window.Logs = LogsPage

wax.shared.ClearLogs = LogsPage.ClearLogs
wax.shared.GetCurrentLog = LogsPage.GetCurrentLog

--// Modal Builders \\--
local SettingsBuilder = require(script.Components.Modal.Builder.Settings)({
	ContextMenu = ContextMenus,
})

--// Modals \\--
Window.Modals.Settings = require(script.Modals.Settings)({
	ModalController = Window.Modals.Controller,
	SettingsBuilder = SettingsBuilder,
	DPIHandler = DPIHandler,
	PaginationManager = PaginationManager,
	LogsPage = LogsPage,
	Window = Window,
})

Window.Modals.Plugins = require(script.Modals.Plugins)({
	ModalController = Window.Modals.Controller,
	SettingsBuilder = SettingsBuilder,
	GetDPIScale = GetDPIScale,
})

Window.Modals.Info = require(script.Modals.Info)({
	ModalController = Window.Modals.Controller,
	ContextMenu = ContextMenus,
	GetDPIScale = GetDPIScale,
	LogsPage = LogsPage,
})

Window.Modals.Search = require(script.Modals.Search)({
	ModalController = Window.Modals.Controller,
	LogsPage = LogsPage,
})

PluginManager.AttachWindow({
	ModalController = Window.Modals.Controller,
	InfoModal = Window.Modals.Info,
	PluginsModal = Window.Modals.Plugins,
	GetCurrentLog = LogsPage.GetCurrentLog,
	ClearLogs = LogsPage.ClearLogs,
	GetDPIScale = GetDPIScale,
})

--// Topbar \\--
require(script.Components.Topbar)({
	MainFrame = MainFrame,
	ShowButton = ShowButton,
	CobaltLogo = CobaltLogo,
	Modals = Window.Modals,
	GetDPIScale = GetDPIScale,
})

return Window
