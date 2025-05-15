local Hooking = {}

Hooking.HookFunction = hookfunction

Hooking.HookMetaMethod = function(object, method, hook)
	local UseAltHooks = wax.shared.SaveManager:GetState("UseAlternativeHooks")
	local alternativeEnabled = type(UseAltHooks) ~= "Boolean" and false or UseAltHooks
    if alternativeEnabled then
        local Metatable = wax.shared.getrawmetatable(object)
	    local originalMethod = rawget(Metatable, method)
	
	    setreadonly(Metatable, false)
	    rawset(Metatable, method, wax.shared.newcclosure(hook))
	    setreadonly(Metatable, true)

	    return originalMethod;
    end

	return hookmetamethod(object, method, hook);
end

return Hooking