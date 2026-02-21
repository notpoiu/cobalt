local FileHelperUtil = require(script.Parent.FileHelper)

local SaveManager = {
	State = {},
}

local FileHelper = FileHelperUtil.new("Cobalt")
FileHelper:EnsureFile("Settings.json", "{}")

local Success, Error = pcall(function()
	SaveManager.State = wax.shared.HttpService:JSONDecode(FileHelper:ReadFile("Settings.json"))
end)

if not Success then
	warn("Failed to load settings: " .. Error)
end

function SaveManager:SetState(Idx, Value)
	SaveManager.State[Idx] = Value
	pcall(FileHelper.WriteFile, FileHelper, "Settings.json", wax.shared.HttpService:JSONEncode(SaveManager.State))
end

function SaveManager:GetState(Idx, Default)
	if SaveManager.State[Idx] ~= nil then
		return SaveManager.State[Idx]
	end

	return Default
end

return SaveManager
