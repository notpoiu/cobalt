local Hooking = {
	IncludeInStackFunctions = {},
}

local AlternativeEnabled = wax.shared.SaveManager:GetState("UseAlternativeHooks", false)
wax.shared.AlternativeEnabled = AlternativeEnabled
wax.shared.CobaltLuaSetStackHidden = false

Hooking.HookFunction = function(Original, Replacement)
	if not wax.shared.ExecutorSupport["hookfunction"].IsWorking then
		return Original
	end

	return hookfunction(Original, Replacement)
end
Hooking.HookMetaMethod = function(object, method, hook)
	if
		AlternativeEnabled
		or (
			not wax.shared.ExecutorSupport["hookmetamethod"].IsWorking
			and wax.shared.ExecutorSupport["getrawmetatable"].IsWorking
		)
	then
		local Metatable = wax.shared.getrawmetatable(object)
		local originalMethod = rawget(Metatable, method)

		setreadonly(Metatable, false)
		rawset(Metatable, method, hook)
		setreadonly(Metatable, true)

		return originalMethod
	end

	if not wax.shared.ExecutorSupport["hookmetamethod"].IsWorking then
		if method == "__index" then
			local _, Metamethod = xpcall(function()
				return object[tostring(math.random())]
			end, function(err)
				return debug.info(2, "f")
			end)

			return Metamethod
		elseif method == "__newindex" then
			local _, Metamethod = xpcall(function()
				object[tostring(math.random())] = true
			end, function(err)
				return debug.info(2, "f")
			end)

			return Metamethod
		elseif method == "__namecall" then
			local _, Metamethod = xpcall(function()
				object:Mustard()
			end, function(err)
				return debug.info(2, "f")
			end)

			return Metamethod
		end

		return nil
	end

	return hookmetamethod(object, method, hook)
end

return Hooking
