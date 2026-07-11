--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")

local LazySerializer = require("@src/Window/Utils/Text/LazySerializer")
local SyntaxHighlighter = require("@src/Window/Utils/Text/Highlighter")
local TextBounds = require("@src/Window/Utils/Text/TextBounds")

local ArgumentList = {}

local DefaultPreviewMaxLength = 500

type HolderOptions = {
	IsBlockedCall: boolean?,
	IsError: boolean?,
	IsPreview: boolean?,
	Label: string?,
	MaxPreviewLength: number?,
	PreviewCache: { [number]: string }?,
}

local function TruncatePreviewText(Text: string, MaxLength: number): string
	local NormalizedText = Text:gsub("[\r\n\t]", " ")
	if #Text <= MaxLength then
		return NormalizedText
	end

	return NormalizedText:sub(1, MaxLength) .. "..."
end

function ArgumentList.CreatePreviewText(Value: any, MaxLength: number?): string
	MaxLength = MaxLength or DefaultPreviewMaxLength

	if typeof(Value) == "string" then
		return `"{TruncatePreviewText(Value, MaxLength)}"`
	end

	return TruncatePreviewText(tostring(LazySerializer.QuickSerializeArgument(Value)), MaxLength)
end

function ArgumentList.Clear(Frame: GuiObject)
	for _, Object in Frame:QueryDescendants("Frame") do
		Object:Destroy()
	end
end

function ArgumentList.CreateHolder(Index: number, Value: any, Parent: GuiObject, Options: HolderOptions | boolean?)
	if typeof(Options) ~= "table" then
		Options = {
			IsBlockedCall = Options,
		}
	end

	--// Variables \\--
	local IsBlockedCall = Options.IsBlockedCall
	local IsError = Options.IsError == true
	local PreviewCache = Options.PreviewCache
	local IsPreview = Options.IsPreview == true

	--// UI \\--
	local Holder = Interface.New("Frame", {
		BackgroundColor3 = if IsBlockedCall
			then Color3.fromRGB(58, 24, 24)
			else Color3.fromRGB(25, 25, 25),
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

	local IndexLabel = Interface.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = Options.Label or Index,
		TextColor3 = if IsBlockedCall or IsError then Color3.fromRGB(255, 190, 190) else Color3.new(1, 1, 1),
		TextSize = 15,
		TextTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,

		Parent = Holder,
	})
	local IndexX = TextBounds.GetCachedWidth(IndexLabel.Text, IndexLabel.FontFace, IndexLabel.TextSize)

	local TypeLabel = Interface.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = typeof(Value),
		TextColor3 = if IsBlockedCall or IsError then Color3.fromRGB(255, 190, 190) else Color3.new(1, 1, 1),
		TextSize = 15,
		TextTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,

		Parent = Holder,
	})
	local TypeX = TextBounds.GetCachedWidth(TypeLabel.Text, TypeLabel.FontFace, TypeLabel.TextSize)

	local Text
	if IsPreview then
		if PreviewCache then
			if not PreviewCache[Index] then
				PreviewCache[Index] = ArgumentList.CreatePreviewText(Value, Options.MaxPreviewLength)
			end

			Text = PreviewCache[Index]
		else
			Text = ArgumentList.CreatePreviewText(Value, Options.MaxPreviewLength)
		end
	else
		Text = tostring(LazySerializer.QuickSerializeArgument(Value)):gsub("<", "&lt;"):gsub(">", "&gt;")
	end

	local TextLabel = Interface.New("TextLabel", {
		Position = UDim2.fromOffset(IndexX + 6, 0),
		Size = UDim2.new(1, -(IndexX + TypeX + 10), 1, 0),
		TextColor3 = if IsBlockedCall or IsError
			then Color3.fromRGB(255, 190, 190)
			else Color3.fromHex(SyntaxHighlighter.GetArgumentColor(Value)),
		Text = Text,
		RichText = not IsPreview,
		TextSize = 15,
		TextTruncate = if IsPreview then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None,
		TextWrapped = not IsPreview,
		TextXAlignment = Enum.TextXAlignment.Left,

		Parent = Holder,
	})

	if not IsPreview then
		local _, TextY = TextBounds.Get(TextLabel.Text, TextLabel.FontFace, TextLabel.TextSize, TextLabel.AbsoluteSize.X)
		Holder.Size = UDim2.new(1, 0, 0, TextY + 12)
	end

	return Holder
end

function ArgumentList.Populate(Frame: GuiObject, Values: { [any]: any }?)
	if not Values then
		return
	end

	for Index = 1, wax.shared.GetTableLength(Values) do
		if Index % 25 == 0 then
			task.wait()
		end

		ArgumentList.CreateHolder(Index, Values[Index], Frame)
	end
end

return ArgumentList
