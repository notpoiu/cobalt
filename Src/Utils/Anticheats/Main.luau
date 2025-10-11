--[[
    Bypasses for popular roblox anticheats
]]

local AnticheatData = {
	Disabled = false,
	Name = "N/A",
}

local BypassEnabled = wax.shared.SaveManager:GetState("AnticheatBypass", true)
if not BypassEnabled then
	return AnticheatData
end

type Bypass = {
	Name: string,
	Game: string | number | { number } | { string },
	Detect: () -> boolean,
	Bypass: () -> boolean,
}

local GeneralPurposeBypasses: { Bypass } = {}
local DedicatedPlaceACBypass: Bypass = nil

local AnticheatBypasses = script.Parent.impl
for _, Anticheat in AnticheatBypasses:GetChildren() do
	local Data = require(Anticheat) :: Bypass

	local IsDedicatedACBypass = (
		if typeof(Data.Game) == "table"
			then (table.find(Data.Game, game.PlaceId) or table.find(Data.Game, tostring(game.PlaceId)))
			else (tostring(Data.Game) == tostring(game.PlaceId))
	)

	if IsDedicatedACBypass then
		DedicatedPlaceACBypass = Data
		break
	end

	if Data.Game ~= "*" then
		continue
	end

	table.insert(GeneralPurposeBypasses, Data)
end

if DedicatedPlaceACBypass and DedicatedPlaceACBypass.Detect() then
	DedicatedPlaceACBypass.Bypass()

	AnticheatData.Name = DedicatedPlaceACBypass.Name
	AnticheatData.Disabled = true
	return AnticheatData
end

for _, Data in GeneralPurposeBypasses do
	if not Data.Detect() then
		continue
	end

	if Data.Bypass() then
		AnticheatData.Name = Data.Name
		AnticheatData.Disabled = true
		break
	end
end

return AnticheatData
