--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")

local LazySerializer = require("@src/Window/Utils/Text/LazySerializer")
local SyntaxHighlighter = require("@src/Window/Utils/Text/Highlighter")

local ArgumentList = {}

function ArgumentList.Clear(Frame: GuiObject)
	for _, Object in Frame:QueryDescendants("Frame") do
		Object:Destroy()
	end
end

function ArgumentList.CreateHolder(Index: number, Value: any, Parent: GuiObject, IsBlockedCall: boolean?)
	local Holder = Interface.New("Frame", {
		BackgroundColor3 = if IsBlockedCall then Color3.fromRGB(58, 24, 24) else Color3.fromRGB(25, 25, 25),
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
		TextColor3 = if IsBlockedCall then Color3.fromRGB(255, 190, 190) else Color3.new(1, 1, 1),
		TextSize = 15,
		TextTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,

		Parent = Holder,
	})

	local TypeLabel = Interface.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = typeof(Value),
		TextColor3 = if IsBlockedCall then Color3.fromRGB(255, 190, 190) else Color3.new(1, 1, 1),
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
		TextColor3 = if IsBlockedCall
			then Color3.fromRGB(255, 190, 190)
			else Color3.fromHex(SyntaxHighlighter.GetArgumentColor(Value)),
		Text = tostring(LazySerializer.QuickSerializeArgument(Value)):gsub("<", "&lt;"):gsub(">", "&gt;"),
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
