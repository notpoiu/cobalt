local Operators = wax.shared.CallFilterOperators or require("@src/Utils/CallFilter/Operators")
local InstanceSerializer = wax.shared.InstanceSerializer or require("@src/Utils/CodeGen/Serializer/Instance")
local Validation = wax.shared.Validation or require("@src/Utils/Validation")
local CallFilterSchema = wax.shared.CallFilterSchema or require("@src/Utils/CallFilter/Schema")
local RemoteFields = wax.shared.CallFilterRemoteFields or require("@src/Utils/CallFilter/RemoteFields")

local CallFilters = {
	Items = {},
	ById = {},
	Listeners = {},
}

local ActionPriorities = {
	Highlight = 1,
	Ignore = 2,
	Block = 3,
}

local function Validate(Data, DataSchema, Context: string)
	local IsValid, Result, Errors = Validation.ValidateSchema(Data, DataSchema)
	assert(IsValid, `{Context}: {Errors[1] or "validation failed"}`)
	return Result
end

local function CopyFilter(Filter)
	local Copy = table.clone(Filter)
	Copy.Conditions = {}

	for _, Condition in Filter.Conditions or {} do
		local ConditionCopy = table.clone(Condition)
		ConditionCopy.Subject = table.clone(Condition.Subject)
		table.insert(Copy.Conditions, ConditionCopy)
	end

	Copy.Target = table.clone(Filter.Target)
	if Filter.Target.Type == "Query" then
		Copy.Target.Conditions = {}
		for _, Condition in Filter.Target.Conditions do
			table.insert(Copy.Target.Conditions, table.clone(Condition))
		end
	end

	Copy.Enabled = Filter.Enabled ~= false
	return Copy
end

local function EmitChanged()
	local Snapshot = CallFilters:GetAll()
	for Listener in CallFilters.Listeners do
		if task then
			task.spawn(Listener, Snapshot)
		else
			Listener(Snapshot)
		end
	end
end

function CallFilters:GetAll()
	local Filters = {}
	for _, Filter in self.Items do
		table.insert(Filters, CopyFilter(Filter))
	end
	return Filters
end

function CallFilters:Get(Id: string)
	local Filter = self.ById[Id]
	return Filter and CopyFilter(Filter) or nil
end

function CallFilters:Add(Filter)
	local Copy = Validate(Filter, CallFilterSchema.Filter, "Invalid call filter")
	Copy.Id = Copy.Id or wax.shared.HttpService:GenerateGUID(false)
	assert(not self.ById[Copy.Id], `A call filter with id {Copy.Id} already exists`)

	table.insert(self.Items, Copy)
	self.ById[Copy.Id] = Copy
	EmitChanged()
	return CopyFilter(Copy)
end

function CallFilters:Update(Id: string, Changes)
	local Filter = self.ById[Id]
	if not Filter then
		return nil
	end

	local ValidChanges = Validate(Changes, CallFilterSchema.Update, "Invalid call filter update")
	local Updated = CopyFilter(Filter)
	for Key, Value in ValidChanges do
		Updated[Key] = Value
	end
	Updated = Validate(Updated, CallFilterSchema.Filter, "Invalid updated call filter")

	local Index = table.find(self.Items, Filter)
	if Index then
		self.Items[Index] = Updated
	end
	self.ById[Id] = Updated

	EmitChanged()
	return CopyFilter(Updated)
end

function CallFilters:SetEnabled(Id: string, Enabled: boolean)
	return self:Update(Id, { Enabled = Enabled })
end

function CallFilters:Remove(Id: string): boolean
	local Filter = self.ById[Id]
	if not Filter then
		return false
	end

	self.ById[Id] = nil
	local Index = table.find(self.Items, Filter)
	if Index then
		table.remove(self.Items, Index)
	end
	EmitChanged()
	return true
end

function CallFilters:ReplaceAll(Filters, Silent: boolean?)
	local Validated = Validate(Filters or {}, Validation.Schema.array(CallFilterSchema.Filter), "Invalid call filters")
	local SeenIds = {}
	for _, Filter in Validated do
		Filter.Id = Filter.Id or wax.shared.HttpService:GenerateGUID(false)
		assert(not SeenIds[Filter.Id], `A call filter with id {Filter.Id} already exists`)
		SeenIds[Filter.Id] = true
	end

	table.clear(self.Items)
	table.clear(self.ById)
	for _, Filter in Validated do
		table.insert(self.Items, Filter)
		self.ById[Filter.Id] = Filter
	end

	if not Silent then
		EmitChanged()
	end
end

function CallFilters:Subscribe(Listener)
	self.Listeners[Listener] = true
	Listener(self:GetAll())

	local Subscription = {}
	function Subscription:Disconnect()
		CallFilters.Listeners[Listener] = nil
	end
	return Subscription
end

function CallFilters:Match(Remote: Instance, Direction: string, Arguments)
	local WinningAction
	local WinningFilter
	local WinningPriority = 0

	for _, Filter in self.Items do
		local TargetMatches = if Filter.Target.Type == "Instance"
			then InstanceSerializer.IsEqualToInstance(Filter.Target.Remote, Remote)
			else RemoteFields.Matches(Filter.Target.Conditions, Remote)
		if
			Filter.Enabled
			and (Filter.Direction == "Any" or Filter.Direction == Direction)
			and TargetMatches
			and Operators.MatchesConditions(Filter.Conditions, Arguments)
		then
			local Priority = ActionPriorities[Filter.Action] or 0
			if Priority > WinningPriority then
				WinningAction = Filter.Action
				WinningFilter = Filter
				WinningPriority = Priority
			end
		end
	end

	return WinningAction, WinningFilter and CopyFilter(WinningFilter) or nil
end

function CallFilters:Resolve(Remote: Instance, Direction: string, Info)
	local Action, Filter = self:Match(Remote, Direction, Info.Arguments or {})
	if Action == "Highlight" then
		Info.Highlighted = true
		Info.CallFilterId = Filter.Id
	elseif Action then
		Info.CallFilterId = Filter.Id
	end
	return Action, Filter
end

return CallFilters
