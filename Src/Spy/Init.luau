local LuaEncode = require(script.Parent.Parent.Utils.Serializer.LuaEncode)
local Hooks = script.Parent.Hooks

-- Main Thread Hooks
for _, Hook in ipairs(Hooks.Default:GetChildren()) do
	task.spawn(require, Hook)
end

-- Actors use a different lua vm
-- This means that our main thread metatable hooks dont apply in the actor's vm
-- So we need to set up the hooks again in the actor lua vm in order to log everything
local ActorsUtils = script.Parent.Actors

local TargetActor = getactors and getactors()[1] or nil
wax.shared.ActorsEnabled = (create_comm_channel and run_on_actor and TargetActor) ~= nil

if wax.shared.ActorsEnabled then
	local ActorEnvironementCode = ActorsUtils.Environement.Value

	local CommunicationChannelID, Channel = create_comm_channel()
	wax.shared.ActorCommunicator = get_comm_channel(CommunicationChannelID)

	local UseAltHooks = wax.shared.SaveManager:GetState("UseAlternativeHooks")
	local AlternativeEnabled = typeof(UseAltHooks) == "boolean" and UseAltHooks or false

	local IgnorePlayerModule = wax.shared.SaveManager:GetState("IgnorePlayerModule")
	local IngoredRemotesDropdown = wax.shared.SaveManager:GetState("IgnoredRemotesDropdown")

	local ActorData = LuaEncode({
		Token = wax.shared.CobaltVerificationToken,

		IgnorePlayerModule = if typeof(IgnorePlayerModule) == "boolean" then IgnorePlayerModule else true,
		IgnoredRemotesDropdown = if typeof(IngoredRemotesDropdown) == "table"
			then IngoredRemotesDropdown
			else {
				["BindableEvent"] = true,
				["BindableFunction"] = true,
			},
		UseAlternativeHooks = AlternativeEnabled,

		ExecutorSupport = wax.shared.ExecutorSupport,
	})

	ActorEnvironementCode = ActorEnvironementCode:gsub("COBALT_ACTOR_DATA", ActorData)

	local function ReconstructTable(Info, CyclicRefs)
		local Reconstructed = {}

		for Key, Value in Info do
			if type(Value) == "table" then
				if Value["__Function"] and Value["Validation"] == wax.shared.CobaltVerificationToken then
					local FunctionData = table.clone(Value)
					FunctionData["__Function"] = nil
					FunctionData["Validation"] = nil

					Reconstructed[Key] = FunctionData
					continue
				end

				-- Check for Cobalt Created Object
				if not Value["__CyclicRef"] then
					Reconstructed[Key] = ReconstructTable(Value, CyclicRefs)
					continue
				end

				local CyclicId = Value["__Id"]

				if not CyclicRefs[CyclicId] then
					warn("CyclicRef not found: " .. CyclicId)
					continue
				end

				Reconstructed[Key] = CyclicRefs[CyclicId]
				continue
			end

			Reconstructed[Key] = Value
		end

		return Reconstructed
	end

	wax.shared.Connect(Channel.Event:Connect(function(EventType, ...)
		local LogActors = wax.shared.SaveManager:GetState("LogActors")
		local ShouldLogActors = typeof(LogActors) ~= "boolean" and true or LogActors

		if not ShouldLogActors then
			return
		end

		if EventType ~= "ActorCall" then
			return
		end

		local Instance, Type, RawInfo, CyclicRefs = ...
		local Method = wax.shared.FunctionForClasses[Type][Instance.ClassName]
		local Log = wax.shared.Logs[Type][Instance]

		if not Log then
			Log = wax.shared.NewLog(Instance, Type, Method, RawInfo.Origin)
		end

		if Log.Blocked then
			return
		elseif not Log.Ignored then
			local ReconstructedInfo = ReconstructTable(RawInfo, CyclicRefs)

			Log:Call(ReconstructedInfo)
			wax.shared.Communicator:Fire(Log.Instance, Type, #Log.Calls)
		end
	end))

	for _, ActorHook in ipairs(Hooks.Actors:GetChildren()) do
		run_on_actor(TargetActor, ActorEnvironementCode .. ActorHook.Value, CommunicationChannelID)
	end

	run_on_actor(TargetActor, ActorsUtils.Unload.Value, CommunicationChannelID)
end

return {}
