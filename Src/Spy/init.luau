return function()
	local Hooks = script.Hooks
	local IncomingOnlyOptions = {
		IncomingConnections = true,
		IncomingCallbacks = false,
		HookIncomingConnections = false,
		Outgoing = false,
		Actors = true,
	}

	if wax.shared.IsUsingRakNetHooks then
		local CleanupLuau = require(Hooks.Luau)(IncomingOnlyOptions)
		local CleanupRakNet = require(Hooks.RakNet)()

		return function()
			pcall(CleanupRakNet)
			pcall(CleanupLuau)
		end
	end

	if not wax.shared.IsOutgoingLoggable then
		return require(Hooks.Luau)(IncomingOnlyOptions)
	end

	return require(Hooks.Luau)()
end
