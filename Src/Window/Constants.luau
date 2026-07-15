--// Imports \\--
local Interface = require("@src/Utils/UI/Interface")
local AssetManager = require("@src/Utils/UI/Assets/Manager")

--// Constants \\--
local Constants = {}

Constants.MainUICorner = Interface.New("UICorner", {
	CornerRadius = UDim.new(0, 6),
})

Constants.DefaultTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Exponential)

Constants.InstanceClassImages = AssetManager.GetInstanceClassImages()

return Constants
