if not isfolder("Cobalt") then
	makefolder("Cobalt")
end

if not isfile("Cobalt/Settings.json") then
	writefile("Cobalt/Settings.json", "{}")
end

local SaveManager = {
	State = {},
}

local Success, Error = pcall(function()
	SaveManager.State = wax.shared.HttpService:JSONDecode(readfile("Cobalt/Settings.json"))
end)

if not Success then
	warn("Failed to load settings: " .. Error)
end

function SaveManager:SetState(Idx, Value)
	SaveManager.State[Idx] = Value
	pcall(writefile, "Cobalt/Settings.json", wax.shared.HttpService:JSONEncode(SaveManager.State))
end

function SaveManager:GetState(Idx, Default)
	if SaveManager.State[Idx] ~= nil then
		return SaveManager.State[Idx]
	end

	return Default
end

return SaveManager
