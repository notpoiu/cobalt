--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local AssetManager = require("@src/Utils/UI/Assets/Manager")

--// Constants \\--
local Constants = {}

Constants.MainUICorner = Interface.New("UICorner", {
	CornerRadius = UDim.new(0, 6),
})

Constants.DefaultTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Exponential)

Constants.InstanceClassImages = AssetManager.GetInstanceClassImages({
	RemoteEvent = "rbxassetid://110803789420086",
	UnreliableRemoteEvent = "rbxassetid://126244162339059",
	RemoteFunction = "rbxassetid://108537517159060",
	BindableEvent = "rbxassetid://116839398727495",
	BindableFunction = "rbxassetid://112264959079193",
})

return Constants
