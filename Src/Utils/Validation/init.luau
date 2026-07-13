--// Imports \\--
local Schema = wax.shared.ValidationSchema or require(script.Schema)

--// Module \\--
local Validation = {
	Schema = Schema,
}

--// Functions \\--
function Validation.FillTemplate(Data, Template)
	local NewData = {}
	for Key, Value in Template do
		if Data[Key] == nil or typeof(Data[Key]) ~= typeof(Value) then
			NewData[Key] = Value
		else
			NewData[Key] = Data[Key]
		end
	end

	return NewData
end

function Validation.ValidateSchema(Data, DataSchema)
	return Schema.Validate(DataSchema, Data)
end

return Validation
