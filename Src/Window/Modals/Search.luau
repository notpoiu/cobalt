--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local Constants = require("@src/Window/Constants")
local Types = require("@src/Window/Types")

local ModalController = require("@src/Window/Components/Modal")

--// Constants \\--
local SearchableClasses = {
	"RemoteEvent",
	"UnreliableRemoteEvent",
	"RemoteFunction",
	"BindableEvent",
	"BindableFunction",
}

--// Setup \\--
local function SetupModal(ModalController: ModalController.Modal)
	local SearchFrame = Interface.New("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.5, 0, 0.8, 0),
		Text = "",
		Visible = false,
		Parent = ModalController.Background,

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

	local SearchBox: TextBox = Interface.New("TextBox", {
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

	ModalController:ConnectCloseButton(SearchCloseButton, SearchCloseImage)

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

	return SearchFrame, SearchBox, SearchFilterList, FilterAllButton, SearchResults
end

--// UI \\--
return function(props: {
	ModalController: ModalController.Modal,
	LogsPage: Types.LogsPage,
})
	--// Props \\--
	local ModalController = props.ModalController
	local LogsPage = props.LogsPage

	--// State \\--
	local Search = {
		ResultInfo = {},
		CurrentResults = {},
		SelectedResult = -1,
		ExcludedClasses = {},
		ResultByLog = setmetatable({}, { __mode = "k" }),
	}

	--// Setup \\--
	local SearchFrame, SearchBox, SearchFilterList, FilterAllButton, SearchResults = SetupModal(ModalController)
	local SearchFilterButtons = {}

	--// Functions \\--
	local function SelectResult(NewResult: number, UpdateCanvasPosition: boolean?)
		if Search.SelectedResult > 0 and Search.CurrentResults[Search.SelectedResult] then
			Search.CurrentResults[Search.SelectedResult].BackgroundTransparency = 1
		end

		if NewResult == -1 or #Search.CurrentResults == 0 then
			Search.SelectedResult = -1
			return
		end

		Search.SelectedResult = math.clamp(NewResult, 1, #Search.CurrentResults)
		Search.CurrentResults[Search.SelectedResult].BackgroundTransparency = 0

		if not UpdateCanvasPosition then
			return
		end

		local ScrollSize = SearchResults.AbsoluteSize.Y
		local SelectedMin = Search.CurrentResults[Search.SelectedResult].AbsolutePosition.Y
			- SearchResults.AbsolutePosition.Y
		local SelectedMax = SelectedMin + Search.CurrentResults[Search.SelectedResult].AbsoluteSize.Y

		if SelectedMin < 0 then
			SearchResults.CanvasPosition += Vector2.new(0, SelectedMin - 6)
		elseif SelectedMax > ScrollSize then
			SearchResults.CanvasPosition += Vector2.new(0, SelectedMax - ScrollSize + 6)
		end
	end

	local function EnterResult(ResultIndex: number)
		local Result = Search.CurrentResults[ResultIndex]
		local Info = Result and Search.ResultInfo[Result]
		if not Info then
			ModalController:Close()
			return
		end

		LogsPage.ShowLog(Info.Log)
		ModalController:Close()
	end

	local function CreateSearchResult(RemoteInstance: Instance, Type: string)
		local SearchResult = Interface.New("TextButton", {
			BackgroundColor3 = Color3.fromRGB(25, 25, 25),
			BackgroundTransparency = 1,
			Name = RemoteInstance.Name,
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
				Text = RemoteInstance.Name,
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		})

		SearchResult.MouseEnter:Connect(function()
			local Index = table.find(Search.CurrentResults, SearchResult)
			if Index then
				SelectResult(Index)
			end
		end)

		SearchResult.MouseButton1Click:Connect(function()
			local Index = table.find(Search.CurrentResults, SearchResult)
			if Index then
				EnterResult(Index)
			end
		end)

		Interface.New("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Constants.InstanceClassImages[RemoteInstance.ClassName],
			Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Parent = SearchResult,
		})

		Interface.New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = Type,
			TextSize = 15,
			TextTransparency = 0.5,
			TextXAlignment = Enum.TextXAlignment.Right,

			Parent = SearchResult,
		})

		return SearchResult
	end

	local function HandleSearch(Text: string, Type: string)
		for RemoteInstance, Log in pairs(wax.shared.Logs[Type]) do
			local SearchResult = Search.ResultByLog[Log]
			if not SearchResult then
				SearchResult = CreateSearchResult(RemoteInstance, Type)
				Search.ResultByLog[Log] = SearchResult
				Search.ResultInfo[SearchResult] = {
					Type = Type,
					Log = Log,
				}
			end

			local LoweredName = string.lower(RemoteInstance.Name)
			if
				Text ~= "" and not LoweredName:find(Text, 1, true)
				or table.find(Search.ExcludedClasses, RemoteInstance.ClassName)
			then
				SearchResult.Parent = nil
				continue
			end

			SearchResult.BackgroundTransparency = 1
			SearchResult.Parent = SearchResults
			table.insert(Search.CurrentResults, SearchResult)
		end
	end

	function Search:Update()
		table.clear(self.CurrentResults)
		SelectResult(-1)

		local Text = string.lower(SearchBox.Text)
		HandleSearch(Text, "Outgoing")
		HandleSearch(Text, "Incoming")

		if #self.CurrentResults == 0 then
			return
		end

		table.sort(self.CurrentResults, function(Left, Right)
			return Left.AbsolutePosition.Y < Right.AbsolutePosition.Y
		end)

		SelectResult(1, true)
	end

	function Search:Open()
		ModalController:Open(SearchFrame)
		self:Update()
		SearchBox:CaptureFocus()
	end

	--// Events \\--
	FilterAllButton.MouseButton1Click:Connect(function()
		table.clear(Search.ExcludedClasses)
		FilterAllButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)

		for _, Button in SearchFilterButtons do
			Button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		end

		Search:Update()
	end)

	for Order, ClassName in SearchableClasses do
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

		Interface.New("ImageLabel", {
			Image = Constants.InstanceClassImages[ClassName],
			Size = UDim2.new(1, -8, 1, -8),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(0.5, 0),
			Parent = ClassNameFilterButton,
		})

		ClassNameFilterButton.MouseButton1Click:Connect(function()
			local FoundIndex = table.find(Search.ExcludedClasses, ClassName)
			if FoundIndex then
				table.remove(Search.ExcludedClasses, FoundIndex)
				ClassNameFilterButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)

				if #Search.ExcludedClasses == 0 then
					FilterAllButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
				end

				Search:Update()
				return
			end

			table.insert(Search.ExcludedClasses, ClassName)
			ClassNameFilterButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
			FilterAllButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
			Search:Update()
		end)

		table.insert(SearchFilterButtons, ClassNameFilterButton)
	end

	SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		Search:Update()
	end)

	wax.shared.Connect(wax.shared.UserInputService.InputBegan:Connect(function(Input: InputObject)
		if Input.KeyCode == Enum.KeyCode.K and wax.shared.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			Search:Open()
			return
		end

		if ModalController.OpenedModal ~= SearchFrame then
			return
		end

		if Input.KeyCode == Enum.KeyCode.Escape then
			ModalController:Close()
		elseif Input.KeyCode == Enum.KeyCode.Return then
			EnterResult(Search.SelectedResult)
		elseif Input.KeyCode == Enum.KeyCode.Up then
			SelectResult(Search.SelectedResult - 1, true)
		elseif Input.KeyCode == Enum.KeyCode.Down then
			SelectResult(Search.SelectedResult + 1, true)
		end
	end))

	Search.Frame = SearchFrame
	Search.TopButton = {
		Icon = "search",
		Order = 0,
	}

	return Search
end
