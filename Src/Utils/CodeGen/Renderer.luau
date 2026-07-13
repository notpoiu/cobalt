local Renderer = {}

local Types = require(script.Parent.Types)

local Formatter = require(script.Parent.Formatter)

local Templates = {}
do
	Templates.Call = require(script.Parent.Templates.Call)
	Templates.Hook = require(script.Parent.Templates.Hook)
	Templates.Actor = require(script.Parent.Templates.Actor)
end

local ReferencingTemplate = require(script.Parent.Templates.Referencing)
local GetNilCode = ReferencingTemplate.GetNilCode

local InstanceSerializer = require(script.Parent.Serializer.Instance)
local ResolveEventPath
do
	--#region @export "FindEventReferenceInTable"
	--[[
		Finds an event reference in a table, used to search upvalues which are tables.

		@param Table: The table to search.
		@param Instance: The instance to search for.
		@param Visited: The visited table.
		@return The event reference.
	]]
	local function FindEventReferenceInTable(
		Table: { [any]: any },
		Instance: Instance,
		Visited: { [any]: boolean }?
	): { any }?
		local Seen = Visited or {}
		if Seen[Table] then
			return nil
		end

		Seen[Table] = true

		for Key, Value in next, Table do
			if
				typeof(Value) == "Instance"
				and InstanceSerializer.IsEqualToInstance(Value, Instance)
				and Formatter.FormatLuaLiteral(Key)
			then
				return { Key }
			end

			if type(Value) == "table" and Formatter.FormatLuaLiteral(Key) then
				local ChildPath = FindEventReferenceInTable(Value, Instance, Seen)
				if ChildPath then
					table.insert(ChildPath, 1, Key)
					return ChildPath
				end
			end
		end

		return nil
	end
	--#endregion

	--#region @export "ResolveEventReference"
	--[[
		Resolves an event reference from a call info.

		@param CallInfo: The call info.
		@return The event reference.
	]]
	local function ResolveEventReference(
		CallInfo: Types.CallInfo
	): { Hash: string, Index: number, ExcludeExecutor: boolean?, Path: { any }? }?
		if wax.shared.SaveManager:GetState("EventReferenceStrategy") ~= "Upvalue Lookup" then
			return nil
		end

		if (CallInfo.IsActor == true or CallInfo.Actor ~= nil) and typeof(CallInfo.Function) == "table" then
			-- local FunctionHash = CallInfo.Function.FunctionHash
			-- local Upvalues = CallInfo.Function.Upvalues

			-- if FunctionHash and type(Upvalues) == "table" then
			-- 	local UpvaluePath = FindEventReferenceInTable(Upvalues, CallInfo.Instance)
			-- 	if not UpvaluePath then
			-- 		return nil
			-- 	end

			-- 	local UpvalueIndex = table.remove(UpvaluePath, 1)
			-- 	return {
			-- 		Hash = FunctionHash,
			-- 		Index = UpvalueIndex,
			-- 		Path = UpvaluePath,
			-- 		ExcludeExecutor = true,
			-- 	}
			-- end

			local RequestId = tick()
			local Thread = coroutine.running()
			local Response = nil
			wax.shared.Communicator:Fire("ResolveEventReference", getfunctionhash(CallInfo.Function), CallInfo.Instance, CallInfo.IsExecutor ~= true, RequestId)

			local ResponseConnection
			ResponseConnection = wax.shared.Communicator.Event:Connect(function(Type, ...)
				if Type ~= "ResolveEventReferenceResponse" then
					return
				end

				local ResolvedRequestId, ResolvedResponse = ...
				if ResolvedRequestId == RequestId then
					ResponseConnection:Disconnect()
					Response = ResolvedResponse
					coroutine.resume(Thread)
				end
			end)

			coroutine.yield()
			if not Response then
				return nil
			end

			return {
				Hash = Response.Hash,
				Index = Response.Index,
				Path = Response.Path,
				ExcludeExecutor = CallInfo.IsExecutor ~= true,
			}
		end

		if
			typeof(CallInfo.Function) ~= "function"
			or not islclosure
			or not islclosure(CallInfo.Function)
			or not getfunctionhash
		then
			return nil
		end

		local UpvaluePath = FindEventReferenceInTable(debug.getupvalues(CallInfo.Function), CallInfo.Instance)
		if not UpvaluePath then
			return nil
		end

		local UpvalueIndex = table.remove(UpvaluePath, 1)
		return {
			Hash = getfunctionhash(CallInfo.Function),
			Index = UpvalueIndex,
			Path = UpvaluePath,
			ExcludeExecutor = CallInfo.IsExecutor ~= true,
		}
	end
	--#endregion

	ResolveEventPath = function(CallInfo: Types.CallInfo): (string, string?)
		return InstanceSerializer.Serialize(CallInfo.Instance, {
			VariableName = "Event",
			DisableNilParentHandler = false,
			OmitNilFunctionGetterCodeGeneration = true,
			EventReference = ResolveEventReference(CallInfo),
		})
	end
end

--[[
    Renders a code string with the given arguments.

    @param Code: The code string to render.
    @param Args: The arguments to render the code with.
    @return The rendered code string.
]]
local function RenderCode(Code: string, Args: { [string]: any })
	local RenderedCode = Code:gsub("{{%s*([%w_]+)%s*}}", function(Key)
		local Value = Args[Key]
		assert(Value ~= nil, `Missing CodeGen template variable: {Key}`)
		return tostring(Value)
	end)
	return RenderedCode
end

--[[
    Renders a code string with the given arguments.

    @param Code: The code string to render.
    @param Args: The arguments to render the code with.
    @return The rendered code string.
]]
function Renderer.Render(Data: {
	Code: string,
	Args: { [string]: any },

	CallInfo: Types.CallInfo?,
})
	local RenderedCode = RenderCode(Data.Code, Data.Args)

	if Data.CallInfo and Data.CallInfo.IsActor then
		local TemplateToUse = Templates.Actor.TargetedWrapper
		if not Data.CallInfo.Actor then
			TemplateToUse = Templates.Actor.GenericWrapper
		end

		local Args = {
			Prelude = "-- Event originated from an Actor Environment",
			Actor = "",

			IndentedCode = Formatter.IndentCode(RenderedCode, TemplateToUse.IndentLevel),
		}

		if Data.CallInfo.Actor then
			local Actor, ActorPrelude = InstanceSerializer.Serialize(Data.CallInfo.Actor, {
				OmitNilFunctionGetterCodeGeneration = true,
				DisableNilParentHandler = false,
			})

			Args.Prelude = ActorPrelude and `{Args.Prelude}\n{ActorPrelude}\n\n` or Args.Prelude
			Args.Actor = Actor or ""
		end

		RenderedCode = RenderCode(TemplateToUse.Text, Args)
	end

	return RenderedCode
end

--[[
	Resolves the template string based on the scenario.

	@param Context: The context to resolve the template for.
	@param Scenario: The scenario to resolve the template for.
	@return The resolved template string.
]]
function Renderer.ResolveTemplate(Context: "Call" | "Hook", Scenario: Types.Scenario)
	local TemplateContext = Templates[Context]

	if Scenario.Type == "Outgoing" then
		return TemplateContext.Outgoing
	end

	local Template = TemplateContext.Incoming[Scenario.Shape]
	if type(Template) == "table" then
		return Template[Scenario.InvokeKind] or Template.Default
	end

	return Template
end

--[[
	Derives the variables for a given scenario and call info.

	@param Scenario: The scenario to derive the variables for.
	@param CallInfo: The call info to derive the variables for.
	@return The derived variables.
]]
function Renderer.DeriveVariables(
	Context: "Call" | "Hook",
	Data: {
		Scenario: Types.Scenario,
		CallInfo: Types.CallInfo,
	}
): { [string]: any }
	local Preludes = {}
	local PreludeLookup = {}

	local function AddPrelude(Code: string?)
		if not Code or PreludeLookup[Code] then
			return
		end

		table.insert(Preludes, Code)
		PreludeLookup[Code] = true
	end

	local EventPath, EventPrelude = ResolveEventPath(Data.CallInfo)
	AddPrelude(EventPrelude)

	local Variables = {
		Prelude = "",
		Path = EventPath,
		Method = Data.Scenario.Method,
	}

	if Context == "Call" then
		local SerializedArgs, ArgsRequiresNilHandler = wax.shared.LuaEncode(Data.Scenario.Arguments, {
			Prettify = true,
			InsertCycles = true,
			IsArray = true,
		})

		local ExpectedResult, ExpectedResultRequiresNilHandler = nil, false
		local HasError = Data.Scenario.Error ~= nil and Data.CallInfo.Blocked ~= true
		if HasError then
			Variables.CapturePrefix = "local Success, ResultOrError = pcall(function()\n\treturn table.pack("
			Variables.CaptureSuffix = ")\nend)"
		else
			Variables.CapturePrefix = "local Result = table.pack("
			Variables.CaptureSuffix = ")"
		end

		--// Handle Invoke Result \\--
		local HasInvokeResult = (Data.Scenario.Result ~= nil and Data.CallInfo.Blocked ~= true and not HasError)
		if HasInvokeResult then
			ExpectedResult, ExpectedResultRequiresNilHandler = wax.shared.LuaEncode(Data.Scenario.Result, {
				Prettify = true,
				InsertCycles = true,
				IsArray = true,
			})

			Variables.ExpectedResultCode = "\n\nlocal ExpectedResult = table.unpack(" .. ExpectedResult .. ")\n"
		else
			Variables.ExpectedResultCode = if HasError
				then `\n\nlocal ExpectedSuccess = false\nlocal ExpectedError = {Formatter.FormatLuaLiteral(
					tostring(Data.Scenario.Error)
				)}\n`
				else "\n"
		end

		if ArgsRequiresNilHandler or ExpectedResultRequiresNilHandler then
			AddPrelude(GetNilCode)
		end

		--// Add Variables \\--
		Variables.Args = Formatter.CreateArgsString(SerializedArgs, Data.Scenario.Arguments)
		if HasError then
			Variables.Args = Variables.Args:gsub("\n", "\n\t")
		end
		Variables.ArgsWithLeadingComma = Formatter.CreateArgsString(SerializedArgs, Data.Scenario.Arguments, ", ")
	end

	if #Preludes > 0 then
		Variables.Prelude = table.concat(Preludes, "\n\n") .. "\n\n"
	end

	return Variables
end

return Renderer
