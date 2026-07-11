--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Constants = require("@src/Window/Constants")
local Types = require("@src/Window/Types")

local ModalController = require("@src/Window/Components/Modal")
local SettingsBuilder = require("@src/Window/Components/Modal/Builder/Settings")

local Resize = require("@src/Window/Utils/Input/Resize")
local DPI = require("@src/Window/Utils/DPI")

--// Data \\--
local AnticheatData = require("@src/Utils/Anticheats/Main")
local Session = require("@src/Utils/CodeGen/Serializer/Session")

local SettingIds = {
	IgnoredRemotesDropdown = "IgnoredRemotesDropdown",
	AutoIgnoreSpammyEvents = "AutoIgnoreSpammyEvents",
	IgnorePlayerModule = "IgnorePlayerModule",
	ShowExecutorLogs = "ShowExecutorLogs",
	LogBlockedRemotes = "LogBlockedRemotes",
}

local FilterResetSettingIds = {
	SettingIds.IgnoredRemotesDropdown,
	SettingIds.AutoIgnoreSpammyEvents,
	SettingIds.IgnorePlayerModule,
	SettingIds.ShowExecutorLogs,
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

	local DetectionDetails = {}
	for _, Name in DetectionRiskFailures do
		local Check = wax.shared.ExecutorSupport[Name]
		local Details = if Check then Check.Details else "No details available."
		table.insert(
			DetectionDetails,
			`<b><font color="#ff9900">{Name}</font></b>\n<font transparency="0.35">{Details}</font>`
		)
	end

	WarningDisplay.MouseButton1Click:Connect(function()
		Window.Dialog.new({
			Title = "Detection Risk",
			TitleColor = Color3.fromRGB(245, 60, 54),
			Description = "Cobalt may be detectable because your executor does not support the following functions or libraries:\n\n"
				.. table.concat(DetectionDetails, "\n\n"),
			Icon = "triangle-alert",
			Footer = {
				{
					Text = "Close",
					Action = "Dismiss",
				},
			},
		})
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
		if wax.shared.SaveManager.State.CallsPerPage == nil and wax.shared.SaveManager.State.MaxItemPerPages ~= nil then
			wax.shared.SaveManager:SetState("CallsPerPage", wax.shared.SaveManager.State.MaxItemPerPages)
		end

		GeneralSection:CreateDropdown("WindowDPIScale", {
			Text = "Interface Scale",
			Values = {
				"50%",
				"75%",
				"100%",
				"125%",
				"150%",
			},
			Default = "100%",

			Callback = DPIHandler:CreateDPIScaleChangedCallback(),
		})

		PaginationManager:BindPagination({
			Component = GeneralSection:CreateTextBox("CallsPerPage", {
				Text = "Calls Per Page",
				Default = 20,
				NumericOnly = true,
			}),

			PaginationKey = "ItemsPerPage",
			Refresh = LogsPage.RefreshCurrentLog,
		})

		GeneralSection:CreateCheckbox("ExecuteOnTeleport", {
			Text = "Relaunch After Teleport",
			Default = false,
		})

		GeneralSection:AddSpacer()
		GeneralSection:CreateButton("Clear Captured Calls", function()
			Window.Dialog.new({
				Title = "Clear Captured Calls?",
				TitleColor = Color3.fromRGB(245, 60, 54),
				Description = "This will permanently remove all captured incoming and outgoing calls. This action cannot be undone.",
				Icon = "trash",
				Footer = {
					{
						Text = "Cancel",
						Action = "Dismiss",
					},
					{
						Text = "Clear Calls",
						Type = "Primary",
						Action = function(Dialog: Types.Dialog)
							LogsPage.ClearLogs()
							Dialog:Dismiss()
						end,
					},
				},
			})
		end)
	end

	--// Capture Section \\--
	local CaptureSection = MainSettings:CreateSection("Capture")
	do
		CaptureSection:CreateCheckbox("RakNetHooks", {
			Text = "Use RakNet Hooks on Relaunch (Experimental)",
			Default = false,
			Risky = true,

			PreSetCallback = function(value)
				if not wax.shared.ExecutorSupport["raknet"].IsWorking then
					if value then
						wax.shared.Sonner.error("RakNet hooks are not supported by your executor:\n\n" .. wax.shared.ExecutorSupport["raknet"].Details)
					end

					return false
				end

				if value then
					local Thread = coroutine.running()
					task.spawn(Window.Dialog.new, {
						Title = "Warning",
						Description = "Are you sure you want to use RakNet hooks? This is risky and could theoretically lead to account bans. Cobalt is not responsible for any bans you may receive. This change takes effect the next time Cobalt launches.",
						Icon = "triangle-alert",

						AutoShow = true,

						Footer = {
							{
								Text = "Nevermind",
								Action = function(Dialog: Types.Dialog)
									Dialog:Dismiss()
									coroutine.resume(Thread, false)
								end,
							},
							{
								Text = "Continue",
								Type = "Primary",
								Action = function(Dialog: Types.Dialog)
									Dialog:Dismiss()
									coroutine.resume(Thread, true)
								end,
							},
						},
					})

					return coroutine.yield()
				end

				return true
			end,
		})

		CaptureSection:CreateCheckbox("LogRobloxInternalEvents", {
			Text = "Capture Roblox Internal Events",
			Default = false,
		})

		CaptureSection:CreateCheckbox("LogActors", {
			Text = "Capture Actor Calls",
			Default = true,
		})

		CaptureSection:CreateCheckbox(SettingIds.LogBlockedRemotes, {
			Text = "Record Blocked Calls",
			Default = false,
		})
	end

	--// Filter Section \\--
	local FilterSection = MainSettings:CreateSection("Filtering")
	do
		FilterSection:CreateDropdown(SettingIds.IgnoredRemotesDropdown, {
			Text = "Ignored Remote Classes",
			Values = Constants.InstanceClassImages,
			Default = { "BindableEvent", "BindableFunction" },
			AllowNull = true,
			Multi = true,
		})

		FilterSection:CreateCheckbox(SettingIds.AutoIgnoreSpammyEvents, {
			Text = "Auto-ignore High-frequency Calls",
			Default = false,
		})

		FilterSection:CreateCheckbox(SettingIds.IgnorePlayerModule, {
			Text = "Ignore PlayerModule Calls",
			Default = true,
		})

		FilterSection:CreateCheckbox(SettingIds.ShowExecutorLogs, {
			Text = `Show {wax.shared.ExecutorName} Calls`,
			Default = true,
			Callback = LogsPage.RefreshCurrentLog,
		})

		FilterSection:CreateButton("Reset Filters", function()
			for _, SettingName in FilterResetSettingIds do
				wax.shared.Settings[SettingName]:Reset()
			end

			wax.shared.Sonner.success("Successfully reset remote filtering to default")
		end)
	end

	--// Managed Remotes Section \\--
	local ManagedRemotesSection = MainSettings:CreateSection("Managed Remotes")
	do
		ManagedRemotesSection:CreateRemoteList("IgnoredRemotes", {
			Text = "Ignored Remotes",
			NullMessage = "No remotes have been ignored yet.",
			Callback = function(Log)
				Log.Ignored = false
			end,
		})

		ManagedRemotesSection:CreateRemoteList("BlockedRemotes", {
			Text = "Blocked Remotes",
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
		CodeGenSection:CreateDropdown("InstancePathLookupChain", {
			Text = "Instance Path Style",
			Values = {
				["Index"] = "file",
				["WaitForChild"] = "file-clock",
				["FindFirstChild"] = "file-search",
			},
			Default = "Index",
		})

		CodeGenSection:CreateDropdown("EventReferenceStrategy", {
			Text = "Nil Instance Strategy",
			Values = {
				["GetNil"] = "bug",
				["Upvalue Lookup"] = "circle-fading-arrow-up",
			},
			Default = "GetNil",
		})

		CodeGenSection:CreateCheckbox("PreferBufferFromString", {
			Text = "Use buffer.fromstring()",
			Default = false,
		})

		CodeGenSection:CreateCheckbox("ShowWatermark", {
			Text = "Include Cobalt Header",
			Default = true,
		})
	end

	--// File Logging Section \\--
	local LoggingSection = MainSettings:CreateSection("File Logging")
	do
		local SessionLogLabel

		LoggingSection:CreateCheckbox("EnableLogging", {
			Text = "Save Calls to File",
			Default = false,
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

		CompatibilitySection:CreateCheckbox("DisableNonEssentialChecks", {
			Text = "Skip Optional Executor Checks",
			Default = false,
		})

		CompatibilitySection:CreateCheckbox("AnticheatBypass", {
			Text = "Enable Anti-Cheat Bypass",
			Default = false,
		})
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
		Window.Dialog.new({
			Title = "Credits",
			Description = table.concat({
				"<b>upio</b> · Cobalt Developer",
				"<b>deivid</b> · Cobalt Developer",
				'<b>shadcn</b> · UI design inspiration · <font color="#3798ff">ui.shadcn.com</font>',
				'<b>The Lucide Team</b> · Icon library · <font color="#3798ff">lucide.dev</font>',
				'<b>Emil Kowalski</b> · Sonner · <font color="#3798ff">sonner.emilkowal.ski</font>',
			}, "\n\n"),
			Footer = {
				{
					Text = "Close",
					Action = "Dismiss",
				},
			},
		})
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
