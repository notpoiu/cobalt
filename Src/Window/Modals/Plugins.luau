--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Constants = require("@src/Window/Constants")

local ModalController = require("@src/Window/Components/Modal")
local SettingsBuilder = require("@src/Window/Components/Modal/Builder/Settings")
local Resize = require("@src/Window/Utils/Input/Resize")

--// Setup \\--
local function SetupModal(ModalController: ModalController.Modal, GetDPIScale: () -> number)
	local PluginsFrame = Interface.New("TextButton", {
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
		MainFrame = PluginsFrame,

		MaximumSize = UDim2.new(1, -2, 1, -2),
		MinimumSize = UDim2.fromScale(0.65, 0.712),
		Mirrored = true,
		LockedPosition = true,

		CornerHandleSize = 20,
		HandleSize = 6,
		GetDPIScale = GetDPIScale,
	})

	ModalController:CreateTop("Plugins", "blocks", PluginsFrame)

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

	return PluginsFrame, PluginsScrollingFrame
end

--// UI \\--
return function(props: {
	ModalController: ModalController.Modal,
	SettingsBuilder: SettingsBuilder.Builder,
	GetDPIScale: () -> number,
})
	--// Props \\--
	local ModalController = props.ModalController
	local SettingsBuilder = props.SettingsBuilder
	local GetDPIScale = props.GetDPIScale

	--// Setup \\--
	local _PluginsFrame, PluginsScrollingFrame = SetupModal(ModalController, GetDPIScale)

	local PluginSettings = SettingsBuilder.new(PluginsScrollingFrame)
	local PluginsSection = PluginSettings:CreateSection("Plugins")

	--// Actual UI \\--
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
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingTop = UDim.new(0, 7),
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
		local ErrorCount = #Registry.Errored

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

	return {
		Frame = _PluginsFrame,
		ScrollingFrame = PluginsScrollingFrame,
		Settings = PluginSettings,
		TopButton = {
			Icon = "blocks",
			Order = 1,
		},
	}
end
