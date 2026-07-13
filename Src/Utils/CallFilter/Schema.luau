--// Imports \\--
local Validation = wax.shared.Validation or require("@src/Utils/Validation")
local Operators = wax.shared.CallFilterOperators or require("@src/Utils/CallFilter/Operators")
local RemoteFields = wax.shared.CallFilterRemoteFields or require("@src/Utils/CallFilter/RemoteFields")

local Schema = Validation.Schema

--// Helpers \\--
local function GetOperatorNames()
	local Names = {}
	for _, Option in Operators.GetOptions() do
		table.insert(Names, Option.Value)
	end
	return Names
end

local function IsConditionValueValid(Condition): boolean
	return Operators.IsConditionValid({ Condition }, Condition)
end

local function HasNoConditionConflicts(Conditions): boolean
	return Operators.Validate(Conditions)
end

--// Schemas \\--
local Remote = Schema.instance():refine(function(Value)
	return RemoteFields.IsValueAllowed("ClassName", Value.ClassName)
end, "must be a supported remote")

local Subject = Schema.object({
	Type = Schema.enum({ "Argument", "ArgumentCount" }),
	Index = Schema.number():integer():min(1):optional(),
}):refine(function(Value)
	return Value.Type == "ArgumentCount" and Value.Index == nil or Value.Type == "Argument" and Value.Index ~= nil
end, "must provide an index only for argument subjects")

local Condition = Schema.object({
	Subject = Subject,
	Operator = Schema.enum(GetOperatorNames()),
	Value = Schema.any():optional(),
	Join = Schema.enum({ "And", "Or" }):optional(),
}):refine(IsConditionValueValid, "has a value that is incompatible with its operator")

local ConditionArray = Schema.array(Condition):refine(HasNoConditionConflicts, "contains conflicting conditions")
local Conditions = ConditionArray:default({})

local RemoteCondition = Schema.object({
	Field = Schema.enum(RemoteFields.GetNames()),
	Operator = Schema.enum(GetOperatorNames()),
	Value = Schema.string(),
	Join = Schema.enum({ "And", "Or" }):optional(),
}):refine(RemoteFields.IsConditionValid, "has an operator or value that is incompatible with its field")

local RemoteConditions = Schema.array(RemoteCondition):refine(function(Value)
	return #Value > 0 and RemoteFields.Validate(Value)
end, "must contain at least one non-conflicting remote condition")

local Target = Schema.union({
	Schema.object({
		Type = Schema.literal("Instance"),
		Remote = Remote,
	}),
	Schema.object({
		Type = Schema.literal("Query"),
		Conditions = RemoteConditions,
	}),
})

local Filter = Schema.object({
	Id = Schema.string():optional(),
	Enabled = Schema.boolean():default(true),
	Target = Target,
	Direction = Schema.enum({ "Outgoing", "Incoming", "Any" }),
	Conditions = Conditions,
	Action = Schema.enum({ "Ignore", "Block", "Highlight" }):default("Ignore"),
})

local Update = Schema.object({
	Enabled = Schema.boolean():optional(),
	Target = Target:optional(),
	Direction = Schema.enum({ "Outgoing", "Incoming", "Any" }):optional(),
	Conditions = ConditionArray:optional(),
	Action = Schema.enum({ "Ignore", "Block", "Highlight" }):optional(),
})

return {
	Remote = Remote,
	Subject = Subject,
	Condition = Condition,
	Conditions = Conditions,
	RemoteCondition = RemoteCondition,
	RemoteConditions = RemoteConditions,
	Target = Target,
	Filter = Filter,
	Update = Update,
}
