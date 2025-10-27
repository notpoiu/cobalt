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

wax.shared.ActorsEnabled = create_comm_channel and run_on_actor

if wax.shared.ActorsEnabled then
	local ActorEnvironementCode = ActorsUtils.Environement.Value

	local CommunicationChannelID, Channel = create_comm_channel()
	wax.shared.ActorCommunicator = Channel

	local AlternativeEnabled = wax.shared.SaveManager:GetState("UseAlternativeHooks", false)

	local IgnorePlayerModule = wax.shared.SaveManager:GetState("IgnorePlayerModule", true)
	local IngoredRemotesDropdown = wax.shared.SaveManager:GetState("IgnoredRemotesDropdown", {
		["BindableEvent"] = true,
		["BindableFunction"] = true,
	})

	local ActorData = LuaEncode({
		Token = wax.shared.CobaltVerificationToken,

		IgnorePlayerModule = IgnorePlayerModule,
		IgnoredRemotesDropdown = IngoredRemotesDropdown,
		UseAlternativeHooks = AlternativeEnabled,

		ExecutorSupport = wax.shared.ExecutorSupport,
	})

	ActorEnvironementCode = ActorEnvironementCode:gsub("COBALT_ACTOR_DATA", ActorData)

	-- Actor Logs Sync Layer
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
		local ShouldLogActors = wax.shared.SaveManager:GetState("LogActors", true)

		if not ShouldLogActors then
			return
		end

		if EventType ~= "ActorCall" then
			return
		end

		local Instance, Type, RawInfo, CyclicRefs = ...
		if Instance == Channel or Instance == wax.shared.Communicator then
			return
		end

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

	-- Actual Hooking Logic
	wax.shared.HookedActors = {}

	local function IsActorHooked(Actor: Actor)
		if table.find(wax.shared.HookedActors, Actor) then
			return true
		end

		for _, ActorToCompare in wax.shared.HookedActors do
			if wax.shared.ExecutorSupport["compareinstances"].IsWorking and compareinstances(Actor, ActorToCompare) then
				return true
			end
		end

		return false
	end

	for _, TargetActor in getactors() do
		for _, ActorHook in Hooks.Actors:GetChildren() do
			run_on_actor(TargetActor, ActorEnvironementCode .. ActorHook.Value, CommunicationChannelID)
		end

		run_on_actor(TargetActor, ActorsUtils.Unload.Value, CommunicationChannelID)

		-- Deletion Handler
		local TargetActorRef = cloneref(TargetActor)
		table.insert(wax.shared.HookedActors, TargetActorRef)

		wax.shared.Connect(TargetActor.Destroying:Connect(function()
			table.remove(wax.shared.HookedActors, table.find(wax.shared.HookedActors, TargetActorRef))
		end))
	end

	wax.shared.Connect(game.DescendantAdded:Connect(function(actor)
		if not actor:IsA("Actor") or IsActorHooked(actor) then
			return
		end

		-- wait until executor is ready to run_on_actor (fails on some execs if its not in getactors() i think)
		repeat
			task.wait()
		until table.find(getactors(), actor) ~= nil

		for _, ActorHook in Hooks.Actors:GetChildren() do
			run_on_actor(actor, ActorEnvironementCode .. ActorHook.Value, CommunicationChannelID)
		end

		run_on_actor(actor, ActorsUtils.Unload.Value, CommunicationChannelID)

		-- Deletion Handler
		local ActorRef = cloneref(actor)
		table.insert(wax.shared.HookedActors, ActorRef)

		wax.shared.Connect(actor.Destroying:Connect(function()
			table.remove(wax.shared.HookedActors, table.find(wax.shared.HookedActors, ActorRef))
		end))
	end))
end

return {}
