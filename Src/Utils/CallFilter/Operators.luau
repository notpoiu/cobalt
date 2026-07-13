local Operators = {}

local Registry = {
	Equals = {
		Text = "==",
		AllowedTypes = { boolean = true, number = true, string = true },
		Evaluate = function(Value, Expected)
			return Value == Expected
		end,
	},
	NotEquals = {
		Text = "~=",
		AllowedTypes = { boolean = true, number = true, string = true },
		Evaluate = function(Value, Expected)
			return Value ~= Expected
		end,
	},
	LessThan = {
		Text = "<",
		NumericComparison = true,
		AllowedTypes = { number = true },
		Evaluate = function(Value, Expected)
			return typeof(Value) == "number" and typeof(Expected) == "number" and Value < Expected
		end,
	},
	LessThanOrEqual = {
		Text = "<=",
		NumericComparison = true,
		AllowedTypes = { number = true },
		Evaluate = function(Value, Expected)
			return typeof(Value) == "number" and typeof(Expected) == "number" and Value <= Expected
		end,
	},
	GreaterThan = {
		Text = ">",
		NumericComparison = true,
		AllowedTypes = { number = true },
		Evaluate = function(Value, Expected)
			return typeof(Value) == "number" and typeof(Expected) == "number" and Value > Expected
		end,
	},
	GreaterThanOrEqual = {
		Text = ">=",
		NumericComparison = true,
		AllowedTypes = { number = true },
		Evaluate = function(Value, Expected)
			return typeof(Value) == "number" and typeof(Expected) == "number" and Value >= Expected
		end,
	},
	Contains = {
		Text = "Contains",
		SummaryText = "contains",
		AllowedTypes = { string = true },
		Evaluate = function(Value, Expected)
			return typeof(Value) == "string"
				and typeof(Expected) == "string"
				and string.find(Value, Expected, 1, true) ~= nil
		end,
	},
	StartsWith = {
		Text = "Starts with",
		SummaryText = "starts with",
		AllowedTypes = { string = true },
		Evaluate = function(Value, Expected)
			return typeof(Value) == "string"
				and typeof(Expected) == "string"
				and string.sub(Value, 1, #Expected) == Expected
		end,
	},
	EndsWith = {
		Text = "Ends with",
		SummaryText = "ends with",
		AllowedTypes = { string = true },
		Evaluate = function(Value, Expected)
			return typeof(Value) == "string"
				and typeof(Expected) == "string"
				and (Expected == "" or string.sub(Value, -#Expected) == Expected)
		end,
	},
	TypeIs = {
		Text = "Type",
		SummaryText = "type",
		Evaluate = function(Value, Expected)
			return typeof(Value) == tostring(Expected)
		end,
	},
}

local Order = {
	"Equals",
	"NotEquals",
	"LessThan",
	"LessThanOrEqual",
	"GreaterThan",
	"GreaterThanOrEqual",
	"Contains",
	"StartsWith",
	"EndsWith",
	"TypeIs",
}

local TypeNames = {
	"nil",
	"boolean",
	"number",
	"string",
	"table",
	"function",
	"thread",
	"userdata",
	"Instance",
	"EnumItem",
	"RBXScriptSignal",
	"RBXScriptConnection",
	"Vector2",
	"Vector3",
	"CFrame",
	"Color3",
	"BrickColor",
	"UDim",
	"UDim2",
	"Rect",
	"Ray",
	"buffer",
}

local TypeNameLookup = {}
for _, TypeName in TypeNames do
	TypeNameLookup[TypeName] = true
end

local function GetSubjectKey(Subject): string
	return if Subject.Type == "ArgumentCount" then "ArgumentCount" else `Argument:{Subject.Index}`
end

local function FormatSubject(Subject): string
	return if Subject.Type == "ArgumentCount" then "#Arg" else `Arg[{Subject.Index}]`
end

local function GetAndGroupRange(Conditions, Condition)
	local ConditionIndex = table.find(Conditions, Condition)
	if not ConditionIndex then
		return 1, #Conditions
	end

	local FirstIndex = 1
	for Index = ConditionIndex, 2, -1 do
		if Conditions[Index].Join == "Or" then
			FirstIndex = Index
			break
		end
	end

	local LastIndex = #Conditions
	for Index = ConditionIndex + 1, #Conditions do
		if Conditions[Index].Join == "Or" then
			LastIndex = Index - 1
			break
		end
	end

	return FirstIndex, LastIndex
end

local function FormatValue(Value): string
	return if typeof(Value) == "string" then `"{Value}"` else tostring(Value)
end

function Operators.Get(Operator)
	return Registry[Operator]
end

function Operators.GetOptions()
	local Options = {}
	for _, Operator in Order do
		local Definition = Registry[Operator]
		table.insert(Options, {
			Value = Operator,
			Text = Definition.Text,
		})
	end
	return Options
end

function Operators.GetTypeNames()
	return table.clone(TypeNames)
end

function Operators.IsTypeName(Value): boolean
	return type(Value) == "string" and TypeNameLookup[Value] == true
end

function Operators.GetText(Operator, Summary: boolean?): string
	local Definition = Registry[Operator]
	if not Definition then
		return tostring(Operator)
	end
	return Summary and Definition.SummaryText or Definition.Text
end

function Operators.FormatValue(Value): string
	return FormatValue(Value)
end

function Operators.IsNumericComparison(Operator): boolean
	local Definition = Registry[Operator]
	return Definition ~= nil and Definition.NumericComparison == true
end

function Operators.Evaluate(Operator, Value, Expected): boolean
	local Definition = Registry[Operator]
	return Definition ~= nil and Definition.Evaluate(Value, Expected) or false
end

function Operators.ResolveSubject(Subject, Arguments)
	if Subject.Type == "ArgumentCount" then
		return Arguments.n or #Arguments
	end

	return Arguments[Subject.Index]
end

function Operators.MatchesCondition(Condition, Arguments): boolean
	return Operators.Evaluate(Condition.Operator, Operators.ResolveSubject(Condition.Subject, Arguments), Condition.Value)
end

function Operators.Matches(Conditions, ResolveValue): boolean
	if #Conditions == 0 then
		return true
	end

	local AnyGroupMatches = false
	local CurrentGroupMatches = Operators.Evaluate(
		Conditions[1].Operator,
		ResolveValue(Conditions[1]),
		Conditions[1].Value
	)
	for Index = 2, #Conditions do
		local Condition = Conditions[Index]
		local Matches = Operators.Evaluate(Condition.Operator, ResolveValue(Condition), Condition.Value)
		if Condition.Join == "Or" then
			AnyGroupMatches = AnyGroupMatches or CurrentGroupMatches
			CurrentGroupMatches = Matches
		else
			CurrentGroupMatches = CurrentGroupMatches and Matches
		end
	end

	return AnyGroupMatches or CurrentGroupMatches
end

function Operators.MatchesConditions(Conditions, Arguments): boolean
	return Operators.Matches(Conditions, function(Condition)
		return Operators.ResolveSubject(Condition.Subject, Arguments)
	end)
end

function Operators.GetConditionType(Conditions, Condition): string?
	if Condition.Subject.Type == "ArgumentCount" then
		return "number"
	end

	local SubjectKey = GetSubjectKey(Condition.Subject)
	local FirstIndex, LastIndex = GetAndGroupRange(Conditions, Condition)
	for Index = FirstIndex, LastIndex do
		local OtherCondition = Conditions[Index]
		if
			OtherCondition ~= Condition
			and GetSubjectKey(OtherCondition.Subject) == SubjectKey
			and OtherCondition.Operator == "TypeIs"
		then
			return tostring(OtherCondition.Value)
		end
	end

	if Condition.Operator == "TypeIs" then
		return tostring(Condition.Value)
	end

	local ValueType = typeof(Condition.Value)
	if ValueType == "boolean" or ValueType == "number" then
		return ValueType
	end

	for Index = FirstIndex, LastIndex do
		local OtherCondition = Conditions[Index]
		local OtherValueType = typeof(OtherCondition.Value)
		if
			OtherCondition ~= Condition
			and GetSubjectKey(OtherCondition.Subject) == SubjectKey
			and (OtherValueType == "boolean" or OtherValueType == "number")
		then
			return OtherValueType
		end
	end

	return if ValueType == "string" then "string" else nil
end

function Operators.IsAllowed(Conditions, Condition, Operator): boolean
	if Operator == "TypeIs" then
		return Condition.Subject.Type == "Argument"
	end

	local Definition = Registry[Operator]
	if not Definition then
		return false
	end

	local ConditionType = Operators.GetConditionType(Conditions, Condition)
	return ConditionType == nil or Definition.AllowedTypes[ConditionType] == true
end

function Operators.IsConditionValid(Conditions, Condition): boolean
	local Definition = Registry[Condition.Operator]
	if not Definition then
		return false
	end

	if Condition.Operator == "TypeIs" then
		return Condition.Subject.Type == "Argument" and Operators.IsTypeName(Condition.Value)
	end

	local ConditionType = Operators.GetConditionType(Conditions, Condition)
	return ConditionType ~= nil
		and Definition.AllowedTypes ~= nil
		and Definition.AllowedTypes[ConditionType] == true
		and typeof(Condition.Value) == ConditionType
end

local function NumericConditionsConflict(First, Second): boolean
	if typeof(First.Value) ~= "number" or typeof(Second.Value) ~= "number" then
		return false
	end

	if First.Operator == "Equals" and Operators.IsNumericComparison(Second.Operator) then
		return not Operators.Evaluate(Second.Operator, First.Value, Second.Value)
	elseif Second.Operator == "Equals" and Operators.IsNumericComparison(First.Operator) then
		return not Operators.Evaluate(First.Operator, Second.Value, First.Value)
	elseif not Operators.IsNumericComparison(First.Operator) or not Operators.IsNumericComparison(Second.Operator) then
		return false
	end

	local FirstIsLower = First.Operator == "GreaterThan" or First.Operator == "GreaterThanOrEqual"
	local SecondIsLower = Second.Operator == "GreaterThan" or Second.Operator == "GreaterThanOrEqual"
	if FirstIsLower == SecondIsLower then
		return false
	end

	local Lower = if FirstIsLower then First else Second
	local Upper = if FirstIsLower then Second else First
	return Lower.Value > Upper.Value
		or Lower.Value == Upper.Value and (Lower.Operator == "GreaterThan" or Upper.Operator == "LessThan")
end

local function AreInSameAndBranch(Conditions, FirstIndex: number, SecondIndex: number): boolean
	for Index = FirstIndex + 1, SecondIndex do
		if Conditions[Index].Join == "Or" then
			return false
		end
	end
	return true
end

function Operators.Validate(Conditions, Adapter)
	local Errors = {}
	local Conflicts = {}
	local GetKey = Adapter and Adapter.GetKey or function(Condition)
		return GetSubjectKey(Condition.Subject)
	end
	local GetLabel = Adapter and Adapter.GetLabel or function(Condition)
		return FormatSubject(Condition.Subject)
	end
	local IsConditionValid = Adapter and Adapter.IsConditionValid or function(Condition)
		return Operators.IsConditionValid(Conditions, Condition)
	end

	local function AddConflict(FirstIndex: number, SecondIndex: number, Message: string)
		Conflicts[FirstIndex] = true
		Conflicts[SecondIndex] = true
		table.insert(Errors, Message)
	end

	for Index, Condition in Conditions do
		if not IsConditionValid(Condition) then
			Conflicts[Index] = true
			table.insert(
				Errors,
				`{GetLabel(Condition)} has a value that is incompatible with {Operators.GetText(Condition.Operator, true)}.`
			)
		end
	end

	for FirstIndex = 1, #Conditions do
		local First = Conditions[FirstIndex]
		for SecondIndex = FirstIndex + 1, #Conditions do
			local Second = Conditions[SecondIndex]
			if Conflicts[FirstIndex] or Conflicts[SecondIndex] then
				continue
			end
			if GetKey(First) ~= GetKey(Second) or not AreInSameAndBranch(Conditions, FirstIndex, SecondIndex) then
				continue
			end
			local SubjectText = GetLabel(First)

			if First.Operator == "Equals" and Second.Operator == "Equals" and First.Value ~= Second.Value then
				AddConflict(FirstIndex, SecondIndex, `{SubjectText} cannot equal both {FormatValue(First.Value)} and {FormatValue(Second.Value)}.`)
			elseif
				First.Operator == "Equals" and Second.Operator == "NotEquals" and First.Value == Second.Value
				or First.Operator == "NotEquals" and Second.Operator == "Equals" and First.Value == Second.Value
			then
				AddConflict(FirstIndex, SecondIndex, `{SubjectText} cannot both equal and not equal {FormatValue(First.Value)}.`)
			elseif First.Operator == "TypeIs" and Second.Operator == "TypeIs" and First.Value ~= Second.Value then
				AddConflict(FirstIndex, SecondIndex, `{SubjectText} cannot have both type {First.Value} and {Second.Value}.`)
			elseif NumericConditionsConflict(First, Second) then
				AddConflict(FirstIndex, SecondIndex, `{SubjectText} cannot satisfy both numeric comparisons.`)
			else
				local TypeCondition
				local OtherCondition
				if First.Operator == "TypeIs" then
					TypeCondition, OtherCondition = First, Second
				elseif Second.Operator == "TypeIs" then
					TypeCondition, OtherCondition = Second, First
				end

				if TypeCondition and OtherCondition and OtherCondition.Operator ~= "TypeIs" then
					local Definition = Registry[OtherCondition.Operator]
					local TypeName = tostring(TypeCondition.Value)
					if Definition and Definition.AllowedTypes and not Definition.AllowedTypes[TypeName] then
						AddConflict(FirstIndex, SecondIndex, `{SubjectText} has type {TypeName}, so it cannot use {Definition.SummaryText or Definition.Text}.`)
					end
				end
			end
		end
	end

	return #Errors == 0, Errors, Conflicts
end

return Operators
