local CodeGen = {
	CleanTable = { ['"'] = '\\"', ["\\"] = "\\\\" },
	IndentTemplate = string.rep(" ", 4),
}

export type SupportedRemoteTypes = RemoteEvent | RemoteFunction | BindableEvent | BindableFunction | UnreliableRemoteEvent
export type CallInfo = {
	Arguments: { [number]: any, n: number },
	Time: string,
	Origin: BaseScript?,
	Function: (
		...any
	) -> any | {
		Address: string,
		Name: string,
		IsC: boolean,
		Constants: { any }?,
		Upvalues: { any }?,
		Protos: { any }?,
	},
	Line: number?,
	Instance: SupportedRemoteTypes,
	Order: number,
	Type: "Incoming" | "Outgoing",
	OriginalInvokeArgs: { [number]: any, n: number }?,
	IsActor: boolean?,
}

wax.shared.FunctionForClasses = {
	Incoming = {
		RemoteEvent = "OnClientEvent",
		RemoteFunction = "OnClientInvoke",
		UnreliableRemoteEvent = "OnClientEvent",
		BindableEvent = "Event",
		BindableFunction = "OnInvoke",
	},

	Outgoing = {
		RemoteEvent = "FireServer",
		RemoteFunction = "InvokeServer",
		UnreliableRemoteEvent = "FireServer",
		BindableEvent = "Fire",
		BindableFunction = "Invoke",
	},
}

local GetNilCode = [[local function GetNil(Name, DebugId)
	for _, Object in getnilinstances() do
		if Object.Name == Name and Object:GetDebugId() == DebugId then
			return Object
		end
	end
end]]

--// Pasted from Dex (maximum detection)
for i = 0, 31 do
	CodeGen.CleanTable[string.char(i)] = "\\" .. string.format("%03d", i)
end
for i = 127, 255 do
	CodeGen.CleanTable[string.char(i)] = "\\" .. string.format("%03d", i)
end

function CodeGen.FormatLuaString(str)
	return string.gsub(str, '["\\\0-\31\127-\255]', CodeGen.CleanTable)
end

local function IsEqualToInstance(Object, ToCompareTo)
	if rawequal(Object, ToCompareTo) then
		return true
	end

	if wax.shared.ExecutorSupport["compareinstances"].IsWorking then
		return compareinstances(Object, ToCompareTo)
	end

	return false
end

local ChildLookupModes = { "FindFirstChild", "WaitForChild", "Index" }
function CodeGen.GetFullPath(Object, ExcludeCode, VariableName, IsInTable)
	local ChildLookupMode = wax.shared.SaveManager:GetState("InstancePathLookupChain")
	if not table.find(ChildLookupModes, ChildLookupMode) then
		ChildLookupMode = "Index"
	end

	local function BuildDynamicAccessor(Expression: string): string
		if ChildLookupMode == "WaitForChild" then
			return ":WaitForChild(" .. Expression .. ")"
		elseif ChildLookupMode == "FindFirstChild" then
			return ":FindFirstChild(" .. Expression .. ")"
		end

		return "[" .. Expression .. "]"
	end

	local function BuildStaticAccessor(Name: string): string
		local SanitizedName = CodeGen.FormatLuaString(Name)

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
	local DidInsertNilFunction = false
	local IsNil = false
	local Path = ""

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

				if ExcludeCode then
					Path = Path .. " --[[Nil Parent]]"
				else
					local Base = `GetNil("{CodeGen.FormatLuaString(CurrentObject.Name)}", "{CodeGen.FormatLuaString(
						CurrentObject:GetDebugId()
					)}")`
					DidInsertNilFunction = true
					if IsInTable then
						Path = Base
						break
					end

					Path = GetNilCode .. `\n\n{VariableName and `local {VariableName} = ` or ""}` .. Base
					break
				end
			end
		end

		Path = IndexName .. Path

		CurrentObject = CurrentObject.Parent
	until CurrentObject == nil

	if IsNil then
		return Path, DidInsertNilFunction
	end

	return `{VariableName and `local {VariableName} = ` or ""}{Path}`, DidInsertNilFunction
end

local function DoesUseCallbackValue(Instance: Instance)
	return Instance.ClassName == "RemoteFunction" or Instance.ClassName == "BindableFunction"
end

local CodeGenHeaderTemplate = [[-- This code was generated by Cobalt
-- https://github.com/notpoiu/cobalt

]]

local ClientRemoteClassNames = {
	BindableEvent = true,
	BindableFunction = true,
}

local function IndentCode(Code: string, IndentLevel: number)
	local Indent = CodeGen.IndentTemplate:rep(IndentLevel)
	local IndentedCode = Code:gsub("\n", "\n" .. Indent)
	return Indent .. IndentedCode
end

local function WrapCodeInActor(Code: string, ShouldWrap: boolean)
	if not ShouldWrap then
		return Code
	end

	return string.format(
		"-- Event originated from an Actor environement\nrun_on_actor(getactors()[1], [[\n%s\n]])",
		IndentCode(Code, 1)
	)
end

function CodeGen:BuildHookCode(CallInfo: CallInfo)
	local Type = CallInfo.Type
	local Path = self.GetFullPath(CallInfo.Instance, false, "Event")
	local IsFromActor = CallInfo.IsActor or false
	local Method = wax.shared.FunctionForClasses[Type][CallInfo.Instance.ClassName]

	local CodeGenHeader = CodeGenHeaderTemplate
	if
		typeof(wax.shared.SaveManager:GetState("ShowWatermark")) == "boolean"
		and wax.shared.SaveManager:GetState("ShowWatermark") == false
	then
		CodeGenHeader = ""
	end

	if Type == "Incoming" then
		if DoesUseCallbackValue(CallInfo.Instance) then
			-- :InvokeServer -> Returned value
			if CallInfo.OriginalInvokeArgs then
				Method = wax.shared.FunctionForClasses.Outgoing[CallInfo.Instance.ClassName]

				return CodeGenHeader
					.. WrapCodeInActor(
						string.format(
							[[%s
local mtHook; mtHook = hookmetamethod(game, "__namecall", function(...)
	local self = ...

	if rawequal(self, Event) and getnamecallmethod() == "%s" then
		local Args = table.pack(...)

		local Result = table.pack(
			mtHook(table.unpack(Args, 1, Args.n))
		)

		return table.unpack(Result, 1, Result.n)
	end

	return mtHook(self, ...)
end)

local Old%s; Old%s = hookfunction(Event.%s, function(...)
	local self = ...

	if rawequal(self, Event) then
		local Args = table.pack(...)

		local Result = table.pack(
			Old%s(table.unpack(Args, 1, Args.n))
		)

		return table.unpack(Result, 1, Result.n)
	end

	return Old%s(self, ...)
end)]],
							Path,
							Method,
							Method,
							Method,
							Method,
							Method,
							Method
						),
						IsFromActor
					)
			end

			-- Callback value
			return CodeGenHeader
				.. WrapCodeInActor(
					string.format(
						[[%s
local Callback = getcallbackvalue(Event, "%s")
Event.%s = function(...)
	print(`Intercepted (Callback) {Event.Name}.%s`, ...)
	return Callback(...)
end

local mtHook; mtHook = hookmetamethod(game, "__newindex", function(...)
	local self, key, value = ...
	
	if (
		rawequal(self, Event) and
		rawequal(key, "%s") and
		typeof(value) == "function" and
		not checkcaller()
	) then
		Callback = value
	end

	return mtHook(...)
end)]],
						Path,
						Method,
						Method,
						Method,
						Method
					),
					IsFromActor
				)
		end

		return CodeGenHeader
			.. WrapCodeInActor(
				string.format(
					[[%s
for _, Connection in getconnections(Event.%s) do
	local old; old = hookfunction(Connection.Function, function(...)
		print(`Intercepted (Connection) {Event.Name}.%s`, ...)
		return old(...)
	end)
end]],
					Path,
					Method,
					Method
				),
				IsFromActor
			)
	end

	return CodeGenHeader
		.. WrapCodeInActor(
			string.format(
				[[%s
local mtHook; mtHook = hookmetamethod(game, "__namecall", function(...)
	local self = ...

	if rawequal(self, Event) and getnamecallmethod() == "%s" then
		local Args = table.pack(...)
		
		local Result = table.pack(
			mtHook(self, table.unpack(Args, 1, Args.n))
		)

		print(`Intercepted (__namecall) {Event.Name}:%s()`, ...)

		return table.unpack(Result, 1, Result.n)
	end

	return mtHook(...)
end)

local Old%s; Old%s = hookfunction(Event.%s, function(...)
	local self = ...

	if rawequal(self, Event) then
		local Args = table.pack(...)

		local Result = table.pack(
			Old%s(table.unpack(Args, 1, Args.n))
		)

		print(`Intercepted (__index) {Event.Name}:%s()`, self, table.unpack(Result, 1, Result.n))

		return table.unpack(Result, 1, Result.n)
	end

	return Old%s(self, ...)
end)]],
				Path,
				Method,
				Method,
				Method,
				Method,
				Method,
				Method,
				Method,
				Method
			),
			IsFromActor
		)
end

function CreateArgsString(SerializedArgs: string, Args: { [number]: any, n: number }, Prefix: string?)
	if Args.n == 0 then
		return ""
	end

	return `{Prefix == nil and "" or Prefix}{string.sub(SerializedArgs, 2, #SerializedArgs - 1)}`
end

function CodeGen:BuildCallCode(CallInfo: CallInfo)
	local Type = CallInfo.Type
	local IsFromActor = CallInfo.IsActor or false
	local Path = self.GetFullPath(CallInfo.Instance, false, "Event")
	local Method = wax.shared.FunctionForClasses[Type][CallInfo.Instance.ClassName]
	local SerializedArgs, DidInsertNilFunction = wax.shared.LuaEncode(
		{ table.unpack(CallInfo.Arguments, 1, CallInfo.Arguments.n) },
		{ Prettify = true, InsertCycles = true, GetNilFunctionInsert = true }
	)

	local CodeGenHeader = CodeGenHeaderTemplate
	if
		typeof(wax.shared.SaveManager:GetState("ShowWatermark")) == "boolean"
		and wax.shared.SaveManager:GetState("ShowWatermark") == false
	then
		CodeGenHeader = ""
	end

	if Type == "Incoming" then
		if DoesUseCallbackValue(CallInfo.Instance) then
			local PrettifiedExpectedResult, DidInsertNilFunctionInExpectation = wax.shared.LuaEncode(
				{ table.unpack(CallInfo.Arguments, 1, CallInfo.Arguments.n) },
				{ Prettify = true, InsertCycles = true, GetNilFunctionInsert = true }
			)

			if CallInfo.OriginalInvokeArgs then
				local PrettifiedOutput, InsertedNilFunction = wax.shared.LuaEncode(
					{ table.unpack(CallInfo.OriginalInvokeArgs, 1, CallInfo.OriginalInvokeArgs.n) },
					{ Prettify = true, InsertCycles = true }
				)

				Method = wax.shared.FunctionForClasses.Outgoing[CallInfo.Instance.ClassName]

				return CodeGenHeader
					.. string.format(
						[[%s%s
local Result = Event:%s(%s)

local ExpectedResult = table.unpack(%s)

]],
						(
							(InsertedNilFunction or DidInsertNilFunction or DidInsertNilFunctionInExpectation)
								and GetNilCode .. "\n\n"
							or ""
						),
						Path,
						Method,
						CreateArgsString(PrettifiedOutput, CallInfo.OriginalInvokeArgs),
						PrettifiedExpectedResult
					)
			end

			return CodeGenHeader
				.. WrapCodeInActor(
					string.format(
						[[%s%s
local Callback = getcallbackvalue(Event, "%s")
Callback(%s)

local ExpectedResult = table.unpack(%s)

]],
						(DidInsertNilFunction or DidInsertNilFunctionInExpectation and GetNilCode .. "\n\n" or ""),
						Path,
						Method,
						CreateArgsString(SerializedArgs, CallInfo.Arguments),

						PrettifiedExpectedResult
					),
					IsFromActor
				)
		end

		return CodeGenHeader
			.. WrapCodeInActor(
				string.format(
					[[%s%s
firesignal(Event.%s%s)]],
					(DidInsertNilFunction and GetNilCode .. "\n\n" or ""),
					Path,
					Method,
					CreateArgsString(SerializedArgs, CallInfo.Arguments, ", ")
				),
				IsFromActor
			)
	end

	return CodeGenHeader
		.. WrapCodeInActor(
			string.format(
				[[%s%s
Event:%s(%s)]],
				(DidInsertNilFunction and GetNilCode .. "\n\n" or ""),
				Path,
				Method,
				CreateArgsString(SerializedArgs, CallInfo.Arguments)
			),
			IsFromActor and ClientRemoteClassNames[CallInfo.Instance.ClassName]
		)
end

function CodeGen:BuildFunctionInfo(CallInfo: CallInfo)
	if CallInfo.IsActor and typeof(CallInfo.Function) == "table" then
		return string.format(
			[[<b>Function Address:</b> %s
<b>Name:</b> %s
<b>Source:</b> %s
<b>Calling Line:</b> %s
<b>From Actor:</b> true
%s]],
			CallInfo.Function.Address:match("0x%x+") or tostring(CallInfo.Function),
			CallInfo.Function.Name ~= "" and CallInfo.Function.Name or "Anonymous",
			CallInfo.Origin and self.GetFullPath(CallInfo.Origin, true) or wax.shared.ExecutorName,
			tostring(CallInfo.Line),

			CallInfo.Function.IsC and "<b>Closure Type</b>: C closure"
				or string.format(
					"<b>Closure Type</b>: Luau closure\n<b>Constants:</b> %s\n<b>Upvalues:</b> %s\n<b>Protos:</b> %s",
					debug.getconstants and tostring(#CallInfo.Function.Constants) or "N/A",
					debug.getupvalues and tostring(#CallInfo.Function.Upvalues) or "N/A",
					debug.getprotos and tostring(#CallInfo.Function.Protos) or "N/A"
				)
		)
	end

	local FunctionName = debug.info(CallInfo.Function, "n")

	return string.format(
		[[<b>Function Address:</b> %s
<b>Name:</b> %s
<b>Source:</b> %s
<b>Calling Line:</b> %s
%s]],
		tostring(CallInfo.Function):match("0x%x+") or tostring(CallInfo.Function),
		FunctionName ~= "" and FunctionName or "Anonymous",
		CallInfo.Origin and self.GetFullPath(CallInfo.Origin, true) or wax.shared.ExecutorName,
		tostring(CallInfo.Line),

		iscclosure(CallInfo.Function) and "<b>Closure Type</b>: C closure"
			or string.format(
				"<b>Closure Type</b>: Luau closure\n<b>Constants:</b> %s\n<b>Upvalues:</b> %s\n<b>Protos:</b> %s",
				debug.getconstants and tostring(#debug.getconstants(CallInfo.Function)) or "N/A",
				debug.getupvalues and tostring(#debug.getupvalues(CallInfo.Function)) or "N/A",
				debug.getprotos and tostring(#debug.getprotos(CallInfo.Function)) or "N/A"
			)
	)
end

wax.shared.ReplayCallInfo = function(CallInfo: CallInfo)
	local Type = CallInfo.Type
	local Method = wax.shared.FunctionForClasses[Type][CallInfo.Instance.ClassName]

	if Type == "Incoming" then
		if DoesUseCallbackValue(CallInfo.Instance) then
			if CallInfo.OriginalInvokeArgs then
				Method = wax.shared.FunctionForClasses.Outgoing[CallInfo.Instance.ClassName]

				CallInfo.Instance[Method](
					CallInfo.Instance,
					table.unpack(CallInfo.OriginalInvokeArgs, 1, CallInfo.OriginalInvokeArgs.n)
				)
				return
			end

			local Callback = getcallbackvalue(CallInfo.Instance, Method)

			if not Callback then
				return
			end

			Callback(table.unpack(CallInfo.Arguments))
			return
		end

		assert(firesignal or getconnections, "No firesignal or getconnections found")

		if firesignal then
			firesignal(CallInfo.Instance[Method], table.unpack(CallInfo.Arguments, 1, CallInfo.Arguments.n))
		elseif getconnections then
			for _, conn in getconnections(CallInfo.Instance[Method]) do
				conn:Fire(table.unpack(CallInfo.Arguments, 1, CallInfo.Arguments.n))
			end
		end

		return
	end

	CallInfo.Instance[Method](CallInfo.Instance, table.unpack(CallInfo.Arguments, 1, CallInfo.Arguments.n))
end

return CodeGen
