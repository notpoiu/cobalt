local Validation = require(script.Parent.Parent.Validation)

local ControlMethods = {
	Checkbox = "CreateCheckbox",
	Dropdown = "CreateDropdown",
	TextBox = "CreateTextBox",
}

local function CloneValue(Value)
	if type(Value) ~= "table" then
		return Value
	end

	local Copy = {}
	for Key, Child in Value do
		Copy[CloneValue(Key)] = CloneValue(Child)
	end
	return Copy
end

local Setting = {}
Setting.__index = Setting

function Setting.new(Options)
	assert(type(Options) == "table", "Setting options must be a table")
	assert(type(Options.Key) == "string", "Setting key must be a string")
	assert(Options.Schema ~= nil, `Setting {Options.Key} requires a schema`)
	if Options.UI ~= nil then
		assert(type(Options.UI) == "table", `Setting {Options.Key} UI options must be a table`)
		assert(ControlMethods[Options.UI.Type] ~= nil, `Setting {Options.Key} has an unsupported control type`)
	end

	local IsValid, Default, Errors = Validation.ValidateSchema(Options.Default, Options.Schema)
	assert(IsValid, `Setting {Options.Key} has an invalid default: {Errors[1] or "validation failed"}`)

	return setmetatable({
		Key = Options.Key,
		Schema = Options.Schema,
		Default = Default,
		Aliases = table.clone(Options.Aliases or {}),
		UI = if Options.UI then CloneValue(Options.UI) else nil,
	}, Setting)
end

function Setting:GetDefault()
	return CloneValue(self.Default)
end

function Setting:SetupOption(Section, Overrides)
	assert(self.UI, `Setting {self.Key} does not define a UI control`)
	local MethodName = ControlMethods[self.UI.Type]
	local CreateControl = Section[MethodName]
	assert(type(CreateControl) == "function", `Section does not support {self.UI.Type} settings`)

	local Options = CloneValue(self.UI)
	Options.Type = nil
	Options.Default = self:GetDefault()

	for Key, Value in Overrides or {} do
		Options[Key] = Value
	end

	return CreateControl(Section, self.Key, Options)
end

return Setting
