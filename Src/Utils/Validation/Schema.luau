--// Types \\--
type SchemaKind = "Any" | "Type" | "Literal" | "Enum" | "Array" | "Object" | "Union"
type Refinement = {
	Predicate: (any) -> boolean,
	Message: string,
}
type SchemaNode = {
	Kind: SchemaKind,
	ExpectedType: string?,
	Literal: any?,
	Values: { any }?,
	Item: SchemaNode?,
	Shape: { [any]: SchemaNode }?,
	Schemas: { SchemaNode }?,
	IsOptional: boolean?,
	HasDefault: boolean?,
	DefaultValue: any?,
	Refinements: { Refinement }?,
	Minimum: number?,
	Maximum: number?,
	Integer: boolean?,
}

--// Setup \\--
local Node = {}
Node.__index = Node

local Schema = {}

--// Helpers \\--
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

local function CloneNode(self: SchemaNode): SchemaNode
	local Copy = table.clone(self)
	Copy.Refinements = self.Refinements and table.clone(self.Refinements) or nil
	return setmetatable(Copy, Node) :: any
end

local function NewNode(Kind: SchemaKind, Data: { [any]: any }?): SchemaNode
	local NewSchema = Data and table.clone(Data) or {}
	NewSchema.Kind = Kind
	return setmetatable(NewSchema, Node) :: any
end

local function AddError(Errors: { string }, Path: string, Message: string)
	table.insert(Errors, `{Path}: {Message}`)
end

local function ChildPath(Path: string, Key: any): string
	if type(Key) == "number" then
		return `{Path}[{Key}]`
	end
	return Path == "" and tostring(Key) or `{Path}.{Key}`
end

local function IsSchema(Value): boolean
	return type(Value) == "table" and getmetatable(Value) == Node
end

local function ValidateNode(CurrentSchema: SchemaNode, Value: any, Path: string, Errors: { string }): (boolean, any)
	if Value == nil then
		if CurrentSchema.HasDefault then
			return true, CloneValue(CurrentSchema.DefaultValue)
		end
		if CurrentSchema.IsOptional then
			return true, nil
		end

		AddError(Errors, Path, "is required")
		return false, nil
	end

	local IsValid = true
	local Output = Value
	local Kind = CurrentSchema.Kind

	if Kind == "Type" then
		IsValid = typeof(Value) == CurrentSchema.ExpectedType
		if not IsValid then
			AddError(Errors, Path, `expected {CurrentSchema.ExpectedType}, got {typeof(Value)}`)
		end
	elseif Kind == "Literal" then
		IsValid = Value == CurrentSchema.Literal
		if not IsValid then
			AddError(Errors, Path, `expected {tostring(CurrentSchema.Literal)}`)
		end
	elseif Kind == "Enum" then
		IsValid = false
		for _, Option in CurrentSchema.Values or {} do
			if Value == Option then
				IsValid = true
				break
			end
		end
		if not IsValid then
			local Options = {}
			for _, Option in CurrentSchema.Values or {} do
				table.insert(Options, tostring(Option))
			end
			AddError(Errors, Path, `expected one of {table.concat(Options, ", ")}`)
		end
	elseif Kind == "Array" then
		if type(Value) ~= "table" then
			AddError(Errors, Path, `expected table, got {typeof(Value)}`)
			IsValid = false
		else
			Output = {}
			for Index, Child in Value do
				if type(Index) ~= "number" or Index % 1 ~= 0 or Index < 1 then
					AddError(Errors, Path, "expected an array with positive integer keys")
					IsValid = false
					continue
				end

				local ChildValid, ChildOutput = ValidateNode(CurrentSchema.Item :: SchemaNode, Child, ChildPath(Path, Index), Errors)
				IsValid = ChildValid and IsValid
				if ChildValid then
					Output[Index] = ChildOutput
				end
			end
		end
	elseif Kind == "Object" then
		if type(Value) ~= "table" then
			AddError(Errors, Path, `expected table, got {typeof(Value)}`)
			IsValid = false
		else
			Output = {}
			for Key, ChildSchema in CurrentSchema.Shape or {} do
				local ChildValid, ChildOutput = ValidateNode(ChildSchema, Value[Key], ChildPath(Path, Key), Errors)
				IsValid = ChildValid and IsValid
				if ChildOutput ~= nil then
					Output[Key] = ChildOutput
				end
			end
		end
	elseif Kind == "Union" then
		IsValid = false
		for _, ChildSchema in CurrentSchema.Schemas or {} do
			local ChildErrors = {}
			local ChildValid, ChildOutput = ValidateNode(ChildSchema, Value, Path, ChildErrors)
			if ChildValid then
				IsValid = true
				Output = ChildOutput
				break
			end
		end
		if not IsValid then
			AddError(Errors, Path, "did not match any allowed schema")
		end
	end

	if not IsValid then
		return false, nil
	end

	if type(Output) == "number" then
		if CurrentSchema.Integer and Output % 1 ~= 0 then
			AddError(Errors, Path, "expected an integer")
			IsValid = false
		end
		if CurrentSchema.Minimum ~= nil and Output < CurrentSchema.Minimum then
			AddError(Errors, Path, `must be at least {CurrentSchema.Minimum}`)
			IsValid = false
		end
		if CurrentSchema.Maximum ~= nil and Output > CurrentSchema.Maximum then
			AddError(Errors, Path, `must be at most {CurrentSchema.Maximum}`)
			IsValid = false
		end
	end

	for _, Refinement in CurrentSchema.Refinements or {} do
		local Success, Result = pcall(Refinement.Predicate, Output)
		if not Success or not Result then
			AddError(Errors, Path, Refinement.Message)
			IsValid = false
		end
	end

	if not IsValid then
		return false, nil
	end
	return true, Output
end

--// Modifiers \\--
function Node:optional(): SchemaNode
	local Copy = CloneNode(self)
	Copy.IsOptional = true
	return Copy
end

function Node:default(Value: any): SchemaNode
	local Copy = CloneNode(self)
	Copy.HasDefault = true
	Copy.DefaultValue = Value
	return Copy
end

function Node:refine(Predicate: (any) -> boolean, Message: string?): SchemaNode
	assert(type(Predicate) == "function", "Schema refinement must be a function")
	local Copy = CloneNode(self)
	Copy.Refinements = Copy.Refinements or {}
	table.insert(Copy.Refinements, {
		Predicate = Predicate,
		Message = Message or "failed refinement",
	})
	return Copy
end

function Node:integer(): SchemaNode
	assert(self.Kind == "Type" and self.ExpectedType == "number", "integer() can only be used on number schemas")
	local Copy = CloneNode(self)
	Copy.Integer = true
	return Copy
end

function Node:min(Value: number): SchemaNode
	assert(self.Kind == "Type" and self.ExpectedType == "number", "min() can only be used on number schemas")
	local Copy = CloneNode(self)
	Copy.Minimum = Value
	return Copy
end

function Node:max(Value: number): SchemaNode
	assert(self.Kind == "Type" and self.ExpectedType == "number", "max() can only be used on number schemas")
	local Copy = CloneNode(self)
	Copy.Maximum = Value
	return Copy
end

--// Constructors \\--
function Schema.any(): SchemaNode
	return NewNode("Any")
end

function Schema.type(ExpectedType: string): SchemaNode
	assert(type(ExpectedType) == "string", "Schema type must be a string")
	return NewNode("Type", { ExpectedType = ExpectedType })
end

function Schema.string(): SchemaNode
	return Schema.type("string")
end

function Schema.number(): SchemaNode
	return Schema.type("number")
end

function Schema.boolean(): SchemaNode
	return Schema.type("boolean")
end

function Schema.table(): SchemaNode
	return Schema.type("table")
end

function Schema.callback(): SchemaNode
	return Schema.type("function")
end

function Schema.instance(ClassName: string?): SchemaNode
	local InstanceSchema = Schema.type("Instance")
	if ClassName then
		return InstanceSchema:refine(function(Value)
			return Value:IsA(ClassName)
		end, `expected an Instance that is a {ClassName}`)
	end
	return InstanceSchema
end

function Schema.literal(Value: any): SchemaNode
	assert(Value ~= nil, "Schema literal cannot be nil; use optional() instead")
	return NewNode("Literal", { Literal = Value })
end

function Schema.enum(Values: { any }): SchemaNode
	assert(type(Values) == "table" and #Values > 0, "Schema enum requires at least one value")
	return NewNode("Enum", { Values = table.clone(Values) })
end

function Schema.array(ItemSchema: SchemaNode): SchemaNode
	assert(IsSchema(ItemSchema), "Schema array requires an item schema")
	return NewNode("Array", { Item = ItemSchema })
end

function Schema.object(Shape: { [any]: SchemaNode }): SchemaNode
	assert(type(Shape) == "table", "Schema object requires a shape")
	for Key, ChildSchema in Shape do
		assert(IsSchema(ChildSchema), `Schema object field {tostring(Key)} must be a schema`)
	end
	return NewNode("Object", { Shape = table.clone(Shape) })
end

function Schema.union(Schemas: { SchemaNode }): SchemaNode
	assert(type(Schemas) == "table" and #Schemas > 0, "Schema union requires at least one schema")
	for _, ChildSchema in Schemas do
		assert(IsSchema(ChildSchema), "Schema union entries must be schemas")
	end
	return NewNode("Union", { Schemas = table.clone(Schemas) })
end

--// Validation \\--
function Schema.Validate(DataSchema: SchemaNode, Value: any): (boolean, any, { string })
	assert(IsSchema(DataSchema), "ValidateSchema requires a schema created by Validation.Schema")
	local Errors = {}
	local IsValid, Output = ValidateNode(DataSchema, Value, "Value", Errors)
	return IsValid, Output, Errors
end

return Schema
