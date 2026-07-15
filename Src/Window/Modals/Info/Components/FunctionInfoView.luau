--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local AssetManager = require("@src/Utils/UI/Assets/Manager")

local CodeGen = require("@src/Utils/CodeGen/Generator")

--// Assets \\--
local IBMPlexMono = AssetManager.GetCustomFont("IBMPlexMono")

local FunctionInfoView = {}
FunctionInfoView.__index = FunctionInfoView

function FunctionInfoView.new(Parent: ScrollingFrame)
	return setmetatable({
		Text = Interface.New("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			TextSize = 16,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = IBMPlexMono,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Text = "",
			Parent = Parent,
		}),
	}, FunctionInfoView)
end

function FunctionInfoView:SetCallInfo(CallInfo)
	xpcall(function()
		self.Text.Text = CodeGen:BuildFunctionInfo(CallInfo)
	end, function(Error)
		self.Text.Text = table.concat({
			"Error while fetching function data.",
			`Calling Function: {CallInfo.Function} (type: {typeof(CallInfo.Function)})`,
			`\n\nError: {Error}`,
		}, "\n")
	end)
end

return FunctionInfoView
