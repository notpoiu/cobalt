--// Imports \\--
local Validation = require("@src/Utils/Validation")
local LuaEncode = require("@src/Utils/CodeGen/Serializer/LuaEncode")

local Interceptors = script.Interceptors

--// Types \\--
export type Options = {
	IncomingConnections: boolean?,
	IncomingCallbacks: boolean?,
	HookIncomingConnections: boolean?,
	Outgoing: boolean?,
	Actors: boolean?,
}

local OptionsTemplate: Options = {
	IncomingConnections = true,
	IncomingCallbacks = true,
	HookIncomingConnections = true,
	Outgoing = true,
	Actors = true,
}

return function(Options: Options?)
	--// Validation \\--
	Options = Validation.FillTemplate(Options or {}, OptionsTemplate)

	--// Options \\--
	local IncomingConnections = Options.IncomingConnections ~= false
	local IncomingCallbacks = Options.IncomingCallbacks ~= false
	local HookIncomingConnections = Options.HookIncomingConnections ~= false
	local Outgoing = Options.Outgoing ~= false
	local Actors = Options.Actors ~= false

	-- Main Thread Hooks
	task.spawn(require(Interceptors.Incoming), {
		Connections = IncomingConnections,
		Callbacks = IncomingCallbacks,
		HookConnections = HookIncomingConnections,
	})

	if Outgoing then
		task.spawn(require, Interceptors.Outgoing)
	end

	getgenv().CobaltInitialized = true

	-- Actors use a different lua vm
	-- This means that our main thread metatable hooks dont apply in the actor's vm
	-- So we need to set up the hooks again in the actor lua vm in order to log everything
	local ActorsUtils = script.Actors

	wax.shared.ActorsEnabled = Actors
		and (
			wax.shared.ExecutorSupport["run_on_actor"].IsWorking
			and wax.shared.ExecutorSupport["getactors"].IsWorking
			and wax.shared.ExecutorSupport["create_comm_channel"].IsWorking
		)

	if wax.shared.ActorsEnabled then
		local ActorEnvironmentCode = ActorsUtils.Environment.Value

		local CommunicationChannelID, Channel = create_comm_channel()
		wax.shared.ActorCommunicator = Channel

		local IgnorePlayerModule = wax.shared.SaveManager:GetState("IgnorePlayerModule")
		local LogBlockedRemotes = wax.shared.SaveManager:GetState("LogBlockedRemotes")
		local IngoredRemotesDropdown = wax.shared.SaveManager:GetState("IgnoredRemotesDropdown")
		local LogRobloxInternalEvents = wax.shared.SaveManager:GetState("LogRobloxInternalEvents")

		local ActorData = LuaEncode({
			Token = wax.shared.CobaltVerificationToken,

			--// Luau Hook Options \\--
			IncomingConnections = IncomingConnections,
			IncomingCallbacks = IncomingCallbacks,
			HookIncomingConnections = HookIncomingConnections,
			Outgoing = Outgoing,

			--// Settings \\--
			LogRobloxInternalEvents = LogRobloxInternalEvents,
			IgnorePlayerModule = IgnorePlayerModule,
			LogBlockedRemotes = LogBlockedRemotes,
			IgnoredRemotesDropdown = IngoredRemotesDropdown,

			--// Executor Support \\--
			ExecutorSupport = wax.shared.ExecutorSupport,
		})

		ActorEnvironmentCode = ActorEnvironmentCode:gsub("COBALT_ACTOR_DATA", ActorData)

		--#region Actor Logs Sync Layer
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

		local function ReconstructPacked(Packed)
			if not Packed or not Packed.Data then
				return Packed
			end

			local PackedN, PackedData = Packed.n, Packed.Data
			PackedData.n = PackedN
			return PackedData
		end

		wax.shared.Connect(Channel.Event:Connect(function(EventType, ...)
			local ShouldLogActors = wax.shared.SaveManager:GetState("LogActors")

			if not ShouldLogActors then
				return
			end

			if EventType == "IncomingConnectionMetadata" then
				local Instance, LogIndex, CallIndex, RawInfo, CyclicRefs = ...
				local Log = wax.shared.Logs.Incoming[Instance]
				if not Log and LogIndex ~= nil then
					for _, Candidate in wax.shared.Logs.Incoming do
						if Candidate.Index == LogIndex then
							Log = Candidate
							break
						end
					end
				end

				local OriginalCall = Log and Log.Calls[CallIndex]
				if not OriginalCall then
					return
				end

				local Metadata = ReconstructTable(RawInfo, CyclicRefs)
				local NewCallIndex = Log:Call({
					Arguments = OriginalCall.Arguments,
					Origin = Metadata.Origin,
					Function = Metadata.Function,
					Line = Metadata.Line,
					Source = OriginalCall.Source,
					IsExecutor = Metadata.IsExecutor,
					IsActor = true,
					Actor = Metadata.Actor,
					Blocked = OriginalCall.Blocked,
					Highlighted = OriginalCall.Highlighted,
					CallFilterId = OriginalCall.CallFilterId,
				})

				--// Make Memory Usage More Efficient \\--
				if NewCallIndex and Log.Calls[NewCallIndex] then
					Log.Calls[NewCallIndex].Arguments = OriginalCall.Arguments
				end

				return
			end

			if EventType ~= "ActorCall" then
				return
			end

			local Instance, Type, RawInfo, CyclicRefs = ...
			if Instance == Channel or Instance == wax.shared.Communicator then
				return
			end

			local Log = wax.shared.Logs[Type][Instance]

			if not Log then
				Log = wax.shared.NewLog(Instance, Type, RawInfo.Origin)
			end

			local ReconstructedInfo = ReconstructTable(RawInfo, CyclicRefs)
			ReconstructedInfo.IsActor = true -- Incase the Actor Instance is nil for some reason

			--// Reconstruct Packed Arguments (BindableEvents omit ["n"] for unknown reason) \\--
			ReconstructedInfo.Arguments = ReconstructPacked(ReconstructedInfo.Arguments)
			ReconstructedInfo.InvokeResult = ReconstructPacked(ReconstructedInfo.InvokeResult)

			Log:Call(ReconstructedInfo)
		end))
		--#endregion

		--#region Actor Hooking Logic
		-- The hooking code wont run again if cobalt is already initialized in that Actor (to address deleted actors aka LuaStateProxy stuff)

		-- `HookActor` is to address Volcano returning non initialized actors inside their `getactors` function.
		-- God this code is so ass 🥹
		local function HookActor(TargetActor: Actor)
			local Hooked = false
			local Attempts = 0

			repeat
				Hooked, _ = pcall(run_on_actor, TargetActor, ActorEnvironmentCode, CommunicationChannelID, TargetActor)

				Attempts += 1
				task.wait(0.25)
			until Hooked or Attempts > 10

			if Hooked then
				pcall(Channel.Fire, Channel, "MainCallFiltersSync", wax.shared.CallFilters:GetAll())
			end
		end

		for _, Category in { getactors(), getdeletedactors and getdeletedactors() or {} } do
			for _, TargetActor in Category do
				task.spawn(HookActor, TargetActor)
			end
		end

		local ActorHookConnection
		local function HandleInstance(Instance)
			if typeof(Instance) == "Instance" and not Instance:IsA("Actor") then
				return
			end

			HookActor(Instance)
		end

		if on_actor_state_created then
			ActorHookConnection = on_actor_state_created:Connect(HandleInstance)
		else
			ActorHookConnection = game.DescendantAdded:Connect(HandleInstance)
		end

		wax.shared.Connect(ActorHookConnection)
		--#endregion
	end

	--// Cleanup \\--
	return function()
		local gameMetatable = wax.shared.getrawmetatable(game)

		if wax.shared.IsUsingOthHooks then
			if Outgoing then
				pcall(oth.unhook, gameMetatable.__namecall)
			end
			if IncomingCallbacks then
				pcall(oth.unhook, gameMetatable.__newindex)
			end
		else
			if
				wax.shared.ExecutorSupport["restorefunction"].IsWorking
				and wax.shared.ExecutorSupport["hookmetamethod"].IsWorking
			then
				if Outgoing then
					pcall(restorefunction, gameMetatable.__namecall)
				end
				if IncomingCallbacks then
					pcall(restorefunction, gameMetatable.__newindex)
				end
			else
				if Outgoing then
					wax.shared.Hooking.HookMetaMethod(game, "__namecall", wax.shared.NamecallHook)
				end
				if IncomingCallbacks then
					wax.shared.Hooking.HookMetaMethod(game, "__newindex", wax.shared.NewIndexHook)
				end
			end
		end

		if IncomingCallbacks and wax.shared.RestoreCallbackDetours then
			wax.shared.RestoreCallbackDetours()
		end

		for Function, Original in wax.shared.Hooks do
			if wax.shared.IsUsingOthHooks then
				task.spawn(pcall, oth.unhook, Function)
			elseif wax.shared.ExecutorSupport["restorefunction"].IsWorking then
				task.spawn(pcall, wax.shared.restorefunction, Function)
			else
				pcall(wax.shared.Hooking.HookFunction, Function, Original)
			end
		end

		if wax.shared.ActorCommunicator then
			pcall(wax.shared.ActorCommunicator.Fire, wax.shared.ActorCommunicator, "Unload")
		end
	end
end
