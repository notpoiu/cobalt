local HookTemplates = {}

HookTemplates.IncomingCallbackReturn = [[{{Prelude}}{{Path}}
local Callback = getcallbackvalue(Event, "{{Method}}")
Event.{{Method}} = function(...)
	local Args = table.pack(...)

	local Result = table.pack(
		Callback(table.unpack(Args, 1, Args.n))
	)

	return table.unpack(Result, 1, Result.n)
end

local mtHook; mtHook = hookmetamethod(game, "__newindex", function(...)
	local self, key, value = ...
	
	if (
		rawequal(self, Event) and
		rawequal(key, "{{Method}}") and
		typeof(value) == "function" and
		not checkcaller()
	) then
		Callback = value
	end

	return mtHook(...)
end)]]

HookTemplates.IncomingRequestReturn = [[{{Prelude}}{{Path}}
local mtHook; mtHook = hookmetamethod(game, "__namecall", function(...)
	local self = ...

	if rawequal(self, Event) and getnamecallmethod() == "{{Method}}" then
		local Args = table.pack(...)

		local Result = table.pack(
			mtHook(table.unpack(Args, 1, Args.n))
		)

		return table.unpack(Result, 1, Result.n)
	end

	return mtHook(self, ...)
end)

local Old{{Method}}; Old{{Method}} = hookfunction(Event.{{Method}}, function(...)
	local self = ...

	if rawequal(self, Event) then
		local Args = table.pack(...)

		local Result = table.pack(
			Old{{Method}}(table.unpack(Args, 1, Args.n))
		)

		return table.unpack(Result, 1, Result.n)
	end

	return Old{{Method}}(self, ...)
end)]]

HookTemplates.IncomingCallbackValue = [[{{Prelude}}{{Path}}
local Callback = getcallbackvalue(Event, "{{Method}}")
Event.{{Method}} = function(...)
	print(`Intercepted (Callback) {Event.Name}.{{Method}}`, ...)
	return Callback(...)
end

local mtHook; mtHook = hookmetamethod(game, "__newindex", function(...)
	local self, key, value = ...
	
	if (
		rawequal(self, Event) and
		rawequal(key, "{{Method}}") and
		typeof(value) == "function" and
		not checkcaller()
	) then
		Callback = value
	end

	return mtHook(...)
end)]]

HookTemplates.IncomingSignalConnections = [[{{Prelude}}{{Path}}
for _, Connection in getconnections(Event.{{Method}}) do
	local old; old = hookfunction(Connection.Function, function(...)
		print(`Intercepted (Connection) {Event.Name}.{{Method}}`, ...)
		return old(...)
	end)
end]]

HookTemplates.OutgoingRemoteCall = [[{{Prelude}}{{Path}}
local mtHook; mtHook = hookmetamethod(game, "__namecall", function(...)
	local self = ...

	if rawequal(self, Event) and getnamecallmethod() == "{{Method}}" then
		local Args = table.pack(...)
		
		local Result = table.pack(
			mtHook(self, table.unpack(Args, 1, Args.n))
		)

		print(`Intercepted (__namecall) {Event.Name}:{{Method}}()`, ...)

		return table.unpack(Result, 1, Result.n)
	end

	return mtHook(...)
end)

local Old{{Method}}; Old{{Method}} = hookfunction(Event.{{Method}}, function(...)
	local self = ...

	if rawequal(self, Event) then
		local Args = table.pack(...)

		local Result = table.pack(
			Old{{Method}}(table.unpack(Args, 1, Args.n))
		)

		print(`Intercepted (__index) {Event.Name}:{{Method}}()`, self, table.unpack(Result, 1, Result.n))

		return table.unpack(Result, 1, Result.n)
	end

	return Old{{Method}}(self, ...)
end)]]

HookTemplates.Incoming = {
	SSE = {
		Callback = HookTemplates.IncomingCallbackReturn,
		Default = HookTemplates.IncomingCallbackValue,
	},
	Request = HookTemplates.IncomingRequestReturn,
	Signal = HookTemplates.IncomingSignalConnections,
}

HookTemplates.Outgoing = HookTemplates.OutgoingRemoteCall

return HookTemplates
