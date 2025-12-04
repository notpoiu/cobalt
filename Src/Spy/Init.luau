local LuaEncode = require(script.Parent.Parent.Utils.Serializer.LuaEncode)
local CodeGen = require(script.Parent.Parent.Utils.CodeGen.Generator)

local Hooks = script.Parent.Hooks

-- Main Thread Hooks
for _, Hook in ipairs(Hooks.Default:GetChildren()) do
	task.spawn(require, Hook)
end

getgenv().CobaltInitialized = true

-- Actors use a different lua vm
-- This means that our main thread metatable hooks dont apply in the actor's vm
-- So we need to set up the hooks again in the actor lua vm in order to log everything
local ActorsUtils = script.Parent.Actors

wax.shared.ActorsEnabled = (
	wax.shared.ExecutorSupport["run_on_actor"].IsWorking
	and wax.shared.ExecutorSupport["getactors"].IsWorking
	and wax.shared.ExecutorSupport["create_comm_channel"].IsWorking
)

if wax.shared.ActorsEnabled then
	local ActorEnvironmentCode = ActorsUtils.Environment.Value

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

	ActorEnvironmentCode = ActorEnvironmentCode:gsub("COBALT_ACTOR_DATA", ActorData)

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
			ReconstructedInfo.IsActor = true

			Log:Call(ReconstructedInfo)
			wax.shared.Communicator:Fire(Log.Instance, Type, #Log.Calls)
		end
	end))

	-- Actor Hooking Code Generation
	local CodeToRun = ActorEnvironmentCode

	for _, ActorHook in Hooks.Actors:GetChildren() :: { StringValue } do
		CodeToRun ..= table.concat({
			"task.spawn(function()",
			CodeGen:IndentCode(ActorHook.Value, 1),
			"end)",
		}, "\n") .. "\n\n"
	end

	CodeToRun ..= table.concat({
		"task.spawn(function()",
		CodeGen:IndentCode(ActorsUtils.Unload.Value, 1),
		"end)",
	}, "\n")

	-- Actual Hooking Logic
	-- The hooking code wont run again if cobalt is already initialized in that Actor (to address deleted actors aka LuaStateProxy stuff)
	
	-- `HookActor` is to address Volcano returning non initialized actors inside their `getactors` function.
	-- God this code is so ass 🥹
	local function HookActor(TargetActor: Actor)
		local Hooked = false
		repeat
			Hooked, _ = pcall(run_on_actor, TargetActor, CodeToRun, CommunicationChannelID)
			task.wait(0.25)
		until Hooked
	end

	for _, TargetActor in getactors() do
		task.spawn(HookActor, TargetActor)
	end

	wax.shared.Connect(game.DescendantAdded:Connect(function(actor)
		if not actor:IsA("Actor") then
			return
		end

		HookActor(actor)
	end))
end

return {}
