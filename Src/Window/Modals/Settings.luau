--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Types = require("@src/Window/Types")

local ModalController = require("@src/Window/Components/Modal")
local SettingsBuilder = require("@src/Window/Components/Modal/Builder/Settings")

local Resize = require("@src/Window/Utils/Input/Resize")
local DPI = require("@src/Window/Utils/DPI")

--// Data \\--
local AnticheatData = require("@src/Utils/Anticheats/Main")
local Session = require("@src/Utils/CodeGen/Serializer/Session")
local Settings = require("@src/Utils/Settings")

local FilterResetSettings = {
	Settings.IgnoredRemotesDropdown,
	Settings.AutoIgnoreSpammyEvents,
	Settings.IgnorePlayerModule,
	Settings.ShowExecutorLogs,
}

--// Setup \\--
local function SetupModal(ModalController: ModalController.Modal, GetDPIScale: () -> number)
	local SettingsFrame = Interface.New("TextButton", {
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
		MainFrame = SettingsFrame,

		MaximumSize = UDim2.new(1, -2, 1, -2),
		MinimumSize = UDim2.fromScale(0.65, 0.712),
		Mirrored = true,
		LockedPosition = true,

		CornerHandleSize = 20,
		HandleSize = 6,
		GetDPIScale = GetDPIScale,
	})

	ModalController:CreateTop("Settings", "settings", SettingsFrame)

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
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
		},
	})

	return SettingsFrame, SettingsScrollingFrame
end

local function CreateDetectionNotice(Parent: GuiObject, Window: Types.Window)
	local FailedChecks = wax.shared.ExecutorSupport.FailedChecks
	local DetectionRiskFailures = FailedChecks and FailedChecks.DetectionRisk
	if not DetectionRiskFailures or #DetectionRiskFailures == 0 then
		return
	end

	local WarningDisplay = Interface.New("TextButton", {
		Text = "",
		BackgroundColor3 = Color3.fromRGB(245, 60, 54),
		BackgroundTransparency = 0.82,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = Parent,

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
		},
	})

	Interface.New("TextLabel", {
		Text = `⚠  <b>Detection risk</b> · {#DetectionRiskFailures} unsupported {if #DetectionRiskFailures == 1
			then "check"
			else "checks"}`,
		TextSize = 14,
		Size = UDim2.new(1, -82, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = WarningDisplay,
	})

	Interface.New("TextLabel", {
		Text = "View details",
		TextSize = 13,
		TextTransparency = 0.25,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 76, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = WarningDisplay,
	})

	WarningDisplay.MouseButton1Click:Connect(function()
		Window.Dialogs.DetectionRisk.Open(Window, DetectionRiskFailures)
	end)
end

--// UI \\--
return function(props: {
	ModalController: ModalController.Modal,
	SettingsBuilder: SettingsBuilder.Builder,
	DPIHandler: DPI.DPI,
	PaginationManager: Types.PaginationManager,
	LogsPage: Types.LogsPage,
	Window: Types.Window,
})
	--// Props \\--
	local ModalController = props.ModalController
	local SettingsBuilder = props.SettingsBuilder
	local DPIHandler = props.DPIHandler
	local PaginationManager = props.PaginationManager
	local LogsPage = props.LogsPage
	local Window = props.Window

	local function GetDPIScale()
		return DPIHandler:GetDPIScale()
	end

	--// Setup \\--
	local SettingsFrame, SettingsScrollingFrame = SetupModal(ModalController, GetDPIScale)

	local MainSettings = SettingsBuilder.new(SettingsScrollingFrame)
	CreateDetectionNotice(SettingsScrollingFrame, Window)

	--// General Section \\--
	local GeneralSection = MainSettings:CreateSection("General")
	do
		Settings.WindowDPIScale:SetupOption(GeneralSection, {
			Callback = DPIHandler:CreateDPIScaleChangedCallback(),
		})

		PaginationManager:BindPagination({
			Component = Settings.CallsPerPage:SetupOption(GeneralSection),

			PaginationKey = "ItemsPerPage",
			Refresh = LogsPage.RefreshCurrentLog,
		})

		Settings.ExecuteOnTeleport:SetupOption(GeneralSection)

		GeneralSection:AddSpacer()
		GeneralSection:CreateButton("Clear Captured Calls", function()
			Window.Dialogs.ClearCapturedCalls.Open(Window, LogsPage.ClearLogs)
		end)
	end

	--// Capture Section \\--
	local CaptureSection = MainSettings:CreateSection("Capture")
	do
		Settings.RakNetHooks:SetupOption(CaptureSection, {
			PreSetCallback = function(value)
				return not value or Window.Dialogs.RakNet.ConfirmEnable(Window)
			end,
		})

		Settings.OthHooks:SetupOption(CaptureSection, {
			PreSetCallback = function(value)
				local Support = wax.shared.ExecutorSupport["oth"]
				if not Support.IsWorking then
					wax.shared.Sonner.error("Oth hooks are not supported by your executor:\n\n" .. Support.Details)
					return false
				end

				return not value
			end,
		})

		Settings.LogRobloxInternalEvents:SetupOption(CaptureSection)
		Settings.LogActors:SetupOption(CaptureSection)
		Settings.LogBlockedRemotes:SetupOption(CaptureSection)
	end

	--// Filter Section \\--
	local FilterSection = MainSettings:CreateSection("Filtering")
	do
		Settings.IgnoredRemotesDropdown:SetupOption(FilterSection)
		Settings.AutoIgnoreSpammyEvents:SetupOption(FilterSection)
		Settings.IgnorePlayerModule:SetupOption(FilterSection)

		Settings.ShowExecutorLogs:SetupOption(FilterSection, {
			Text = `Show {wax.shared.ExecutorName} Calls`,
			Callback = LogsPage.RefreshCurrentLog,
		})

		FilterSection:CreateButton("Reset Filtering Preferences", function()
			for _, Setting in FilterResetSettings do
				wax.shared.Settings[Setting.Key]:Reset()
			end

			wax.shared.Sonner.success("Successfully reset remote filtering to default")
		end)
	end

	--// Call Filters Section \\--
	local CallFiltersSection = MainSettings:CreateSection("Call Filters")
	do
		CallFiltersSection:CreateCallFilterList({
			Manager = wax.shared.CallFilters,
			OnEdit = function(Filter: Types.CallFilter)
				Window.Dialogs.CallFilter.Open(Window, {
					Filter = Filter,
					OnSave = function(Value)
						wax.shared.CallFilters:Update(Filter.Id, Value)
						wax.shared.Sonner.success("Call filter updated")
					end,
				})
			end,
			OnDuplicate = function(Filter: Types.CallFilter)
				wax.shared.CallFilters:Add({
					Enabled = Filter.Enabled,
					Target = Filter.Target,
					Direction = Filter.Direction,
					Conditions = Filter.Conditions,
					Action = Filter.Action,
				})
				wax.shared.Sonner.success("Call filter duplicated")
			end,
			OnDelete = function(Filter: Types.CallFilter)
				Window.Dialogs.DeleteCallFilter.Open(Window, Filter)
			end,
		})
	end

	--// Remotes Filtering Section \\--
	local IgnoredRemotesSection = MainSettings:CreateSection("Ignored Remotes")
	do
		IgnoredRemotesSection:CreateRemoteList("IgnoredRemotes", {
			NullMessage = "No remotes have been ignored yet.",
			Callback = function(Log)
				Log.Ignored = false
			end,
		})
	end

	local BlockedRemotesSection = MainSettings:CreateSection("Blocked Remotes")
	do
		BlockedRemotesSection:CreateRemoteList("BlockedRemotes", {
			NullMessage = "No remotes have been blocked yet.",
			Callback = function(Log)
				Log.Blocked = false
				Log:SetConnectionsEnabled(true)
			end,
		})
	end

	--// Code Generation Section \\--
	local CodeGenSection = MainSettings:CreateSection("Code Generation")
	do
		Settings.InstancePathLookupChain:SetupOption(CodeGenSection)
		Settings.EventReferenceStrategy:SetupOption(CodeGenSection)
		Settings.PreferBufferFromString:SetupOption(CodeGenSection)
		Settings.ShowWatermark:SetupOption(CodeGenSection)
	end

	--// File Logging Section \\--
	local LoggingSection = MainSettings:CreateSection("File Logging")
	do
		local SessionLogLabel

		Settings.EnableLogging:SetupOption(LoggingSection, {
			Callback = function(value)
				if not value then
					wax.shared.LogConnection:Disconnect()
					wax.shared.LogConnection = nil
					wax.shared.LogFileName = nil

					SessionLogLabel.Text = `Current Log File: <b>Not Logging</b>`
					wax.shared.Sonner.success("Successfully disabled file logging")
					return
				end

				local LogConnection = wax.shared.SetupLoggingConnection()
				SessionLogLabel.Text = `Current Log File: <b>{wax.shared.LogFileName:gsub("Cobalt/Logs/", "")}</b>`
				wax.shared.LogConnection = wax.shared.Connect(wax.shared.Communicator.Event:Connect(LogConnection))

				wax.shared.Sonner.success("Successfully enabled file logging")
			end,
		})

		SessionLogLabel = LoggingSection:AddLabel(
			`Current Log File: <b>{wax.shared.Settings.EnableLogging.Value and wax.shared.LogFileName:gsub(
				"Cobalt/Logs/",
				""
			) or "Not Logging"}</b>`
		)

		LoggingSection:AddLabel(`Log Folder: <b>Cobalt/Logs</b>`)

		--// Session Buttons Row \\--
		LoggingSection:AddSpacer()
		local SessionButtons = LoggingSection:CreateRow()
		do
			local CopySessionName = SessionButtons:CreateButton("Copy File Name", function()
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
			end, 14)
			CopySessionName.Size = UDim2.new(0.5, -4, 0, 24)

			local CopyFullSessionPath = SessionButtons:CreateButton("Copy File Path", function()
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
			end, 14)
			CopyFullSessionPath.Size = UDim2.new(0.5, -4, 0, 24)
		end

		LoggingSection:CreateButton("Export Session as HTML", function()
			wax.shared.Sonner.promise(function(UpdateProgress)
				assert(typeof(writefile) == "function", "Exploit does not support writefile")

				--// Collect all logs \\--
				local AllCalls = Session:FetchAllLogs()
				local SessionData = Session:GetSessionData(AllCalls)

				--// Data Processing \\--
				UpdateProgress("Sorting calls...")
				Session:SortCalls(AllCalls)
				local Events, StringMap = Session:ProcessCalls(AllCalls, SessionData, UpdateProgress)

				--// Export \\--
				local FileName = `Cobalt_Session_{os.time()}.html`
				writefile(FileName, Session:ExportSessionToHTML(Events, StringMap, SessionData))
				return FileName
			end, {
				loadingText = "Starting Export...",
				successText = function(fileName)
					return `Successfully exported trace to {fileName}`
				end,
				errorText = function(err)
					return `Export Failed: {err}`
				end,
			})
		end, 14)
	end

	--// Compatibility & Safety Section \\--
	local CompatibilitySection = MainSettings:CreateSection("Compatibility & Safety")
	do
		CompatibilitySection:AddLabel(`Executor: <b>{wax.shared.ExecutorName}</b>`)
		CompatibilitySection:AddLabel(
			`Support: {#wax.shared.ExecutorSupport.FailedChecks.Essential == 0 and "<b>Full</b>" or "<b>Partial</b> (" .. #wax.shared.ExecutorSupport.FailedChecks.Essential .. " check(s) failed)"}`
		)

		if #wax.shared.ExecutorSupport.FailedChecks.Essential > 0 then
			local PartialSupportDetails = {}
			for _, Name in wax.shared.ExecutorSupport.FailedChecks.Essential do
				table.insert(
					PartialSupportDetails,
					`❌ <b><font color="#ff0000">{Name}</font></b> · <font size="14" transparency="0.5">{wax.shared.ExecutorSupport[Name].Details}</font>`
				)
			end

			CompatibilitySection:AddLabel(table.concat(PartialSupportDetails, "\n"), 14)
		end

		Settings.DisableNonEssentialChecks:SetupOption(CompatibilitySection)
		Settings.AnticheatBypass:SetupOption(CompatibilitySection)
		CompatibilitySection:AddLabel("These options take effect the next time Cobalt launches.", 13).TextTransparency =
			0.5

		if AnticheatData.Disabled then
			CompatibilitySection:AddLabel(`Detected Anti-Cheat: <b>{AnticheatData.Name}</b>`, 14)
		end
	end

	--// About & Credits Section \\--
	local CreditsSection = MainSettings:CreateSection("About & Credits")
	CreditsSection:AddLabel("Cobalt and the open-source projects that make it possible.", 14).TextTransparency = 0.35
	CreditsSection:AddSpacer()
	CreditsSection:CreateButton("View Credits", function()
		Window.Dialogs.Credits.Open(Window)
	end)

	return {
		Frame = SettingsFrame,
		ScrollingFrame = SettingsScrollingFrame,
		Settings = MainSettings,
		TopButton = {
			Icon = "settings",
			Order = 2,
		},
	}
end
