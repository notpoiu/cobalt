local Metadata = {}
local Validate = require("@src/Utils/Validation")

Metadata.TemplatePluginData = {
	Name = "Untitled Plugin",
	Description = "No description provided.",
	Author = "N/A",
	Version = "0.0.0",
	Game = "*",
}

function Metadata.Validate(PluginData)
	return Validate(PluginData, Metadata.TemplatePluginData)
end

function Metadata.IsSupportedInCurrentGame(PluginData): boolean
	if type(PluginData.Game) == "string" then
		return PluginData.Game == "*"
			or tostring(game.PlaceId) == PluginData.Game
			or tostring(game.GameId) == PluginData.Game
	end

	if type(PluginData.Game) == "number" then
		return game.PlaceId == PluginData.Game or game.GameId == PluginData.Game
	end

	if type(PluginData.Game) == "table" then
		for _, Id in pairs(PluginData.Game) do
			if tostring(game.PlaceId) == tostring(Id) or tostring(game.GameId) == tostring(Id) then
				return true
			end
		end

		return false
	end

	return true
end

return Metadata
