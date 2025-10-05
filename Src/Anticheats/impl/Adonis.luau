local Adonis = {
	Name = "Adonis",
	Game = "*",
}

local AdonisAnticheatThreads = {}
function Adonis.Detect()
	if not getreg or not getgc or not isfunctionhooked then
		return false
	end

	local AdonisDetected = false

	for _, thread in getreg() do
		if typeof(thread) ~= "thread" then
			continue
		end

		local Source = debug.info(thread, 1, "s")
		if Source and (Source:match(".Core.Anti") or Source:match(".Plugins.Anti_Cheat")) then
			AdonisDetected = true
			table.insert(AdonisAnticheatThreads, thread)
		end
	end

	return AdonisDetected
end

function Adonis.Bypass()
	for _, thread in AdonisAnticheatThreads do
		pcall(coroutine.close, thread)
	end

	for _, value in getgc(true) do
		if typeof(value) ~= "table" then
			continue
		end

		local IsAdonisOrigin = typeof(rawget(value, "Detected")) == "function" and rawget(value, "RLocked")
		if IsAdonisOrigin then
			for _, DetectionFunc in value do
				-- Just in case they already loaded a custom anticheat bypass for adonis
				if typeof(DetectionFunc) ~= "function" or isfunctionhooked(DetectionFunc) then
					continue
				end

				wax.shared.Hooks[DetectionFunc] = wax.shared.Hooking.HookFunction(
					DetectionFunc,
					function(action, info, nocrash)
						coroutine.yield(coroutine.running())
						return task.wait(9e9)
					end
				)
			end
		end
	end

	return true
end

return Adonis
