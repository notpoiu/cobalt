--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local AssetManager = require("@src/Utils/UI/Assets/Manager")

local SyntaxHighlighter = require("@src/Window/Utils/Text/Highlighter")

--// Assets \\--
local IBMPlexMono = AssetManager.GetCustomFont({
	Name = "IBM Plex Mono",
	Url = "https://raw.githubusercontent.com/notpoiu/cobalt/refs/heads/main/Assets/IBMPlexMono.ttf",

	FallbackId = 16658246179,
})
local LoadingText = SyntaxHighlighter.Run("-- Loading...")

local CodeView = {}
CodeView.__index = CodeView

function CodeView.new(Parent: ScrollingFrame)
	local self = setmetatable({
		Labels = {},
		Parent = Parent,
	}, CodeView)

	for Index = 1, 5 do
		self.Labels[Index] = Interface.New("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			TextSize = 16,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = IBMPlexMono,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Text = "",
			Parent = Parent,
		})
	end

	return self
end

function CodeView:SetText(Code: string)
	for _, Label in self.Labels do
		Label.Text = ""
	end

	local Lines = SyntaxHighlighter.Run(Code):split("\n")
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

	for Index, Content in TextContents do
		if not self.Labels[Index] then
			self.Labels[Index] = Interface.New("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				TextSize = 16,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				FontFace = IBMPlexMono,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				Text = LoadingText,
				Parent = self.Parent,
			})
		end

		self.Labels[Index].Text = table.concat(Content, "\n")
	end
end

return CodeView
