local Metadata = {}
local Validation = require("@src/Utils/Validation")

local Schema = Validation.Schema

local GameIdSchema = Schema.union({ Schema.string(), Schema.number() })
local PluginDataSchema = Schema.object({
	Name = Schema.string():default("Untitled Plugin"),
	Description = Schema.string():default("No description provided."),
	Author = Schema.string():default("N/A"),
	Version = Schema.string():default("0.0.0"),
	Game = Schema.union({ GameIdSchema, Schema.array(GameIdSchema) }):default("*"),
})

function Metadata.Validate(PluginData)
	local IsValid, Result, Errors = Validation.ValidateSchema(PluginData, PluginDataSchema)
	assert(IsValid, Errors[1] or "Invalid plugin metadata")
	return Result
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
