--// Tables \\--
local MethodLookupTable = {
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

	--// Bidirectional \\--
	Bidirectional = {
		RemoteFunction = {
			Request = "InvokeServer",
			SSE = "OnClientInvoke",
		},
		BindableFunction = {
			Request = "Invoke",
			SSE = "OnInvoke",
		},
	},
}

--// Types \\--
local Types = require(script.Parent.Types)

--// Functions \\--
local function CanEventContainCallbackValue(Instance: Instance)
	return (Instance.ClassName == "RemoteFunction" or Instance.ClassName == "BindableFunction")
end

local function BuildTemplateScenario(CallInfo: Types.CallInfo, Data)
	local Method = MethodLookupTable[CallInfo.Type][CallInfo.Instance.ClassName]

	--// Handle Bidirectional Methods \\--
	local BidirectionalLookup = MethodLookupTable.Bidirectional[CallInfo.Instance.ClassName]

	if BidirectionalLookup and Data.Shape then
		Method = BidirectionalLookup[Data.Shape]
	end

	--// Build Scenario \\--
	local Scenario = {
		Type = CallInfo.Type,
		Direction = CallInfo.Type,
		Class = CallInfo.Instance.ClassName,
		Method = Method,
		InvokeKind = CallInfo.InvokeKind,
		Error = CallInfo.Error,
		IsActor = CallInfo.IsActor,
		Actor = CallInfo.Actor,
	}

	--// Merge Data \\--
	for Key, Value in Data do
		Scenario[Key] = Value
	end

	return Scenario
end

--// Classifier \\--
local Classifier = {}
Classifier.MethodLookupTable = MethodLookupTable

--[[
    Determines the scenario of a call.

    Shape:
    - Request (Client -> Server)
    - SSE (Server Sent Event)
    - Signal (Client -> Server)

    @param CallInfo
    @return Scenario
]]
function Classifier.DetermineScenario(CallInfo: Types.CallInfo): Types.Scenario
	local Type = CallInfo.Type

	--// Server -> Client \\--
	if Type == "Incoming" then
		--// RemoteFunction or BindableFunction Handling \\--
		if CanEventContainCallbackValue(CallInfo.Instance) then
			--// Does originate from :InvokeClient()/:Invoke() from Server (Server Sent Event) \\--
			if CallInfo.InvokeKind ~= "Request" then
				return BuildTemplateScenario(CallInfo, {
					Arguments = CallInfo.Arguments,
					Result = CallInfo.InvokeResult,

					Shape = "SSE",
				})
			end

			--// Does originate from :InvokeServer()/:Invoke() \\--
			return BuildTemplateScenario(CallInfo, {
				Arguments = CallInfo.Arguments,
				Result = CallInfo.InvokeResult,

				Shape = "Request",
			})
		end

		--// RemoteEvent or BindableEvent Handling \\--
		return BuildTemplateScenario(CallInfo, {
			Arguments = CallInfo.Arguments,

			Shape = "Signal",
		})
	end

	--// Client -> Server \\--
	return BuildTemplateScenario(CallInfo, {
		Arguments = CallInfo.Arguments,

		Shape = "Request",
	})
end

return Classifier
