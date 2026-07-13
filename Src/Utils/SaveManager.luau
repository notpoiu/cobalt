local FileHelperUtil = require(script.Parent.FileHelper)
local Validation = require(script.Parent.Validation)
local Settings = require(script.Parent.Settings)

local Schema = Validation.Schema

local SettingsSchemas = {}
for _, Setting in Settings do
	SettingsSchemas[Setting.Key] = Setting.Schema
end

local SettingsRootSchema = Schema.table():refine(function(Value)
	for Key in Value do
		if type(Key) ~= "string" then
			return false
		end
	end
	return true
end, "must be a settings object")

local SaveManager = {
	State = {},
	Settings = Settings,
	Schemas = SettingsSchemas,
	WarnedInvalidSettings = {},
}

local function ApplyMigrations(State): boolean
	local Changed = false

	for _, Setting in Settings do
		if State[Setting.Key] == nil then
			for _, Alias in Setting.Aliases do
				if State[Alias] ~= nil then
					State[Setting.Key] = State[Alias]
					Changed = true
					break
				end
			end
		end

		for _, Alias in Setting.Aliases do
			if State[Alias] ~= nil then
				State[Alias] = nil
				Changed = true
			end
		end
	end

	return Changed
end

local FileHelper = FileHelperUtil.new("Cobalt")
FileHelper:EnsureFile("Settings.json", "{}")

local Success, Error = pcall(function()
	local Decoded = wax.shared.HttpService:JSONDecode(FileHelper:ReadFile("Settings.json"))
	local IsValid, State, Errors = Validation.ValidateSchema(Decoded, SettingsRootSchema)
	assert(IsValid, Errors[1] or "Invalid settings data")
	SaveManager.State = State

	if ApplyMigrations(State) then
		FileHelper:WriteFile("Settings.json", wax.shared.HttpService:JSONEncode(State))
	end
end)

if not Success then
	wax.shared.Sonner.warning("Failed to load settings: " .. Error)
end

function SaveManager:SetState(Idx, Value)
	local DataSchema = SaveManager.Schemas[Idx]
	if DataSchema then
		local IsValid, Validated, Errors = Validation.ValidateSchema(Value, DataSchema)
		if not IsValid then
			local Error = `Invalid value for setting {Idx}: {Errors[1] or "validation failed"}`
			wax.shared.Sonner.warning(Error)
			return false, Error
		end
		Value = Validated
	end

	SaveManager.State[Idx] = Value
	pcall(FileHelper.WriteFile, FileHelper, "Settings.json", wax.shared.HttpService:JSONEncode(SaveManager.State))
	return true
end

function SaveManager:GetState(Idx, Default)
	if Default == nil and SaveManager.Settings[Idx] then
		Default = SaveManager.Settings[Idx]:GetDefault()
	end

	local Value = SaveManager.State[Idx]
	if Value == nil then
		return Default
	end

	local DataSchema = SaveManager.Schemas[Idx]
	if not DataSchema then
		return Value
	end

	local IsValid, Validated, Errors = Validation.ValidateSchema(Value, DataSchema)
	if IsValid then
		return Validated
	end

	if not SaveManager.WarnedInvalidSettings[Idx] then
		SaveManager.WarnedInvalidSettings[Idx] = true
		wax.shared.Sonner.warning(`Ignoring invalid saved setting {Idx}: {Errors[1] or "validation failed"}`)
	end

	return Default
end

function SaveManager:RegisterSchema(Idx: string, DataSchema)
	SaveManager.Schemas[Idx] = DataSchema
end

return SaveManager
