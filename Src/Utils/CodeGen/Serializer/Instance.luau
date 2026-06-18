local InstanceSerializer = {}

local Formatter = require(script.Parent.Parent.Formatter)
local ReferencingTemplate = require(script.Parent.Parent.Templates.Referencing)

local GetNilCode = ReferencingTemplate.GetNilCode
local GetEventReferenceCode = ReferencingTemplate.GetEventReferenceCode

--[[
    Checks if two instances are equal.

    @param Object: The first instance.
    @param ToCompareTo: The second instance.
    @return Whether the instances are equal.
]]
local function IsEqualToInstance(Object, ToCompareTo)
	if rawequal(Object, ToCompareTo) then
		return true
	end

	if wax.shared.ExecutorSupport["compareinstances"].IsWorking then
		return compareinstances(Object, ToCompareTo)
	end

	local ObjectDebugId, ToCompareToDebugId, ShouldCompareDebugIds = nil, nil, false
	do
		local identity = getidentity()
		setthreadidentity(8)
		local GetDebugId = Object.GetDebugId

		local Success, ObjectDebugIdResult = pcall(GetDebugId, Object)
		local Success2, ToCompareToDebugIdResult = pcall(GetDebugId, ToCompareTo)
		setthreadidentity(identity)

		if Success and Success2 then
			ObjectDebugId = ObjectDebugIdResult
			ToCompareToDebugId = ToCompareToDebugIdResult
			ShouldCompareDebugIds = true
		end
	end

	if ShouldCompareDebugIds then
		return ObjectDebugId == ToCompareToDebugId
	end

	return false
end

--[[

    Invokes plugin handlers for a given type.

    @param Type: The type of plugin handler to invoke.
    @param ShouldUseResult: Returns whether a plugin result should replace the default codegen output.
    @param ...: The arguments to pass to the plugin handler.
    @return:
		- ShouldContinue: Whether to continue the default behavior.
		- Results: The results of the plugin handlers.
]]
local function InvokePluginHandlers(ShouldUseResult: (...any) -> boolean, ...)
	local PluginManager = wax.shared.CobaltPluginManager
	if PluginManager and PluginManager.HasCodeGenInterceptors then
		local Interceptors = PluginManager.Registry.UIHooks.CodeGen.InstancePath

		for _, Interceptor in Interceptors or {} do
			local Results = table.pack(pcall(Interceptor, ...))
			local Success = Results[1]

			if Success then
				local ReturnValues = table.pack(table.unpack(Results, 2, Results.n))
				if ShouldUseResult(table.unpack(ReturnValues, 1, ReturnValues.n)) then
					return false, ReturnValues
				end
			else
				warn(
					`Error in Cobalt Plugin (CodeGen Interceptor (InstancePath)):`,
					table.unpack(Results, 2, Results.n)
				)
			end
		end
	end

	return true, nil
end

--[[
    Serializes an instance path to a string.

    @param Object: The instance to serialize.
    @param options: The options to use for serialization.
    @return The serialized path.
]]
function InstanceSerializer.Serialize(
	Object,
	options: {
		DisableNilParentHandler: boolean?,
		VariableName: string?,
		OmitNilFunctionGetterCodeGeneration: boolean?,
		IgnorePlugins: boolean?,
		EventReference: {
			Hash: string,
			Index: number,
			ExcludeExecutor: boolean?,
			Path: { any }?,
		}?,
	}?
)
	local DisableNilParentHandler = options and options.DisableNilParentHandler
	local OmitNilFunctionGetterCodeGeneration = options and options.OmitNilFunctionGetterCodeGeneration
	local VariableName = options and options.VariableName
	local IgnorePlugins = options and options.IgnorePlugins
	local EventReference = options and options.EventReference
	do
		if DisableNilParentHandler == nil then
			DisableNilParentHandler = true
		end

		if OmitNilFunctionGetterCodeGeneration == nil then
			OmitNilFunctionGetterCodeGeneration = false
		end
	end

	if not IgnorePlugins then
		local ShouldContinue, Results = InvokePluginHandlers(function(InterceptedCode)
			return type(InterceptedCode) == "string"
		end, Object, options)

		if not ShouldContinue then
			return Results[1]
		end
	end

	local ChildLookupMode = wax.shared.SaveManager:GetState("InstancePathLookupChain", "Index")
	local NilEventReferenceStrategy = wax.shared.SaveManager:GetState("EventReferenceStrategy", "GetNil")

	local function BuildDynamicAccessor(Expression: string): string
		if ChildLookupMode == "WaitForChild" then
			return ":WaitForChild(" .. Expression .. ")"
		elseif ChildLookupMode == "FindFirstChild" then
			return ":FindFirstChild(" .. Expression .. ")"
		end

		return "[" .. Expression .. "]"
	end

	local function BuildStaticAccessor(Name: string): string
		local SanitizedName = Formatter.FormatLuaString(Name)

		if ChildLookupMode == "WaitForChild" then
			return ':WaitForChild("' .. SanitizedName .. '")'
		elseif ChildLookupMode == "FindFirstChild" then
			return ':FindFirstChild("' .. SanitizedName .. '")'
		elseif string.match(Name, "^[%a_][%w_]*$") then
			return "." .. Name
		end

		return '["' .. SanitizedName .. '"]'
	end

	local CurrentObject = Object
	local IsNil = false
	local Path = ""
	local RequiredPrelude = nil

	repeat
		if typeof(CurrentObject) ~= "Instance" then
			break
		end

		if IsEqualToInstance(CurrentObject, game) then
			Path = "game" .. Path
			break
		end

		local IndexName = ""

		if IsEqualToInstance(CurrentObject, wax.shared.LocalPlayer) then
			IndexName = ".LocalPlayer"
		elseif
			wax.shared.LocalPlayer.Character and IsEqualToInstance(CurrentObject, wax.shared.LocalPlayer.Character)
		then
			Path = 'game:GetService("Players").LocalPlayer.Character' .. Path
			break
		elseif CurrentObject.Name and CurrentObject.Name == wax.shared.LocalPlayer.Name then
			IndexName = BuildDynamicAccessor('game:GetService("Players").LocalPlayer.Name')
		elseif CurrentObject.Name and CurrentObject.Name == tostring(wax.shared.LocalPlayer.UserId) then
			IndexName = BuildDynamicAccessor('game:GetService("Players").LocalPlayer.UserId')
		elseif IsEqualToInstance(CurrentObject, workspace) then
			Path = "workspace" .. Path
			break
		elseif CurrentObject.ClassName and CurrentObject.Name then
			IndexName = BuildStaticAccessor(CurrentObject.Name)

			local Parent = CurrentObject.Parent
			if Parent then
				local DirectChildPtr = Parent:FindFirstChild(CurrentObject.Name)

				if
					IsEqualToInstance(Parent, game)
					and IsEqualToInstance(game:FindService(CurrentObject.ClassName), CurrentObject)
				then
					IndexName = ':GetService("' .. CurrentObject.ClassName .. '")'
				elseif DirectChildPtr then
					local Children = Parent:GetChildren()
					local FoundIndex = nil

					if
						wax.shared.ExecutorSupport["compareinstances"].IsWorking
						and not compareinstances(DirectChildPtr, CurrentObject)
					then
						for Index, Child in Children do
							if not compareinstances(Child, CurrentObject) then
								continue
							end

							FoundIndex = Index
							break
						end
					elseif DirectChildPtr ~= CurrentObject then
						FoundIndex = table.find(Children, CurrentObject)
					end

					if FoundIndex then
						IndexName = ":GetChildren()[" .. tostring(FoundIndex) .. "]"
					end
				end
			elseif Parent == nil then
				IsNil = true

				if DisableNilParentHandler then
					Path = Path .. " --[[Nil Parent]]"
				else
					local Base = `GetNil("{Formatter.FormatLuaString(CurrentObject.Name)}", "{Formatter.FormatLuaString(
						CurrentObject:GetDebugId()
					)}")`
					local GetterCode = GetNilCode
					RequiredPrelude = GetterCode

					if NilEventReferenceStrategy == "Upvalue Lookup" and EventReference then
						local EventReferenceCall = {
							"GetEventReference({",
							Formatter.IndentCode(`Hash = "{Formatter.FormatLuaString(EventReference.Hash)}",`, 1),
							Formatter.IndentCode(
								`ExcludeExecutor = {EventReference.ExcludeExecutor == true and "true" or "false"},`,
								1
							),
							Formatter.IndentCode(`Index = {tostring(EventReference.Index)},`, 1),
						}

						if EventReference.Path and #EventReference.Path > 0 then
							table.insert(
								EventReferenceCall,
								Formatter.IndentCode(`Path = {Formatter.FormatLuaArray(EventReference.Path)},`, 1)
							)
						end

						table.insert(EventReferenceCall, "})\n")
						Base = table.concat(EventReferenceCall, "\n")
						GetterCode = GetEventReferenceCode
						RequiredPrelude = GetterCode
					end

					if OmitNilFunctionGetterCodeGeneration then
						Path = `{VariableName and `local {VariableName} = ` or ""}` .. Base
						break
					end

					Path = GetterCode .. `\n\n{VariableName and `local {VariableName} = ` or ""}` .. Base
					break
				end
			end
		end

		Path = IndexName .. Path

		CurrentObject = CurrentObject.Parent
	until CurrentObject == nil

	if IsNil then
		if OmitNilFunctionGetterCodeGeneration then
			return Path, RequiredPrelude
		end

		return Path
	end

	return `{VariableName and `local {VariableName} = ` or ""}{Path}`
end

InstanceSerializer.IsEqualToInstance = IsEqualToInstance
return InstanceSerializer
