local Operators = wax.shared.CallFilterOperators or require("@src/Utils/CallFilter/Operators")

local RemoteFields = {}

local RemoteClassOptions = {
	{ Value = "RemoteEvent", Text = "RemoteEvent" },
	{ Value = "RemoteFunction", Text = "RemoteFunction" },
	{ Value = "UnreliableRemoteEvent", Text = "UnreliableRemoteEvent" },
	{ Value = "BindableEvent", Text = "BindableEvent" },
	{ Value = "BindableFunction", Text = "BindableFunction" },
}

local Registry = {
	Name = {
		Text = "Name",
		GetValue = function(Remote)
			return Remote.Name
		end,
	},
	ClassName = {
		Text = "Class",
		ValueOptions = RemoteClassOptions,
		GetValue = function(Remote)
			return Remote.ClassName
		end,
	},
	FullName = {
		Text = "Full path",
		GetValue = function(Remote)
			local Success, Result = pcall(Remote.GetFullName, Remote)
			return Success and Result or Remote.Name
		end,
	},
}

local Order = { "Name", "ClassName", "FullName" }
local StringOperators = {
	Equals = true,
	NotEquals = true,
	Contains = true,
	StartsWith = true,
	EndsWith = true,
}

function RemoteFields.Get(Field)
	return Registry[Field]
end

function RemoteFields.GetOptions()
	local Options = {}
	for _, Field in Order do
		table.insert(Options, {
			Value = Field,
			Text = Registry[Field].Text,
		})
	end
	return Options
end

function RemoteFields.GetNames()
	return table.clone(Order)
end

function RemoteFields.GetText(Field): string
	local Definition = Registry[Field]
	return Definition and Definition.Text or tostring(Field)
end

function RemoteFields.GetValueOptions(Field)
	local Definition = Registry[Field]
	return Definition and Definition.ValueOptions and table.clone(Definition.ValueOptions) or nil
end

function RemoteFields.IsValueAllowed(Field, Value): boolean
	local Options = RemoteFields.GetValueOptions(Field)
	if not Options then
		return typeof(Value) == "string"
	end

	for _, Option in Options do
		if Option.Value == Value then
			return true
		end
	end
	return false
end

function RemoteFields.IsOperatorAllowed(Operator, Field): boolean
	if Field == "ClassName" then
		return Operator == "Equals" or Operator == "NotEquals"
	end
	return StringOperators[Operator] == true
end

function RemoteFields.IsConditionValid(Condition): boolean
	return Registry[Condition.Field] ~= nil
		and RemoteFields.IsOperatorAllowed(Condition.Operator, Condition.Field)
		and RemoteFields.IsValueAllowed(Condition.Field, Condition.Value)
end

function RemoteFields.Validate(Conditions)
	return Operators.Validate(Conditions, {
		GetKey = function(Condition)
			return Condition.Field
		end,
		GetLabel = function(Condition)
			return RemoteFields.GetText(Condition.Field)
		end,
		IsConditionValid = RemoteFields.IsConditionValid,
	})
end

function RemoteFields.Matches(Conditions, Remote): boolean
	return Operators.Matches(Conditions, function(Condition)
		local Definition = Registry[Condition.Field]
		return Definition and Definition.GetValue(Remote) or nil
	end)
end

return RemoteFields
