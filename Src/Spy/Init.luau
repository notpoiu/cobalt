return function()
	local Hooks = script.Hooks

	local ShouldUseRakNet = (
		wax.shared.SaveManager:GetState("RakNetHooks") and wax.shared.ExecutorSupport["raknet"].IsWorking
	)
	wax.shared.IsUsingRakNetHooks = ShouldUseRakNet

	if ShouldUseRakNet then
		local CleanupLuau = require(Hooks.Luau)({
			IncomingConnections = true,
			IncomingCallbacks = false,
			HookIncomingConnections = false,
			Outgoing = false,
			Actors = true,
		})
		local CleanupRakNet = require(Hooks.RakNet)()

		return function()
			pcall(CleanupRakNet)
			pcall(CleanupLuau)
		end
	end

	return require(Hooks.Luau)()
end
