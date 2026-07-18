local Hooking = {}

Hooking.HookFunction = function(Original, Replacement, Filter)
	if
		wax.shared.IsUsingOthHooks
		and iscclosure(Original)
	then
		return oth.hook(Original, Replacement, Filter)
	end

	if islclosure(Replacement) then
		Replacement = wax.shared.newcclosure(Replacement)
	end

	if not wax.shared.ExecutorSupport["hookfunction"].IsWorking then
		return Original
	end

	return hookfunction(Original, Replacement, Filter)
end

Hooking.HookMetaMethod = function(object, method, hook, filter)
	local Metatable = wax.shared.getrawmetatable(object)
	local originalMethod = rawget(Metatable, method)

	assert(typeof(originalMethod) == "function", `{method} is not a function in the metatable of {object}`)

	if wax.shared.IsUsingOthHooks then
		return oth.hook(originalMethod, hook, filter)
	end

	if islclosure(hook) then
		hook = wax.shared.newcclosure(hook)
	end

	if
		not wax.shared.ExecutorSupport["hookmetamethod"].IsWorking
		and wax.shared.ExecutorSupport["getrawmetatable"].IsWorking
	then
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

	if filter then
		return hookmetamethod(object, method, hook, true, filter)
	end
	
	return hookmetamethod(object, method, hook)
end

return Hooking
