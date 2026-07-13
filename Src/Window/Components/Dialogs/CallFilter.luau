--// Imports \\--
local Types = require("@src/Window/Types")
local Validation = require("@src/Utils/Validation")
local CallFilterSchema = require("@src/Utils/CallFilter/Schema")

--// Types \\--
type CallFilter = Types.CallFilter
type QueryBuilder = Types.QueryBuilder
type QueryBuilderCondition = Types.QueryBuilderCondition
type QueryBuilderValue = Types.QueryBuilderValue
type QueryFilterAction = Types.QueryFilterAction
type QueryFilterDirection = Types.QueryFilterDirection
type QueryRemoteTarget = Types.QueryRemoteTarget
type SupportedRemoteTypes = Types.SupportedRemoteTypes
type Window = Types.Window
type CallFilterDialogOptions = {
	Filter: CallFilter?,
	Target: QueryRemoteTarget?,
	Remote: SupportedRemoteTypes?,
	Direction: QueryFilterDirection?,
	ArgumentCount: number?,
	Conditions: { QueryBuilderCondition }?,
	Action: QueryFilterAction?,
	OnSave: (QueryBuilderValue) -> (),
}

--// Module \\--
local CallFilter = {}

--// Functions \\--
local function ResolveFilterData(Options: CallFilterDialogOptions): (CallFilter?, QueryBuilderValue, number)
	local Existing = Options.Filter
	assert(type(Options.OnSave) == "function", "OnSave is required to create or edit a call filter")

	local Target = Options.Target
	if not Target and Options.Remote then
		Target = {
			Type = "Instance",
			Remote = Options.Remote,
		}
	end

	local Source = Existing or {
		Target = Target,
		Direction = Options.Direction,
		Conditions = Options.Conditions or {},
		Action = Options.Action,
	}

	local IsValid, FilterData, Errors = Validation.ValidateSchema(Source, CallFilterSchema.Filter)
	assert(IsValid, Errors[1] or "Invalid call filter data")

	local ArgumentCount = Options.ArgumentCount or 1
	for _, Condition in FilterData.Conditions do
		if Condition.Subject.Type == "Argument" then
			ArgumentCount = math.max(ArgumentCount, Condition.Subject.Index)
		end
	end

	return Existing, FilterData, math.max(1, ArgumentCount)
end

function CallFilter.Open(Window: Window, Options: CallFilterDialogOptions)
	--// Validation \\--
	local Existing, FilterData, ArgumentCount = ResolveFilterData(Options)

	local ArgumentLabels = {}
	do
		for Index = 1, ArgumentCount do
			ArgumentLabels[Index] = `Argument {Index}`
		end
	end

	local Query: QueryBuilder
	local Dialog = Window.Dialog.new({
		Title = Existing and "Edit Call Filter" or "Create Call Filter",
		Description = "Choose which remote calls Cobalt should match.",
		Icon = "list-filter",
		AutoShow = false,
		Footer = {
			Cancel = {
				Text = "Cancel",
				Action = "Dismiss",
				LayoutOrder = 1,
			},
			SaveChanges = {
				Text = Existing and "Save Changes" or "Create Filter",
				Type = "Primary",
				LayoutOrder = 2,
				Action = function(CurrentDialog: Types.Dialog)
					local IsValid, Errors = Query:Validate()
					if not IsValid then
						wax.shared.Sonner.error(Errors[1] or "This filter contains conflicting conditions.")
						return
					end

					Options.OnSave(Query:GetValue())
					CurrentDialog:Dismiss()
				end,
			},
		},
	})

	Query = Window.QueryBuilder.new(Dialog, {
		Target = FilterData.Target,
		Direction = FilterData.Direction,
		SampleRemote = Options.Remote,
		ArgumentLabels = ArgumentLabels,
		Conditions = FilterData.Conditions,
		Action = FilterData.Action,
		OnValidationChanged = function(IsValid)
			Dialog.Buttons.SaveChanges:SetDisabled(not IsValid)
		end,
	})

	Dialog:Show()
	return Dialog, Query
end

return CallFilter
