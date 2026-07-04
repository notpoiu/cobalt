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
	SettingIds.LogBlockedRemotes,
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
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},
	})

	return SettingsFrame, SettingsScrollingFrame
end

local function CreatePaddingText(Size: number): string
	return `<font size="{Size}"> \n</font>`
end

local function CreateDetectionNotice(Parent: GuiObject)
	local FailedChecks = wax.shared.ExecutorSupport.FailedChecks
	local NonEssentialFailures = FailedChecks and FailedChecks.NonEssential
	if not NonEssentialFailures or #NonEssentialFailures == 0 then
		return
	end

	local WarningDisplay = Interface.New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.fromRGB(245, 60, 54),
		BackgroundTransparency = 0.75,
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
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
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},

		["UIListLayout"] = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
	})

	local NoticeTitleInfoSeparator = CreatePaddingText(4)
	Interface.New("TextLabel", {
		Text = `<font size="16"><b>DETECTION NOTICE ⚠️</b></font>\n{NoticeTitleInfoSeparator}Cobalt can get detected because your executor does not support the following functions/libraries:`,
		TextSize = 15,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		BackgroundTransparency = 1,
		Parent = WarningDisplay,
		TextWrapped = true,
	})

	local DetectionDetails = CreatePaddingText(6)
	local DetectionSuffix = `\n{CreatePaddingText(7)}`
	for _, Name in NonEssentialFailures do
		local Check = wax.shared.ExecutorSupport[Name]
		local Details = if Check then Check.Details else "No details available."
		DetectionDetails ..= `⚠️ <b><font color="#ff9900">{Name}</font></b>\n<i><font size="14" transparency="0.5">{Details}</font></i>{DetectionSuffix}`
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

--// UI \\--
return function(props: {
	ModalController: ModalController.Modal,
	SettingsBuilder: SettingsBuilder.Builder,
	DPIHandler: DPI.DPI,
	PaginationManager: Types.PaginationManager,
	LogsPage: Types.LogsPage,
})
	--// Props \\--
	local ModalController = props.ModalController
	local SettingsBuilder = props.SettingsBuilder
	local DPIHandler = props.DPIHandler
	local PaginationManager = props.PaginationManager
	local LogsPage = props.LogsPage
	local function GetDPIScale()
		return DPIHandler:GetDPIScale()
	end

	--// Setup \\--
	local SettingsFrame, SettingsScrollingFrame = SetupModal(ModalController, GetDPIScale)

	local MainSettings = SettingsBuilder.new(SettingsScrollingFrame)
	CreateDetectionNotice(SettingsScrollingFrame)

	--// Executor Support Section \\--
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

	--// Code Generation Section \\--
	local CodeGenSection = MainSettings:CreateSection("Code Generation")
	do
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

		CodeGenSection:CreateCheckbox("ShowWatermark", {
			Text = "Show Cobalt Watermark",
			Default = true,
		})
	end

	--// Main Section \\--
	local MainSection = MainSettings:CreateSection("Main")
	do
		MainSection:CreateDropdown("WindowDPIScale", {
			Text = "DPI Scale",
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
			Component = MainSection:CreateTextBox("MaxItemPerPages", {
				Text = "Logs Per Page",
				Default = 20,
				NumericOnly = true,
			}),

			PaginationKey = "ItemsPerPage",
			Refresh = LogsPage.RefreshCurrentLog,
		})

		MainSection:CreateCheckbox("ExecuteOnTeleport", {
			Text = "Execute On Teleport",
			Default = false,
		})

		MainSection:CreateCheckbox("DisableNonEssentialChecks", {
			Text = "Disable Edge Case Checks",
			Default = true,
		})

		MainSection:CreateCheckbox("AnticheatBypass", {
			Text = "Built-in Anticheat Bypass",
			Default = false,
		})

		if AnticheatData.Disabled then
			MainSection:AddLabel(`Anticheat Detected: <b>{AnticheatData.Name}</b>`)
		end

		MainSection:CreateButton("Clear All Logs", function()
			LogsPage.ClearLogs()
		end)
	end

	--// Filter Section \\--
	local FilterSection = MainSettings:CreateSection("Filter")
	do
		FilterSection:CreateDropdown(SettingIds.IgnoredRemotesDropdown, {
			Text = "Ignore Remotes",
			Values = Constants.InstanceClassImages,
			Default = { "BindableEvent", "BindableFunction" },
			AllowNull = true,
			Multi = true,
		})

		FilterSection:CreateCheckbox(SettingIds.AutoIgnoreSpammyEvents, {
			Text = "Auto Ignore Spammy Events",
			Default = false,
		})

		FilterSection:CreateCheckbox("LogActors", {
			Text = "Log Events from Actors",
			Default = true,
		})

		FilterSection:CreateCheckbox(SettingIds.IgnorePlayerModule, {
			Text = "Ignore Player Module Remotes",
			Default = true,
		})

		FilterSection:CreateCheckbox(SettingIds.ShowExecutorLogs, {
			Text = `Show {wax.shared.ExecutorName} Remote Logs`,
			Default = true,
			Callback = LogsPage.RefreshCurrentLog,
		})

		FilterSection:CreateCheckbox(SettingIds.LogBlockedRemotes, {
			Text = "Log Blocked Remotes",
			Default = true,
		})

		FilterSection:CreateButton("Reset Filtering to Default", function()
			for _, SettingName in FilterResetSettingIds do
				wax.shared.Settings[SettingName]:Reset()
			end

			wax.shared.Sonner.success("Successfully reset remote filtering to default")
		end)
	end

	--// Ignored Section \\--
	local IgnoredSection = MainSettings:CreateSection("Ignored")
	do
		IgnoredSection:CreateRemoteList("IgnoredRemotes", {
			Text = "Ignored Remotes",
			NullMessage = "No remotes have been ignored yet.",
			Callback = function(Log)
				Log.Ignored = false
			end,
		})
	end

	--// Blocked Section \\--
	local BlockedSection = MainSettings:CreateSection("Blocked")
	do
		BlockedSection:CreateRemoteList("BlockedRemotes", {
			Text = "Blocked Remotes",
			NullMessage = "No remotes have been blocked yet.",
			Callback = function(Log)
				Log.Blocked = false
				Log:SetConnectionsEnabled(true)
			end,
		})
	end

	--// Logging Section \\--
	local LoggingSection = MainSettings:CreateSection("Logging")
	do
		local SessionLogLabel

		LoggingSection:CreateCheckbox("EnableLogging", {
			Text = `Enable File Logs`,
			Default = false,
			Callback = function(value)
				if not value then
					wax.shared.LogConnection:Disconnect()
					wax.shared.LogConnection = nil
					wax.shared.LogFileName = nil

					SessionLogLabel.Text = `Current Session Log: <b>Not Logging</b>`
					wax.shared.Sonner.success("Successfully disabled file logging")
					return
				end

				local LogConnection = wax.shared.SetupLoggingConnection()
				SessionLogLabel.Text = `Current Session Log: <b>{wax.shared.LogFileName:gsub("Cobalt/Logs/", "")}</b>`
				wax.shared.LogConnection = wax.shared.Connect(wax.shared.Communicator.Event:Connect(LogConnection))

				wax.shared.Sonner.success("Successfully enabled file logging")
			end,
		})

		SessionLogLabel = LoggingSection:AddLabel(
			`Current Session Log: <b>{wax.shared.Settings.EnableLogging.Value and wax.shared.LogFileName:gsub(
				"Cobalt/Logs/",
				""
			) or "Not Logging"}</b>`
		)

		LoggingSection:AddLabel(`Logs Path: <b>Cobalt/Logs</b>`)

		--// Session Buttons Row \\--
		local SessionButtons = LoggingSection:CreateRow()
		do
			local CopySessionName = SessionButtons:CreateButton("Copy Session Name", function()
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

			local CopyFullSessionPath = SessionButtons:CreateButton("Copy Full Path", function()
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

		LoggingSection:CreateButton("Export Logs to HTML", function()
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

	--// Credits Section \\--
	local CreditsSection = MainSettings:CreateSection("Credits")
	do
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
				Credit = "The Lucide Team",
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
			Parent = CreditsSection.Parent,

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
	end

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
